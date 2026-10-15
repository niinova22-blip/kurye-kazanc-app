import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Ayni gunun vardiyalari tek gun gibi hesaplanir (kullanici bildirimi 2026-10-15: 2.–3. bolgede 3–4 vardiyada toplam
/// 25 paket; 24–27 primi 760 TL yerine 16–19 primi 200 TL yazilmisti).
final class DaySplitTests: XCTestCase {
    private let day = "2026-10-15"
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])
    private var engine: PayEngine { PayEngine(catalog: catalog) }

    private func shift(_ platform: String, packages: Int, region: String = "r23", km: Decimal? = nil, hours: Int? = nil) -> PayInput {
        var input = PayInput(platformCode: platform, startDay: day)
        input.regionTier = region
        input.dayPackages = packages
        input.totalKm = km
        input.hours = 2
        input.contractHours = hours
        return input
    }

    private func shares(_ inputs: [PayInput]) throws -> [PayBreakdown] {
        try XCTUnwrap(DaySplit.shares(inputs: inputs) { combined, _ in try? self.engine.calculate(combined).get() })
    }

    func testMigrosShiftsGetDailyTierOfDayTotal() throws {
        let inputs = [6, 7, 5, 7].map { shift("pt_migros", packages: $0) }
        let parts = try shares(inputs)
        let total = try engine.calculate(try XCTUnwrap(DaySplit.combine(inputs))).get()
        // 25 paket, 2.–3. bolge: 24–27 primi
        XCTAssertEqual(total.gross, Money(760))
        XCTAssertEqual(parts.map(\.gross).sum(), Money(760))
        // 6, 13, 18 pakette 16–19 (200), 25'te 760: son vardiya farki tasir
        XCTAssertEqual(parts.map(\.gross), [.zero, .zero, Money(200), Money(560)])
    }

    func testOrderOfShiftsDoesNotChangeDayTotal() throws {
        for order in [[10, 8, 7], [7, 8, 10], [25], [1, 1, 23]] {
            let parts = try shares(order.map { shift("pt_migros", packages: $0) })
            XCTAssertEqual(parts.map(\.gross).sum(), Money(760), "\(order)")
        }
    }

    /// Kullanici: "27 paket 760 TL; gun bitmeden 28 yaparsa 28–33 araligina girer, 1.005 TL alir" (parca parca degil).
    func testCrossingTierReplacesLowerTierForWholeDay() throws {
        let parts = try shares([shift("pt_migros", packages: 27), shift("pt_migros", packages: 1)])
        XCTAssertEqual(parts[0].gross, Money(760))
        XCTAssertEqual(parts.map(\.gross).sum(), Money(1_005))
        // Gun dokumunde 24–27 satiri sifirlanir, yalnizca 28–33 kalir
        var byLabel: [String: Money] = [:]
        for line in parts.flatMap(\.lines) where line.included && line.isCash { byLabel[line.label, default: .zero] += line.amount }
        XCTAssertEqual(byLabel.filter { !$0.value.isZero }.count, 1)
        XCTAssertEqual(byLabel.values.filter { !$0.isZero }.first, Money(1_005))
    }

    func testSingleLogUnchanged() throws {
        let input = shift("pt_migros", packages: 38, region: "r1")
        let parts = try shares([input])
        let single = try engine.calculate(input).get()
        XCTAssertEqual(parts.first?.lines, single.lines)
        XCTAssertEqual(parts.first?.gross, single.gross)
    }

    func testRestoranThresholdPrimeCountsDayTotal() throws {
        // 11 saat: 26–40. paket 25 TL, 41.'den 34 TL. 25 + 20 = 45 paket -> 15×25 + 5×34
        let parts = try shares([shift("pt_restoran", packages: 25, hours: 11), shift("pt_restoran", packages: 20, hours: 11)])
        XCTAssertEqual(parts.map(\.gross).sum(), Money(15 * 25 + 5 * 34))
        XCTAssertEqual(parts[0].gross, .zero)
    }

    func testHemenKmBandsAddUpAndTierLineReversed() throws {
        var a = shift("migros_hemen", packages: 17)
        a.deliveryDistancesKm = Array(repeating: 5, count: 17)
        var b = shift("migros_hemen", packages: 8)
        b.deliveryDistancesKm = Array(repeating: 7, count: 8)
        let parts = try shares([a, b])
        let total = try engine.calculate(try XCTUnwrap(DaySplit.combine([a, b]))).get()
        XCTAssertEqual(parts.map(\.gross).sum(), total.gross)
        // Ikinci vardiya ust kademeye gecirir: payi kendi km bandi + kademe farki
        XCTAssertEqual(parts[1].gross, total.gross - parts[0].gross)
    }

    func testCombineMixesKmSources() throws {
        var a = shift("pt_migros", packages: 3, km: 10)
        a.deliveryDistancesKm = []
        var b = shift("pt_migros", packages: 2)
        b.deliveryDistancesKm = [2, 3]
        let combined = try XCTUnwrap(DaySplit.combine([a, b]))
        XCTAssertEqual(combined.totalPackages, 5)
        XCTAssertEqual(combined.distanceKm, 15)
        XCTAssertTrue(combined.deliveryDistancesKm.isEmpty)
        XCTAssertEqual(combined.hours, 4)
    }
}

