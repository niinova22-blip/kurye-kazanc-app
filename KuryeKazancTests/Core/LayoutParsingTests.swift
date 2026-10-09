import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class LayoutParsingTests: XCTestCase {
    private func template(_ layout: OCRTemplate.Layout, total: [String] = ["toplam"], bonus: [String] = [],
                          rows: [String] = [], duration: [String] = []) -> OCRTemplate {
        OCRTemplate(
            id: "t.\(layout.rawValue)", version: 1, status: .calibrating, platformCode: "t",
            detectionKeywords: ["testapp"], fingerprint: [], minFingerprintMatches: 0,
            totalLabels: total, bonusLabels: bonus, packageLabels: ["teslimat"], totalIncludesBonus: true,
            minPackageFee: nil, maxPackageFee: nil, dayLabels: ["bugun"], weekLabels: ["bu hafta"],
            layout: layout, durationLabels: duration, rowLabels: rows, amountsExcludeVAT: layout == .orderCard
        )
    }

    private func parse(_ t: OCRTemplate, _ lines: [String]) -> ParsedEarning {
        EarningsScreenshotParser(templates: [t]).parse(lines: lines)
    }

    func testList_sumsRowsAndCountsThem() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Faturalar 3",
                          "Taşıma Ücreti 303,3₺", "#1420",
                          "Taşıma Ücreti 900₺", "#903",
                          "Taşıma Ücreti 56₺", "#314"])
        XCTAssertEqual(r.totalEarning, 1259.3, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 3)
        XCTAssertEqual(r.bonus, 0)
        XCTAssertEqual(r.layout, .list)
        XCTAssertFalse(r.fieldsToReview.contains(.totalEarning))
        XCTAssertFalse(r.fieldsToReview.contains(.bonus))
        XCTAssertFalse(r.fieldsToReview.contains(.packageCount))
    }

    /// Review Focus 2: tutar alt satirdaysa bile is numarasi tutar sayilmaz.
    func testList_valueOnNextLine_ignoresReferenceNumbers() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Taşıma Ücreti", "#1420", "303,3 ₺", "Taşıma Ücreti", "#903", "70 ₺"])
        XCTAssertEqual(r.totalEarning, 373.3, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 2)
    }

    func testList_shownTotalMismatch_flagsTotal() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Taşıma Ücreti 100₺", "Taşıma Ücreti 100₺", "Toplam 500₺"])
        XCTAssertEqual(r.totalEarning, 200, accuracy: 0.001)
        XCTAssertTrue(r.fieldsToReview.contains(.totalEarning))
    }

    func testList_noRows_fallsBackWithReview() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Toplam 450₺"])
        XCTAssertEqual(r.totalEarning, 450, accuracy: 0.001)
        XCTAssertTrue(r.fieldsToReview.contains(.totalEarning))
    }

    func testOrderCard_largestCurrencyAmountAndExtra() {
        let t = template(.orderCard, total: [], bonus: ["dahil", "includes"])
        let r = parse(t, ["TestApp", "Kabul oranı %89", "₺147,50", "₺37,00 ek dahil", "Teslim al 1,6 km - 12 dk", "Kabul et"])
        XCTAssertEqual(r.totalEarning, 147.5, accuracy: 0.001)
        XCTAssertEqual(r.bonus, 37, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 1)
        XCTAssertEqual(r.period, .order)
        XCTAssertTrue(r.amountsExcludeVAT)
        XCTAssertFalse(r.fieldsToReview.contains(.totalEarning))
        XCTAssertFalse(r.fieldsToReview.contains(.packageCount))
        XCTAssertFalse(r.fieldsToReview.contains(.bonus))
    }

    func testOrderCard_labelledAmountWithoutCurrency() {
        let t = template(.orderCard, total: ["nakit kazanc"])
        let r = parse(t, ["TestApp", "Sipariş №78347 Bugün", "Nakit kazanç", "430", "Gönderi Notu"])
        XCTAssertEqual(r.totalEarning, 430, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 1)
    }

    func testSummary_readsDurationNextToLabel() {
        let t = template(.summary, total: ["kazanclar"], duration: ["cevrimici", "online"])
        let r = parse(t, ["TestApp", "Kazançlar", "₺6.459,90", "Çevrimiçi 23 sa 32 dk", "54 Teslimat"])
        XCTAssertEqual(r.totalEarning, 6459.9, accuracy: 0.001)
        XCTAssertEqual(r.workDuration, 23 * 3600 + 32 * 60)
        XCTAssertEqual(r.packageCount, 54)

        let split = parse(t, ["TestApp", "Online", "23h 32m"])
        XCTAssertEqual(split.workDuration, 23 * 3600 + 32 * 60)
    }

    func testDuration_absentIsNilNotReviewed() {
        let t = template(.summary, duration: ["cevrimici"])
        let r = parse(t, ["TestApp", "Toplam 500₺"])
        XCTAssertNil(r.workDuration)
    }
}
