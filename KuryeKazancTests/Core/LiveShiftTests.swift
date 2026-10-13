import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class LiveShiftTests: XCTestCase {
    private let day = "2026-10-14"
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])
    private let store = GeoPoint(latitude: 41.0082, longitude: 28.9784)

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: hour, minute: minute))!
    }

    /// Kuzeye `km` kus ucusu nokta.
    private func north(_ km: Double) -> GeoPoint {
        GeoPoint(latitude: store.latitude + km / 111.195, longitude: store.longitude)
    }

    func testHaversine() {
        XCTAssertEqual(store.distanceKm(to: north(5)), 5, accuracy: 0.01)
    }

    func testYemeksepetiEveningBandFrom18() {
        XCTAssertEqual(ShiftClock.band(at: date(17, 59), platform: "yemeksepeti", calendar: calendar), .day)
        XCTAssertEqual(ShiftClock.band(at: date(18, 0), platform: "yemeksepeti", calendar: calendar), .night)
        XCTAssertEqual(ShiftClock.band(at: date(7, 30), platform: "yemeksepeti", calendar: calendar), .night)
        XCTAssertEqual(ShiftClock.band(at: date(20), platform: "getir", calendar: calendar), .day)
    }

    func testFirstPointBecomesOriginAndDistanceUsesRoadFactor() {
        var shift = LiveShift(platformCode: "migros_hemen", start: date(9))
        let first = shift.addDelivery(at: date(9, 20), point: store, calendar: calendar)
        XCTAssertNil(first.distanceKm)
        XCTAssertEqual(shift.startPoint, store)
        let second = shift.addDelivery(at: date(9, 50), point: north(4), calendar: calendar)
        XCTAssertEqual(second.distanceKm, Decimal(string: "5.2"))
        XCTAssertEqual(shift.undoLast()?.id, second.id)
        XCTAssertEqual(shift.packageCount, 1)
    }

    func testPaketTaxiZoneShowsDistanceBand() {
        let version = catalog.current(platform: "migros_hemen", day: day)
        var shift = LiveShift(platformCode: "migros_hemen", start: date(9), startPoint: store)
        let near = shift.addDelivery(at: date(10), point: north(2), calendar: calendar)
        let mid = shift.addDelivery(at: date(11), point: north(4), calendar: calendar)
        let far = shift.addDelivery(at: date(12), point: north(6), calendar: calendar)
        XCTAssertEqual(ShiftZones.zone(for: near, platform: "migros_hemen", version: version, day: day).title, "0–4 km")
        let midZone = ShiftZones.zone(for: mid, platform: "migros_hemen", version: version, day: day)
        XCTAssertEqual(midZone.title, "4–6 km bandı")
        XCTAssertTrue(midZone.detail.contains("25"))
        XCTAssertEqual(ShiftZones.zone(for: far, platform: "migros_hemen", version: version, day: day).title, "6 km üstü bandı")
    }

    func testYemeksepetiZoneNamesEveningBand() {
        let version = catalog.current(platform: "yemeksepeti", day: day)
        var shift = LiveShift(platformCode: "yemeksepeti", start: date(17))
        let evening = shift.addDelivery(at: date(19), point: nil, calendar: calendar)
        let zone = ShiftZones.zone(for: evening, platform: "yemeksepeti", version: version, day: day)
        XCTAssertEqual(zone.title, "Akşam bandı")
        XCTAssertTrue(zone.detail.hasPrefix("Paket başı"))
    }

    func testShiftInputSplitsBandsAndPaysDistanceExtras() throws {
        let version = try XCTUnwrap(catalog.current(platform: "migros_hemen", day: day))
        var shift = LiveShift(platformCode: "migros_hemen", start: date(9), startPoint: store)
        _ = shift.addDelivery(at: date(10), point: north(2), calendar: calendar)
        _ = shift.addDelivery(at: date(11), point: north(4), calendar: calendar)
        _ = shift.addDelivery(at: date(12), point: north(6), calendar: calendar)
        var base = PayInput(platformCode: "migros_hemen", startDay: day)
        base.regionTier = "plus"
        let input = ShiftPayInput.make(shift: shift, end: date(17), gpsKm: Decimal(42), base: base, version: version)
        XCTAssertEqual(input.totalPackages, 3)
        XCTAssertEqual(input.nightPackages, 0)
        XCTAssertEqual(input.hours, 8)
        XCTAssertEqual(input.deliveryDistancesKm.count, 3)
        let result = try PayEngine(catalog: catalog).calculate(input).get()
        XCTAssertEqual(result.gross, Money(60))
    }

    func testShiftInputCountsYemeksepetiEveningPackages() throws {
        let version = try XCTUnwrap(catalog.current(platform: "yemeksepeti", day: day))
        var shift = LiveShift(platformCode: "yemeksepeti", start: date(16))
        for hour in [16, 17, 18, 19, 20] { _ = shift.addDelivery(at: date(hour, 30), point: nil, calendar: calendar) }
        let input = ShiftPayInput.make(shift: shift, end: date(21), gpsKm: Decimal(30),
                                       base: PayInput(platformCode: "yemeksepeti", startDay: day), version: version)
        XCTAssertEqual(input.dayPackages, 2)
        XCTAssertEqual(input.nightPackages, 3)
        XCTAssertEqual(input.totalKm, 30)
        XCTAssertTrue(input.deliveryDistancesKm.isEmpty)
    }

    func testGetirHasNoNightSplit() {
        let version = catalog.current(platform: "getir", day: day, vehicleType: "motorcycle")
        var shift = LiveShift(platformCode: "getir", start: date(20))
        _ = shift.addDelivery(at: date(23), point: nil, calendar: calendar)
        let input = ShiftPayInput.make(shift: shift, end: date(23, 30), gpsKm: nil,
                                       base: PayInput(platformCode: "getir", startDay: day), version: version)
        XCTAssertEqual(input.dayPackages, 1)
        XCTAssertNil(input.totalKm)
    }

    func testShiftSurvivesCoding() throws {
        var shift = LiveShift(platformCode: "trendyol_go", start: date(9), province: "İzmir")
        _ = shift.addDelivery(at: date(10), point: store, calendar: calendar)
        let data = try JSONEncoder().encode(shift)
        XCTAssertEqual(try JSONDecoder().decode(LiveShift.self, from: data), shift)
    }
}

