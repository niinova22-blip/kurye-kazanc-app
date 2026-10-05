import XCTest
@testable import KuryeKazanc

final class EarningsCalculatorTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_760_000_000)

    private func hours(_ h: Double) -> Date { base.addingTimeInterval(h * 3600) }

    private func entry(_ start: Double, _ end: Double, gross: Double, bonus: Double = 0,
                       km: Double = 0, platform: String? = nil) -> EarningEntry {
        EarningEntry(start: hours(start), end: hours(end), gross: gross, bonus: bonus,
                     distanceKm: km, platformCode: platform)
    }

    // MARK: - Net TL/saat

    func testNetPerHour_withoutExpenses() {
        let calc = EarningsCalculator(costPerKm: 0)
        let summary = calc.summarize(earnings: [entry(0, 4, gross: 800)], expenses: [])

        XCTAssertEqual(summary.netEarnings, 800, accuracy: 0.001)
        XCTAssertEqual(summary.workHours, 4, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.netPerHour), 200, accuracy: 0.001)
    }

    func testNetPerHour_includesBonusAndSubtractsExpenses() {
        let calc = EarningsCalculator(costPerKm: 0)
        let summary = calc.summarize(
            earnings: [entry(0, 5, gross: 900, bonus: 100)],
            expenses: [ExpenseEntry(type: .fuel, amount: 250)]
        )
        // (900 + 100 - 250) / 5
        XCTAssertEqual(summary.netEarnings, 750, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.netPerHour), 150, accuracy: 0.001)
    }

    func testNetPerHour_isNilWhenNoWorkTime() {
        let summary = EarningsCalculator(costPerKm: 2).summarize(earnings: [], expenses: [])
        XCTAssertNil(summary.netPerHour)
        XCTAssertEqual(summary, .empty)
    }

    func testNetPerHour_canBeNegative() {
        let summary = EarningsCalculator(costPerKm: 0).summarize(
            earnings: [entry(0, 2, gross: 100)],
            expenses: [ExpenseEntry(type: .tire, amount: 300)]
        )
        XCTAssertEqual(try XCTUnwrap(summary.netPerHour), -100, accuracy: 0.001)
    }

    // MARK: - Calisma suresi (cakisan araliklar)

    func testWorkDuration_mergesOverlappingMultiPlatformShifts() {
        // Trendyol GO 09-13, Getir 12-15 -> birlesim 09-15 = 6 saat (7 degil)
        let summary = EarningsCalculator(costPerKm: 0).summarize(
            earnings: [entry(9, 13, gross: 600), entry(12, 15, gross: 400)],
            expenses: []
        )
        XCTAssertEqual(summary.workHours, 6, accuracy: 0.001)
    }

    func testWorkDuration_sumsDisjointShifts() {
        let duration = EarningsCalculator.mergedDuration(of: [
            (start: hours(13), end: hours(15)),
            (start: hours(8), end: hours(10)),
        ])
        XCTAssertEqual(duration, 4 * 3600, accuracy: 0.001)
    }

    func testWorkDuration_handlesContainedAndTouchingIntervals() {
        let duration = EarningsCalculator.mergedDuration(of: [
            (start: hours(8), end: hours(12)),
            (start: hours(9), end: hours(10)),   // icerilen
            (start: hours(12), end: hours(13)),  // ucu ucuna degen
        ])
        XCTAssertEqual(duration, 5 * 3600, accuracy: 0.001)
    }

    func testWorkDuration_ignoresInvalidIntervals() {
        let duration = EarningsCalculator.mergedDuration(of: [
            (start: hours(10), end: hours(9)),
            (start: hours(10), end: hours(10)),
        ])
        XCTAssertEqual(duration, 0)
    }

    // MARK: - Gider tahmini

    func testEstimatedExpense_usesCostPerKm() {
        let summary = EarningsCalculator(costPerKm: 2.5).summarize(
            earnings: [entry(0, 4, gross: 800, km: 60)], expenses: []
        )
        XCTAssertEqual(summary.estimatedExpenses, 150, accuracy: 0.001)
        XCTAssertEqual(summary.netEarnings, 650, accuracy: 0.001)
        XCTAssertTrue(summary.usesEstimatedExpenses)
    }

    func testEstimatedExpense_skippedWhenManualFuelEntered() {
        let summary = EarningsCalculator(costPerKm: 2.5).summarize(
            earnings: [entry(0, 4, gross: 800, km: 60)],
            expenses: [ExpenseEntry(type: .fuel, amount: 200)]
        )
        XCTAssertEqual(summary.estimatedExpenses, 0)
        XCTAssertEqual(summary.totalExpenses, 200, accuracy: 0.001)
    }

    func testEstimatedExpense_skippedWhenManualMaintenanceEntered() {
        let calc = EarningsCalculator(costPerKm: 2.5)
        XCTAssertEqual(calc.estimatedExpense(distanceKm: 60, manualExpenses: [ExpenseEntry(type: .maintenance, amount: 50)]), 0)
    }

    func testEstimatedExpense_stillAppliedWithNonFuelManualExpenses() {
        // Lastik/amortisman/diger km tahminini kapsamaz -> ikisi birlikte sayilir
        let summary = EarningsCalculator(costPerKm: 2.5).summarize(
            earnings: [entry(9, 13, gross: 600, bonus: 50, km: 40), entry(12, 15, gross: 400, km: 20)],
            expenses: [ExpenseEntry(type: .other, amount: 50)]
        )
        XCTAssertEqual(summary.estimatedExpenses, 150, accuracy: 0.001)
        XCTAssertEqual(summary.totalExpenses, 200, accuracy: 0.001)
        XCTAssertEqual(summary.netEarnings, 850, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.netPerHour), 850.0 / 6.0, accuracy: 0.001)
    }

    func testEstimatedExpense_disabled() {
        let calc = EarningsCalculator(costPerKm: 2.5, autoEstimateEnabled: false)
        XCTAssertEqual(calc.estimatedExpense(distanceKm: 100, manualExpenses: []), 0)
    }

    func testNegativeValuesAreClamped() {
        let summary = EarningsCalculator(costPerKm: 1).summarize(
            earnings: [entry(0, 1, gross: 100, km: -10)],
            expenses: [ExpenseEntry(type: .other, amount: -20)]
        )
        XCTAssertEqual(summary.distanceKm, 0)
        XCTAssertEqual(summary.totalExpenses, 0)
    }

    // MARK: - Platform bazinda toplam

    func testTotalsByPlatform() {
        let totals = EarningsCalculator.totalsByPlatform([
            entry(0, 1, gross: 100, bonus: 10, platform: "getir"),
            entry(1, 2, gross: 200, platform: "trendyol_go"),
            entry(2, 3, gross: 50, platform: "getir"),
            entry(3, 4, gross: 30, platform: nil),
        ])
        XCTAssertEqual(totals["getir"], 160)
        XCTAssertEqual(totals["trendyol_go"], 200)
        XCTAssertEqual(totals["other"], 30)
    }
}
