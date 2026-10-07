import Foundation
import CoreLocation
import Observation

extension PendingShift {
    var summary: WorkSessionSummary {
        let region = PlaceRegion(province: province, district: district, neighborhood: neighborhood)
        return WorkSessionSummary(start: start, end: end, distanceKm: distanceKm, lastLocation: nil, region: region)
    }
}

/// Otomatik vardiyanin merkezi (spec 3-4). Tum vardiya baslatma/bitirme buradan gecer ki
/// Canli Etkinlik ve bildirimler her yolda ayni kalsin.
@MainActor
@Observable
final class AutoShiftCoordinator {
    enum PermissionProblem: Equatable {
        case motion, locationAlways
    }

    private(set) var isEnabled: Bool
    private(set) var pendingShifts: [PendingShift]
    private(set) var permissionProblem: PermissionProblem?
    /// "Vardiya bitti" bildirimine dokunulunca Bugun ekrani bu bekleyen vardiyanin formunu acar.
    var requestedPendingID: UUID?

    @ObservationIgnored let workSession: WorkSessionManager
    @ObservationIgnored private let location: LocationService
    @ObservationIgnored private let motion: MotionActivityProviding
    @ObservationIgnored private let notifier: ShiftNotifying
    @ObservationIgnored private let liveActivity: LiveActivityControlling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let policy: AutoShiftPolicy
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let todayNet: () -> Double
    /// nil: gercek "Her zaman" izni (`location.hasAlwaysAuthorization`). Testler enjekte eder.
    @ObservationIgnored private let permissionCheck: (() -> Bool)?
    @ObservationIgnored private let throttle = LiveActivityThrottle()
    @ObservationIgnored private var lastActivityUpdate: Date?
    @ObservationIgnored private var lastActivityMeters: Double = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isDeciding = false

    init(
        workSession: WorkSessionManager,
        location: LocationService,
        motion: MotionActivityProviding,
        notifier: ShiftNotifying,
        liveActivity: LiveActivityControlling,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        policy: AutoShiftPolicy = AutoShiftPolicy(),
        clock: @escaping () -> Date = { Date() },
        todayNet: @escaping () -> Double = { 0 },
        permissionCheck: (() -> Bool)? = nil
    ) {
        self.workSession = workSession
        self.location = location
        self.motion = motion
        self.notifier = notifier
        self.liveActivity = liveActivity
        self.defaults = defaults
        self.calendar = calendar
        self.policy = policy
        self.clock = clock
        self.todayNet = todayNet
        self.permissionCheck = permissionCheck
        self.isEnabled = defaults.bool(forKey: AppPreferences.autoShiftEnabledKey)
        let stored = PendingShiftList.decode(defaults.data(forKey: AppPreferences.pendingShiftsKey))
        self.pendingShifts = PendingShiftList.pruned(stored, now: clock())
    }

    private var hasAlwaysPermission: Bool {
        if let permissionCheck { return permissionCheck() }
        return location.hasAlwaysAuthorization
    }

    var workHours: WorkHours {
        get { WorkHours.decode(defaults.data(forKey: AppPreferences.workHoursKey)) }
        set { defaults.set(newValue.encoded(), forKey: AppPreferences.workHoursKey) }
    }

    // MARK: - Yasam dongusu

    /// Uygulama acilisi veya arka planda yeniden baslatma: izlemeyi ve suren vardiyayi kurar.
    func resume() {
        location.onLocationEvent = { [weak self] in
            guard let self else { return }
            Task { await self.handleWake() }
        }
        if isEnabled {
            location.startSignificantChangeMonitoring()
        }
        workSession.resumeIfNeeded()
        if workSession.isWorking {
            startTimer()
        }
        refreshPending()
    }

    func enable() async -> Bool {
        guard motion.isAvailable, await motion.requestAccess() else {
            permissionProblem = .motion
            return false
        }
        location.requestAlwaysAuthorization()
        _ = await notifier.requestAccess()
        isEnabled = true
        defaults.set(true, forKey: AppPreferences.autoShiftEnabledKey)
        location.startSignificantChangeMonitoring()
        permissionProblem = hasAlwaysPermission ? nil : .locationAlways
        return true
    }

    func disable() {
        isEnabled = false
        permissionProblem = nil
        defaults.set(false, forKey: AppPreferences.autoShiftEnabledKey)
        location.stopSignificantChangeMonitoring()
    }

    // MARK: - Karar

    /// Konum olayi, zamanlayici veya uygulama acilisi.
    func handleWake() async {
        refreshPending()
        if workSession.isWorking {
            tick()
            return
        }
        guard isEnabled, !isDeciding else { return }
        guard hasAlwaysPermission else {
            permissionProblem = .locationAlways
            return
        }
        guard motion.isAuthorized else {
            permissionProblem = .motion
            return
        }
        permissionProblem = nil
        isDeciding = true
        defer { isDeciding = false }

        let now = clock()
        let samples: [MotionSample] = await motion.samples(from: now.addingTimeInterval(-policy.lookback), to: now)
        let lastCancel = defaults.object(forKey: AppPreferences.lastAutoCancelKey) as? Date
        let decision = policy.startDecision(samples: samples, now: now, workHours: workHours, calendar: calendar, lastCancel: lastCancel)
        // Bekleme sirasinda kullanici modu kapatmis ya da elle vardiya baslatmis olabilir
        guard case .start(let start) = decision, isEnabled, !workSession.isWorking else { return }
        beginShift(at: start, origin: .auto)
        notifier.autoShiftStarted()
    }

