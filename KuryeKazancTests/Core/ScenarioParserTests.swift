import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Katman A: senaryo -> OCR satirlari -> cozumleyici. Satir katmaninda OCR gurultusu yok: hepsi gecmeli.
final class ScenarioParserTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    func testGeneratorIsDeterministicAndLargeEnough() {
        let a = ScenarioGenerator().all()
        let b = ScenarioGenerator().all()
        XCTAssertEqual(a, b)
        XCTAssertGreaterThanOrEqual(a.count, 100)
        XCTAssertEqual(Set(a.map(\.id)).count, a.count, "Senaryo kimlikleri benzersiz olmali")
        XCTAssertEqual(Set(a.map(\.templateID)).count, 8, "Her temel duzen en az bir kez")
    }

    func testStyles() {
        let s = ScenarioGenerator().all().first { $0.textStyle == .ascii }!
        XCTAssertEqual(s.styled("Toplam Kazanç Şık"), "Toplam Kazanc Sik")
        let u = ScenarioGenerator().all().first { $0.textStyle == .upper }!
        XCTAssertEqual(u.styled("Sipariş"), "SİPARİŞ")
    }

    func testAllScenariosParseAtLineLevel() {
        let parser = EarningsScreenshotParser(calendar: calendar)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14))!
        var failures: [String] = []
        for scenario in ScenarioGenerator().all() {
            let parsed = parser.parse(lines: scenario.ocrLines(), referenceDate: reference)
            for (field, ok) in scenario.expected.check(parsed) where !ok {
                failures.append("\(scenario.id) \(field.rawValue): satirlar=\(scenario.ocrLines())")
            }
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count) hata:\n" + failures.prefix(15).joined(separator: "\n"))
    }

    func testExpectationCheck() {
        let e = ScenarioExpectation(templateID: "getir.earnings", total: 980, bonus: nil, packages: 11, duration: nil, period: .day)
        let p = ParsedEarning(platformCode: "getir", date: .now, packageCount: 11, totalEarning: 980.004, bonus: 5,
                              totalIncludesBonus: true, fieldsToReview: [], templateID: "getir.earnings", period: .day)
        XCTAssertEqual(e.check(p), [.template: true, .total: true, .packages: true, .period: true])
    }
}
