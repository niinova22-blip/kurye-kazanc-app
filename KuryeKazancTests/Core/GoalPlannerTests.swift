import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class GoalPlannerTests: XCTestCase {
    private let day = "2026-10-13"
    private let engine = PayEngine(catalog: TariffCatalog.merged(bundled: BundledTariffs.all, remote: [], user: []))
    private let fuel = FuelCostModel(
        settings: FuelSettings(entries: [FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline)],
                               consumptionPer100Km: 3),
        vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
    private let pace = PaceEstimate(packagesPerHour: Decimal(string: "4.2")!, kmPerPackage: Decimal(string: "3.5")!,
                                    isAssumed: false, sampleCount: 20)
    private let paketTaxi = CourierTariffProfile(platformCode: "migros_hemen", regionTier: "plus", seniorityYears: 1,
                                                 vehicleType: nil, flags: ["woman_employment"])

    private func plan(_ goal: GoalSpec, profile: CourierTariffProfile? = nil, pace: PaceEstimate? = nil,
                      file: StaticString = #filePath, line: UInt = #line) throws -> GoalPlan {
        let planner = GoalPlanner(engine: engine, fuel: fuel)
        switch planner.plan(goal: goal, profile: profile ?? paketTaxi, pace: pace ?? self.pace, day: day) {
        case let .success(plan): return plan
        case let .failure(error):
            XCTFail(error.message, file: file, line: line)
            throw error
        }
    }

    func testPaketTaxiMonthlyHundredThousand() throws {
        let result = try plan(GoalSpec(amount: Money(100_000), period: .month))
        // 65.223 + 2.000 + N × (38 − 4,725) ≥ 100.000 → N = 986
        XCTAssertEqual(result.monthlyPackages, 986)
        XCTAssertEqual(result.workDays, 26)
        XCTAssertEqual(result.packagesPerDay, 38)
        XCTAssertEqual(result.hoursPerDay, Decimal(string: "9.5"))
        XCTAssertEqual(result.reachability, .reachable)
        XCTAssertEqual(result.sideIncome, Money(2_000))
        XCTAssertTrue(result.guaranteed.contains { $0.label.contains("Kadın") && $0.isSideBenefit })
        XCTAssertTrue(result.guaranteed.contains { $0.amount == Money(65_223) })
        XCTAssertGreaterThanOrEqual(result.net.value, 100_000)
        XCTAssertEqual(result.regionTier, "plus")
        XCTAssertEqual(result.otherTierDelta, Money(12_000))
    }

    func testNextTierHintNearThreshold() throws {
        let result = try plan(GoalSpec(amount: Money(100_000), period: .month))
        XCTAssertEqual(result.nextTier?.threshold, 1_100)
        XCTAssertEqual(result.nextTier?.extraPackages, 114)
        XCTAssertEqual(result.nextTier?.newRate, Money(40))
        XCTAssertTrue((result.nextTier?.extraNet.value ?? 0) > 0)
    }

    func testWithoutWomanFlagNeedsMorePackages() throws {
        var profile = paketTaxi
        profile.flags = []
        XCTAssertGreaterThan(try plan(GoalSpec(amount: Money(100_000), period: .month), profile: profile).monthlyPackages, 986)
    }

    func testGoalBelowGuaranteedIsAlreadyMet() throws {
        let result = try plan(GoalSpec(amount: Money(50_000), period: .month))
        XCTAssertEqual(result.reachability, .alreadyMet)
        XCTAssertEqual(result.monthlyPackages, 0)
    }

    func testUnreachableSuggestsMoreDays() throws {
        // Gunde 8 saat × 4,2 = 33 paket; haftada 4 gun yetmez, 7 gunde (30 is gunu × 33 = 990 >= 986) ulasilir
        let result = try plan(GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 4, maxHoursPerDay: 8))
        XCTAssertEqual(result.reachability, .needsMoreDays(7))
    }

    func testUnreachableEvenWithSevenDays() throws {
        let slow = PaceEstimate(packagesPerHour: 2, kmPerPackage: Decimal(string: "3.5")!, isAssumed: false, sampleCount: 9)
        let result = try plan(GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 5, maxHoursPerDay: 8), pace: slow)
        guard case let .unreachable(maxNet) = result.reachability else { return XCTFail("\(result.reachability)") }
        XCTAssertLessThan(maxNet.value, 100_000)
    }

    func testDailyGoalCannotBeMet() throws {
        let result = try plan(GoalSpec(amount: Money(20_000), period: .day, daysPerWeek: 6, maxHoursPerDay: 10))
        guard case .unreachable = result.reachability else { return XCTFail("\(result.reachability)") }
    }

    func testWeeklyGoalConvertsBack() throws {
        let result = try plan(GoalSpec(amount: Money(20_000), period: .week))
        XCTAssertEqual(result.reachability, .reachable)
        XCTAssertGreaterThanOrEqual(result.periodNet().value, 20_000)
        XCTAssertLessThan(result.periodNet().value, 20_100)
        XCTAssertEqual(result.periodPackages(), Int((Double(result.monthlyPackages) * 6 / 26).rounded(.up)))
    }

    func testGetirHourlyModel() throws {
        let getir = CourierTariffProfile(platformCode: "getir", regionTier: nil, seniorityYears: nil,
                                         vehicleType: "motorcycle", flags: [])
        let result = try plan(GoalSpec(amount: Money(100_000), period: .month), profile: getir)
        XCTAssertGreaterThan(result.monthlyPackages, 0)
        XCTAssertGreaterThanOrEqual(result.net.value, 100_000)
        XCTAssertTrue(result.guaranteed.contains { $0.label == "Saatlik ücret" })
    }

    func testGetirWithoutVehicleDefaultsToMotorcycle() throws {
        let getir = CourierTariffProfile(platformCode: "getir", regionTier: nil, seniorityYears: nil, vehicleType: nil, flags: [])
        XCTAssertGreaterThan(try plan(GoalSpec(amount: Money(80_000), period: .month), profile: getir).monthlyPackages, 0)
    }

    func testUnsupportedPlatformFails() {
        let planner = GoalPlanner(engine: engine, fuel: fuel)
        let other = CourierTariffProfile(platformCode: "uber", regionTier: nil, seniorityYears: nil, vehicleType: nil, flags: [])
        if case .success = planner.plan(goal: GoalSpec(amount: Money(1), period: .month), profile: other, pace: pace, day: day) {
            XCTFail("uber icin tarife yok")
        }
    }

    func testFuelFallbackFlag() {
        let noFuel = FuelCostModel(settings: FuelSettings(), vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
        let planner = GoalPlanner(engine: engine, fuel: noFuel)
        guard case let .success(result) = planner.plan(goal: GoalSpec(amount: Money(100_000), period: .month),
                                                       profile: paketTaxi, pace: pace, day: day) else { return XCTFail() }
        XCTAssertTrue(result.usesFuelFallback)
    }

    func testMonthBounds() {
        XCTAssertEqual(GoalPlanner.monthBounds(of: "2026-10-13").start, "2026-10-01")
        XCTAssertEqual(GoalPlanner.monthBounds(of: "2026-10-13").end, "2026-10-31")
        XCTAssertEqual(GoalPlanner.monthBounds(of: "2028-02-03").end, "2028-02-29")
    }
}
