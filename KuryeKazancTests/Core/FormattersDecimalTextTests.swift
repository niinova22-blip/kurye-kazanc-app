import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class FormattersDecimalTextTests: XCTestCase {
    func testDecimalTextUsesCommaWithoutGrouping() {
        XCTAssertEqual(Formatters.decimalText(Decimal(string: "1234.5")!), "1234,5")
        XCTAssertEqual(Formatters.decimalText(45), "45")
        XCTAssertEqual(Formatters.decimalText(Decimal(string: "9.5")!), "9,5")
        XCTAssertEqual(Formatters.decimalText(Decimal(string: "3.125")!), "3,13")
    }
}
