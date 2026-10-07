import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class PendingShiftTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func shift(_ minutesAgo: Double, now: Date) -> PendingShift {
        let created = now.addingTimeInterval(-minutesAgo * 60)
        return PendingShift(id: UUID(), start: created.addingTimeInterval(-3600), end: created, distanceKm: 12,
                            createdAt: created, province: nil, district: "Kadıköy", neighborhood: nil)
    }

    func testKeepsNewestFiveAndDropsOlderThanADay() {
        var list: [PendingShift] = []
        for minutes in [600.0, 500, 400, 300, 200, 100] {
            list = PendingShiftList.adding(shift(minutes, now: base), to: list, now: base)
        }
        XCTAssertEqual(list.count, 5)
        XCTAssertEqual(list.first?.createdAt, base.addingTimeInterval(-100 * 60), "En yeni once")

        let stale = PendingShiftList.pruned([shift(24 * 60 + 1, now: base), shift(10, now: base)], now: base)
        XCTAssertEqual(stale.count, 1)
    }

    func testEncodeDecode() {
        let list = [shift(5, now: base)]
        XCTAssertEqual(PendingShiftList.decode(PendingShiftList.encode(list)), list)
        XCTAssertEqual(PendingShiftList.decode(nil), [])
    }

    func testThrottle() {
        let throttle = LiveActivityThrottle()
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: nil, lastDistanceMeters: 0, now: base, distanceMeters: 0, isLowPower: false))
        XCTAssertFalse(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(30), distanceMeters: 50, isLowPower: false))
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(30), distanceMeters: 120, isLowPower: false), "100 m")
        XCTAssertFalse(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(10), distanceMeters: 500, isLowPower: false), "15 sn alt sinir")
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(60), distanceMeters: 0, isLowPower: false))
        XCTAssertFalse(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(120), distanceMeters: 900, isLowPower: true))
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(180), distanceMeters: 0, isLowPower: true))
    }
}
