import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class WorkHoursTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    func testStandardWindowCrossesMidnight() {
        let hours = WorkHours.standard // 09:00 - 01:00
        XCTAssertTrue(hours.contains(at(9), calendar: calendar))
        XCTAssertTrue(hours.contains(at(23, 30), calendar: calendar))
        XCTAssertTrue(hours.contains(at(0, 30), calendar: calendar))
        XCTAssertFalse(hours.contains(at(1), calendar: calendar), "Bitis dahil degil")
        XCTAssertFalse(hours.contains(at(2), calendar: calendar))
        XCTAssertFalse(hours.contains(at(8, 59), calendar: calendar))
    }

    func testSameDayWindowAndAlways() {
        let day = WorkHours(isAlways: false, startMinute: 10 * 60, endMinute: 22 * 60)
        XCTAssertTrue(day.contains(at(10), calendar: calendar))
        XCTAssertFalse(day.contains(at(22), calendar: calendar))
        XCTAssertFalse(day.contains(at(9, 59), calendar: calendar))

        let always = WorkHours(isAlways: true, startMinute: 0, endMinute: 0)
        XCTAssertTrue(always.contains(at(3), calendar: calendar))
        // Baslangic == bitis: tum gun
        let fullDay = WorkHours(isAlways: false, startMinute: 600, endMinute: 600)
        XCTAssertTrue(fullDay.contains(at(4), calendar: calendar))
    }

    func testEncodingRoundTripAndFallback() {
        let hours = WorkHours(isAlways: false, startMinute: 8 * 60, endMinute: 23 * 60)
        XCTAssertEqual(WorkHours.decode(hours.encoded()), hours)
        XCTAssertEqual(WorkHours.decode(nil), .standard)
        XCTAssertEqual(WorkHours.decode(Data("bozuk".utf8)), .standard)
    }

    func testMotionSampleIsMoving() {
        let now = Date()
        XCTAssertTrue(MotionSample(start: now, kind: .automotive, confidence: .medium).isMoving)
        XCTAssertTrue(MotionSample(start: now, kind: .cycling, confidence: .high).isMoving)
        XCTAssertFalse(MotionSample(start: now, kind: .automotive, confidence: .low).isMoving)
        XCTAssertFalse(MotionSample(start: now, kind: .walking, confidence: .high).isMoving)
    }
}
