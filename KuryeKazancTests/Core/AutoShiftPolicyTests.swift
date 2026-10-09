import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class AutoShiftPolicyTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private let policy = AutoShiftPolicy()
    private let always = WorkHours(isAlways: true, startMinute: 0, endMinute: 0)

    /// 2026-10-08 14:00 + saniye
    private func t(_ seconds: TimeInterval, hour: Int = 14) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour))!.addingTimeInterval(seconds)
    }

    private func s(_ seconds: TimeInterval, _ kind: MotionSample.Kind, _ confidence: MotionSample.Confidence = .high, hour: Int = 14) -> MotionSample {
        MotionSample(start: t(seconds, hour: hour), kind: kind, confidence: confidence)
    }

    func testThreeMinutesOfDrivingStartsAtMovementStart() {
        let samples = [s(0, .stationary), s(60, .automotive)]
        let decision = policy.startDecision(samples: samples, now: t(60 + 185), workHours: always, calendar: calendar, lastCancel: nil)
        XCTAssertEqual(decision, .start(at: t(60)))
    }

    func testTwoMinutesIsNotEnough() {
        let samples = [s(0, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(120), workHours: always, calendar: calendar, lastCancel: nil), .wait)
    }

    func testLowConfidenceAndWalkingDoNotCount() {
        XCTAssertEqual(policy.startDecision(samples: [s(0, .automotive, .low)], now: t(400), workHours: always, calendar: calendar, lastCancel: nil), .wait)
        XCTAssertEqual(policy.startDecision(samples: [s(0, .walking)], now: t(400), workHours: always, calendar: calendar, lastCancel: nil), .wait)
        XCTAssertEqual(policy.startDecision(samples: [s(0, .cycling, .medium)], now: t(200), workHours: always, calendar: calendar, lastCancel: nil), .start(at: t(0)))
    }

    func testShortStopDoesNotBreakTheRun() {
        // 100 sn surus, 30 sn kirmizi isik, 100 sn surus -> 200 sn hareket
        let samples = [s(0, .automotive), s(100, .stationary), s(130, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(230), workHours: always, calendar: calendar, lastCancel: nil), .start(at: t(0)))
    }

    func testLongStopBreaksTheRun() {
        // 120 sn surus, 120 sn durma, 120 sn surus -> son kosu yalnizca 120 sn
        let samples = [s(0, .automotive), s(120, .stationary), s(240, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(360), workHours: always, calendar: calendar, lastCancel: nil), .wait)
    }

    func testOnlyLookbackWindowCounts() {
        // Hareket 20 dk once basladi ve suruyor: baslangic pencerenin basina kirpilir
        let samples = [s(0, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(1200), workHours: always, calendar: calendar, lastCancel: nil), .start(at: t(600)))
        // Hareket 15 dk once bitti
        let old = [s(0, .automotive), s(300, .stationary)]
        XCTAssertEqual(policy.startDecision(samples: old, now: t(1200), workHours: always, calendar: calendar, lastCancel: nil), .wait)
    }

    func testOutsideWorkHoursWaits() {
        let samples = [s(0, .automotive, hour: 2)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(300, hour: 2), workHours: .standard, calendar: calendar, lastCancel: nil), .wait)
        let night = [s(0, .automotive, hour: 0)]
        XCTAssertEqual(policy.startDecision(samples: night, now: t(300, hour: 0), workHours: .standard, calendar: calendar, lastCancel: nil), .start(at: t(0, hour: 0)))
    }

    func testCooldownAfterCancel() {
        let samples = [s(0, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(300), workHours: always, calendar: calendar, lastCancel: t(-1400)), .wait)
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(300), workHours: always, calendar: calendar, lastCancel: t(-1500 - 60)), .start(at: t(0)))
    }

    func testStopAfterTwentyStationaryMinutes() {
        XCTAssertFalse(policy.shouldStop(lastMovement: t(0), now: t(1199)))
        XCTAssertTrue(policy.shouldStop(lastMovement: t(0), now: t(1200)))
    }

    func testTooShortNeedsBothShortAndClose() {
        XCTAssertTrue(policy.isTooShort(duration: 299, distanceKm: 0.9))
        XCTAssertFalse(policy.isTooShort(duration: 300, distanceKm: 0.5), "5 dk ve uzeri tutulur")
        XCTAssertFalse(policy.isTooShort(duration: 120, distanceKm: 1.0), "1 km ve uzeri tutulur")
    }
}
