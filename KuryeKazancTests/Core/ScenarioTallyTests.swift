import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScenarioTallyTests: XCTestCase {
    func testAccuracyDropsAndReport() {
        var tally = ScenarioTally()
        tally.add(platform: "getir", results: [.total: true, .packages: true])
        tally.add(platform: "getir", results: [.total: false, .packages: true])
        tally.add(platform: "uber", results: [.duration: true])

        XCTAssertEqual(tally.accuracy(), ["getir/total": 50, "getir/packages": 100, "uber/duration": 100])
        XCTAssertEqual(tally.drops(from: ["getir/total": 60, "getir/packages": 100], tolerance: 5), ["getir/total: 60.0 -> 50.0"])
        XCTAssertEqual(tally.drops(from: ["getir/total": 54], tolerance: 5), [])
        // Sutun sirasi ScenarioField.allCases: template, total, bonus, packages, duration, period
        XCTAssertTrue(tally.markdown(title: "Taklit").contains("| getir | – | 50.0 | – | 100.0 | – | – |"))

        let decoded = try? JSONDecoder().decode([String: Double].self, from: Data(tally.baselineJSON().utf8))
        XCTAssertEqual(decoded, tally.accuracy())
    }
}
