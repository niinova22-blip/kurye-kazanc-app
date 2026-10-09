import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScanResultBuilderTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var builder: ScanResultBuilder { ScanResultBuilder(calendar: calendar) }

    private func input(_ template: String?, platform: String = "getir", total: Double, bonus: Double = 0,
                       period: OCRTemplate.Period = .day, day: Int = 9, at second: Int, text: String) -> ScanInput {
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 14))!
        let parsed = ParsedEarning(platformCode: platform, date: date, packageCount: period == .order ? 1 : 10,
                                   totalEarning: total, bonus: bonus, totalIncludesBonus: true,
                                   fieldsToReview: [], templateID: template, period: period)
        return ScanInput(parsed: parsed, lines: [RecognizedLine(text: text, x: 0, y: 0, width: 1, height: 0.1)],
                         capturedAt: Date(timeIntervalSince1970: TimeInterval(1_791_565_000 + second)))
    }

    /// Review Focus 1: ayni degerler, farkli metin (saat degisti) -> tek kalem.
    func testSameValuesDifferentText_oneItem() {
        let items = builder.build([
            input("getir.earnings", total: 980, at: 0, text: "20:14 Getir 980"),
            input("getir.earnings", total: 980, at: 60, text: "20:15 Getir 980"),
        ])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].kind, .daily)
    }

    func testUnrecognizedDropped_weeklyKind() {
        let items = builder.build([
            input(nil, total: 50, at: 0, text: "Mesajlar"),
            input("uber.earnings", platform: "uber", total: 6459.9, period: .week, at: 5, text: "Kazançlar"),
        ])
        XCTAssertEqual(items.map(\.kind), [.weekly])
    }

    func testOrderCardsMergedPerDayAndPlatform() {
        let items = builder.build([
            input("yemeksepeti.order", platform: "yemeksepeti", total: 147.5, bonus: 37, period: .order, at: 0, text: "a"),
            input("yemeksepeti.order", platform: "yemeksepeti", total: 120, bonus: 0, period: .order, at: 10, text: "b"),
            // Review Focus 3: ayni gun baska platform ayri grup
            input("banabikurye.order", platform: "banabikurye", total: 430, period: .order, at: 20, text: "c"),
            // ertesi gun ayri grup
            input("yemeksepeti.order", platform: "yemeksepeti", total: 90, period: .order, day: 10, at: 30, text: "d"),
        ])
        XCTAssertEqual(items.count, 3)
        let ys = items.first { $0.parsed.platformCode == "yemeksepeti" && calendar.component(.day, from: $0.parsed.date) == 9 }!
        XCTAssertEqual(ys.kind, .orderGroup(count: 2))
        XCTAssertEqual(ys.parsed.totalEarning, 267.5, accuracy: 0.001)
        XCTAssertEqual(ys.parsed.bonus, 37, accuracy: 0.001)
        XCTAssertEqual(ys.parsed.packageCount, 2)
        XCTAssertEqual(ys.parsed.period, .order)
        XCTAssertEqual(ys.lines.map(\.text), ["a", "b"])
        XCTAssertEqual(ys.textHash, TextHash.of(["a", "b"]))
    }

    func testSameOrderCardTwice_countedOnce() {
        let items = builder.build([
            input("yemeksepeti.order", platform: "yemeksepeti", total: 147.5, period: .order, at: 0, text: "a"),
            input("yemeksepeti.order", platform: "yemeksepeti", total: 147.5, period: .order, at: 5, text: "a2"),
        ])
        XCTAssertEqual(items.first?.kind, .orderGroup(count: 1))
    }

    func testSortedByCaptureTime() {
        let items = builder.build([
            input("trendyol_go.earnings", platform: "trendyol_go", total: 1245.5, at: 50, text: "t"),
            input("getir.earnings", total: 980, at: 0, text: "g"),
        ])
        XCTAssertEqual(items.map { $0.parsed.platformCode }, ["getir", "trendyol_go"])
    }
}
