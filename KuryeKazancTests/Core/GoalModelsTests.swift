import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class GoalModelsTests: XCTestCase {
    func testMonthWorkDaysFromDaysPerWeek() {
        XCTAssertEqual(GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 6).monthWorkDays, 26)
        XCTAssertEqual(GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 5).monthWorkDays, 22)
        XCTAssertEqual(GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 7).monthWorkDays, 30)
    }

    func testMonthlyTargetConvertsPeriods() {
        XCTAssertEqual(GoalSpec(amount: Money(100_000), period: .month).monthlyTarget(), Money(100_000))
        // Haftalik 24.000, haftada 6 gun -> ayda 26 gun: 24.000 * 26 / 6 = 104.000
        XCTAssertEqual(GoalSpec(amount: Money(24_000), period: .week, daysPerWeek: 6).monthlyTarget(), Money(104_000))
        // Gunluk 4.000 * 26 = 104.000
        XCTAssertEqual(GoalSpec(amount: Money(4_000), period: .day, daysPerWeek: 6).monthlyTarget(), Money(104_000))
    }

    func testPeriodWorkDays() {
        XCTAssertEqual(GoalSpec(amount: Money(1), period: .day).periodWorkDays(), 1)
        XCTAssertEqual(GoalSpec(amount: Money(1), period: .week, daysPerWeek: 5).periodWorkDays(), 5)
        XCTAssertEqual(GoalSpec(amount: Money(1), period: .month, daysPerWeek: 6).periodWorkDays(), 26)
    }

    func testOldStateDecodesWithDefaults() throws {
        let json = #"{"schemaVersion":1,"logs":[],"regionTier":"plus"}"#
        let state = try JSONDecoder().decode(PayrollState.self, from: Data(json.utf8))
        XCTAssertEqual(state.flags, [])
        XCTAssertNil(state.goal)
        XCTAssertEqual(state.fuel, FuelSettings())
        XCTAssertEqual(state.demoRecordIDs, [])
    }

    func testStorePersistsGoalFuelAndFlags() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("goal-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PayrollStore(fileURL: url)
        store.select(platform: "migros_hemen")
        store.setPreferences(regionTier: "plus", seniorityYears: 1, vehicleType: nil)
        store.setFlags(["woman_employment"])
        store.setGoal(GoalSpec(amount: Money(100_000), period: .month))
        store.setConsumption(3)
        let entry = FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline)
        store.addFuelPrice(entry)

        let reloaded = PayrollStore(fileURL: url)
        XCTAssertEqual(reloaded.state.flags, ["woman_employment"])
        XCTAssertEqual(reloaded.state.goal?.amount, Money(100_000))
        XCTAssertEqual(reloaded.state.fuel.entries, [entry])
        XCTAssertEqual(reloaded.state.fuel.consumptionPer100Km, 3)
        XCTAssertEqual(reloaded.state.tariffProfile,
                       CourierTariffProfile(platformCode: "migros_hemen", regionTier: "plus", seniorityYears: 1,
                                            vehicleType: nil, flags: ["woman_employment"]))
        reloaded.deleteFuelPrice(id: entry.id)
        XCTAssertTrue(PayrollStore(fileURL: url).state.fuel.entries.isEmpty)
    }

    func testReplaceFuelAndRemoveLogs() throws {
        let store = PayrollStore(fileURL: nil)
        store.addFuelPrice(FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline))
        store.replaceFuel(FuelSettings())
        XCTAssertTrue(store.state.fuel.entries.isEmpty)
        store.setDemoIDs(records: [UUID()], logs: [UUID()])
        XCTAssertEqual(store.state.demoLogIDs.count, 1)
    }

    func testMarkEventsSeen() {
        let store = PayrollStore(fileURL: nil)
        store.markEventsSeen(["switch:a|b"])
        store.markEventsSeen(["switch:a|b"])
        XCTAssertEqual(store.state.seenEventIDs, ["switch:a|b"])
    }

    func testMoneyFromDoubleDropsBinaryNoise() {
        XCTAssertEqual(Money(double: 64.5), Money(Decimal(string: "64.5")!))
        XCTAssertEqual(Money(double: 0.1 + 0.2), Money(Decimal(string: "0.3")!))
        XCTAssertEqual(Money(double: 2.5).value, Decimal(string: "2.5"))
    }
}
