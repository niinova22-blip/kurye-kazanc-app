import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class EarningsForecasterTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var forecaster: EarningsForecaster { EarningsForecaster(calendar: calendar) }

    /// 2026-10-12 Pazartesi (plan gunu). Gecmis Pazartesiler: 5, 28 Eyl, 21 Eyl ...
    private func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    private var planDay: Date { at(10, 12, 0) }

    private func entry(_ s: Date, _ e: Date, _ total: Double, km: Double = 0, code: String = "getir", packages: Int? = nil) -> EarningEntry {
        EarningEntry(start: s, end: e, gross: total, bonus: 0, distanceKm: km, platformCode: code, packageCount: packages)
    }

    func testWeekdayHourLevelWithPercentiles() {
        // Uc Pazartesi 18-20: 200, 300, 400 TL/saat
        let entries = [
            entry(at(10, 5, 18), at(10, 5, 20), 400, km: 20, packages: 4),
            entry(at(9, 28, 18), at(9, 28, 20), 600, km: 30, packages: 6),
            entry(at(9, 21, 18), at(9, 21, 20), 800, km: 40, packages: 8),
        ]
        let f = forecaster.forecast(entries: entries, platform: "getir", day: planDay, hour: 19)!
        XCTAssertEqual(f.basis, .weekdayHour)
        XCTAssertEqual(f.samples, 3)
        XCTAssertEqual(f.low, 250, accuracy: 0.001)
        XCTAssertEqual(f.mid, 300, accuracy: 0.001)
        XCTAssertEqual(f.high, 350, accuracy: 0.001)
        XCTAssertEqual(f.kmPerHour, 15, accuracy: 0.001)
        XCTAssertEqual(f.packagesPerHour!, 3, accuracy: 0.001)
    }

    func testFallsBackToHourThenPlatform() {
        // Farkli gunlerde 12:00 civari uc kayit -> Pazartesi 12 icin "saat" seviyesi
        let noon = [
            entry(at(10, 6, 12), at(10, 6, 13), 200),
            entry(at(10, 7, 12), at(10, 7, 13), 220),
            entry(at(10, 8, 12), at(10, 8, 13), 240),
        ]
        XCTAssertEqual(forecaster.forecast(entries: noon, platform: "getir", day: planDay, hour: 12)?.basis, .hour)
        XCTAssertEqual(forecaster.forecast(entries: noon, platform: "getir", day: planDay, hour: 9)?.basis, .platform)
    }

    func testInsufficientSamplesReturnsNilWithoutOfferedRate() {
        let two = [entry(at(10, 5, 18), at(10, 5, 20), 400), entry(at(10, 6, 18), at(10, 6, 20), 400)]
        XCTAssertNil(forecaster.forecast(entries: two, platform: "getir", day: planDay, hour: 19))
        let offered = forecaster.forecast(entries: two, platform: "getir", day: planDay, hour: 19, offeredRate: 180)!
        XCTAssertEqual(offered.basis, .offeredRate)
        XCTAssertEqual(offered.mid, 180)
        XCTAssertEqual(offered.samples, 0)
    }

    func testIgnoresOldEntriesSameDayOtherPlatformsAndTinyShifts() {
        let entries = [
            entry(at(8, 10, 18), at(8, 10, 20), 400), // 9 haftadan eski
            entry(at(10, 12, 9), at(10, 12, 11), 400), // plan gunu
            entry(at(10, 5, 18), at(10, 5, 20), 400, code: "yemeksepeti"),
            entry(at(10, 6, 18), at(10, 6, 18, 10), 400), // 10 dk
        ]
        XCTAssertNil(forecaster.forecast(entries: entries, platform: "getir", day: planDay, hour: 19))
        XCTAssertEqual(forecaster.sampleCount(entries: entries, platform: "getir", day: planDay), 0)
    }

    func testPercentileEdgeCases() {
        XCTAssertEqual(EarningsForecaster.percentile([5], 0.25), 5)
        XCTAssertEqual(EarningsForecaster.percentile([], 0.5), 0)
        XCTAssertEqual(EarningsForecaster.percentile([1, 2, 3, 4], 0.5), 2.5, accuracy: 0.0001)
    }

    func testWorkProfileDecodesOldPayloadAndClampsOvernightRange() throws {
        let profile = try JSONDecoder().decode(WorkProfile.self, from: Data(#"{"region":"Ankara/Sincan"}"#.utf8))
        XCTAssertEqual(profile.region, "Ankara/Sincan")
        XCTAssertEqual(profile.switchBufferMinutes, 20)
        XCTAssertEqual(profile.maxHoursPerDay, 10)

        var p = WorkProfile()
        p.availability = [1: [TimeRange(startMinute: 20 * 60, endMinute: 2 * 60)]]
        XCTAssertEqual(p.ranges(weekday: 1), [TimeRange(startMinute: 1200, endMinute: 1440)])
        XCTAssertTrue(p.isAvailable(weekday: 1, start: 1320, end: 1440))
        XCTAssertFalse(p.isAvailable(weekday: 2, start: 1320, end: 1380))
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(WorkProfile.self, from: data), p)

        p.monthlySocialSecurity = 5200
        p.monthlyOtherFixed = 0
        XCTAssertEqual(p.dailyFixedCost, 200, accuracy: 0.001)
    }
}
