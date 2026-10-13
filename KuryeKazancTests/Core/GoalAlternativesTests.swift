import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class GoalAlternativesTests: XCTestCase {
    private let day = "2026-10-13"
    private let engine = PayEngine(catalog: TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: []))
    private let fuel = FuelCostModel(
        settings: FuelSettings(entries: [FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline)],
                               consumptionPer100Km: 3),
        vehicleType: "motorcycle", fallbackCostPerKm: Money(2))

    private func run(_ goal: GoalSpec, platform: String, region: String? = nil, flags: [String] = [],
                     perHour: Decimal = 3) throws -> (GoalPlan, [GoalAlternative]) {
        let pace = PaceEstimate(packagesPerHour: perHour, kmPerPackage: 3, isAssumed: false, sampleCount: 10)
        let profile = CourierTariffProfile(platformCode: platform, regionTier: region, seniorityYears: nil,
                                           vehicleType: platform == "getir" ? "motorcycle" : nil, flags: flags)
        let planner = GoalPlanner(engine: engine, fuel: fuel)
        let plan = try planner.plan(goal: goal, profile: profile, pace: pace, day: day).get()
        return (plan, GoalAlternatives.suggest(base: plan, planner: planner, profile: profile, pace: pace, day: day))
    }

    func testTrendyolDailyBonusPathNeedsFewerHours() throws {
        let (plan, alternatives) = try run(GoalSpec(amount: Money(80_000), period: .month), platform: "trendyol_go", perHour: 4)
        XCTAssertEqual(plan.reachability, .reachable)
        let bonus = try XCTUnwrap(alternatives.first { $0.kind == .bonusPace })
        XCTAssertEqual(bonus.packagesPerDay, 42)
        XCTAssertGreaterThan(bonus.hoursSaved, 0)
        XCTAssertFalse(bonus.net < plan.goal.monthlyTarget())
        XCTAssertTrue(bonus.title.contains("42"))
    }

    func testTrendyolEveningOptionWhenNightRateHigher() throws {
        let (plan, alternatives) = try run(GoalSpec(amount: Money(50_000), period: .month), platform: "trendyol_go")
        let evening = try XCTUnwrap(alternatives.first { $0.kind == .evening })
        XCTAssertLessThan(evening.packagesPerDay, plan.packagesPerDay + 1)
        XCTAssertGreaterThan(evening.hoursSaved, 0)
    }

    func testPaketTaxiSuggestsBigMonthlyTierJump() throws {
        let (plan, alternatives) = try run(GoalSpec(amount: Money(70_000), period: .month), platform: "migros_hemen",
                                           region: "plus", perHour: 6)
        XCTAssertEqual(plan.monthlyPackages, 700)
        let tier = try XCTUnwrap(alternatives.first { $0.kind == .nextTier })
        XCTAssertTrue(tier.title.contains("1.700"))
        XCTAssertGreaterThan(tier.extraNet.value, 30_000)
    }

    func testUnreachableGoalGetsReachableDayOption() throws {
        let (plan, alternatives) = try run(GoalSpec(amount: Money(40_000), period: .month, daysPerWeek: 5, maxHoursPerDay: 8),
                                           platform: "trendyol_go", perHour: 2)
        XCTAssertNotEqual(plan.reachability, .reachable)
        XCTAssertTrue(alternatives.contains { $0.kind == .days || $0.kind == .bonusPace })
        XCTAssertTrue(alternatives.allSatisfy { !($0.net < plan.goal.monthlyTarget()) || $0.kind == .nextTier })
    }

    func testAlreadyMetHasNoAlternatives() throws {
        let (plan, alternatives) = try run(GoalSpec(amount: Money(50_000), period: .month), platform: "migros_hemen",
                                           region: "plus")
        XCTAssertEqual(plan.reachability, .alreadyMet)
        XCTAssertTrue(alternatives.isEmpty)
    }

    func testDailyGoalHasNoDayCountOptions() throws {
        let (_, alternatives) = try run(GoalSpec(amount: Money(2_500), period: .day), platform: "trendyol_go")
        XCTAssertFalse(alternatives.contains { $0.kind == .days || $0.kind == .bonusPace })
    }

    func testAtMostThreeSortedByHoursSaved() throws {
        let (_, alternatives) = try run(GoalSpec(amount: Money(80_000), period: .month), platform: "trendyol_go", perHour: 4)
        XCTAssertLessThanOrEqual(alternatives.count, 3)
        XCTAssertEqual(alternatives.map(\.hoursSaved), alternatives.map(\.hoursSaved).sorted(by: >))
    }
}
