import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class GoalNudgeTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(_ hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: hour, minute: minute))!
    }

    private func progress(target: Int, done: Int, targetNet: Int = 3_000, net: Int = 0) -> DailyGoalProgress {
        DailyGoalProgress(targetPackages: target, targetHours: 10, targetNet: Money(targetNet), packages: done, net: Money(net))
    }

    func testSchedulesRemainingSlotsOnly() {
        let nudges = GoalNudgePlanner.today(progress: progress(target: 30, done: 10), packagesPerHour: Decimal(string: "2.5")!,
                                            now: at(13), calendar: calendar, isWorkDay: true)
        XCTAssertEqual(nudges.map(\.fireDate), [at(16), at(19)])
        XCTAssertEqual(nudges.first?.id, "reminder.goalNudge.1")
    }

    func testSkipsSlotTooClose() {
        let nudges = GoalNudgePlanner.today(progress: progress(target: 30, done: 10), packagesPerHour: 3,
                                            now: at(15, minute: 50), calendar: calendar, isWorkDay: true)
        XCTAssertEqual(nudges.map(\.fireDate), [at(19)])
    }

    func testNothingWhenDoneOrOffDay() {
        XCTAssertTrue(GoalNudgePlanner.today(progress: progress(target: 30, done: 30), packagesPerHour: 3,
                                             now: at(8), calendar: calendar, isWorkDay: true).isEmpty)
        XCTAssertTrue(GoalNudgePlanner.today(progress: progress(target: 30, done: 0), packagesPerHour: 3,
                                             now: at(8), calendar: calendar, isWorkDay: false).isEmpty)
        XCTAssertTrue(GoalNudgePlanner.today(progress: progress(target: 0, done: 0), packagesPerHour: 3,
                                             now: at(8), calendar: calendar, isWorkDay: true).isEmpty)
    }

    func testMessagesMentionPackagesAndMoney() {
        let nudges = GoalNudgePlanner.today(progress: progress(target: 30, done: 10, targetNet: 3_000, net: 1_000),
                                            packagesPerHour: Decimal(string: "2.5")!, now: at(8), calendar: calendar, isWorkDay: true)
        XCTAssertEqual(nudges.count, 3)
        XCTAssertEqual(nudges[0].title, "Bugünkü hedefe 20 paket var")
        XCTAssertTrue(nudges[0].body.contains("20 paket daha at"))
        XCTAssertTrue(nudges[0].body.contains("daha kazanalım"))
        XCTAssertTrue(nudges[0].body.contains("8 saat"), nudges[0].body)
    }

    func testLateWarningWhenNotEnoughTime() {
        // 16:00'da 7 saat kaldi; 2,5 paket/sa ile 40 paket 16 saat surer
        let nudges = GoalNudgePlanner.today(progress: progress(target: 40, done: 0), packagesPerHour: Decimal(string: "2.5")!,
                                            now: at(13), calendar: calendar, isWorkDay: true)
        XCTAssertEqual(nudges.first?.title, "Hedefe geç kalıyorsun")
        XCTAssertTrue(nudges.first?.body.contains("saatte 6 paket") == true, nudges.first?.body ?? "")
    }

    func testPeriodBehindSuggestsExtraPackages() throws {
        let pace = GoalPace(period: .month, goal: Money(100_000), projected: Money(90_000), workedDays: 10)
        let nudge = try XCTUnwrap(GoalNudgePlanner.period(pace: pace, netPerPackage: 100, daysLeft: 10, now: at(20), calendar: calendar))
        XCTAssertEqual(nudge.fireDate, calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 10)))
        XCTAssertTrue(nudge.body.contains("günde 10 paket fazla"), nudge.body)
        XCTAssertEqual(nudge.title, "Ay sonuna 10 iş günü kaldı")
    }

    func testPeriodAheadAndDailyGoal() {
        let ahead = GoalPace(period: .week, goal: Money(10_000), projected: Money(12_000), workedDays: 3)
        XCTAssertEqual(GoalNudgePlanner.period(pace: ahead, netPerPackage: 100, daysLeft: 2, now: at(9), calendar: calendar)?.title,
                       "Hedefin önündesin 👏")
        let daily = GoalPace(period: .day, goal: Money(1_000), projected: Money(500), workedDays: 1)
        XCTAssertNil(GoalNudgePlanner.period(pace: daily, netPerPackage: 100, daysLeft: 2, now: at(9), calendar: calendar))
        XCTAssertNil(GoalNudgePlanner.period(pace: ahead, netPerPackage: 100, daysLeft: 0, now: at(9), calendar: calendar))
    }

    func testUserPaceOverridesMeasured() {
        let pace = PaceEstimate.estimate(entries: [], platform: "yemeksepeti", now: at(9), userPackagesPerHour: Decimal(string: "3.2")!)
        XCTAssertEqual(pace.packagesPerHour, Decimal(string: "3.2")!)
        XCTAssertTrue(pace.isUserProvided)
        XCTAssertFalse(pace.isAssumed)
        XCTAssertEqual(pace.kmPerPackage, PaceEstimate.defaultKmPerPackage)
        let clamped = PaceEstimate.estimate(entries: [], platform: "x", now: at(9), userPackagesPerHour: 40)
        XCTAssertEqual(clamped.packagesPerHour, 8)
        let none = PaceEstimate.estimate(entries: [], platform: "x", now: at(9), userPackagesPerHour: nil)
        XCTAssertTrue(none.isAssumed)
        XCTAssertFalse(none.isUserProvided)
    }

    func testDurationFormatterSurvivesBadIntervals() {
        XCTAssertEqual(Formatters.duration(.nan), "0 dk")
        XCTAssertEqual(Formatters.duration(.infinity), "0 dk")
        XCTAssertEqual(Formatters.duration(-60), "0 dk")
        XCTAssertEqual(Formatters.duration(3 * 3600 + 25 * 60), "3 sa 25 dk")
    }

    func testRemainingWorkDaysAndWorkDay() {
        // 15 Ekim 2026 Persembe; ay sonuna 16 gun (16-31)
        let monthly = GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 7)
        XCTAssertEqual(GoalNudgePlanner.remainingWorkDays(goal: monthly, now: at(12), calendar: calendar), 16)
        // Yalnizca Pazartesi (2) ve Cuma (6): 16-31 Ekim arasi 3 Cuma + 2 Pazartesi
        let picked = GoalSpec(amount: Money(100_000), period: .month, workWeekdays: [2, 6])
        XCTAssertEqual(GoalNudgePlanner.remainingWorkDays(goal: picked, now: at(12), calendar: calendar), 5)
        XCTAssertFalse(GoalNudgePlanner.isWorkDay(goal: picked, now: at(12), calendar: calendar))
        XCTAssertTrue(GoalNudgePlanner.isWorkDay(goal: GoalSpec(amount: Money(1_000), period: .day), now: at(12), calendar: calendar))
        XCTAssertEqual(GoalNudgePlanner.remainingWorkDays(goal: GoalSpec(amount: Money(1_000), period: .day), now: at(12),
                                                          calendar: calendar), 0)
    }
}
