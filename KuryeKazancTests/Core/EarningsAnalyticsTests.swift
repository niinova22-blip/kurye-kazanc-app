import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class EarningsAnalyticsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var analytics: EarningsAnalytics { EarningsAnalytics(calendar: calendar, costPerKm: 2) }

    /// 2026-10-05 Pazartesi
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func entry(_ start: Date, _ end: Date, total: Double, km: Double = 0, code: String? = "getir", packages: Int? = nil) -> EarningEntry {
        EarningEntry(start: start, end: end, gross: total, bonus: 0, distanceKm: km, platformCode: code, packageCount: packages)
    }

    func testHeatmapSplitsShiftAcrossHoursProportionally() {
        // Pazartesi 18:30-20:00, 300 TL, 10 km -> tahmini net 280; 90 dk
        let map = analytics.heatmap([entry(at(5, 18, 30), at(5, 20), total: 300, km: 10)])
        let h18 = map[HourSlot(weekday: 1, hour: 18)]!
        let h19 = map[HourSlot(weekday: 1, hour: 19)]!
        XCTAssertEqual(h18.minutes, 30, accuracy: 0.001)
        XCTAssertEqual(h19.minutes, 60, accuracy: 0.001)
        XCTAssertEqual(h18.estimatedNet, 280.0 / 3, accuracy: 0.01)
        XCTAssertEqual(h19.netPerHour!, 280.0 / 1.5, accuracy: 0.01)
        XCTAssertNil(map[HourSlot(weekday: 1, hour: 20)])
    }

    func testHeatmapOvernightShiftCrossesIntoMonday() {
        // Pazar 4 Ekim 23:00 - Pazartesi 01:00
        let map = analytics.heatmap([entry(at(4, 23), at(5, 1), total: 200)])
        XCTAssertEqual(map[HourSlot(weekday: 7, hour: 23)]?.minutes, 60)
        XCTAssertEqual(map[HourSlot(weekday: 1, hour: 0)]?.minutes, 60)
    }

    func testHeatmapAccumulatesSameSlotAcrossWeeks() {
        let map = analytics.heatmap([
            entry(at(5, 19), at(5, 20), total: 100),
            entry(at(12, 19), at(12, 20), total: 300),
        ])
        let slot = map[HourSlot(weekday: 1, hour: 19)]!
        XCTAssertEqual(slot.minutes, 120)
        XCTAssertEqual(slot.netPerHour!, 200, accuracy: 0.001)
    }

    func testTopSlotsRequireMinimumMinutesAndSortByNetPerHour() {
        let entries = [
            entry(at(5, 12), at(5, 13), total: 150),       // Pzt 12: 150/sa
            entry(at(6, 19), at(6, 20), total: 400),       // Sal 19: 400/sa
            entry(at(7, 21), at(7, 21, 20), total: 500),   // Car 21: 20 dk -> esik alti
        ]
        let top = analytics.topSlots(entries, limit: 3, minimumMinutes: 60)
        XCTAssertEqual(top.map { $0.slot }, [HourSlot(weekday: 2, hour: 19), HourSlot(weekday: 1, hour: 12)])
    }

    func testPlatformStats() {
        let stats = analytics.platformStats([
            entry(at(5, 10), at(5, 12), total: 500, km: 25, code: "getir", packages: 10),
            entry(at(5, 13), at(5, 14), total: 200, km: 0, code: "trendyol_go", packages: nil),
        ])
        XCTAssertEqual(stats.map(\.platformCode), ["getir", "trendyol_go"]) // toplama gore azalan
        let getir = stats[0]
        XCTAssertEqual(getir.hours, 2, accuracy: 0.001)
        XCTAssertEqual(getir.netPerHour!, 225, accuracy: 0.001)   // (500 - 50) / 2
        XCTAssertEqual(getir.netPerPackage!, 45, accuracy: 0.001)
        XCTAssertEqual(getir.netPerKm!, 18, accuracy: 0.001)
        XCTAssertNil(stats[1].netPerPackage)
        XCTAssertNil(stats[1].netPerKm)
    }

    func testPercentChange() {
        XCTAssertEqual(EarningsAnalytics.percentChange(current: 1200, previous: 1000)!, 20, accuracy: 0.001)
        XCTAssertEqual(EarningsAnalytics.percentChange(current: 500, previous: 1000)!, -50, accuracy: 0.001)
        XCTAssertNil(EarningsAnalytics.percentChange(current: 500, previous: 0))
    }
}
