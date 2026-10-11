import XCTest
@testable import KuryeCore

/// Donem sinirlari, cift sayim, odeme karsilastirmasi ve gider / net raporlari.
final class PeriodAggregatorTests: XCTestCase {
    private let aggregator = PeriodAggregator(engine: TariffFixtures.engine)

    private func log(_ platform: String, _ day: String, packages: Int, hours: Decimal = 8, vehicle: String? = nil,
                     region: String? = nil, tips: Money = .zero) -> WorkLog {
        var input = TariffFixtures.input(platform, day: day)
        input.dayPackages = packages
        input.hours = hours
        input.vehicleType = vehicle
        input.regionTier = region
        input.tips = tips
        return WorkLog(method: .detailed, input: input, result: TariffFixtures.calc(input))
    }

    private func days(from start: Int, to end: Int, month: String = "2026-10") -> [String] {
        (start...end).map { String(format: "\(month)-%02d", $0) }
    }

    func testPaketTaxiMonthReplacesProvisionalDailyRates() {
        let logs = days(from: 1, to: 25).map { log("migros_hemen", $0, packages: 50, region: "plus") }
        let result = aggregator.summarize(platform: "migros_hemen", logs: logs, start: "2026-10-01", end: "2026-10-31")
        XCTAssertEqual(result.packages, 1250)
        XCTAssertEqual(result.provisionalPart, money("47500"))
        XCTAssertTrue(result.provisionalReplaced)
        XCTAssertEqual(result.monthlyPart, money("115223"))
        XCTAssertEqual(result.gross, money("115223"), "taban ucret ve aylik kademe iki kez sayilmaz")
        XCTAssertTrue(result.progress.contains { $0.unit == .month && $0.target == 1300 && $0.remaining == 50 })
    }

    func testGetirWeekendBonusFromFridayToSunday() {
        // 2026-10-02 Cuma, 03 Cumartesi, 04 Pazar; 01 Persembe hafta sonuna sayilmaz
        let logs = [
            log("getir", "2026-10-01", packages: 30, vehicle: "motorcycle"),
            log("getir", "2026-10-02", packages: 20, vehicle: "motorcycle"),
            log("getir", "2026-10-03", packages: 25, vehicle: "motorcycle"),
            log("getir", "2026-10-04", packages: 20, vehicle: "motorcycle"),
        ]
        XCTAssertEqual(aggregator.weekendPackages(logs), 65)
        let result = aggregator.summarize(platform: "getir", logs: logs, start: "2026-10-01", end: "2026-10-31")
        XCTAssertEqual(result.weeklyPart, money("900"))
        let daily = logs.map(\.result.gross).sum()
        XCTAssertEqual(result.gross, daily + money("900"))
    }

    func testWeekSpanningTwoMonthsCountedOnlyOnce() {
        // Hafta 28 Eylul (Pzt) – 4 Ekim (Paz): Pazari Ekim'de
        let logs = [
            log("getir", "2026-09-28", packages: 10, vehicle: "motorcycle"),
            log("getir", "2026-10-02", packages: 20, vehicle: "motorcycle"),
            log("getir", "2026-10-03", packages: 25, vehicle: "motorcycle"),
        ]
        let september = aggregator.summarize(platform: "getir", logs: logs, start: "2026-09-01", end: "2026-09-30")
        let october = aggregator.summarize(platform: "getir", logs: logs, start: "2026-10-01", end: "2026-10-31")
        XCTAssertEqual(september.weeklyPart, .zero)
        XCTAssertEqual(october.weeklyPart, money("800"))
        XCTAssertTrue(september.progress.contains { $0.unit == .week }, "suren hafta ilerleme olarak gosterilir")
    }

    func testOtherPlatformsLogsExcluded() {
        let logs = [log("trendyol_go", "2026-10-05", packages: 10), log("yemeksepeti", "2026-10-05", packages: 10)]
        let result = aggregator.summarize(platform: "trendyol_go", logs: logs, start: "2026-10-01", end: "2026-10-31")
        XCTAssertEqual(result.logCount, 1)
        XCTAssertEqual(result.gross, money("645"))
    }

    func testPeriodLogUsedWhenNoDailyLogs() {
        var input = TariffFixtures.input("yemeksepeti", day: "2026-10-05", span: .week, end: "2026-10-11")
        input.dayPackages = 100
        let period = WorkLog(method: .period, input: input, result: TariffFixtures.calc(input))
        let result = aggregator.summarize(platform: "yemeksepeti", logs: [period], start: "2026-10-01", end: "2026-10-31")
        XCTAssertEqual(result.periodLogPart, money("7500"))
        XCTAssertEqual(result.gross, money("7500"))
    }

    func testWeekAndMonthRanges() {
        XCTAssertEqual(aggregator.weekRange(containing: "2026-10-07")?.start, "2026-10-05")
        XCTAssertEqual(aggregator.weekRange(containing: "2026-10-11")?.end, "2026-10-11")
        XCTAssertEqual(aggregator.monthRange(containing: "2026-02-10")?.end, "2026-02-28")
        XCTAssertEqual(aggregator.monthRange(containing: "2026-10-31")?.start, "2026-10-01")
    }

