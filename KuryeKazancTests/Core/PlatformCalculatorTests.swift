import XCTest
@testable import KuryeCore

/// Platforma ozgu hesaplamalar (ornek baslangic tarifesiyle; degerler dogrulanmis tarife degildir).
final class PlatformCalculatorTests: XCTestCase {
    // MARK: - Trendyol GO

    func testTrendyolDayNightAndCombinedRange() {
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 30
        input.nightPackages = 10
        input.combinedPackages = 5
        let result = TariffFixtures.calc(input)
        XCTAssertEqual(result.line("package.day")?.amount, money("1935"))
        XCTAssertEqual(result.line("package.night")?.amount, money("920"))
        XCTAssertEqual(result.line("package.combined")?.amount, money("135"))
        XCTAssertEqual(result.line("package.combined")?.amountUpper, money("207.50"))
        // 45 paket: gunluk 42 bonusu
        XCTAssertEqual(result.line("bonus.daily.42")?.amount, money("1610"))
        XCTAssertNil(result.line("bonus.daily.82"))
        XCTAssertEqual(result.gross, money("4600"))
        XCTAssertEqual(result.grossUpper, money("4672.50"))
        XCTAssertTrue(result.needsVerification, "ornek tarife dogrulanmamis")
    }

    func testTrendyolDailyBonusBoundaries() {
        func bonus(_ packages: Int) -> Money {
            var input = TariffFixtures.input("trendyol_go")
            input.dayPackages = packages
            return TariffFixtures.calc(input).bonusTotal
        }
        XCTAssertEqual(bonus(41), .zero)
        XCTAssertEqual(bonus(42), money("1610"))
        XCTAssertEqual(bonus(81), money("1610"))
        // 82: yalnizca en yuksek kademe (ayar), toplanma dogrulanmadi -> alternatif uyarisi
        XCTAssertEqual(bonus(82), money("4400"))
    }

    func testTrendyolBonusStackingIsConfigurableAndAmbiguityShown() {
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 85
        let highest = TariffFixtures.calc(input)
        XCTAssertEqual(highest.bonusTotal, money("4400"))
        let ambiguity = highest.notices.first { $0.kind == .ambiguity && $0.message.contains("Günlük bonus") }
        XCTAssertEqual(ambiguity?.alternativeGross, highest.gross + money("1610"))

        var version = TariffFixtures.bundled("trendyol_go-esnaf-v1")
        version.settings.bonusStacking = .cumulative
        version.settings.confidence["bonus_stacking"] = .verified
        let cumulative = TariffFixtures.calc(input, engine: TariffFixtures.engine([version]))
        XCTAssertEqual(cumulative.bonusTotal, money("6010"))
        XCTAssertFalse(cumulative.notices.contains { $0.kind == .ambiguity && $0.message.contains("Günlük bonus") },
                       "dogrulanmis ayarda alternatif gosterilmez")
    }

    func testTrendyolKmSlabWholeDistanceAndUndefinedGap() {
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 3
        input.deliveryDistancesKm = [2, 7, Decimal(string: "4.5")!]
        let slab = TariffFixtures.calc(input)
        // Dilimli: 0-3 bandinda 2+3+3 = 8 km x 6,50; 6+ bandinda 1 km x 7,80; 3-6 arasi 4,5 km tanimsiz
        XCTAssertEqual(slab.line("km.band.0")?.amount, money("52"))
        XCTAssertEqual(slab.line("km.band.6")?.amount, money("7.80"))
        XCTAssertTrue(slab.notices.contains { $0.message.contains("4.5 km") && $0.kind == .needsVerification })
        let alt = slab.notices.first { $0.kind == .ambiguity && $0.message.contains("Km") }
        // Tum mesafe: 2 km x 6,50 + 7 km x 7,80 = 67,60 (4,5 km yine tanimsiz)
        XCTAssertEqual(alt?.alternativeGross, slab.gross - money("59.80") + money("67.60"))

        var version = TariffFixtures.bundled("trendyol_go-esnaf-v1")
        version.settings.kmMethod = .wholeDistance
        let whole = TariffFixtures.calc(input, engine: TariffFixtures.engine([version]))
        XCTAssertEqual(whole.line("km.band.0")?.amount, money("13"))
        XCTAssertEqual(whole.line("km.band.6")?.amount, money("54.60"))
    }

