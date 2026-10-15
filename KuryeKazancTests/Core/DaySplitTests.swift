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
