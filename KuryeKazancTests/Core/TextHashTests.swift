import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class TextHashTests: XCTestCase {
    func testSameTextWithDifferentCaseAndWhitespaceGivesSameHash() {
        let a = TextHash.of(["Getir", "TOPLAM KAZANÇ", "₺980,00", "Sipariş Sayısı", "11"])
        let b = TextHash.of(["  getir ", "toplam   kazanc", "", "₺980,00", "SİPARİŞ SAYISI", "11", "   "])
        XCTAssertEqual(a, b)
    }

    func testDifferentAmountGivesDifferentHash() {
        let a = TextHash.of(["Getir", "Toplam Kazanç", "₺980,00"])
        let b = TextHash.of(["Getir", "Toplam Kazanç", "₺981,00"])
        XCTAssertNotEqual(a, b)
    }

    func testLineBoundariesMatter() {
        XCTAssertNotEqual(TextHash.of(["ab", "c"]), TextHash.of(["a", "bc"]))
    }

    func testFormatIsSixteenLowercaseHexCharactersAndDeterministic() {
        let hash = TextHash.of(["Getir"])
        XCTAssertEqual(hash.count, 16)
        XCTAssertTrue(hash.allSatisfy { "0123456789abcdef".contains($0) }, hash)
        XCTAssertEqual(hash, TextHash.of(["Getir"]))
    }

    func testKnownFNV1aValues() {
        // Metinsiz girdi ozet uretmez (her bos ekran birbirinin tekrari sayilmasin); "a" = af63dc4c8601ec8c
        XCTAssertEqual(TextHash.of([]), "")
        XCTAssertEqual(TextHash.of(["   ", ""]), "")
        XCTAssertEqual(TextHash.of(["A"]), "af63dc4c8601ec8c")
    }
}
