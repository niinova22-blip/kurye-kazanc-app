import XCTest
@testable import KuryeKazanc

@MainActor
final class AutoShiftCoordinatorTests: XCTestCase {
    final class FakeMotion: MotionActivityProviding {
        var isAvailable = true
        var isAuthorized = true
        var list: [MotionSample] = []
        func requestAccess() async -> Bool { isAuthorized }
        func samples(from start: Date, to end: Date) async -> [MotionSample] { list }
    }

    final class FakeNotifier: ShiftNotifying {
        var started = 0, cleared = 0
        var ended: [PendingShift] = []
        func requestAccess() async -> Bool { true }
        func autoShiftStarted() { started += 1 }
        func clearAutoShiftStarted() { cleared += 1 }
        func shiftEnded(_ shift: PendingShift) { ended.append(shift) }
    }

    @MainActor
    final class FakeActivity: LiveActivityControlling {
        var begun = 0, updates = 0, finished = 0, dismissed = 0
        func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState) { begun += 1 }
        func update(_ state: ShiftActivityAttributes.ContentState) { updates += 1 }
        func finish(_ state: ShiftActivityAttributes.ContentState) { finished += 1 }
        func dismiss() { dismissed += 1 }
    }

    private var now = Date(timeIntervalSince1970: 1_800_000_000)
    private var defaults: UserDefaults!
    private var motion: FakeMotion!
    private var notifier: FakeNotifier!
    private var activity: FakeActivity!
    private var workSession: WorkSessionManager!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "coordinator-\(UUID())")!
        motion = FakeMotion()
        notifier = FakeNotifier()
        activity = FakeActivity()
        workSession = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
    }

    private func makeCoordinator(enabled: Bool = true) -> AutoShiftCoordinator {
        defaults.set(enabled, forKey: AppPreferences.autoShiftEnabledKey)
        let always = WorkHours(isAlways: true, startMinute: 0, endMinute: 0)
        defaults.set(always.encoded(), forKey: AppPreferences.workHoursKey)
        return AutoShiftCoordinator(
            workSession: workSession, location: workSession.location, motion: motion, notifier: notifier,
            liveActivity: activity, defaults: defaults, policy: AutoShiftPolicy(), clock: { [unowned self] in self.now },
            todayNet: { 500 }, permissionCheck: { true }
        )
    }

    private func driving(minutes: Double) {
        motion.list = [MotionSample(start: now.addingTimeInterval(-minutes * 60), kind: .automotive, confidence: .high)]
    }

    func testWakeStartsAutoShiftAndNotifies() async {
        let coordinator = makeCoordinator()
        driving(minutes: 4)
        await coordinator.handleWake()
        XCTAssertTrue(workSession.isWorking)
        XCTAssertEqual(workSession.origin, .auto)
        XCTAssertEqual(workSession.sessionStart, now.addingTimeInterval(-240))
        XCTAssertEqual(notifier.started, 1)
        XCTAssertEqual(activity.begun, 1)
    }

    func testDisabledDoesNothing() async {
        let coordinator = makeCoordinator(enabled: false)
        driving(minutes: 10)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
    }

    func testCancelLeavesNoTraceAndCoolsDown() async {
        let coordinator = makeCoordinator()
        driving(minutes: 4)
        await coordinator.handleWake()
        coordinator.cancelAutoShift()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertTrue(coordinator.pendingShifts.isEmpty)
        XCTAssertEqual(activity.dismissed, 1, "Iptalde ozet gosterilmez")
        XCTAssertEqual(activity.finished, 0)

        now = now.addingTimeInterval(600)
        driving(minutes: 5)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking, "30 dk bekleme")
    }

    func testStationaryTwentyMinutesEndsOnTimerTickWithPending() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let start = workSession.sessionStart!
        workSession.location.markMovement(at: start.addingTimeInterval(1500))
        now = start.addingTimeInterval(1500 + 1200)
        coordinator.tick()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.pendingShifts.count, 1)
        XCTAssertEqual(coordinator.pendingShifts.first?.end, start.addingTimeInterval(1500), "Bitis son hareket ani")
        XCTAssertEqual(notifier.ended.count, 1)
    }

    func testTooShortAutoShiftIsDiscardedSilently() async {
        let coordinator = makeCoordinator()
        driving(minutes: 3.5)
        await coordinator.handleWake()
        let start = workSession.sessionStart!
        workSession.location.markMovement(at: start.addingTimeInterval(200))
        now = start.addingTimeInterval(200 + 1200)
        coordinator.tick()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertTrue(coordinator.pendingShifts.isEmpty)
        XCTAssertTrue(notifier.ended.isEmpty)
        XCTAssertEqual(activity.dismissed, 1)
        XCTAssertEqual(activity.finished, 0)
    }

    func testManualShiftNeverAutoEnds() async {
        let coordinator = makeCoordinator()
        coordinator.startManualShift()
        workSession.location.markMovement(at: now)
        now = now.addingTimeInterval(7200)
        coordinator.tick()
        await coordinator.handleWake()
        XCTAssertTrue(workSession.isWorking)
        XCTAssertEqual(workSession.origin, .manual)
    }

    func testTakePendingReturnsSummaryAndRemoves() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        workSession.location.markMovement(at: now)
        now = now.addingTimeInterval(1300)
        coordinator.tick()
        let id = coordinator.pendingShifts[0].id
        let summary = coordinator.takePending(id: id)
        XCTAssertNotNil(summary)
        XCTAssertTrue(coordinator.pendingShifts.isEmpty)
    }

    func testMissingPermissionReportsProblem() async {
        defaults.set(true, forKey: AppPreferences.autoShiftEnabledKey)
        let coordinator = AutoShiftCoordinator(
            workSession: workSession, location: workSession.location, motion: motion, notifier: notifier,
            liveActivity: activity, defaults: defaults, clock: { [unowned self] in self.now },
            todayNet: { 0 }, permissionCheck: { false }
        )
        driving(minutes: 10)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.permissionProblem, .locationAlways)
    }

    func testStaleLastMovementDoesNotEndNewShiftInstantly() async {
        let coordinator = makeCoordinator()
        // Onceki vardiyadan kalan eski hareket zamani
        workSession.location.markMovement(at: now.addingTimeInterval(-7200))
        driving(minutes: 4)
        await coordinator.handleWake()
        XCTAssertTrue(workSession.isWorking)
        now = now.addingTimeInterval(60)
        coordinator.tick()
        XCTAssertTrue(workSession.isWorking, "Son hareket vardiya baslangicindan once sayilmaz")
    }

    func testMotionSampleAfterLastMovementKeepsShiftAlive() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let start = workSession.sessionStart!
        workSession.location.markMovement(at: start)
        // GPS 50 m gormedi ama 15. dakikada arac hareketi var
        motion.list = [MotionSample(start: start.addingTimeInterval(900), kind: .automotive, confidence: .high)]
        now = start.addingTimeInterval(1500)
        await coordinator.handleWake()
        XCTAssertTrue(workSession.isWorking)
        XCTAssertEqual(workSession.location.lastMovementDate, start.addingTimeInterval(900))

        // Ayni ornek artik son hareketten sonra degil: hareketi tazelemez, 20 dk dolunca biter
        now = start.addingTimeInterval(900 + 1200)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.pendingShifts.first?.end, start.addingTimeInterval(900))
        XCTAssertEqual(activity.finished, 1)
    }

    func testLiveActivityEndStoresPendingAndNotifies() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let start = workSession.sessionStart!
        now = now.addingTimeInterval(120)
        let pending = coordinator.endShiftToPending()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertNotNil(pending)
        XCTAssertEqual(coordinator.pendingShifts.count, 1)
        XCTAssertEqual(coordinator.pendingShifts.first?.start, start)
        XCTAssertEqual(coordinator.pendingShifts.first?.end, now, "Acik bitirmede bitis bitirme ani")
        XCTAssertEqual(notifier.ended.count, 1)
        XCTAssertEqual(activity.finished, 1)
        XCTAssertEqual(activity.dismissed, 0)
    }

    func testLiveActivityEndKeepsEvenVeryShortShift() async {
        let coordinator = makeCoordinator()
        coordinator.startManualShift()
        now = now.addingTimeInterval(30)
        coordinator.endShiftToPending()
        XCTAssertEqual(coordinator.pendingShifts.count, 1, "Kullanici acikca bitirdi: kisa vardiya filtresi yok")
        XCTAssertEqual(notifier.ended.count, 1)
        XCTAssertNil(coordinator.endShiftToPending(), "Suren vardiya yokken hicbir sey yapmaz")
        XCTAssertEqual(coordinator.pendingShifts.count, 1)
    }

    func testEnsureLiveActivityRequestsForRunningShiftOnly() async {
        let coordinator = makeCoordinator()
        coordinator.ensureLiveActivity()
        XCTAssertEqual(activity.begun, 0, "Vardiya yokken etkinlik acilmaz")
        driving(minutes: 4)
        await coordinator.handleWake()
        XCTAssertEqual(activity.begun, 1)
        // Arka planda istek basarisiz olmus olabilir: on plana donuste yeniden istenir
        coordinator.ensureLiveActivity()
        XCTAssertEqual(activity.begun, 2)
    }

    func testMotionAfterLongDeadGapEndsShiftAtLastMovement() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let movedAt = now
        workSession.location.markMovement(at: movedAt)
        // Surec oldu; 3 saat sonra yeni surus ornegi ve uyanma
        motion.list = [MotionSample(start: movedAt.addingTimeInterval(3 * 3600), kind: .automotive, confidence: .high)]
        now = movedAt.addingTimeInterval(3 * 3600 + 60)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.pendingShifts.count, 1)
        XCTAssertEqual(coordinator.pendingShifts.first?.end, movedAt, "Bitis bosluktan onceki son hareket")
        XCTAssertEqual(notifier.ended.count, 1)
    }

    func testMotionGapBetweenSamplesEndsShiftBeforeGap() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let movedAt = now
        workSession.location.markMovement(at: movedAt)
        // 5. dk'da surus, 6. dk'da durus; 2 saat sonra yeni surus
        motion.list = [
            MotionSample(start: movedAt.addingTimeInterval(300), kind: .automotive, confidence: .high),
            MotionSample(start: movedAt.addingTimeInterval(360), kind: .stationary, confidence: .high),
            MotionSample(start: movedAt.addingTimeInterval(7200), kind: .automotive, confidence: .high),
        ]
        now = movedAt.addingTimeInterval(7260)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.pendingShifts.first?.end, movedAt.addingTimeInterval(360), "Son hareket durus ornegine kadar surer")
    }

    func testGpsMovementAfterLongDeadGapEndsShiftAtLastMovement() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let movedAt = now
        workSession.location.markMovement(at: movedAt)
        coordinator.tick()
        XCTAssertTrue(workSession.isWorking)
        motion.list = []
        // Surec oldu; 3 saat sonra ilk GPS hareketi geldi
        workSession.location.markMovement(at: movedAt.addingTimeInterval(3 * 3600))
        now = movedAt.addingTimeInterval(3 * 3600 + 5)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.pendingShifts.first?.end, movedAt)
    }

    func testFreshGpsMovementSkipsMotionQueryAndKeepsShift() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let start = workSession.sessionStart!
        workSession.location.markMovement(at: start.addingTimeInterval(300))
        coordinator.tick()
        // GPS 30 sn once hareket gordu: hareket gecmisi sorgulanmaz (sorgulansaydi 910. sn isaretlenirdi)
        motion.list = [MotionSample(start: start.addingTimeInterval(910), kind: .automotive, confidence: .high)]
        workSession.location.markMovement(at: start.addingTimeInterval(900))
        now = start.addingTimeInterval(930)
        await coordinator.handleWake()
        XCTAssertTrue(workSession.isWorking)
        XCTAssertEqual(workSession.location.lastMovementDate, start.addingTimeInterval(900))
    }

    func testMotionPermissionWarningClearsWhenGrantedWhileDisabled() async {
        let coordinator = makeCoordinator(enabled: false)
        motion.isAuthorized = false
        let enabled = await coordinator.enable()
        XCTAssertFalse(enabled)
        XCTAssertEqual(coordinator.permissionProblem, .motion)
        motion.isAuthorized = true
        await coordinator.handleWake()
        XCTAssertNil(coordinator.permissionProblem, "Izin Ayarlar'dan verildi: uyari kalkar")
        XCTAssertFalse(coordinator.isEnabled)
    }
}