/// 1.12.2 gun dongusu: gece yarisini gecen vardiya gunlere bolunur.
final class ShiftDayPartTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testMidnightShiftSplitsPackagesByDeliveryDay() {
        var shift = LiveShift(platformCode: "pt_migros", start: at(15, 20))
        for minute in stride(from: 0, to: 230, by: 10) {          // 20:00–23:50 arasi 23 paket
            _ = shift.addDelivery(at: at(15, 20).addingTimeInterval(Double(minute) * 60), point: nil, calendar: calendar)
        }
        for minute in [10, 40, 70, 100, 130] {                      // 00:10–02:10 arasi 5 paket
            _ = shift.addDelivery(at: at(16, 0).addingTimeInterval(Double(minute) * 60), point: nil, calendar: calendar)
        }
        var base = PayInput(platformCode: "pt_migros", startDay: "2026-10-15")
        base.regionTier = "r23"
        let parts = ShiftPayInput.makeByDay(shift: shift, end: at(16, 2, 30), gpsKm: 39, base: base, version: nil, calendar: calendar)
        XCTAssertEqual(parts.map(\.day), ["2026-10-15", "2026-10-16"])
        XCTAssertEqual(parts.map { $0.input.totalPackages }, [23, 5])
        XCTAssertEqual(parts[0].input.startDay, "2026-10-15")
        XCTAssertEqual(parts[1].input.startDay, "2026-10-16")
        // 4 saat + 2,5 saat; km sureyle orantili
        XCTAssertEqual(parts[0].input.hours, 4)
        XCTAssertEqual(parts[1].input.hours, Decimal(string: "2.5")!)
        XCTAssertEqual(parts.compactMap(\.input.totalKm).reduce(0, +), 39)
    }

    func testSameDayShiftIsOnePart() {
        var shift = LiveShift(platformCode: "yemeksepeti", start: at(15, 10))
        _ = shift.addDelivery(at: at(15, 11), point: nil, calendar: calendar)
        let base = PayInput(platformCode: "yemeksepeti", startDay: "2026-10-15")
        let parts = ShiftPayInput.makeByDay(shift: shift, end: at(15, 14), gpsKm: nil, base: base, version: nil, calendar: calendar)
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0].input.totalPackages, 1)
    }

    func testEmptyShiftHasNoParts() {
        let shift = LiveShift(platformCode: "yemeksepeti", start: at(15, 10))
        let base = PayInput(platformCode: "yemeksepeti", startDay: "2026-10-15")
        XCTAssertTrue(ShiftPayInput.makeByDay(shift: shift, end: at(15, 14), gpsKm: nil, base: base, version: nil, calendar: calendar).isEmpty)
    }
}

final class DaySplitYemeksepetiTests: XCTestCase {
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])
    private var engine: PayEngine { PayEngine(catalog: catalog) }

    /// Vardiya (saatli) + elle hesap (saatsiz) ayni gun: vardiyanin aksam saatleri korunur, gunluk bonus toplamdan.
    func testShiftSlotsKeptWhenManualEntrySameDay() throws {
        let day = "2026-10-13" // Sali
        var shift = PayInput(platformCode: "yemeksepeti", startDay: day)
        shift.regionTier = "ys_istanbul"
        shift.deliverySlots = [DeliverySlot(weekday: 3, hour: 19, count: 12)]
        shift.dayPackages = 12
        var manual = PayInput(platformCode: "yemeksepeti", startDay: day)
        manual.regionTier = "ys_istanbul"
        manual.dayPackages = 10
        let parts = try XCTUnwrap(DaySplit.shares(inputs: [shift, manual]) { combined, _ in try? self.engine.calculate(combined).get() })
        // 12 × 70,50 (Pzt–Per 18:00) + 10 × 59 (12:00) + gunluk 20–22 bonusu 150
        XCTAssertEqual(parts.map(\.gross).sum(), Money(Decimal(string: "846")! + 590 + 150))
    }
}
