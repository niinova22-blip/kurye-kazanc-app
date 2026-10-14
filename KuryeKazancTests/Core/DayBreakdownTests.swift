import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class DayBreakdownTests: XCTestCase {
    private func row(_ id: String, _ category: PayDetailCategory, _ label: String, _ amount: String) -> PayDetailRow {
        PayDetailRow(id: id, category: category, label: label, quantityText: "x", periodAmount: money(amount), perDay: money(amount))
    }

    func testMergesSameItemsAcrossShiftsAndAddsFixedShareOnce() {
        let morning = PayDetail(rows: [row("a", .packages, "Paket ücreti", "1200"), row("b", .bonus, "Günlük bonus", "300")], days: 1)
        let evening = PayDetail(rows: [row("c", .packages, "Paket ücreti", "800"),
                                       row("d", .side, "Yemek kartı", "100")], days: 1)
        let fixed = PayDetailRow(id: "share", category: .fixed, label: "Sabit ücret", quantityText: "52.000 ÷ 26",
                                 periodAmount: money("52000"), perDay: money("2000"), isEstimate: true)
        let day = DayBreakdown.make(logs: [(morning, money("1500")), (evening, money("800"))], unlinkedRecords: money("250"),
                                    liveShift: money("400"), fixedShare: [fixed])

        XCTAssertEqual(day.rows.first { $0.label == "Paket ücreti" }?.periodAmount, money("2000"))
        XCTAssertNil(day.rows.first { $0.label == "Paket ücreti" }?.quantityText, "birlesen satirda adet yazilmaz")
        XCTAssertEqual(day.rows.first { $0.category == .fixed }?.periodAmount, money("2000"), "gunluk pay, aylik tutar degil")
        XCTAssertFalse(day.rows.contains { $0.category == .side }, "yan haklar nakit toplama girmez")
        XCTAssertEqual(day.rows.map(\.category), [.packages, .fixed, .bonus, .other, .other])
        // 2000 paket + 2000 sabit + 300 bonus + 250 diger + 400 suren vardiya
        XCTAssertEqual(day.gross, money("4950"))
    }

    func testEditedRecordShowsAdjustment() {
        let shift = PayDetail(rows: [row("a", .packages, "Paket ücreti", "1000")], days: 1)
        let day = DayBreakdown.make(logs: [(shift, money("1100"))], unlinkedRecords: .zero, liveShift: .zero, fixedShare: [])
        XCTAssertEqual(day.rows.first { $0.id == "day.adjustment" }?.periodAmount, money("100"))
        XCTAssertEqual(day.gross, money("1100"))
    }

    func testPaceProjectsWorkedDayAverageOverPeriod() throws {
        let goal = GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 6)  // 26 is gunu
        let pace = try XCTUnwrap(GoalPace.project(goal: goal, dailyNets: [money("3000"), money("4000"), .zero]))
        XCTAssertEqual(pace.workedDays, 2)
        XCTAssertEqual(pace.projected, money("91000"))   // 3.500 × 26
        XCTAssertEqual(pace.difference, money("-9000"))
        XCTAssertFalse(pace.isAhead)

        let daily = try XCTUnwrap(GoalPace.project(goal: GoalSpec(amount: Money(3_000), period: .day), dailyNets: [money("3200")]))
        XCTAssertTrue(daily.isAhead)
        XCTAssertEqual(daily.difference, money("200"))
        XCTAssertNil(GoalPace.project(goal: goal, dailyNets: []))
    }
}
