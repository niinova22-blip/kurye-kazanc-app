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
        var begun = 0, updates = 0, finished = 0
        func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState) { begun += 1 }
        func update(_ state: ShiftActivityAttributes.ContentState) { updates += 1 }
        func finish(_ state: ShiftActivityAttributes.ContentState) { finished += 1 }
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
        XCTAssertEqual(activity.finished, 1)

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
}
