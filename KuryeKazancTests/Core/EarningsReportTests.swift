import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class EarningsReportTests: XCTestCase {
    private let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: [])
    private var engine: PayEngine { PayEngine(catalog: catalog) }

    private func log(_ platform: String, day: String, packages: Int, region: String, km: Decimal = 0) throws -> WorkLog {
        var input = PayInput(platformCode: platform, startDay: day)
        input.regionTier = region
        input.dayPackages = packages
        input.hours = 8
        input.totalKm = km
        return WorkLog(method: .shift, input: input, result: try engine.calculate(input).get())
    }

    func testMonthReportRowsAddUpToPeriodGross() throws {
        let logs = [try log("pt_migros", day: "2026-10-14", packages: 25, region: "r23"),
                    try log("pt_migros", day: "2026-10-15", packages: 38, region: "r23")]
        let aggregator = PeriodAggregator(engine: engine)
        var prefs = PayInput(platformCode: "pt_migros", startDay: "2026-10-01", endDay: "2026-10-31")
        prefs.regionTier = "r23"
        let result = aggregator.summarize(platform: "pt_migros", logs: logs, start: "2026-10-01", end: "2026-10-31", preferences: prefs)
        let report = EarningsReportBuilder.make(platformName: "Paket Taxi Migros", span: .month, start: "2026-10-01", end: "2026-10-31",
                                                result: result, logs: logs, fixedSharePerDay: nil, fuel: Money(100), otherExpenses: .zero)
        XCTAssertEqual(report.gross, result.gross)
        XCTAssertEqual(report.days.map(\.day), ["2026-10-14", "2026-10-15"])
        XCTAssertEqual(report.packages, 63)
        XCTAssertEqual(report.net, result.gross - Money(100))
        // Gunluk primler (760 + 1.595) + aylik sabit ucret 55.223
        XCTAssertTrue(report.rows.contains { $0.id == "monthly" })
        XCTAssertTrue(report.csv().contains("Net;"))
        XCTAssertTrue(report.csv().contains("2026-10-15;38;"))
    }

    func testWeekReportYemeksepetiWeeklyBonusNoMonthly() throws {
        // 13–19 Ekim haftasi, Istanbul: 7 gun × 30 = 210 paket -> haftalik 200–219 bonusu 5.250
        let days = ["2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18", "2026-10-12"]
        let logs = try days.map { try log("yemeksepeti", day: $0, packages: 30, region: "ys_istanbul") }
        let aggregator = PeriodAggregator(engine: engine)
        var prefs = PayInput(platformCode: "yemeksepeti", startDay: "2026-10-12", endDay: "2026-10-18")
        prefs.regionTier = "ys_istanbul"
        let result = aggregator.summarize(platform: "yemeksepeti", logs: logs, start: "2026-10-12", end: "2026-10-18",
                                          preferences: prefs, includeMonthly: false)
        let report = EarningsReportBuilder.make(platformName: "Yemeksepeti", span: .week, start: "2026-10-12", end: "2026-10-18",
                                                result: result, logs: logs, fixedSharePerDay: nil, fuel: .zero, otherExpenses: .zero)
        XCTAssertEqual(report.rows.first { $0.id == "weekly" }?.amount, Money(5_250))
        XCTAssertNil(report.rows.first { $0.id == "monthly" })
        XCTAssertEqual(report.gross, result.gross)
        XCTAssertTrue(report.notes.isEmpty)
    }

    func testDayReportAddsFixedShareWhenAsked() throws {
        let logs = [try log("pt_migros", day: "2026-10-15", packages: 25, region: "r23")]
        let aggregator = PeriodAggregator(engine: engine)
        let result = aggregator.summarize(platform: "pt_migros", logs: logs, start: "2026-10-15", end: "2026-10-15", includeMonthly: false)
        let report = EarningsReportBuilder.make(platformName: "Paket Taxi Migros", span: .day, start: "2026-10-15", end: "2026-10-15",
                                                result: result, logs: logs, fixedSharePerDay: Money(2_123), fuel: .zero, otherExpenses: .zero)
        XCTAssertEqual(report.gross, Money(760 + 2_123))
    }
}
