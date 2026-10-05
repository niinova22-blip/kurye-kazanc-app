import XCTest
@testable import KuryeKazanc

final class TurkishNumberParserTests: XCTestCase {
    func testTurkishFormats() {
        XCTAssertEqual(TurkishNumberParser.parseDecimal("1.234,56"), 1234.56)
        XCTAssertEqual(TurkishNumberParser.parseDecimal("1234,5"), 1234.5)
        XCTAssertEqual(TurkishNumberParser.parseDecimal("850"), 850)
        XCTAssertEqual(TurkishNumberParser.parseDecimal("1.250"), 1250)
        XCTAssertEqual(TurkishNumberParser.parseDecimal("1.250.000"), 1_250_000)
    }

    func testDotAsDecimalWhenNotThousands() {
        XCTAssertEqual(TurkishNumberParser.parseDecimal("12.50"), 12.5)
        XCTAssertEqual(TurkishNumberParser.parseDecimal("2.5"), 2.5)
    }

    func testEnglishGroupingWithBothSeparators() {
        XCTAssertEqual(TurkishNumberParser.parseDecimal("1,234.56"), 1234.56)
    }

    func testCurrencyMarkersAndSpaces() {
        XCTAssertEqual(TurkishNumberParser.parseDecimal("₺1.245,50"), 1245.5)
        XCTAssertEqual(TurkishNumberParser.parseDecimal(" 980,75 TL "), 980.75)
        XCTAssertEqual(TurkishNumberParser.parseDecimal("₺\u{00A0}75"), 75)
    }

    func testInvalidInput() {
        XCTAssertNil(TurkishNumberParser.parseDecimal(""))
        XCTAssertNil(TurkishNumberParser.parseDecimal("abc"))
        XCTAssertNil(TurkishNumberParser.parseDecimal("12a"))
        XCTAssertNil(TurkishNumberParser.parseDecimal("₺"))
    }

    func testParseInt() {
        XCTAssertEqual(TurkishNumberParser.parseInt("18"), 18)
        XCTAssertNil(TurkishNumberParser.parseInt("18,5"))
        XCTAssertNil(TurkishNumberParser.parseInt(""))
    }

    func testFormatRoundTrip() {
        let text = TurkishNumberParser.format(1250.5)
        XCTAssertEqual(text, "1250,5")
        XCTAssertEqual(TurkishNumberParser.parseDecimal(text), 1250.5)
    }
}
