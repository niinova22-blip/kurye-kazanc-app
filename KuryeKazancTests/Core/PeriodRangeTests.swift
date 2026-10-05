import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore // Windows/Linux: swift test
#else
@testable import KuryeKazanc // Xcode / CI
#endif

final class PeriodRangeTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Istanbul")!
    private var periods: PeriodRange { PeriodRange(calendar: PeriodRange.turkishCalendar(timeZone: tz)) }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testWeekStartsOnMonday() {
        // 8 Ekim 2026 Persembe -> hafta 5 Ekim Pazartesi - 12 Ekim
        let interval = periods.interval(of: .week, containing: date(2026, 10, 8))
        XCTAssertEqual(interval.start, date(2026, 10, 5, 0))
        XCTAssertEqual(interval.end, date(2026, 10, 12, 0))
        XCTAssertEqual(periods.days(in: interval).count, 7)
    }

    func testSundayBelongsToPreviousWeek() {
        let interval = periods.interval(of: .week, containing: date(2026, 10, 11))
        XCTAssertEqual(interval.start, date(2026, 10, 5, 0))
    }

    func testMonthAndDay() {
        let month = periods.interval(of: .month, containing: date(2026, 2, 14))
        XCTAssertEqual(month.start, date(2026, 2, 1, 0))
        XCTAssertEqual(month.end, date(2026, 3, 1, 0))
        XCTAssertEqual(periods.days(in: month).count, 28)

        let day = periods.interval(of: .day, containing: date(2026, 10, 6, 23))
        XCTAssertEqual(day.start, date(2026, 10, 6, 0))
        XCTAssertEqual(day.duration, 86_400)
    }

    func testShift() {
        XCTAssertEqual(periods.shift(date(2026, 10, 6), kind: .week, by: -1), date(2026, 9, 29))
        XCTAssertEqual(periods.shift(date(2026, 1, 31), kind: .month, by: 1), date(2026, 2, 28))
    }

    func testTurkishTitles() {
        XCTAssertTrue(periods.title(of: .month, containing: date(2026, 10, 6)).lowercased().contains("ekim"))
    }
}