    /// Suren vardiya: Canli Etkinligi gunceller; otomatik vardiyada duraganligi denetler.
    func tick() {
        guard workSession.isWorking else {
            stopTimer()
            return
        }
        let now = clock()
        if workSession.origin == .auto {
            let sessionStart: Date = workSession.sessionStart ?? now
            // Onceki vardiyadan kalan eski hareket zamani bu vardiyanin baslangicindan once sayilmaz
            let recorded: Date = location.lastMovementDate ?? sessionStart
            let lastMovement: Date = max(recorded, sessionStart)
            if policy.shouldStop(lastMovement: lastMovement, now: now) {
                finishAutoShift(end: lastMovement)
                return
            }
        }
        pushActivityUpdate(now: now)
    }

    // MARK: - Kullanici eylemleri

    func startManualShift() {
        beginShift(at: clock(), origin: .manual)
    }

    /// Bugun ekrani veya Canli Etkinlik "Vardiyayi bitir". Ozet kazanc formunu doldurur.
    @discardableResult
    func endShift() -> WorkSessionSummary? {
        guard workSession.isWorking else { return nil }
        let state = currentState(endedAt: clock())
        let summary = workSession.stop(now: clock())
        stopTimer()
        liveActivity.finish(state)
        notifier.clearAutoShiftStarted()
        return summary
    }

    func cancelAutoShift() {
        guard workSession.isWorking, workSession.origin == .auto else { return }
        workSession.cancel()
        stopTimer()
        liveActivity.finish(currentState(endedAt: clock()))
        notifier.clearAutoShiftStarted()
        defaults.set(clock(), forKey: AppPreferences.lastAutoCancelKey)
    }

    func takePending(id: UUID) -> WorkSessionSummary? {
        guard let shift = pendingShifts.first(where: { $0.id == id }) else { return nil }
        removePending(id: id)
        return shift.summary
    }

    func dismissPending(id: UUID) {
        removePending(id: id)
    }

    // MARK: - Ic

    private func beginShift(at start: Date, origin: ShiftOrigin) {
        workSession.start(at: start, origin: origin)
        lastActivityUpdate = nil
        lastActivityMeters = 0
        liveActivity.begin(start: start, isAuto: origin == .auto, state: currentState(endedAt: nil))
        startTimer()
    }

    private func finishAutoShift(end: Date) {
        let state = currentState(endedAt: end)
        guard let summary = workSession.stop(now: clock(), end: end) else { return }
        stopTimer()
        liveActivity.finish(state)
        notifier.clearAutoShiftStarted()
        let duration = summary.end.timeIntervalSince(summary.start)
        if policy.isTooShort(duration: duration, distanceKm: summary.distanceKm) { return }

        let pending = PendingShift(
            id: UUID(), start: summary.start, end: summary.end, distanceKm: summary.distanceKm,
            createdAt: clock(), province: nil, district: nil, neighborhood: nil
        )
        storePending(PendingShiftList.adding(pending, to: pendingShifts, now: clock()))
        notifier.shiftEnded(pending)
        if let last = summary.lastLocation {
            Task { await self.attachRegion(to: pending.id, from: last) }
        }
    }

    private func attachRegion(to id: UUID, from last: CLLocation) async {
        guard let region = await location.region(for: last) else { return }
        var list = pendingShifts
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].province = region.province
        list[index].district = region.district
        list[index].neighborhood = region.neighborhood
        storePending(list)
    }

    private func currentState(endedAt: Date?) -> ShiftActivityAttributes.ContentState {
        let net = todayNet()
        let worked: TimeInterval = workSession.sessionStart.map { clock().timeIntervalSince($0) } ?? 0
        let perHour = TodayViewModel.liveNetPerHour(todayNet: net, workedSeconds: 0, elapsed: worked)
        return ShiftActivityAttributes.ContentState(
            distanceKm: workSession.sessionDistanceKm, todayNet: net, netPerHour: perHour, endedAt: endedAt
        )
    }

    private func pushActivityUpdate(now: Date) {
        let meters = workSession.location.sessionDistanceMeters
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard throttle.shouldUpdate(lastUpdate: lastActivityUpdate, lastDistanceMeters: lastActivityMeters,
                                    now: now, distanceMeters: meters, isLowPower: lowPower) else { return }
        lastActivityUpdate = now
        lastActivityMeters = meters
        liveActivity.update(currentState(endedAt: nil))
    }

    private func refreshPending() {
        let pruned = PendingShiftList.pruned(pendingShifts, now: clock())
        if pruned != pendingShifts { storePending(pruned) }
    }

    private func removePending(id: UUID) {
        storePending(pendingShifts.filter { $0.id != id })
    }

    private func storePending(_ list: [PendingShift]) {
        pendingShifts = list
        defaults.set(PendingShiftList.encode(list), forKey: AppPreferences.pendingShiftsKey)
    }

    /// Konum guncellemesi gelmese de (duragan) 60 sn'de bir karar verilir.
    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