    func testTrendyolTotalKmIsSplitWithEstimateNotice() {
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 4
        input.totalKm = 8
        let result = TariffFixtures.calc(input)
        // 4 teslimat x 2 km: hepsi 0-3 bandinda
        XCTAssertEqual(result.line("km.band.0")?.amount, money("52"))
        XCTAssertTrue(result.notices.contains { $0.kind == .estimate })
    }

    func testTrendyolSurgeOnlyFromUserInput() {
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 10
        let none = TariffFixtures.calc(input)
        XCTAssertNil(none.lines.first { $0.type == .surgeMultiplier }, "otomatik carpan yok")
        input.surgeMultiplier = Decimal(string: "1.5")
        input.surgePackages = 4
        let surge = TariffFixtures.calc(input)
        let line = surge.lines.first { $0.type == .surgeMultiplier }
        XCTAssertEqual(line?.amount, money("129")) // 4 x 64,50 x 0,5
        XCTAssertEqual(line?.confidence, .userEntered)
    }

    func testTrendyolWeeklyPerformanceOnlyWhenFlagged() {
        var input = TariffFixtures.input("trendyol_go", span: .week, end: "2026-10-11")
        input.dayPackages = 200
        XCTAssertNil(TariffFixtures.calc(input).line("bonus.weekly.performance"))
        input.flags = ["weekly_performance"]
        let range = TariffFixtures.calc(input).line("bonus.weekly.performance")
        XCTAssertEqual(range?.amount, money("500"))
        XCTAssertEqual(range?.amountUpper, money("1000"))
        input.flagAmounts["weekly_performance"] = money("750")
        let exact = TariffFixtures.calc(input).line("bonus.weekly.performance")
        XCTAssertEqual(exact?.amount, money("750"))
        XCTAssertEqual(exact?.confidence, .userEntered)
    }

    func testTrendyolPeriodModeUsesBonusDays() {
        var input = TariffFixtures.input("trendyol_go", span: .week, end: "2026-10-11")
        input.dayPackages = 300
        let missing = TariffFixtures.calc(input)
        XCTAssertTrue(missing.notices.contains { $0.kind == .missing && $0.message.contains("gün sayısını") })
        input.bonusTierDays = ["bonus.daily.42": 3, "bonus.daily.82": 1]
        let result = TariffFixtures.calc(input)
        // En yuksek kademe: 1 gun 82 (4400) + 2 gun yalnizca 42 (2 x 1610)
        XCTAssertEqual(result.bonusTotal, money("7620"))
    }

    // MARK: - Getir

    func testGetirMotorcycleAndCarTariffs() {
        var input = TariffFixtures.input("getir")
        input.hours = 8
        input.dayPackages = 20
        input.combinedPackages = 4
        input.totalKm = 50
        input.vehicleType = "motorcycle"
        let motor = TariffFixtures.calc(input)
        XCTAssertEqual(motor.tariffVersionID, "getir-esnaf-motorcycle-v1")
        XCTAssertEqual(motor.gross, money("3177.50"))
        input.vehicleType = "car"
        let car = TariffFixtures.calc(input)
        XCTAssertEqual(car.tariffVersionID, "getir-esnaf-car-v1")
        XCTAssertEqual(car.gross, money("3917.50"))
    }

    func testGetirWithoutVehicleIsAmbiguous() {
        let result = TariffFixtures.engine.calculate(TariffFixtures.input("getir"))
        XCTAssertEqual(result.failureValue, .ambiguousScope("araç tipi"))
    }

    func testGetirWeekendBonusTiers() {
        func bonus(_ weekend: Int) -> Money {
            var input = TariffFixtures.input("getir", day: "2026-10-05", span: .week, end: "2026-10-11")
            input.vehicleType = "motorcycle"
            input.dayPackages = 150
            input.weekendPackages = weekend
            return TariffFixtures.calc(input).bonusTotal
        }
        XCTAssertEqual(bonus(39), .zero)
        XCTAssertEqual(bonus(40), money("800"))
        XCTAssertEqual(bonus(60), money("800"))
        XCTAssertEqual(bonus(61), money("900"))
        XCTAssertEqual(bonus(80), money("1050"))
        XCTAssertEqual(bonus(100), money("1300"))
        XCTAssertEqual(bonus(101), money("1700"))
    }