final class RegionResolverTests: XCTestCase {
    private func profile(_ platform: String, tier: String? = nil, flags: [String] = []) -> CourierTariffProfile {
        CourierTariffProfile(platformCode: platform, regionTier: tier, seniorityYears: nil, vehicleType: nil, flags: flags)
    }

    func testNormalizesTurkishCityNames() {
        XCTAssertEqual(RegionResolver.normalized("İZMİR"), "izmir")
        XCTAssertEqual(RegionResolver.normalized("İstanbul"), "istanbul")
        XCTAssertEqual(RegionResolver.normalized(" Kırşehir "), "kirsehir")
    }

    func testYemeksepetiCityFlagFollowsLocation() throws {
        let added = try XCTUnwrap(RegionResolver.suggest(province: "İzmir", profile: profile("yemeksepeti")))
        XCTAssertTrue(added.changed)
        XCTAssertEqual(added.flags, ["ys_ankara_izmir"])
        XCTAssertNotNil(added.message)
        let removed = try XCTUnwrap(RegionResolver.suggest(province: "Bursa",
                                                          profile: profile("yemeksepeti", flags: ["ys_ankara_izmir", "woman_employment"])))
        XCTAssertEqual(removed.flags, ["woman_employment"])
        let same = try XCTUnwrap(RegionResolver.suggest(province: "Ankara", profile: profile("yemeksepeti", flags: ["ys_ankara_izmir"])))
        XCTAssertFalse(same.changed)
    }

    func testPaketTaxiStandardOutsideIstanbulAnkara() throws {
        let outside = try XCTUnwrap(RegionResolver.suggest(province: "Antalya", profile: profile("migros_hemen", tier: "plus")))
        XCTAssertEqual(outside.regionTier, "standard")
        XCTAssertTrue(outside.changed)
        let istanbul = try XCTUnwrap(RegionResolver.suggest(province: "İstanbul", profile: profile("migros_hemen", tier: "plus")))
        XCTAssertFalse(istanbul.changed)
        XCTAssertFalse(istanbul.needsRegionChoice)
        let unknown = try XCTUnwrap(RegionResolver.suggest(province: "Ankara", profile: profile("migros_hemen")))
        XCTAssertTrue(unknown.needsRegionChoice)
        XCTAssertNil(RegionResolver.suggest(province: nil, profile: profile("migros_hemen")))
    }
}

