import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class OCRTemplateTests: XCTestCase {
    func testBundledTemplatesDecodeAndCoverMainPlatforms() {
        let codes = Set(BundledTemplates.all.map(\.platformCode))
        XCTAssertEqual(codes, ["trendyol_go", "getir", "yemeksepeti", "migros_hemen", "uber", "thekurye", "banabikurye"])
        // Gercek ekranla kalibre edilene kadar hicbiri aktif degil
        XCTAssertTrue(BundledTemplates.all.allSatisfy { $0.status == .calibrating })
        XCTAssertEqual(BundledTemplates.generic.platformCode, "")
        XCTAssertNotNil(BundledTemplates.template(id: "getir.earnings"))
    }

    func testFingerprintAndPeriodDetection() {
        let template = BundledTemplates.template(id: "trendyol_go.earnings")!
        let text = TextNormalizer.normalize("Trendyol GO Kazançlarım Haftalık Kazanç Toplam Kazanç ₺3.200")
        XCTAssertGreaterThanOrEqual(template.fingerprintMatches(in: text), 2)
        XCTAssertEqual(template.period(in: text), .week)
        XCTAssertEqual(template.period(in: TextNormalizer.normalize("Bugün Toplam Kazanç")), .day)
        XCTAssertEqual(template.period(in: "toplam"), .unknown)
    }

    func testParserReportsTemplateMetadata() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 14))!
        let parsed = EarningsScreenshotParser(calendar: calendar).parse(
            lines: ["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"],
            referenceDate: reference
        )
        XCTAssertEqual(parsed.templateID, "getir.earnings")
        XCTAssertEqual(parsed.templateVersion, 2)
        XCTAssertEqual(parsed.templateStatus, .calibrating)
        XCTAssertEqual(parsed.period, .day)
        XCTAssertGreaterThanOrEqual(parsed.fingerprintMatches, 1)
    }

    func testUnknownPlatformUsesGenericTemplateWithoutID() {
        let parsed = EarningsScreenshotParser().parse(lines: ["Toplam 500 TL"])
        XCTAssertNil(parsed.templateID)
        XCTAssertNil(parsed.platformCode)
        XCTAssertTrue(parsed.fieldsToReview.contains(.platform))
    }
}
