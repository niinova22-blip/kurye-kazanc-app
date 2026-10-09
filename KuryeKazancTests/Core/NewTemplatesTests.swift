import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Satirlar App Store magaza gorsellerindeki duzenden turetildi (spec §2); gercek ekranla kalibre edilmedi.
final class NewTemplatesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var reference: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14))! }
    private func parse(_ lines: [String]) -> ParsedEarning {
        EarningsScreenshotParser(calendar: calendar).parse(lines: lines, referenceDate: reference)
    }

    func testUberEarnings_turkish() {
        let r = parse(["9:41", "Kazançlar", "4 Şub - 10 Şub", "₺6.459,90", "Çevrimiçi 23 sa 32 dk",
                       "54 Teslimat", "73 Puan", "Ayrıntıları gör", "Bakiye: ₺1.550,00", "Sonraki ödeme 11 Şub"])
        XCTAssertEqual(r.templateID, "uber.earnings")
        XCTAssertEqual(r.platformCode, "uber")
        XCTAssertEqual(r.totalEarning, 6459.9, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 54)
        XCTAssertEqual(r.workDuration, 23 * 3600 + 32 * 60)
        XCTAssertEqual(r.period, .week)
    }

    func testUberEarnings_english() {
        let r = parse(["Earnings", "Feb 4 - Feb 10", "£645.99", "Online 23h 32m", "54 Trips", "73 Points",
                       "See details", "Balance: £155.00"])
        XCTAssertEqual(r.templateID, "uber.earnings")
        XCTAssertEqual(r.packageCount, 54)
        XCTAssertEqual(r.workDuration, 23 * 3600 + 32 * 60)
        XCTAssertEqual(r.period, .week)
    }

    /// Hafta etiketi / tarih araligi okunamasa bile 16 saati asan sure gunluk olamaz.
    func testUberEarnings_longDurationWithoutWeekLabel_isWeek() {
        let r = parse(["Kazançlar", "₺3.645,99", "Çevrimiçi 23 sa 32 dk", "54 Sefer", "Ayrıntıları gör"])
        XCTAssertEqual(r.templateID, "uber.earnings")
        XCTAssertEqual(r.workDuration, 23 * 3600 + 32 * 60)
        XCTAssertEqual(r.period, .week)
    }

    func testTheKuryeInvoices_withoutDayLabel_isWeek() {
        let r = parse(["The Kurye", "Faturalar 3", "Taşıma Ücreti 303.3₺", "#1420", "Taşıma Ücreti 900₺", "#903",
                       "Taşıma Ücreti 56₺", "#314", "Tümünü Seç", "Fatura Oluştur"])
        XCTAssertEqual(r.period, .week)
    }

    func testTheKuryeInvoices_withToday_isDay() {
        let r = parse(["The Kurye", "Bugün", "Faturalar 3", "Taşıma Ücreti 303.3₺", "#1420", "Taşıma Ücreti 900₺", "#903",
                       "Taşıma Ücreti 56₺", "#314", "Tümünü Seç", "Fatura Oluştur"])
        XCTAssertEqual(r.period, .day)
    }

    func testTheKuryeInvoices() {
        let r = parse(["The Kurye", "Faturalar 3", "Taşıma Ücreti 303.3₺", "#1420", "Taşıma Ücreti 900₺", "#903",
                       "Taşıma Ücreti 56₺", "#314", "Tümünü Seç", "Fatura Oluştur"])
        XCTAssertEqual(r.templateID, "thekurye.invoices")
        XCTAssertEqual(r.totalEarning, 1259.3, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 3)
    }

    func testYemeksepetiOrderCard() {
        let r = parse(["Kabul oranı %89", "Reddet", "₺147,50", "₺37,00 ek dahil", "Teslim al 1,6 km - 12 dk", "Kabul et"])
        XCTAssertEqual(r.templateID, "yemeksepeti.order")
        XCTAssertEqual(r.totalEarning, 147.5, accuracy: 0.001)
        XCTAssertEqual(r.bonus, 37, accuracy: 0.001)
        XCTAssertEqual(r.period, .order)
        XCTAssertTrue(r.amountsExcludeVAT)
    }

    func testBanabikuryeOrderCard() {
        let r = parse(["Sipariş №78347 Bugün", "Tanım Tarif Chat Ödeme", "Nakit kazanç", "430", "Gönderi Notu"])
        XCTAssertEqual(r.templateID, "banabikurye.order")
        XCTAssertEqual(r.totalEarning, 430, accuracy: 0.001)
        XCTAssertEqual(r.period, .order)
    }

    func testYemeksepetiSummary_isVATExclusiveV2() {
        let t = BundledTemplates.template(id: "yemeksepeti.earnings")!
        XCTAssertEqual(t.version, 2)
        XCTAssertTrue(t.amountsExcludeVAT)
    }

    /// Mevcut Getir ekrani yeni parmak izi sablonlarina dusmemeli.
    func testExistingGetirScreenUnaffected() {
        let r = parse(["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"])
        XCTAssertEqual(r.templateID, "getir.earnings")
        XCTAssertEqual(r.period, .day)
    }
}