final class PayDetailTests: XCTestCase {
    private let day = "2026-10-14"
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])

    func testDailyPaketTaxiAddsFixedShareAsEstimate() throws {
        var input = PayInput(platformCode: "migros_hemen", startDay: day)
        input.regionTier = "plus"
        input.dayPackages = 30
        input.deliveryDistancesKm = [5, 7]
        let result = try PayEngine(catalog: catalog).calculate(input).get()
        let version = catalog.current(platform: "migros_hemen", day: day)
        let detail = PayDetailBuilder.make(breakdown: result, days: 1, version: version, regionTier: "plus", monthWorkDays: 26)
        let fixed = try XCTUnwrap(detail.rows(in: .fixed).first)
        XCTAssertTrue(fixed.isEstimate)
        XCTAssertEqual(fixed.perDay, Money(Money.round(Decimal(65_223) / 26)))
        XCTAssertEqual(detail.total(.distance), Money(60))
        XCTAssertTrue(detail.hasEstimates)
        XCTAssertEqual(detail.periodTotal, fixed.periodAmount + Money(60))
    }

    func testMonthlyPlanSplitsPerDay() throws {
        var input = PayInput(platformCode: "migros_hemen", span: .month, startDay: "2026-10-01", endDay: "2026-10-31")
        input.regionTier = "standard"
        input.dayPackages = 1_700
        let result = try PayEngine(catalog: catalog).calculate(input).get()
        let detail = PayDetailBuilder.make(breakdown: result, days: 26)
        XCTAssertEqual(detail.total(.fixed), Money(53_223))
        XCTAssertEqual(detail.total(.bonus), Money(55_600))
        XCTAssertFalse(detail.hasEstimates)
        XCTAssertEqual(detail.rows(in: .fixed).first?.perDay, Money(Money.round(Decimal(53_223) / 26)))
    }

    func testTrendyolPackagesGroupedSeparately() throws {
        var input = PayInput(platformCode: "trendyol_go", startDay: day)
        input.dayPackages = 20
        input.nightPackages = 5
        input.totalKm = 40
        let result = try PayEngine(catalog: catalog).calculate(input).get()
        let detail = PayDetailBuilder.make(breakdown: result, days: 1)
        XCTAssertEqual(detail.rows(in: .packages).count, 2)
        XCTAssertEqual(detail.periodTotal, result.gross)
        XCTAssertTrue(detail.rows(in: .packages).allSatisfy { $0.quantityText?.contains("paket") == true })
    }
}

final class ManualEntryTests: XCTestCase {
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])

    func testWeekOfEvenDaysMatchesSixDailyCalculations() throws {
        let engine = PayEngine(catalog: catalog)
        let version = catalog.current(platform: "trendyol_go", day: "2026-10-12")
        let day = ManualEntry(packages: 45, hours: 9).input(base: PayInput(platformCode: "trendyol_go", startDay: "2026-10-12"),
                                                          version: version)
        let daily = try engine.calculate(day).get().gross
        let base = PayInput(platformCode: "trendyol_go", span: .week, startDay: "2026-10-12", endDay: "2026-10-18")
        let week = ManualEntry(packages: 270, hours: 54, days: 6).input(base: base, version: version)
        XCTAssertEqual(week.periodPackages, 270)
        XCTAssertFalse(week.bonusTierDays.isEmpty)
        XCTAssertEqual(try engine.calculate(week).get().gross, daily * 6)
    }

    func testDayIgnoresPeriodFields() {
        let input = ManualEntry(packages: 10, nightPackages: 2, km: 0, hours: 4, days: 5)
            .input(base: PayInput(platformCode: "yemeksepeti", startDay: "2026-10-12"), version: nil)
        XCTAssertNil(input.periodPackages)
        XCTAssertNil(input.totalKm)
        XCTAssertEqual(input.totalPackages, 12)
    }
}
