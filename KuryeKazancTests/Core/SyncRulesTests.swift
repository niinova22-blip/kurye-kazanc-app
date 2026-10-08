import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class SyncRulesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func make(level: String = "ocrUnverified", platform: String? = "getir", hash: String = "abc", end: Date? = nil) -> ShiftPayload? {
        ShiftPayloadBuilder.make(
            recordID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, platformCode: platform,
            province: "İstanbul", district: "Kadıköy", vehicle: "motorcycle",
            start: date(5, 18, 37), end: end ?? date(5, 21, 10), gross: 900, bonus: 100, packages: 12,
            distanceKm: 41.3, level: level, templateID: "getir.earnings", templateVersion: 1, textHash: hash,
            calendar: calendar
        )
    }

    func testPayloadRoundsAndBuckets() throws {
        let p = try XCTUnwrap(make())
        XCTAssertEqual(p.weekday, 1, "5 Ekim 2026 Pazartesi")
        XCTAssertEqual(p.startSlot, 18 * 4 + 2, "18:37 -> 18:30 dilimi")
        XCTAssertEqual(p.durationMin, 153)
        XCTAssertEqual(p.distanceKm, 41.5, "0,5'e yuvarlanir")
        XCTAssertEqual(p.clientRecordID, "00000000-0000-0000-0000-000000000001")
    }

    func testOnlyEligibleRecordsProducePayload() {
        XCTAssertNotNil(make(level: "verified"))
        XCTAssertNil(make(level: "manual"))
        XCTAssertNil(make(level: "ocrEdited"))
        XCTAssertNil(make(platform: nil))
        XCTAssertNil(make(platform: "other"))
        XCTAssertNil(make(hash: ""))
        XCTAssertNil(make(end: date(5, 18, 37)))
    }

    func testPayloadJSONUsesSnakeCase() throws {
        let p = try XCTUnwrap(make())
        let json = String(decoding: try JSONEncoder().encode(p), as: UTF8.self)
        XCTAssertTrue(json.contains("\"start_slot\""))
        XCTAssertTrue(json.contains("\"text_hash\""))
        XCTAssertTrue(json.contains("\"client_record_id\""))
    }

    func testOutboxPolicy() {
        XCTAssertTrue(OutboxPolicy.isFinal(.ok))
        XCTAssertTrue(OutboxPolicy.isFinal(.duplicate))
        XCTAssertTrue(OutboxPolicy.isFinal(.invalid))
        XCTAssertFalse(OutboxPolicy.isFinal(.transient))
        XCTAssertFalse(OutboxPolicy.isFinal(.rateLimited))
        let now = date(8, 12)
        XCTAssertEqual(OutboxPolicy.nextAttempt(after: 1, now: now), now.addingTimeInterval(60))
        XCTAssertEqual(OutboxPolicy.nextAttempt(after: 3, now: now), now.addingTimeInterval(240))
        XCTAssertEqual(OutboxPolicy.nextAttempt(after: 20, now: now), now.addingTimeInterval(21_600))
    }

    func testMasker() {
        XCTAssertEqual(CalibrationMasker.mask("IBAN TR33 0006 1005 1978 6457 8413 26"), "IBAN ***")
        XCTAssertEqual(CalibrationMasker.mask("TR330006100519786457841326"), "***")
        XCTAssertEqual(CalibrationMasker.mask("Tel: 0532 123 45 67"), "Tel: ***")
        XCTAssertEqual(CalibrationMasker.mask("+90 532 123 4567"), "***")
        XCTAssertEqual(CalibrationMasker.mask("TC 12345678901"), "TC ***")
        XCTAssertEqual(CalibrationMasker.mask("ali.veli@ornek.com"), "***")
        XCTAssertEqual(CalibrationMasker.mask("Toplam Kazanç ₺980,00"), "Toplam Kazanç ₺980,00", "Tutarlar korunur")
        XCTAssertEqual(CalibrationMasker.mask("Sipariş Sayısı 11"), "Sipariş Sayısı 11")
    }

    func testTemplateMerger() {
        var newer = BundledTemplates.template(id: "getir.earnings")!
        newer.version = 2
        newer.status = .active
        var older = BundledTemplates.template(id: "trendyol_go.earnings")!
        older.version = 0
        var extra = BundledTemplates.generic
        extra.id = "bolt.earnings"
        extra.platformCode = "bolt"
        let merged = TemplateMerger.merge(bundled: BundledTemplates.all, remote: [newer, older, extra])
        XCTAssertEqual(merged.count, BundledTemplates.all.count + 1)
        XCTAssertEqual(merged.first { $0.id == "getir.earnings" }?.version, 2)
        XCTAssertEqual(merged.first { $0.id == "trendyol_go.earnings" }?.version, 1, "Eski uzak surum gomuluyu ezmez")
        XCTAssertEqual(merged.last?.id, "bolt.earnings")
    }
}
