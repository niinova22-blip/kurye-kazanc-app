import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class GoalAlternativesTests: XCTestCase {
    private let day = "2026-10-13"
    private let engine = TariffFixtures.engine(catalog: TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: []))
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

    func testPaketTaxiPlanUsesDailyPrimeAndMonthlyBonus() throws {
        let (plan, alternatives) = try run(GoalSpec(amount: Money(120_000), period: .month), platform: "pt_migros",
                                           region: "r1", perHour: 5)
        XCTAssertEqual(plan.reachability, .reachable)
        XCTAssertFalse(plan.net < Money(120_000))
        XCTAssertTrue(plan.breakdown.lines.contains { $0.type == .dailyBonus })
        XCTAssertTrue(plan.breakdown.lines.contains { $0.type == .monthlyBonus })
        XCTAssertTrue(alternatives.allSatisfy { !($0.net < plan.goal.monthlyTarget()) || $0.kind == .nextTier })
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

    // MARK: - Uygulama

    func testApplyingNextTierRaisesGoalAndPlanReachesTier() throws {
        let tier = GoalAlternative(id: "tier.1200", kind: .nextTier, title: "", detail: "", daysPerWeek: 6, packagesPerDay: 47,
                                   hoursPerDay: Decimal(string: "9.5")!, monthlyHours: 247, net: Money(Decimal(string: "151234.56")!),
                                   hoursSaved: 0, extraNet: Money(10_000))
        let goal = GoalSpec(amount: Money(120_000), period: .month)
        let applied = GoalAlternatives.applied(tier, to: goal)
        XCTAssertEqual(applied.amount, Money(151_230))
        XCTAssertEqual(applied.maxHoursPerDay, 10)
        let weekly = GoalAlternatives.applied(tier, to: GoalSpec(amount: Money(20_000), period: .week))
        XCTAssertEqual(weekly.amount, Money(Decimal(34_900)))
        let (plan, _) = try run(applied, platform: "pt_migros", region: "r1", perHour: 5)
        XCTAssertFalse(plan.net < applied.amount)
    }

    func testApplyingEveningSetsNightShareAndNeedsFewerPackages() throws {
        let goal = GoalSpec(amount: Money(50_000), period: .month)
        let (base, alternatives) = try run(goal, platform: "trendyol_go")
        let evening = try XCTUnwrap(alternatives.first { $0.kind == .evening })
        let applied = GoalAlternatives.applied(evening, to: goal)
        XCTAssertEqual(applied.nightShare, Decimal(string: "0.5"))
        XCTAssertEqual(applied.amount, goal.amount)
        let (plan, again) = try run(applied, platform: "trendyol_go")
        XCTAssertLessThan(plan.monthlyPackages, base.monthlyPackages)
        XCTAssertFalse(again.contains { $0.kind == .evening })
    }

    func testApplyingDaysKeepsAmountAndChangesWeekdays() throws {
        let goal = GoalSpec(amount: Money(40_000), period: .week, daysPerWeek: 5, maxHoursPerDay: 8,
                            workWeekdays: [2, 3, 4, 5, 6])
        let alternative = GoalAlternative(id: "days.6", kind: .days, title: "", detail: "", daysPerWeek: 6, packagesPerDay: 30,
                                          hoursPerDay: Decimal(string: "9.5")!, monthlyHours: 247, net: Money(1), hoursSaved: 0,
                                          extraNet: .zero)
        let applied = GoalAlternatives.applied(alternative, to: goal)
        XCTAssertEqual(applied.amount, goal.amount)
        XCTAssertEqual(applied.daysPerWeek, 6)
        XCTAssertEqual(applied.workWeekdays, [2, 3, 4, 5, 6, 7])
        XCTAssertEqual(applied.maxHoursPerDay, 10)
    }

    func testNightShareSurvivesCoding() throws {
        let goal = GoalSpec(amount: Money(100), period: .day, nightShare: Decimal(string: "0.5"))
        let data = try JSONEncoder().encode(goal)
        XCTAssertEqual(try JSONDecoder().decode(GoalSpec.self, from: data), goal)
        let old = try JSONDecoder().decode(GoalSpec.self, from: Data(#"{"amount":"100","period":"day"}"#.utf8))
        XCTAssertNil(old.nightShare)
    }
}