    func testGetirWeekendBonusDeferredOnDailyLogAndSideBenefitsSeparate() {
        var input = TariffFixtures.input("getir")
        input.vehicleType = "motorcycle"
        input.hours = 4
        input.dayPackages = 10
        let result = TariffFixtures.calc(input)
        XCTAssertEqual(result.bonusTotal, .zero)
        XCTAssertTrue(result.notices.contains { $0.kind == .deferred })
        XCTAssertTrue(result.sideBenefits.contains { $0.itemKey == "side.p1" && !$0.included && !$0.isCash })
        XCTAssertEqual(result.gross, money("1300"), "yan haklar nakit hakedise eklenmez")
    }

    // MARK: - Yemeksepeti Express

    func testYemeksepetiGuaranteeNotCountedWhileUnverified() {
        var input = TariffFixtures.input("yemeksepeti")
        input.dayPackages = 10
        input.combinedPackages = 2
        input.hours = 5
        let result = TariffFixtures.calc(input)
        XCTAssertEqual(result.gross, money("810"))
        let guarantee = result.line("guarantee.hourly")
        XCTAssertEqual(guarantee?.included, false)
        let notice = result.notices.first { $0.message.contains("Saatlik garanti") }
        XCTAssertEqual(notice?.kind, .needsVerification)
        XCTAssertEqual(notice?.alternativeGross, money("1500"))
    }

    func testYemeksepetiGuaranteeTopUpWhenVerified() {
        var version = TariffFixtures.bundled("yemeksepeti-esnaf-v1")
        for i in version.items.indices where version.items[i].key == "guarantee.hourly" {
            version.items[i].confidence = .verified
        }
        let engine = TariffFixtures.engine([version])
        var input = TariffFixtures.input("yemeksepeti")
        input.dayPackages = 10
        input.combinedPackages = 2
        input.hours = 5
        let low = TariffFixtures.calc(input, engine: engine)
        // Garanti 1500; paket geliri 810–830 -> fark 690–670; brut her senaryoda 1500
        XCTAssertEqual(low.gross, money("1500"))
        XCTAssertEqual(low.grossUpper, money("1500"))
        // Gelir garantiyi asarsa fark odemesi yok
        input.dayPackages = 30
        let high = TariffFixtures.calc(input, engine: engine)
        XCTAssertEqual(high.line("guarantee.hourly")?.amount, .zero)
        XCTAssertEqual(high.gross, money("2310"))
    }

    func testYemeksepetiTipsSeparateAndReferralOnlyWhenEligible() {
        var input = TariffFixtures.input("yemeksepeti")
        input.dayPackages = 4
        input.tips = money("120")
        let result = TariffFixtures.calc(input)
        XCTAssertEqual(result.gross, money("300"), "bahsis brute girmez")
        XCTAssertEqual(result.tips, money("120"))
        XCTAssertEqual(result.prePayment, money("420"))
        XCTAssertNil(result.lines.first { $0.type == .referralBonus })

        input.referralConditionsMet = true
        let noAmount = TariffFixtures.calc(input)
        XCTAssertTrue(noAmount.notices.contains { $0.kind == .missing && $0.message.contains("Referans") })
        input.referralAmount = money("500")
        let withReferral = TariffFixtures.calc(input)
        XCTAssertEqual(withReferral.gross, money("800"))
    }