    // MARK: - Odeme karsilastirmasi

    func testReconciliationMatchAndDifferenceWithChecks() {
        let logs = [log("trendyol_go", "2026-10-05", packages: 10, tips: money("50")),
                    log("trendyol_go", "2026-10-06", packages: 10)]
        let period = aggregator.summarize(platform: "trendyol_go", logs: logs, start: "2026-10-05", end: "2026-10-11")
        XCTAssertEqual(period.prePayment, money("1340"))
        let match = PaymentReconciler.reconcile(period: period, actual: money("1340.50"), periodDays: 7)
        XCTAssertEqual(match.status, .matches)
        XCTAssertTrue(match.checks.isEmpty)

        let lower = PaymentReconciler.reconcile(period: period, actual: money("1200"), advances: money("100"), periodDays: 7)
        XCTAssertEqual(lower.expected, money("1240"))
        XCTAssertEqual(lower.difference, money("-40"))
        XCTAssertEqual(lower.status, .lower)
        XCTAssertTrue(lower.checks.contains { $0.contains("5 gün") })
        XCTAssertTrue(lower.checks.contains { $0.contains("Bahşiş") })
        XCTAssertTrue(lower.checks.contains { $0.contains("doğrulanmamış") })
    }

    func testReconciliationWithinRangeIsNotAnError() {
        var input = TariffFixtures.input("trendyol_go", day: "2026-10-05")
        input.combinedPackages = 10
        let entry = WorkLog(method: .detailed, input: input, result: TariffFixtures.calc(input))
        let period = aggregator.summarize(platform: "trendyol_go", logs: [entry], start: "2026-10-05", end: "2026-10-05")
        XCTAssertEqual(period.prePayment, money("270"))
        XCTAssertEqual(period.prePaymentUpper, money("415"))
        let result = PaymentReconciler.reconcile(period: period, actual: money("350"))
        XCTAssertEqual(result.status, .withinRange)
    }

    // MARK: - Gider ve net

    func testExpenseReportAndDashboardNet() {
        let logs = [log("trendyol_go", "2026-10-05", packages: 10, hours: 5)]
        var input = logs[0].input
        input.totalKm = 40
        let withKm = WorkLog(method: .detailed, input: input, result: logs[0].result)
        let expenses = [
            DatedExpense(day: "2026-10-05", category: .fuel, amount: money("200")),
            DatedExpense(day: "2026-10-05", category: .phone, amount: money("45")),
            DatedExpense(day: "2026-09-10", category: .insurance, amount: money("500")),
        ]
        let october = expenses.filter { $0.day.hasPrefix("2026-10") }
        let report = ExpenseReport.build(logs: [withKm], expenses: october, allLogs: [withKm], allExpenses: expenses,
                                         lastMonth: "2026-10", months: 3)
        XCTAssertEqual(report.total, money("245"))
        XCTAssertEqual(report.byCategory[.phone], money("45"))
        XCTAssertEqual(report.net, money("400")) // 645 - 245
        XCTAssertEqual(report.perPackageNet, money("40"))
        XCTAssertEqual(report.perHourNet, money("80"))
        XCTAssertEqual(report.costPerKm, money("6.13")) // 245 / 40
        XCTAssertEqual(report.trend.map(\.month), ["2026-08", "2026-09", "2026-10"])
        XCTAssertEqual(report.trend[1].net, money("-500"))

        let period = aggregator.summarize(platform: "trendyol_go", logs: logs, start: "2026-10-01", end: "2026-10-31")
        let dashboard = PayrollDashboard(period: period, expenses: money("245"), paymentDifference: nil)
        XCTAssertEqual(dashboard.estimatedNet, money("400"))
        XCTAssertEqual(dashboard.netPerHour, money("80"))
        XCTAssertEqual(dashboard.nextBonus?.target, 42)
        XCTAssertEqual(dashboard.nextBonus?.remaining, 32)
    }

    func testPlatformComparisonUsesFrozenResults() {
        let logs = [
            log("getir", "2026-08-10", packages: 20, vehicle: "motorcycle"),
            log("getir", "2026-09-10", packages: 20, vehicle: "motorcycle"),
            log("trendyol_go", "2026-10-05", packages: 10),
        ]
        let comparison = PlatformComparison.build(logs)
        let getir = comparison.first { $0.platformCode == "getir" }
        XCTAssertEqual(getir?.months, 2)
        XCTAssertEqual(getir?.monthlyAverage, money("2600")) // (400 + 2200) x 2 / 2
        XCTAssertEqual(getir?.perPackage, money("130"))
        XCTAssertEqual(comparison.first { $0.platformCode == "trendyol_go" }?.gross, money("645"))
    }
}
