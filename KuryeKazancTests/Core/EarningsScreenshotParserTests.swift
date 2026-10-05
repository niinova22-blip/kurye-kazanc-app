import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore // Windows/Linux: swift test
#else
@testable import KuryeKazanc // Xcode / CI
#endif

/// OCR ayristirma regex testleri. Girdiler Vision'in dondurdugu satir dizisi bicimindedir.
/// Gercek ekran goruntuleriyle (TestFlight) yeni ekran duzenleri goruldukce buraya test eklenmeli.
final class EarningsScreenshotParserTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    private var parser: EarningsScreenshotParser {
        EarningsScreenshotParser(calendar: calendar)
    }

    /// 6 Ekim 2026 14:00 (Istanbul)
    private var reference: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 14))!
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Trendyol GO

    func testTrendyolGo_valuesOnNextLine() {
        let lines = [
            "Trendyol GO", "Kazançlarım", "05.10.2026",
            "Toplam Kazanç", "₺1.245,50",
            "Teslimat Sayısı", "18",
            "Bonus", "₺150,00",
        ]
        let result = parser.parse(lines: lines, referenceDate: reference)

        XCTAssertEqual(result.platformCode, "trendyol_go")
        XCTAssertEqual(result.totalEarning, 1245.5, accuracy: 0.001)
        XCTAssertEqual(result.bonus, 150, accuracy: 0.001)
        XCTAssertEqual(result.packageCount, 18)
        XCTAssertEqual(result.date, day(2026, 10, 5))
        XCTAssertTrue(result.fieldsToReview.isEmpty, "Beklenmeyen kontrol alanlari: \(result.fieldsToReview)")
        XCTAssertEqual(result.grossEarning, 1095.5, accuracy: 0.001) // toplam bonus dahil
    }

    func testTrendyolGo_uppercaseWithoutTurkishCharacters() {
        let lines = [
            "TRENDYOL GO KURYE", "BUGUN",
            "TOPLAM HAKEDIS 2.040,00 TL",
            "18 PAKET",
            "PRIM 200 TL",
        ]
        let result = parser.parse(lines: lines, referenceDate: reference)

        XCTAssertEqual(result.platformCode, "trendyol_go")
        XCTAssertEqual(result.totalEarning, 2040, accuracy: 0.001)
        XCTAssertEqual(result.bonus, 200, accuracy: 0.001)
        XCTAssertEqual(result.packageCount, 18)
        XCTAssertEqual(result.date, day(2026, 10, 6))
        XCTAssertTrue(result.fieldsToReview.isEmpty)
    }

    func testTrendyolGo_timeAndDateDoNotLookLikeAmounts() {
        let lines = ["Trendyol GO", "05.10.2026 14:35", "Toplam Kazanç", "₺ 1.020,00", "Teslimat", "11"]
        let result = parser.parse(lines: lines, referenceDate: reference)
        XCTAssertEqual(result.totalEarning, 1020, accuracy: 0.001)
        XCTAssertEqual(result.packageCount, 11)
        XCTAssertEqual(result.date, day(2026, 10, 5))
    }

    // MARK: - Getir

    func testGetir_valuesOnSameLine() {
        let lines = [
            "getir", "6 Ekim",
            "Sipariş Sayısı: 12",
            "Toplam Kazanç 980,75 TL",
            "Ek Kazanç 45 TL",
        ]
        let result = parser.parse(lines: lines, referenceDate: reference)

        XCTAssertEqual(result.platformCode, "getir")
        XCTAssertEqual(result.totalEarning, 980.75, accuracy: 0.001)
        XCTAssertEqual(result.bonus, 45, accuracy: 0.001)
        XCTAssertEqual(result.packageCount, 12)
        XCTAssertEqual(result.date, day(2026, 10, 6))
        XCTAssertTrue(result.fieldsToReview.isEmpty)
    }

    func testGetir_monthNameWithYearAndValueAboveLabel() {
        let lines = ["GetirKurye", "28 Eylül 2026", "₺ 1.310,40", "Toplam Tutar", "Tamamlanan Sipariş 21", "Bonus ₺ 90"]
        let result = parser.parse(lines: lines, referenceDate: reference)

        XCTAssertEqual(result.platformCode, "getir")
        XCTAssertEqual(result.totalEarning, 1310.4, accuracy: 0.001)
        XCTAssertEqual(result.packageCount, 21)
        XCTAssertEqual(result.bonus, 90, accuracy: 0.001)
        XCTAssertEqual(result.date, day(2026, 9, 28))
    }

    func testMonthWithoutYearInFutureMeansPreviousYear() {
        let lines = ["getir", "28 Aralık", "Toplam Kazanç 500 TL"]
        let result = parser.parse(lines: lines, referenceDate: reference)
        XCTAssertEqual(result.date, day(2025, 12, 28))
    }

    // MARK: - Guvenilmez okuma: alanlar bos birakilmaz, kontrol icin isaretlenir

    func testUnreliableRead_fillsBestGuessesAndFlagsFields() {
        let lines = ["getir", "Özet", "₺ 820,00", "₺ 35,00"]
        let result = parser.parse(lines: lines, referenceDate: reference)

        XCTAssertEqual(result.platformCode, "getir")
        XCTAssertEqual(result.totalEarning, 820, accuracy: 0.001)   // en buyuk tutar tahmini
        XCTAssertEqual(result.bonus, 0)
        XCTAssertEqual(result.packageCount, 0)
        XCTAssertEqual(result.date, day(2026, 10, 6))                 // bugun
        XCTAssertEqual(result.fieldsToReview, [.totalEarning, .bonus, .packageCount, .date])
    }

    func testUnknownPlatform_isFlagged() {
        let lines = ["Kurye Paneli", "Toplam Kazanç 700 TL", "Teslimat Sayısı 9", "Bonus 0 TL", "01.10.2026"]
        let result = parser.parse(lines: lines, referenceDate: reference)
        XCTAssertNil(result.platformCode)
        XCTAssertTrue(result.fieldsToReview.contains(.platform))
        XCTAssertEqual(result.totalEarning, 700, accuracy: 0.001)
        XCTAssertEqual(result.packageCount, 9)
    }

    func testEmptyInput_neverCrashesAndFlagsEverything() {
        let result = parser.parse(lines: [], referenceDate: reference)
        XCTAssertEqual(result.totalEarning, 0)
        XCTAssertEqual(result.fieldsToReview, Set(ParsedEarning.Field.allCases))
    }

    func testPlatformDetectionRequiresWholeWord() {
        // "getirildi" Getir platformu degildir
        let lines = ["Siparişin getirildi", "Toplam 100 TL"]
        XCTAssertNil(parser.parse(lines: lines, referenceDate: reference).platformCode)
    }

    // MARK: - Normalizasyon

    func testTextNormalizer() {
        XCTAssertEqual(TextNormalizer.normalize("TOPLAM KAZANÇ"), "toplam kazanc")
        XCTAssertEqual(TextNormalizer.normalize("Sipariş  Sayısı"), "siparis sayisi")
        XCTAssertEqual(TextNormalizer.normalize("İŞ GÜNÜ"), "is gunu")
        XCTAssertEqual(TextNormalizer.normalize("EYLÜL"), "eylul")
    }
}
