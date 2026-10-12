import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class DailyGoalProgressTests: XCTestCase {
    func testTodayShareAndAchieved() throws {
        let engine = PayEngine(catalog: TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: []))
        let fuel = FuelCostModel(settings: FuelSettings(entries: [FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline)],
                                                        consumptionPer100Km: 3), vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
        let pace = PaceEstimate(packagesPerHour: Decimal(string: "4.2")!, kmPerPackage: Decimal(string: "3.5")!, isAssumed: false, sampleCount: 9)
        let profile = CourierTariffProfile(platformCode: "migros_hemen", regionTier: "plus", seniorityYears: 1, vehicleType: nil,
                                           flags: ["woman_employment"])
        guard case let .success(plan) = GoalPlanner(engine: engine, fuel: fuel)
            .plan(goal: GoalSpec(amount: Money(100_000), period: .month), profile: profile, pace: pace, day: "2026-10-13")
        else { return XCTFail() }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 15)))
        let start = now.addingTimeInterval(-4 * 3600)
        let entries = [
            EarningEntry(start: start, end: now, gross: 532, bonus: 0, distanceKm: 49, platformCode: "migros_hemen", packageCount: 14),
            EarningEntry(start: start.addingTimeInterval(-86_400), end: now.addingTimeInterval(-86_400), gross: 999, bonus: 0,
                         distanceKm: 1, platformCode: "migros_hemen", packageCount: 30),
            EarningEntry(start: start, end: now, gross: 100, bonus: 0, distanceKm: 1, platformCode: "getir", packageCount: 3),
        ]
        let progress = DailyGoalProgress.today(plan: plan, entries: entries, platform: "migros_hemen", day: "2026-10-13",
                                               fuel: fuel, calendar: calendar, now: now)
        XCTAssertEqual(progress.targetPackages, 38)
        XCTAssertEqual(progress.packages, 14)
        XCTAssertEqual(progress.remainingPackages, 24)
        // 532 − 49 × 1,35 = 465,85
        XCTAssertEqual(progress.net, Money(Decimal(string: "465.85")!))
        XCTAssertEqual(progress.targetNet, Money(Money.round(Decimal(100_000) / 26)))
        XCTAssertEqual(progress.fraction, 14.0 / 38.0, accuracy: 0.0001)
    }

    func testFractionCapsAtOne() {
        let p = DailyGoalProgress(targetPackages: 10, targetHours: 4, targetNet: Money(100), packages: 15, net: Money(200))
        XCTAssertEqual(p.fraction, 1)
        XCTAssertEqual(p.remainingPackages, 0)
    }
}
