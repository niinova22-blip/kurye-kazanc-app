import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class TemplateSelectionTests: XCTestCase {
    private func template(id: String, keywords: [String], fingerprint: [String], min: Int) -> OCRTemplate {
        OCRTemplate(
            id: id, version: 1, status: .calibrating, platformCode: id,
            detectionKeywords: keywords, fingerprint: fingerprint, minFingerprintMatches: min,
            totalLabels: ["toplam"], bonusLabels: [], packageLabels: [], totalIncludesBonus: true,
            minPackageFee: nil, maxPackageFee: nil, dayLabels: [], weekLabels: []
        )
    }

    private func normalized(_ lines: [String]) -> [String] { lines.map(TextNormalizer.normalize) }

    func testFingerprintOnly_selectsWhenThresholdMet() {
        let uber = template(id: "uber", keywords: [], fingerprint: ["kazanclar", "cevrimici", "teslimat", "bakiye"], min: 3)
        let parser = EarningsScreenshotParser(templates: [uber])
        XCTAssertEqual(parser.detectTemplate(in: normalized(["Kazançlar", "Çevrimiçi 5 sa", "54 Teslimat"]))?.id, "uber")
        XCTAssertNil(parser.detectTemplate(in: normalized(["Kazançlar", "Çevrimiçi 5 sa"])))
    }

    func testFingerprintOnly_ignoresLowThresholdTemplates() {
        let loose = template(id: "loose", keywords: [], fingerprint: ["toplam", "kazanc"], min: 2)
        let parser = EarningsScreenshotParser(templates: [loose])
        XCTAssertNil(parser.detectTemplate(in: normalized(["Toplam", "Kazanç"])))
    }

    /// Review Focus 5: ad eslesmesi her zaman parmak izinden once gelir.
    func testNameMatchBeatsStrongerFingerprint() {
        let getir = template(id: "getir", keywords: ["getir"], fingerprint: ["kazanclarim"], min: 1)
        let other = template(id: "other", keywords: [], fingerprint: ["kazanclarim", "toplam kazanc", "siparis sayisi"], min: 3)
        let parser = EarningsScreenshotParser(templates: [other, getir])
        let lines = normalized(["Getir", "Kazançlarım", "Toplam Kazanç", "Sipariş Sayısı"])
        XCTAssertEqual(parser.detectTemplate(in: lines)?.id, "getir")
    }

    func testSameKeyword_tieBrokenByFingerprint() {
        let summary = template(id: "ys.earnings", keywords: ["yemeksepeti"], fingerprint: ["odemeler", "toplam kazanc"], min: 2)
        let order = template(id: "ys.order", keywords: ["yemeksepeti"], fingerprint: ["kabul et", "reddet", "ek dahil"], min: 3)
        let parser = EarningsScreenshotParser(templates: [summary, order])
        XCTAssertEqual(parser.detectTemplate(in: normalized(["Yemeksepeti", "Kabul et", "Reddet", "₺37 ek dahil"]))?.id, "ys.order")
        XCTAssertEqual(parser.detectTemplate(in: normalized(["Yemeksepeti", "Ödemeler", "Toplam Kazanç"]))?.id, "ys.earnings")
    }

    func testDateRangeMeansWeek() {
        let t = template(id: "u", keywords: [], fingerprint: [], min: 0)
        XCTAssertEqual(t.period(in: TextNormalizer.normalize("Kazançlar 4 Şub - 10 Şub")), .week)
    }
}
