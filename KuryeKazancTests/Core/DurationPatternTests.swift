import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class DurationPatternTests: XCTestCase {
    private func d(_ text: String) -> TimeInterval? {
        TextPatterns.duration(in: TextNormalizer.normalize(text))
    }

    func testHourMinuteForms() {
        XCTAssertEqual(d("23 sa 32 dk"), 23 * 3600 + 32 * 60)
        XCTAssertEqual(d("23sa 32dk"), 23 * 3600 + 32 * 60)
        XCTAssertEqual(d("23h 32m"), 23 * 3600 + 32 * 60)
        XCTAssertEqual(d("Çevrimiçi 5 saat 5 dakika"), 5 * 3600 + 5 * 60)
    }

    func testSingleUnits() {
        XCTAssertEqual(d("5 saat"), 5 * 3600)
        XCTAssertEqual(d("45 dk"), 45 * 60)
        XCTAssertEqual(d("02:15 saat"), 2 * 3600 + 15 * 60)
    }

    /// Review Focus 3: saat gibi gorunen degerler sure degildir.
    func testNotDurations() {
        XCTAssertNil(d("12:30"))
        XCTAssertNil(d("3 paket"))
        XCTAssertNil(d("Toplam 500 TL"))
        XCTAssertNil(d("23 sa 75 dk"))   // gecersiz dakika
        XCTAssertNil(d("400 saat"))      // haftalik ustu (> 168 sa) gercekci degil
    }

    func testDateRange() {
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("4 Şub - 10 Şub")))
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("28 Eylül – 4 Ekim")))
        XCTAssertFalse(TextPatterns.containsDateRange(TextNormalizer.normalize("4 Şubat")))
        XCTAssertFalse(TextPatterns.containsDateRange("10 - 20 paket"))
    }

    func testDateRange_englishMonthFirst() {
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("Feb 4 - Feb 10")))
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("Oct 28 – Nov 3")))
        XCTAssertFalse(TextPatterns.containsDateRange(TextNormalizer.normalize("Feb 4")))
    }

    func testDateRange_compactDayDashDayMonth() {
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("4-10 Şub")))
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("4 – 10 Şubat")))
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("4-10 Feb")))
    }

    func testDateRange_marketNotAMonth() {
        XCTAssertFalse(TextPatterns.containsDateRange(TextNormalizer.normalize("5 market - 3 kasa")))
    }

    func testStrippingReferenceNumbers() {
        XCTAssertEqual(TextPatterns.strippingReferenceNumbers("tasima ucreti #1420").trimmingCharacters(in: .whitespaces), "tasima ucreti")
        XCTAssertEqual(TextPatterns.strippingReferenceNumbers("siparis №78347 bugun"), "siparis   bugun")
        XCTAssertEqual(TextPatterns.strippingReferenceNumbers("siparis no 123").trimmingCharacters(in: .whitespaces), "siparis")
    }
}
