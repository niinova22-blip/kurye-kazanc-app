import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Sunucudan gelen eski / ileri surum sablon JSON'u cokmeden cozulmeli (Review Focus 1).
final class TemplateCompatibilityTests: XCTestCase {
    private let oldJSON = #"""
    {"id":"x.earnings","version":1,"status":"calibrating","platformCode":"getir",
     "detectionKeywords":["getir"],"fingerprint":["kazanclarim"],"minFingerprintMatches":1,
     "totalLabels":["toplam"],"bonusLabels":[],"packageLabels":[],"totalIncludesBonus":true,
     "dayLabels":["bugun"],"weekLabels":["bu hafta"]}
    """#

    func testOldJSONWithoutNewFields_usesDefaults() throws {
        let template = try JSONDecoder().decode(OCRTemplate.self, from: Data(oldJSON.utf8))
        XCTAssertEqual(template.layout, .summary)
        XCTAssertEqual(template.durationLabels, [])
        XCTAssertEqual(template.rowLabels, [])
        XCTAssertFalse(template.amountsExcludeVAT)
        XCTAssertNil(template.minPackageFee)
    }

    func testUnknownLayout_fallsBackToSummary() throws {
        let json = oldJSON.replacingOccurrences(of: #""version":1,"#, with: #""version":1,"layout":"grid","#)
        let template = try JSONDecoder().decode(OCRTemplate.self, from: Data(json.utf8))
        XCTAssertEqual(template.layout, .summary)
    }

    func testNewFields_roundTrip() throws {
        var template = try JSONDecoder().decode(OCRTemplate.self, from: Data(oldJSON.utf8))
        template.layout = .list
        template.durationLabels = ["cevrimici"]
        template.rowLabels = ["tasima ucreti"]
        template.amountsExcludeVAT = true
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(OCRTemplate.self, from: data)
        XCTAssertEqual(decoded, template)
    }

    func testOrderPeriodRawValue() {
        XCTAssertEqual(OCRTemplate.Period(rawValue: "order"), .order)
    }
}
