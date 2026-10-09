import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScreenshotSuggestionRuleTests: XCTestCase {
    private let parser = EarningsScreenshotParser()

    private func qualifies(_ lines: [String]) -> Bool {
        ScreenshotSuggestionRule.qualifies(parser.parse(lines: lines))
    }

    func testEarningsScreenWithFingerprintAndTotalQualifies() {
        XCTAssertTrue(qualifies(["Getir", "Kazançlarım", "Toplam Kazanç", "₺700"]))
        XCTAssertTrue(qualifies(["Trendyol GO", "Kazanç Raporu", "Toplam Kazanç", "₺1.200,00", "Teslimat Sayısı", "15"]))
    }

    func testPlatformWithSingleFingerprintDoesNotQualify() {
        // Ornek: kampanya bildirimi; platform adi ve "toplam kazanc" var ama kazanc ekrani degil
        XCTAssertFalse(qualifies(["Getir", "Toplam Kazanç", "₺700"]))
    }

    func testZeroTotalDoesNotQualify() {
        XCTAssertFalse(qualifies(["Getir", "Kazançlarım", "Toplam Kazanç"]))
    }

    func testUnknownPlatformDoesNotQualify() {
        XCTAssertFalse(qualifies(["Hava durumu", "18°"]))
        XCTAssertFalse(qualifies(["Kazançlarım", "Toplam Kazanç", "₺700"]))
    }

    func testOrderCardNeverQualifies() {
        var parsed = ParsedEarning(platformCode: "yemeksepeti", date: .now, packageCount: 1, totalEarning: 147.5, bonus: 0,
                                   totalIncludesBonus: true, fieldsToReview: [], templateID: "yemeksepeti.order",
                                   fingerprintMatches: 5)
        parsed.period = .order
        XCTAssertFalse(ScreenshotSuggestionRule.qualifies(parsed))
    }

    func testUnknownTemplateIDDoesNotQualify() {
        let parsed = ParsedEarning(platformCode: "getir", date: .now, packageCount: 1, totalEarning: 500, bonus: 0,
                                   totalIncludesBonus: true, fieldsToReview: [], templateID: "yok.earnings",
                                   fingerprintMatches: 5)
        XCTAssertFalse(ScreenshotSuggestionRule.qualifies(parsed))
    }
}
