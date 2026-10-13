import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Guncel (v2) gomulu tarifeler: Paket Taxi resmi 2026 ucretleri, Yemeksepeti 2026 tablosu.
final class CurrentTariffsTests: XCTestCase {
    private let engine = PayEngine(catalog: TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: []),
                                   clock: { Date(timeIntervalSince1970: 1_790_000_000) })

    private func calc(_ input: PayInput, file: StaticString = #filePath, line: UInt = #line) -> PayBreakdown {
        TariffFixtures.calc(input, engine: engine, file: file, line: line)
    }

    private func paketTaxiMonth(_ packages: Int, km: Decimal? = nil, distances: [Decimal] = []) -> PayInput {
        var input = TariffFixtures.input("migros_hemen", day: "2026-10-01", span: .month, end: "2026-10-31")
        input.dayPackages = packages
        input.periodPackages = packages
        input.totalKm = km
        input.deliveryDistancesKm = distances
        input.regionTier = "plus"
        return input
    }

    func testNewestVersionIsChosen() {
        XCTAssertEqual(calc(paketTaxiMonth(10)).tariffVersionID, "migros_hemen-esnaf-v2")
        XCTAssertEqual(calc(TariffFixtures.input("yemeksepeti")).tariffVersionID, "yemeksepeti-esnaf-v2")
        XCTAssertEqual(calc(TariffFixtures.input("trendyol_go")).tariffVersionID, "trendyol_go-esnaf-v1")
    }

    func testPaketTaxiFixedPlusMonthlyBonusWithoutPerPackageFee() {
        let result = calc(paketTaxiMonth(1_700, km: 1_700 * Decimal(string: "3.5")!))
        XCTAssertEqual(result.gross, Money(65_223 + 55_600))
        XCTAssertFalse(result.lines.contains { $0.type == .singlePackage })
        XCTAssertFalse(result.notices.contains { $0.message.contains("paket ücreti yok") })
        XCTAssertTrue(result.progress.contains { $0.target == 1_800 && $0.reward == Money(66_870) })
    }

    func testPaketTaxiLowestBonusCoversUnpublishedRange() {
        XCTAssertEqual(calc(paketTaxiMonth(1_200)).gross, Money(65_223 + 12_000))
        XCTAssertEqual(calc(paketTaxiMonth(699)).gross, Money(65_223))
        XCTAssertEqual(calc(paketTaxiMonth(1_850)).gross, Money(65_223 + 66_870))
    }

    func testPaketTaxiDistanceExtraPerDelivery() {
        let distances: [Decimal] = [3, 4, Decimal(string: "5.5")!, 6, Decimal(string: "6.5")!, 12]
        let result = calc(paketTaxiMonth(6, distances: distances))
        let extra: Money = result.lines.filter { $0.itemKey.hasPrefix("distance.") }.map(\.amount).sum()
        XCTAssertEqual(extra, Money(25 * 3 + 35 * 2))
        XCTAssertEqual(result.lines.first { $0.itemKey == "distance.4_6" }?.quantity, 3)
    }

    func testPaketTaxiDistanceExtraFromAverageIsAnEstimate() {
        let result = calc(paketTaxiMonth(100, km: 500))
        XCTAssertEqual(result.lines.first { $0.itemKey == "distance.4_6" }?.amount, Money(2_500))
        XCTAssertTrue(result.notices.contains { $0.kind == .estimate && $0.message.contains("ortalama") })
        XCTAssertNil(calc(paketTaxiMonth(100, km: 300)).lines.first { $0.itemKey.hasPrefix("distance.") })
    }

    func testYemeksepetiDayEveningKmAndDailyBonus() {
        var input = TariffFixtures.input("yemeksepeti")
        input.dayPackages = 30
        input.nightPackages = 10
        input.totalKm = 50
        let result = calc(input)
        // 30 × 59 + 10 × 67,5 + 50 × 3,7 + gunluk 40–44 paket bonusu 600
        XCTAssertEqual(result.gross, Money(text: "3230")!)
        XCTAssertNil(result.lines.first { $0.type == .hourly }, "dogrulanmamis garanti kalemi kalkti")
    }

    func testYemeksepetiWeeklyBonusOnlyInAnkaraIzmir() {
        var input = TariffFixtures.input("yemeksepeti", day: "2026-10-05", span: .week, end: "2026-10-11")
        input.dayPackages = 220
        input.periodPackages = 220
        XCTAssertNil(calc(input).lines.first { $0.type == .weeklyBonus })
        input.flags = ["ys_ankara_izmir"]
        XCTAssertEqual(calc(input).lines.first { $0.type == .weeklyBonus }?.amount, Money(3_500))
    }

    func testQuestionsFollowNewestVersion() {
        let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])
        let paketTaxi = TariffQuestions.required(platform: "migros_hemen", catalog: catalog, day: "2026-10-13")
        XCTAssertEqual(paketTaxi.regionTiers, ["plus", "standard"])
        XCTAssertFalse(paketTaxi.asksSeniority, "kidem 2026 tarifesinde yok")
        XCTAssertEqual(paketTaxi.flags, ["woman_employment"])
        let yemeksepeti = TariffQuestions.required(platform: "yemeksepeti", catalog: catalog, day: "2026-10-13")
        XCTAssertEqual(yemeksepeti.flags, ["ys_ankara_izmir"])
        let getir = TariffQuestions.required(platform: "getir", catalog: catalog, day: "2026-10-13")
        XCTAssertEqual(getir.vehicleTypes, ["car", "motorcycle"])
    }

    func testPlannerUsesNewPaketTaxiTariff() throws {
        let fuel = FuelCostModel(
            settings: FuelSettings(entries: [FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline)],
                                   consumptionPer100Km: 3),
            vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
        let pace = PaceEstimate(packagesPerHour: 4, kmPerPackage: Decimal(string: "3.5")!, isAssumed: false, sampleCount: 20)
        let profile = CourierTariffProfile(platformCode: "migros_hemen", regionTier: "plus", seniorityYears: nil,
                                           vehicleType: nil, flags: [])
        let planner = GoalPlanner(engine: engine, fuel: fuel)
        let plan = try planner.plan(goal: GoalSpec(amount: Money(70_000), period: .month), profile: profile, pace: pace,
                                    day: "2026-10-13").get()
        // 65.223 sabit; 700 paket bonusu (12.000) ile 77.223 − yakit (700 × 3,5 km × 0,03 L × 45 TL) ≥ 70.000
        XCTAssertEqual(plan.monthlyPackages, 700)
        XCTAssertEqual(plan.reachability, .reachable)
    }

    func testWeekendBonusCountsOnlyChosenWeekendDays() {
        let items: [TariffItem] = BundledTariffs.all.first { $0.id == "getir-esnaf-motorcycle-v1" }!.items
        let all = GoalPlanner.weeklyBonus(items: items, perDay: 20, daysPerWeek: 6, workDays: 26)
        XCTAssertEqual(all.first?.rate, Money(800), "Cuma–Pazar 3 gün × 20 = 60 paket: 40–60 kademesi")
        let weekdaysOnly = GoalPlanner.weeklyBonus(items: items, perDay: 20, daysPerWeek: 5, workDays: 22,
                                                   weekdays: [2, 3, 4, 5, 6])
        XCTAssertEqual(weekdaysOnly.first?.rate, nil, "yalnizca Cuma: 20 paket, kademe yok")
    }

    func testGoalSpecWeekdaysDefineDayCount() throws {
        let spec = GoalSpec(amount: Money(1_000), period: .week, daysPerWeek: 6, workWeekdays: [7, 1, 6, 6, 9])
        XCTAssertEqual(spec.workWeekdays, [1, 6, 7])
        XCTAssertEqual(spec.daysPerWeek, 3)
        let decoded = try JSONDecoder().decode(GoalSpec.self, from: JSONEncoder().encode(spec))
        XCTAssertEqual(decoded, spec)
        let legacy = try JSONDecoder().decode(GoalSpec.self, from: Data(#"{"amount":"500","period":"day","daysPerWeek":5}"#.utf8))
        XCTAssertNil(legacy.workWeekdays)
        XCTAssertEqual(legacy.daysPerWeek, 5)
        XCTAssertEqual(GoalSpec.defaultWeekdays(count: 6), [2, 3, 4, 5, 6, 7])
    }
}
