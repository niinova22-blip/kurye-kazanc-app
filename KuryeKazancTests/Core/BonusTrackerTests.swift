import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Gunluk / haftalik / aylik sayac ve kademe durumu (bizim tarifeler, 2026-10).
final class BonusTrackerTests: XCTestCase {
    private let day = "2026-10-15"
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])
    private var engine: PayEngine { PayEngine(catalog: catalog) }

    private func tracks(_ platform: String, region: String?, hours: Int? = nil,
                        day d: Int, week w: Int, month m: Int) throws -> [BonusTrack] {
        var base = PayInput(platformCode: platform, startDay: day)
        base.regionTier = region
        base.contractHours = hours
        let version = try XCTUnwrap(catalog.current(platform: platform, day: day))
        return BonusTracker.tracks(engine: engine, version: version, base: base, day: day,
                                   counts: [.day: d, .week: w, .month: m])
    }

    func testMigrosDailyPrimeAndMonthlyBonus() throws {
        let t = try tracks("pt_migros", region: "r23", day: 25, week: 110, month: 760)
        XCTAssertEqual(t.map(\.scope), [.day, .week, .month])
        // Gun: 25 paket -> 24–27 primi 760 TL, siradaki 28 -> 1.005 TL
        XCTAssertEqual(t[0].reached, Money(760))
        XCTAssertEqual(t[0].next?.target, 28)
        XCTAssertEqual(t[0].next?.reward, Money(1_005))
        // Hafta: Paket Taxi'de haftalik bonus yok, yalnizca sayac
        XCTAssertFalse(t[1].hasBonus)
        XCTAssertEqual(t[1].packages, 110)
        // Ay: 760 paket -> 700–799 bonusu 12.800 TL, siradaki 800 -> 20.224 TL
        XCTAssertEqual(t[2].reached, Money(12_800))
        XCTAssertEqual(t[2].next?.target, 800)
        XCTAssertEqual(t[2].reached.value, 12_800)
    }

    func testMigrosBelowFirstTiers() throws {
        let t = try tracks("pt_migros", region: "r23", day: 10, week: 10, month: 10)
        XCTAssertEqual(t[0].reached, .zero)
        XCTAssertEqual(t[0].next?.target, 16)
        XCTAssertEqual(t[2].reached, .zero)
        XCTAssertEqual(t[2].next?.target, 700)
    }

    func testYemeksepetiDailyAndWeeklyNoMonthly() throws {
        let t = try tracks("yemeksepeti", region: "ys_istanbul", day: 24, week: 185, month: 700)
        XCTAssertEqual(t.map(\.scope), [.day, .week])
        // Gun: 23–25 -> 200 TL, siradaki 26 -> 250 TL
        XCTAssertEqual(t[0].reached, Money(200))
        XCTAssertEqual(t[0].next?.target, 26)
        // Hafta (Istanbul): 180–199 -> 2.850 TL, siradaki 200 -> 5.250 TL
        XCTAssertEqual(t[1].reached, Money(2_850))
        XCTAssertEqual(t[1].next?.target, 200)
        XCTAssertEqual(t[1].next?.reward, Money(5_250))
    }

    func testRestoranPrimeFromThreshold() throws {
        // 11 saat, 2.–3. bolge: 26–40. paket 25 TL, 41.'den 34 TL; 45 paket -> 15×25 + 5×34
        let t = try tracks("pt_restoran", region: "r23", hours: 11, day: 45, week: 200, month: 900)
        XCTAssertEqual(t[0].reached, Money(15 * 25 + 5 * 34))
        XCTAssertTrue(t[0].hasBonus)
    }
}
