import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class StableCaptureFilterTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func parsed(_ template: String?, total: Double, day: Int = 9, period: OCRTemplate.Period = .day) -> ParsedEarning {
        ParsedEarning(platformCode: "getir",
                      date: calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 15))!,
                      packageCount: 3, totalEarning: total, bonus: 0, totalIncludesBonus: true,
                      fieldsToReview: [], templateID: template, period: period)
    }

    func testKey_roundsCentsAndDay_nilWithoutTemplateOrTotal() {
        let a = CaptureKey(parsed: parsed("getir.earnings", total: 980.004), calendar: calendar)
        let b = CaptureKey(parsed: parsed("getir.earnings", total: 980.0), calendar: calendar)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a?.totalCents, 98000)
        XCTAssertNil(CaptureKey(parsed: parsed(nil, total: 980), calendar: calendar))
        XCTAssertNil(CaptureKey(parsed: parsed("getir.earnings", total: 0), calendar: calendar))
    }

    func testTwoConsecutiveFramesAccept_singleFrameDoesNot() {
        let k1 = CaptureKey(parsed: parsed("getir.earnings", total: 100), calendar: calendar)
        let k2 = CaptureKey(parsed: parsed("getir.earnings", total: 200), calendar: calendar)
        var f = StableCaptureFilter()
        XCTAssertNil(f.offer(k1))          // ilk gorulus
        XCTAssertNil(f.offer(k2))          // yarim kare / farkli ekran
        XCTAssertNil(f.offer(k1))          // araya baska kare girdi: yeniden ilk gorulus
        XCTAssertEqual(f.offer(k1), k1)    // art arda ikinci: kabul
        XCTAssertNil(f.offer(k1))          // ayni ekranda kalmak tekrar uretmez
        XCTAssertEqual(f.duplicateCount, 1)
        XCTAssertEqual(f.unconfirmedCount, 1) // k2 hic onaylanmadi
    }

    func testUnrecognizedFrameBreaksSequence() {
        let k = CaptureKey(parsed: parsed("uber.earnings", total: 500, period: .week), calendar: calendar)
        var f = StableCaptureFilter()
        XCTAssertNil(f.offer(k))
        XCTAssertNil(f.offer(nil))
        XCTAssertNil(f.offer(k))
        XCTAssertEqual(f.offer(k), k)
        XCTAssertEqual(f.unconfirmedCount, 0)
    }

    func testCaptureCodableRoundTrip() throws {
        let c = BroadcastCapture(capturedAt: Date(timeIntervalSince1970: 1_791_565_000),
                                 lines: [RecognizedLine(text: "Getir", x: 0, y: 0.9, width: 0.3, height: 0.03)])
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(BroadcastCapture.self, from: data), c)
    }
}
