import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// 2026 tarifeleri (yalnizca iki firma). Paket Taxi tutarlari firmanin kendi paylasimindaki ornek kazanclarla
/// birebir (or. Migros 1. bolge, gunde 38 paket, 26 gun: 144.103 TL).
final class CurrentTariffsTests: XCTestCase {
    private let day = "2026-10-14"
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])
    private var engine: PayEngine { PayEngine(catalog: catalog) }
    private let fuel = FuelCostModel(settings: FuelSettings(), vehicleType: "motorcycle", fallbackCostPerKm: .zero)

    private func profile(_ platform: String, region: String? = nil, hours: Int? = nil, seniority: Int? = nil) -> CourierTariffProfile {
        CourierTariffProfile(platformCode: platform, regionTier: region, seniorityYears: seniority, vehicleType: nil, flags: [],
                             contractHours: hours)
    }

    /// Ay boyunca 26 gun, gunde `perDay` paket (planlayicinin esit dagilim hesabiyla).
    private func month(_ platform: String, region: String?, perDay: Int, hours: Int? = nil, seniority: Int? = nil) throws -> PayBreakdown {
        let planner = GoalPlanner(engine: engine, fuel: fuel)
        let pace = PaceEstimate(packagesPerHour: 4, kmPerPackage: 0, isAssumed: false, sampleCount: 10)
        let evaluation = try planner.evaluate(packages: perDay * 26, profile: profile(platform, region: region, hours: hours,
                                                                                     seniority: seniority),
                                              pace: pace, day: day, daysPerWeek: 6).get()
        return evaluation.breakdown
    }

    // MARK: - Katalog

    func testOnlyTwoFirmsAndNewestVersions() {
        XCTAssertEqual(catalog.current(platform: "yemeksepeti", day: day)?.id, "yemeksepeti-esnaf-v3")
        XCTAssertEqual(catalog.current(platform: "migros_hemen", day: day)?.id, "migros_hemen-esnaf-v3")
        XCTAssertEqual(catalog.current(platform: "pt_migros", day: day)?.id, "pt_migros-esnaf-v1")
        XCTAssertEqual(catalog.current(platform: "pt_restoran", day: day)?.id, "pt_restoran-esnaf-v1")
        XCTAssertNil(catalog.current(platform: "getir", day: day))
        XCTAssertNil(catalog.current(platform: "trendyol_go", day: day))
        XCTAssertEqual(Set(PayEngine.standardCalculators.map(\.platformCode)), ["yemeksepeti", "pt_restoran", "pt_migros", "migros_hemen"])
    }

    // MARK: - Paket Taxi Migros (gorseldeki ornek kazanclar)

    func testMigrosMatchesPublishedExamples() throws {
        let expected: [(String, Int, Decimal)] = [
            ("r1", 38, 144_103), ("r1", 43, 164_291),
            ("r23", 38, 130_973), ("r23", 43, 148_561),
            ("r4", 38, 125_123), ("r4", 43, 141_541),
        ]
        for (region, perDay, total) in expected {
            XCTAssertEqual(try month("pt_migros", region: region, perDay: perDay).gross, Money(total), "\(region) \(perDay)")
        }
    }

    func testMigrosHemenMatchesPublishedExamples() throws {
        let expected: [(String, Int, Decimal)] = [
            ("r1", 38, 135_263), ("r1", 43, 155_321),
            ("r23", 38, 124_213), ("r23", 43, 141_671),
            ("r4", 38, 119_273), ("r4", 43, 135_691),
        ]
        for (region, perDay, total) in expected {
            XCTAssertEqual(try month("migros_hemen", region: region, perDay: perDay).gross, Money(total), "\(region) \(perDay)")
        }
    }

    func testMigrosDailyPrimeOnSingleDay() throws {
        var input = PayInput(platformCode: "pt_migros", startDay: day)
        input.regionTier = "r1"
        input.dayPackages = 38
        let result = try engine.calculate(input).get()
        XCTAssertEqual(result.gross, Money(2_360))
        XCTAssertTrue(result.notices.contains { $0.kind == .deferred }, "sabit ucret ay sonunda")
        // Bolge yoksa gunluk prim yok
        input.regionTier = nil
        XCTAssertEqual(try engine.calculate(input).get().gross, .zero)
    }

    func testHemenDeliveryBandsAndSideBenefits() throws {
        var input = PayInput(platformCode: "migros_hemen", startDay: day)
        input.regionTier = "r23"
        input.dayPackages = 20
        input.deliveryDistancesKm = [3, 5, 7]
        let result = try engine.calculate(input).get()
        XCTAssertEqual(result.gross, Money(255 + 25 + 35))
        XCTAssertTrue(result.sideBenefits.contains { $0.label == "Öğle yemeği" })
        XCTAssertTrue(result.sideBenefits.contains { $0.label == "1,5 saat yemek molası" })
    }

    // MARK: - Paket Taxi Restoran

    func testRestoranFixedBySeniorityAndDailyPrime() throws {
        // 1. bolge, gunde 10 saat, 2 yil kidem, gunde 40 paket: 77.370 + 2.250 + 26 × (15 × 34 + 5 × 43)
        let result = try month("pt_restoran", region: "r1", perDay: 40, hours: 10, seniority: 2)
        XCTAssertEqual(result.gross, Money(77_370 + 2_250 + 26 * (15 * 34 + 5 * 43)))
        // 4. bolge, 12 saat, kidem yok, gunde 30 paket: 84.430 + 26 × (5 × 17)
        XCTAssertEqual(try month("pt_restoran", region: "r4", perDay: 30, hours: 12).gross, Money(84_430 + 26 * 5 * 17))
        // 3 yil ve uzeri kidem, 9 saat, 2.–3. bolge, gunde 20 paket (prim yok)
        XCTAssertEqual(try month("pt_restoran", region: "r23", perDay: 20, hours: 9, seniority: 5).gross, Money(67_220 + 2_700))
    }

    func testRestoranSingleDayPrime() throws {
        var input = PayInput(platformCode: "pt_restoran", startDay: day)
        input.regionTier = "r23"
        input.contractHours = 11
        input.dayPackages = 45
        // 11–12 saat: 26–40. paket 25 TL, 41. paketten 34 TL
        XCTAssertEqual(try engine.calculate(input).get().gross, Money(15 * 25 + 5 * 34))
        input.contractHours = nil
        let missing = try engine.calculate(input).get()
        XCTAssertEqual(missing.gross, .zero)
        XCTAssertTrue(missing.notices.contains { $0.kind == .missing })
    }

    func testRestoranQuestionsAskRegionAndHours() {
        let q = TariffQuestions.required(platform: "pt_restoran", catalog: catalog, day: day)
        XCTAssertEqual(q.regionTiers, ["r1", "r23", "r4"])
        XCTAssertEqual(q.contractHours, [9, 10, 11, 12])
        XCTAssertTrue(q.asksSeniority)
        let migros = TariffQuestions.required(platform: "pt_migros", catalog: catalog, day: day)
        XCTAssertTrue(migros.contractHours.isEmpty)
        XCTAssertFalse(migros.asksSeniority)
    }

    // MARK: - Yemeksepeti

    func testYemeksepetiPaysByWeekdayAndHour() throws {
        // 2026-10-12 Pazartesi, 2026-10-18 Pazar
        var input = PayInput(platformCode: "yemeksepeti", startDay: "2026-10-12")
        input.deliverySlots = [DeliverySlot(weekday: 2, hour: 19, count: 5), DeliverySlot(weekday: 2, hour: 9, count: 2)]
        input.dayPackages = 7
        var result = try engine.calculate(input).get()
        XCTAssertEqual(result.gross, Money(Decimal(string: "352.5")! + 118))
        // Pazar 18:30 (+15 Pazar aksam) ve 02:00 (+15 gece)
        input = PayInput(platformCode: "yemeksepeti", startDay: "2026-10-18")
        input.deliverySlots = [DeliverySlot(weekday: 1, hour: 18, count: 1), DeliverySlot(weekday: 1, hour: 2, count: 1)]
        input.dayPackages = 2
        result = try engine.calculate(input).get()
        XCTAssertEqual(result.gross, Money(Decimal(string: "78.5")! + 15 + Decimal(string: "60.5")! + 15))
    }

    func testYemeksepetiDailyBonusAndKm() throws {
        var input = PayInput(platformCode: "yemeksepeti", startDay: "2026-10-13") // Sali
        input.dayPackages = 20
        input.totalKm = 10
        let result = try engine.calculate(input).get()
        // Saat bilinmiyor: gunduz 12:00–14:59 (59 TL); gunluk 20–22 paket bonusu 150 TL; km 3,70
        XCTAssertEqual(result.gross, Money(20 * 59 + 150 + 37))
        XCTAssertTrue(result.notices.contains { $0.kind == .estimate })
    }

    func testYemeksepetiWeeklyBonusByCityGroup() throws {
        let expected: [(String, Decimal)] = [("ys_istanbul", 5_250), ("ys_ankara_izmir", 3_600), ("ys_group3", 3_100), ("ys_other", 3_085)]
        for (region, bonus) in expected {
            var input = PayInput(platformCode: "yemeksepeti", span: .week, startDay: "2026-10-12", endDay: "2026-10-18")
            input.regionTier = region
            input.dayPackages = 200
            input.periodPackages = 200
            let result = try engine.calculate(input).get()
            XCTAssertEqual(result.lines.filter { $0.type == .weeklyBonus }.map(\.amount).sum(), Money(bonus), region)
        }
    }

    func testYemeksepetiPlanCountsCityWeeklyBonusOnly() throws {
        let planner = GoalPlanner(engine: engine, fuel: fuel)
        let pace = PaceEstimate(packagesPerHour: 3, kmPerPackage: 3, isAssumed: false, sampleCount: 10)
        let istanbul = try planner.evaluate(packages: 26 * 40, profile: profile("yemeksepeti", region: "ys_istanbul"), pace: pace, day: day).get()
        let other = try planner.evaluate(packages: 26 * 40, profile: profile("yemeksepeti", region: "ys_other"), pace: pace, day: day).get()
        XCTAssertEqual(istanbul.weeklyBonus.count, 1)
        XCTAssertGreaterThan(istanbul.gross, other.gross)
    }

    func testYemeksepetiSideBenefitsListed() throws {
        var input = PayInput(platformCode: "yemeksepeti", startDay: day)
        input.dayPackages = 5
        let result = try engine.calculate(input).get()
        XCTAssertTrue(result.sideBenefits.contains { $0.label == "Çalışma saati zorunluluğu yok" })
        XCTAssertTrue(result.sideBenefits.contains { $0.label.hasPrefix("Muhasebe desteği") })
    }
}
