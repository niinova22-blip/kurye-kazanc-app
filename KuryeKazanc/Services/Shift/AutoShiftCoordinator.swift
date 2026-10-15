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
    /// Bugun kaydedilmis kayitlarin calisma suresi (suren vardiya haric): ~TL/saat tahmini icin.
    @ObservationIgnored private let todayWorkedSeconds: () -> TimeInterval
    /// nil: gercek "Her zaman" izni (`location.hasAlwaysAuthorization`). Testler enjekte eder.
    @ObservationIgnored private let permissionCheck: (() -> Bool)?
    @ObservationIgnored private let throttle = LiveActivityThrottle()
    @ObservationIgnored private var lastActivityUpdate: Date?
    @ObservationIgnored private var lastActivityMeters: Double = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isDeciding = false
    /// "Her zaman" yukseltmesi bu etkinlestirmede istendi mi (her etkinlestirmede bir kez).
    @ObservationIgnored private var alwaysUpgradeRequested = false
    /// Son degerlendirmede (tick) gorulen son hareket. Surec oluyken gecen uzun duraganlik sonrasi
    /// gelen ilk GPS hareketi bununla ayirt edilir. Acilista kayitli son hareketle baslar.
    @ObservationIgnored private var observedLastMovement: Date?
    /// 1.12: paket sayilan canli vardiyanin anlik durumu (Canli Etkinlikte paket sayisi ve brut). nil: canli vardiya yok.
    @ObservationIgnored var liveShiftSnapshot: (() -> (packages: Int, gross: Double, region: String?)?)?
    /// Otomatik vardiya basladi: paket sayma (canli vardiya) da baslar, kilit ekranindan "+1 paket" calisir.
    @ObservationIgnored var onAutoShiftStarted: (() -> Void)?
    /// Otomatik vardiya duraganliktan bitti. true donerse canli vardiya kaydedildi: bekleyen vardiya olusturulmaz.
    @ObservationIgnored var onAutoShiftFinished: ((WorkSessionSummary) -> Bool)?
    /// "Bu bir vardiya değil": otomatik baslayan canli vardiya da kayitsiz kapanir.
    @ObservationIgnored var onAutoShiftCancelled: (() -> Void)?
    /// 1.12.1: kilit ekraninda "Bitir"e basildi, onay bekleniyor.
    @ObservationIgnored private var isConfirmingEnd = false
    /// Son hareket bundan yeniyse (GPS hareketi zaten kanitliyor) hareket gecmisi sorgulanmaz.
    @ObservationIgnored private let motionRefreshMinAge: TimeInterval = 60

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
        todayWorkedSeconds: @escaping () -> TimeInterval = { 0 },
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
        self.todayWorkedSeconds = todayWorkedSeconds
        self.permissionCheck = permissionCheck
        self.isEnabled = defaults.bool(forKey: AppPreferences.autoShiftEnabledKey)
        let stored = PendingShiftList.decode(defaults.data(forKey: AppPreferences.pendingShiftsKey))
        self.pendingShifts = PendingShiftList.pruned(stored, now: clock())
        self.observedLastMovement = location.lastMovementDate
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
        installLocationHandlers()
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
        installLocationHandlers()
        isEnabled = true
        defaults.set(true, forKey: AppPreferences.autoShiftEnabledKey)
        // "Kullanirken" zaten verilmisse bu cagri dogrudan yukseltmeyi ister; degilse once "Kullanirken"
        // istenir, yukseltme izin degisikliginde (handleAuthorizationChange) istenir.
        alwaysUpgradeRequested = location.authorizationStatus == .authorizedWhenInUse
        location.requestAlwaysAuthorization()
        _ = await notifier.requestAccess()
        location.startSignificantChangeMonitoring()
        // Izin diyalogu asenkron: anahtar acik kalir, "Her zaman" gelene kadar uyari gosterilir
        refreshPermissionProblem()
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
        refreshPermissionProblem()
        if workSession.isWorking {
            if workSession.origin == .auto {
                // Surec oluyken (zamanlayici yok) 20 dk'yi asan duraganlik: yeni surus eski vardiyaya eklenmez
                if endIfMovementResumedAfterGap() { return }
                let now = clock()
                if now.timeIntervalSince(effectiveLastMovement(now: now)) >= motionRefreshMinAge {
                    await refreshMovementFromMotion()
                }
            }
            tick()
            return
        }
        guard isEnabled, !isDeciding, permissionProblem == nil else { return }
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
        onAutoShiftStarted?()
    }

    /// Suren vardiya: Canli Etkinligi gunceller; otomatik vardiyada duraganligi denetler.
    func tick() {
        guard workSession.isWorking else {
            stopTimer()
            return
        }
        let now = clock()
        if workSession.origin == .auto {
            let lastMovement: Date = effectiveLastMovement(now: now)
            if policy.shouldStop(lastMovement: lastMovement, now: now) {
                finishAutoShift(end: lastMovement)
                return
            }
            observedLastMovement = lastMovement
        }
        pushActivityUpdate(now: now)
    }

    /// Arka planda baslayan vardiyada ActivityKit istegi basarisiz olabilir (uygulama on planda degil).
    /// On plana donuste suren vardiyanin Canli Etkinligi yoksa acilir; varsa yalnizca guncellenir.
    func ensureLiveActivity() {
        guard workSession.isWorking, let start = workSession.sessionStart else { return }
        liveActivity.begin(start: start, isAuto: workSession.origin == .auto, state: currentState(endedAt: nil))
    }

    /// Paket eklendi / geri alindi: Canli Etkinlik kisitlamasiz hemen guncellenir (kilit ekranindaki sayi aninda artsin).
    func liveShiftChanged() {
        guard workSession.isWorking else { return }
        isConfirmingEnd = false
        lastActivityUpdate = clock()
        lastActivityMeters = workSession.location.sessionDistanceMeters
        ensureLiveActivity()
    }

    /// Kilit ekrani "Bitir": Canli Etkinlik "Emin misin?" gorunumune gecer.
    func requestEndConfirmation() {
        guard workSession.isWorking else { return }
        isConfirmingEnd = true
        lastActivityUpdate = clock()
        ensureLiveActivity()
    }

    func cancelEndConfirmation() {
        guard isConfirmingEnd else { return }
        isConfirmingEnd = false
        lastActivityUpdate = clock()
        ensureLiveActivity()
    }

    // MARK: - Kullanici eylemleri

    func startManualShift() {
        beginShift(at: clock(), origin: .manual)
    }

    /// Bugun ekrani "Vardiyayi bitir": ozet dogrudan acilan kazanc formunu doldurur.
    @discardableResult
    func endShift() -> WorkSessionSummary? {
        guard workSession.isWorking else { return nil }
        isConfirmingEnd = false
        let state = currentState(endedAt: clock())
        let summary = workSession.stop(now: clock())
        stopTimer()
        liveActivity.finish(state)
        notifier.clearAutoShiftStarted()
        return summary
    }

    /// Canli Etkinlik "Vardiyayi bitir": form acilamaz (uygulama arka planda olabilir), ozet
    /// bekleyen vardiya olarak saklanir ve "Vardiya bitti" bildirimi gider. Kullanici acikca
    /// bitirdigi icin kisa vardiya filtresi uygulanmaz: her zaman kazanc formuna ulasir (spec).
    @discardableResult
    func endShiftToPending() -> PendingShift? {
        guard let summary = endShift() else { return nil }
        return storeEndedShift(summary)
    }

    func cancelAutoShift() {
        guard workSession.isWorking, workSession.origin == .auto else { return }
        workSession.cancel()
        stopTimer()
        liveActivity.dismiss()
        notifier.clearAutoShiftStarted()
        defaults.set(clock(), forKey: AppPreferences.lastAutoCancelKey)
        onAutoShiftCancelled?()
    }

    /// Bekleyen vardiyanin ozeti; listeden SILMEZ. Kazanc kaydedilene kadar bekleyen kalir (spec 3):
    /// form vazgecilerek kapanirsa sure/km kaybolmaz. Kayitta dismissPending(id:) cagrilir.
    func pendingSummary(id: UUID) -> WorkSessionSummary? {
        pendingShifts.first(where: { $0.id == id })?.summary
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
        isConfirmingEnd = false
        workSession.start(at: start, origin: origin)
        lastActivityUpdate = nil
        lastActivityMeters = 0
        observedLastMovement = nil
        liveActivity.begin(start: start, isAuto: origin == .auto, state: currentState(endedAt: nil))
        startTimer()
    }

    private func finishAutoShift(end: Date) {
        let state = currentState(endedAt: end)
        guard let summary = workSession.stop(now: clock(), end: end) else { return }
        stopTimer()
        notifier.clearAutoShiftStarted()
        // Paket sayilan vardiya kendiliginden hesaplanip kaydedildiyse bekleyen vardiya gerekmez
        if let handler = onAutoShiftFinished, handler(summary) {
            liveActivity.finish(state)
            return
        }
        let duration = summary.end.timeIntervalSince(summary.start)
        if policy.isTooShort(duration: duration, distanceKm: summary.distanceKm) {
            // Kayit yok: ozet de gosterilmez
            liveActivity.dismiss()
            return
        }
        liveActivity.finish(state)
        storeEndedShift(summary)
    }

    /// Biten vardiyayi bekleyen listeye yazar, "Vardiya bitti" bildirimini gonderir ve bolgeyi
    /// arka planda ekler. Otomatik bitis ve Canli Etkinlik "bitir" ortak kullanir.
    @discardableResult
    private func storeEndedShift(_ summary: WorkSessionSummary) -> PendingShift {
        let pending = PendingShift(
            id: UUID(), start: summary.start, end: summary.end, distanceKm: summary.distanceKm,
            createdAt: clock(), province: nil, district: nil, neighborhood: nil
        )
        storePending(PendingShiftList.adding(pending, to: pendingShifts, now: clock()))
        notifier.shiftEnded(pending)
        if let last = summary.lastLocation {
            Task { await self.attachRegion(to: pending.id, from: last) }
        }
        return pending
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
        // Bitmis vardiyada bitis ani (son hareket) kullanilir: 20 dk bekleme sayilmaz
        let end: Date = endedAt ?? clock()
        let elapsed: TimeInterval = workSession.sessionStart.map { end.timeIntervalSince($0) } ?? 0
        let perHour = TodayViewModel.liveNetPerHour(
            todayNet: net, workedSeconds: todayWorkedSeconds(), elapsed: elapsed
        )
        let live = liveShiftSnapshot?()
        return ShiftActivityAttributes.ContentState(
            distanceKm: workSession.sessionDistanceKm, todayNet: net, netPerHour: perHour, endedAt: endedAt,
            packages: live?.packages, shiftGross: live?.gross, region: live?.region,
            confirmingEnd: isConfirmingEnd && endedAt == nil ? true : nil
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

    private func installLocationHandlers() {
        location.onLocationEvent = { [weak self] in
            guard let self else { return }
            Task { await self.handleWake() }
        }
        location.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
        }
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        if isEnabled, status == .authorizedWhenInUse, !alwaysUpgradeRequested {
            alwaysUpgradeRequested = true
            location.requestAlwaysAuthorization()
        }
        refreshPermissionProblem()
    }

    /// Acikken once "Her zaman", sonra Hareket izni denetlenir. Mod kapaliyken yalnizca basarisiz
    /// enable() sonrasi kalan "Ayarlar'dan ac" uyarisi (.motion), izin Ayarlar'dan verilince temizlenir.
    private func refreshPermissionProblem() {
        guard isEnabled else {
            if permissionProblem == .motion, motion.isAuthorized {
                permissionProblem = nil
            }
            return
        }
        let problem: PermissionProblem?
        if !hasAlwaysPermission {
            problem = .locationAlways
        } else if !motion.isAuthorized {
            problem = .motion
        } else {
            problem = nil
        }
        if problem != permissionProblem {
            permissionProblem = problem
        }
    }

    /// Bu vardiyadaki son hareket. Onceki vardiyadan kalan eski zaman baslangictan once sayilmaz.
    private func effectiveLastMovement(now: Date) -> Date {
        let sessionStart: Date = workSession.sessionStart ?? now
        let recorded: Date = location.lastMovementDate ?? sessionStart
        return max(recorded, sessionStart)
    }

    /// Son tick'ten bu yana GPS son hareketi 20 dk'den fazla ileri attiysa arada surec olu/askida
    /// kalmis demektir (canli olsaydi tick vardiyayi bitirirdi). Vardiya aradan onceki son harekette biter.
    /// - Returns: Vardiya bittiyse true.
    private func endIfMovementResumedAfterGap() -> Bool {
        guard workSession.isWorking, workSession.origin == .auto, let sessionStart = workSession.sessionStart else { return false }
        let now = clock()
        let previous: Date = max(observedLastMovement ?? sessionStart, sessionStart)
        let latest: Date = effectiveLastMovement(now: now)
        guard latest.timeIntervalSince(previous) >= policy.stationaryLimit else { return false }
        finishAutoShift(end: previous)
        return true
    }

    /// Bitirme kurali "50 m konum degisimi ya da hareket ornegi" der: GPS hareket gormese de
    /// son hareketten sonra baslayan bir arac/bisiklet ornegi son hareket zamanini ileri alir.
    /// Ornekler arasinda 20 dk'yi asan bosluk varsa (surec oluyken duraganlik) vardiya boslugun
    /// basinda biter; sonraki surus eski vardiyaya eklenmez.
    private func refreshMovementFromMotion() async {
        guard let sessionStart = workSession.sessionStart else { return }
        let queryFrom: Date = effectiveLastMovement(now: clock())
        let samples: [MotionSample] = await motion.samples(from: queryFrom, to: clock())
        // Bekleme sirasinda vardiya bitmis ya da degismis olabilir
        guard workSession.isWorking, workSession.sessionStart == sessionStart, workSession.origin == .auto else { return }
        let now = clock()
        // Bekleme sirasinda GPS hareketi ileri almis olabilir: en yeni son hareketten bakilir
        let lastMovement: Date = effectiveLastMovement(now: now)
        let sorted: [MotionSample] = samples
            .filter { $0.start > lastMovement && $0.start <= now }
            .sorted { $0.start < $1.start }

        // Hareketin en son goruldugu an: hareket ornegi bir sonraki ornege kadar surer; son ornegin
        // yalnizca baslangici kesindir.
        var seenUntil: Date = lastMovement
        var sawMovement = false
        for index in sorted.indices where sorted[index].isMoving {
            let sample = sorted[index]
            if sample.start.timeIntervalSince(seenUntil) >= policy.stationaryLimit {
                finishAutoShift(end: seenUntil)
                return
            }
            let until: Date = index + 1 < sorted.count ? sorted[index + 1].start : sample.start
            seenUntil = max(seenUntil, until)
            sawMovement = true
        }
        guard sawMovement else { return }
        if let current = location.lastMovementDate, current >= seenUntil { return }
        location.markMovement(at: seenUntil)
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
            Task { @MainActor in await self.timerFired() }
        }
    }

    /// Zamanlayici: hareket gecmisini de denetlemek icin handleWake uzerinden gecer.
    private func timerFired() async {
        guard workSession.isWorking else {
            stopTimer()
            return
        }
        await handleWake()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