    func testYemeksepetiWeeklyBonusFromUserTariff() {
        var version = TariffFixtures.bundled("yemeksepeti-esnaf-v1")
        version.id = "ys-user"
        version.origin = .user
        version.items.append(TariffFixtures.item("bonus.weekly.100", .weeklyBonus, "1000", version: "ys-user",
                                                 method: .tier, unit: .week, lower: "100", confidence: .userEntered))
        let engine = TariffFixtures.engine(TariffFixtures.bundled + [version])
        var input = TariffFixtures.input("yemeksepeti", day: "2026-10-05", span: .week, end: "2026-10-11")
        input.dayPackages = 99
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).bonusTotal, .zero)
        input.dayPackages = 100
        let result = TariffFixtures.calc(input, engine: engine)
        XCTAssertEqual(result.tariffVersionID, "ys-user", "kullanici onayli tarife oncelikli")
        XCTAssertEqual(result.bonusTotal, money("1000"))
    }

    // MARK: - Paket Taxi / Migros Hemen

    func testPaketTaxiMonthRegionFixedAndAllUnitsTier() {
        var input = TariffFixtures.input("migros_hemen", day: "2026-10-01", span: .month, end: "2026-10-31")
        input.regionTier = "plus"
        input.dayPackages = 1250
        let result = TariffFixtures.calc(input)
        XCTAssertEqual(result.line("fixed.region.plus")?.amount, money("65223"))
        XCTAssertEqual(result.line("package.performance.1100")?.amount, money("50000"))
        XCTAssertEqual(result.gross, money("115223"))
        let alt = result.notices.first { $0.kind == .ambiguity && $0.message.contains("Kademe") }
        // Esik ustu: 1099 x 38 + 151 x 40 = 47.802
        XCTAssertEqual(alt?.alternativeGross, money("113025"))
    }

    func testPaketTaxiAboveThresholdOnlyAndBoundaries() {
        var version = TariffFixtures.bundled("migros_hemen-esnaf-v1")
        version.settings.thresholdApplication = .aboveThresholdOnly
        version.settings.confidence["threshold_application"] = .verified
        let engine = TariffFixtures.engine([version])
        func pay(_ count: Int, _ engine: PayEngine) -> Money {
            var input = TariffFixtures.input("migros_hemen", day: "2026-10-01", span: .month, end: "2026-10-31")
            input.dayPackages = count
            return TariffFixtures.calc(input, engine: engine).lines.filter { $0.type == .singlePackage }.map(\.amount).sum()
        }
        XCTAssertEqual(pay(1250, engine), money("47802"))
        XCTAssertEqual(pay(1099, engine), money("41762"))
        XCTAssertEqual(pay(1100, engine), money("41802")) // 1099 x 38 + 1 x 40
        XCTAssertEqual(pay(1099, TariffFixtures.engine), money("41762"))
        XCTAssertEqual(pay(1100, TariffFixtures.engine), money("44000")) // tum paketlere 40
    }

    func testPaketTaxiSeniorityIsAlternativeNotAdded() {
        var input = TariffFixtures.input("migros_hemen", day: "2026-10-01", span: .month, end: "2026-10-31")
        input.regionTier = "standard"
        input.seniorityYears = 2
        input.dayPackages = 500
        let result = TariffFixtures.calc(input)
        XCTAssertEqual(result.line("fixed.region.standard")?.included, true)
        XCTAssertEqual(result.line("fixed.seniority.2")?.included, false)
        XCTAssertEqual(result.gross, money("72223")) // 53.223 + 500 x 38
        let alt = result.notices.first { $0.message.contains("kıdem") }
        XCTAssertEqual(alt?.alternativeGross, money("57000")) // 38.000 + 19.000
    }

    func testPaketTaxiFixedCoveredPackagesNotDoubleCounted() {
        var version = TariffFixtures.bundled("migros_hemen-esnaf-v1")
        version.settings.fixedCoversPackages = 1000
        var input = TariffFixtures.input("migros_hemen", day: "2026-10-01", span: .month, end: "2026-10-31")
        input.regionTier = "plus"
        input.dayPackages = 1250
        let result = TariffFixtures.calc(input, engine: TariffFixtures.engine([version]))
        XCTAssertEqual(result.line("package.performance.1100")?.amount, money("10000")) // 250 x 40
        XCTAssertEqual(result.gross, money("75223"))
    }

    func testPaketTaxiDailyLogIsProvisionalAndSideBenefitsNotCash() {
        var input = TariffFixtures.input("migros_hemen")
        input.dayPackages = 50
        input.flags = ["woman_employment"]
        let result = TariffFixtures.calc(input)
        XCTAssertEqual(result.gross, money("1900"))
        XCTAssertEqual(result.lines.first?.provisional, true)
        XCTAssertTrue(result.notices.contains { $0.kind == .deferred && $0.message.contains("sabit") })
        XCTAssertEqual(result.sideBenefits.map(\.itemKey).sorted(), ["side.shopping_card", "side.woman_employment"])
        XCTAssertFalse(result.sideBenefits.contains { $0.included })
    }
}

extension Result {
    var failureValue: Failure? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
