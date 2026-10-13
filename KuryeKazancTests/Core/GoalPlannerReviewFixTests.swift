import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Son inceleme bulgulari: ay ortasi tarife, gunluk / hafta sonu bonuslari, profil isaretleri, ileri uyumluluk.
final class GoalPlannerReviewFixTests: XCTestCase {
    private let day = "2026-10-13"
    private let fuel = FuelCostModel(
        settings: FuelSettings(entries: [FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline)],
                               consumptionPer100Km: 3),
        vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
    private let pace = PaceEstimate(packagesPerHour: 5, kmPerPackage: 3, isAssumed: false, sampleCount: 20)

    private func engine(user: [TariffVersion] = []) -> PayEngine {
        TariffFixtures.engine(catalog: TariffCatalog.merged(bundled: TariffFixtures.bundled, remote: [], user: user))
    }

    func testMidMonthTariffIsUsed() throws {
        var version = try XCTUnwrap(TariffFixtures.all.first { $0.platformCode == "trendyol_go" })
        version.id = "user-ty-mid"
        version.origin = .user
        version.versionNumber = 50
        version.effectiveFrom = "2026-10-10"
        version.items = version.items.map { var i = $0; i.id = "mid-" + i.id; i.versionID = "user-ty-mid"; return i }
        let planner = GoalPlanner(engine: engine(user: [version]), fuel: fuel)
        let profile = CourierTariffProfile(platformCode: "trendyol_go", regionTier: nil, seniorityYears: nil, vehicleType: nil, flags: [])
        guard case let .success(e) = planner.evaluate(packages: 900, profile: profile, pace: pace, day: day) else { return XCTFail() }
        XCTAssertEqual(e.breakdown.tariffVersionID, "user-ty-mid")
    }

    func testTrendyolDailyBonusCountsInMonthlyPlan() {
        let planner = GoalPlanner(engine: engine(), fuel: fuel)
        let profile = CourierTariffProfile(platformCode: "trendyol_go", regionTier: nil, seniorityYears: nil, vehicleType: nil, flags: [])
        // 26 gun × 45 paket: her gun 42 paket esigi asilir
        guard case let .success(e) = planner.evaluate(packages: 45 * 26, profile: profile, pace: pace, day: day, daysPerWeek: 6)
        else { return XCTFail() }
        let bonusLines = e.breakdown.lines.filter { $0.type == .dailyBonus && $0.included }
        XCTAssertFalse(bonusLines.isEmpty, "gunluk bonus aylik planda sayilmali")
        XCTAssertTrue(bonusLines.contains { $0.quantity == 26 })
        // 41 paket/gun: esik asilmaz
        guard case let .success(low) = planner.evaluate(packages: 41 * 26, profile: profile, pace: pace, day: day, daysPerWeek: 6)
        else { return XCTFail() }
        XCTAssertTrue(low.breakdown.lines.filter { $0.type == .dailyBonus }.isEmpty)
    }

    func testGetirWeekendBonusCountsInMonthlyPlan() {
        let planner = GoalPlanner(engine: engine(), fuel: fuel)
        let profile = CourierTariffProfile(platformCode: "getir", regionTier: nil, seniorityYears: nil, vehicleType: "motorcycle", flags: [])
        // Gunde 20 paket, haftada 6 gun: hafta sonu 3 gun × 20 = 60 paket -> 40–60 kademesi (800 TL/hafta)
        guard case let .success(e) = planner.evaluate(packages: 20 * 26, profile: profile, pace: pace, day: day, daysPerWeek: 6)
        else { return XCTFail() }
        XCTAssertEqual(e.weeklyBonus.count, 1)
        XCTAssertEqual(e.weeklyBonus.first?.rate, Money(800))
        // 26 is gunu / 6 gun = 4,33 hafta -> 800 × 4,33
        XCTAssertEqual(e.weeklyBonus.first?.amount, Money(Money.round(Decimal(800) * Decimal(26) / Decimal(6))))
        XCTAssertTrue(e.breakdown.lines.contains { $0.id.hasSuffix(".weeks") }, "haftalik bonus satiri dokume eklenmeli")
    }

    func testGetirPlanIncludesWeekendBonus() throws {
        let planner = GoalPlanner(engine: engine(), fuel: fuel)
        let profile = CourierTariffProfile(platformCode: "getir", regionTier: nil, seniorityYears: nil, vehicleType: "motorcycle", flags: [])
        guard case let .success(plan) = planner.plan(goal: GoalSpec(amount: Money(100_000), period: .month), profile: profile,
                                                     pace: pace, day: day) else { return XCTFail() }
        XCTAssertGreaterThan(plan.weeklyBonusIncome.value, 0)
        XCTAssertGreaterThanOrEqual(plan.net.value, 100_000)
    }

    func testOnlyProfileFlagsAreAsked() {
        let catalog = TariffCatalog.merged(bundled: TariffFixtures.bundled, remote: [], user: [])
        XCTAssertTrue(TariffQuestions.required(platform: "trendyol_go", catalog: catalog, day: day).flags.isEmpty)
        XCTAssertTrue(TariffQuestions.required(platform: "yemeksepeti", catalog: catalog, day: day).flags.isEmpty)
        XCTAssertEqual(TariffQuestions.required(platform: "migros_hemen", catalog: catalog, day: day).flags, ["woman_employment"])
    }

    func testNestedGoalTypesDecodeWithMissingKeys() throws {
        let goal = try JSONDecoder().decode(GoalSpec.self, from: Data(#"{"amount":"1000","period":"week"}"#.utf8))
        XCTAssertEqual(goal.daysPerWeek, 6)
        XCTAssertEqual(goal.maxHoursPerDay, 10)
        let fuel = try JSONDecoder().decode(FuelSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(fuel, FuelSettings())
        let entry = try JSONDecoder().decode(FuelPriceEntry.self,
                                             from: Data(#"{"day":"2026-10-01","pricePerUnit":"45"}"#.utf8))
        XCTAssertEqual(entry.type, .gasoline)
        XCTAssertEqual(entry.source, .manual)
    }

    func testSwitchBaselineFirstEvaluationIsSilent() {
        let store = PayrollStore(fileURL: nil)
        XCTAssertNil(store.state.switchBaseline)
        store.setSwitchBaseline("a|b")
        XCTAssertEqual(store.state.switchBaseline, "a|b")
    }
}
