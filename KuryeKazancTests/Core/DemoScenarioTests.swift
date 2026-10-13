import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class DemoScenarioTests: XCTestCase {
    private let today = "2026-10-13"

    private func fuel(_ s: DemoScenario) -> FuelCostModel {
        FuelCostModel(settings: FuelSettings(entries: s.fuelPrices.map {
            FuelPriceEntry(day: DemoScenarioCatalog.day(offset: $0.dayOffset, from: today), pricePerUnit: $0.price, type: .gasoline)
        }, consumptionPer100Km: s.consumption), vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
    }

    private func entries(_ s: DemoScenario, platform: String) -> [EarningEntry] {
        s.workDays.map { w in
            let start = Date(timeIntervalSince1970: 1_791_000_000 + Double(w.dayOffset) * 86_400)
            return EarningEntry(start: start, end: start.addingTimeInterval(NSDecimalNumber(decimal: w.hours).doubleValue * 3600),
                                gross: 0, bonus: 0, distanceKm: NSDecimalNumber(decimal: w.km).doubleValue,
                                platformCode: platform, packageCount: w.packages)
        }
    }

    func testCatalogIDs() {
        XCTAssertEqual(DemoScenarioCatalog.all.map(\.id), ["paketTaxi30", "yemeksepetiBehind", "tariffChanged", "fresh"])
    }

    func testDeterministic() {
        XCTAssertEqual(DemoScenarioCatalog.workDays(count: 5, skipEvery: nil, packages: 30...45, rate: 4, kmPerPackage: 3, seed: 17),
                       DemoScenarioCatalog.workDays(count: 5, skipEvery: nil, packages: 30...45, rate: 4, kmPerPackage: 3, seed: 17))
    }

    func testPaketTaxiShape() throws {
        let s = try XCTUnwrap(DemoScenarioCatalog.scenario("paketTaxi30"))
        XCTAssertEqual(s.profile?.platformCode, "migros_hemen")
        XCTAssertEqual(s.profile?.flags, ["woman_employment"])
        XCTAssertEqual(s.goal?.amount, Money(110_000))
        XCTAssertEqual(s.fuelPrices.count, 4)
        XCTAssertEqual(s.workDays.count, 26)
        XCTAssertTrue(s.workDays.allSatisfy { (34...44).contains($0.packages) && $0.dayOffset <= 0 && $0.dayOffset > -31 })
    }

    func testPaketTaxiPlanIsReachable() throws {
        let s = try XCTUnwrap(DemoScenarioCatalog.scenario("paketTaxi30"))
        let pace = PaceEstimate.estimate(entries: entries(s, platform: "migros_hemen"), platform: "migros_hemen",
                                         now: Date(timeIntervalSince1970: 1_791_000_000 + 86_400))
        XCTAssertFalse(pace.isAssumed)
        // Uygulamadaki gercek katalog (guncel tarifeler) ile
        let planner = GoalPlanner(engine: TariffFixtures.engine(catalog: TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: [])),
                                  fuel: fuel(s))
        guard case let .success(plan) = planner.plan(goal: try XCTUnwrap(s.goal), profile: try XCTUnwrap(s.profile), pace: pace,
                                                     day: today) else { return XCTFail() }
        XCTAssertEqual(plan.reachability, .reachable)
    }

    func testYemeksepetiBehindNeedsMoreDaysOrUnreachable() throws {
        let s = try XCTUnwrap(DemoScenarioCatalog.scenario("yemeksepetiBehind"))
        XCTAssertEqual(s.profile?.platformCode, "yemeksepeti")
        XCTAssertEqual(s.workDays.count, 14)
        let pace = PaceEstimate.estimate(entries: entries(s, platform: "yemeksepeti"), platform: "yemeksepeti",
                                         now: Date(timeIntervalSince1970: 1_791_000_000 + 86_400))
        let planner = GoalPlanner(engine: TariffFixtures.engine(catalog: TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: [])),
                                  fuel: fuel(s))
        guard case let .success(plan) = planner.plan(goal: try XCTUnwrap(s.goal), profile: try XCTUnwrap(s.profile), pace: pace,
                                                     day: today) else { return XCTFail() }
        XCTAssertNotEqual(plan.reachability, .reachable)
    }

    func testTariffChangedHasTwoUserVersionsAndSwitchSuggestion() throws {
        let s = try XCTUnwrap(DemoScenarioCatalog.scenario("tariffChanged"))
        let versions = s.userTariffs(today: today)
        XCTAssertEqual(versions.count, 2)
        XCTAssertTrue(versions.allSatisfy { $0.origin == .user && $0.platformCode == "yemeksepeti" })
        let catalog = TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: versions)
        XCTAssertEqual(TariffFuelCorrelation.evaluate(platform: "yemeksepeti", catalog: catalog, fuel: fuel(s), today: today)?.verdict,
                       .consistent)
        let rows = TariffComparison.rows(workload: WorkloadSpec(packagesPerDay: 32, hoursPerDay: 8, kmPerPackage: 3, daysPerMonth: 26),
                                         profile: try XCTUnwrap(s.profile), catalog: catalog, fuel: fuel(s), day: today)
        XCTAssertEqual(TariffComparison.switchSuggestion(rows: rows)?.platformCode, "yemeksepeti")
    }

    func testFreshIsEmpty() throws {
        let s = try XCTUnwrap(DemoScenarioCatalog.scenario("fresh"))
        XCTAssertNil(s.profile)
        XCTAssertTrue(s.workDays.isEmpty)
        XCTAssertTrue(s.resetsOnboarding)
    }

    func testDayOffset() {
        XCTAssertEqual(DemoScenarioCatalog.day(offset: -13, from: "2026-10-13"), "2026-09-30")
    }

    /// Uygulamada kayit yokken varsayilan is yuku (2,5 paket/sa × 8 sa = 20 paket/gun) ile de oneri cikmali.
    func testTariffChangedSuggestionWithDefaultWorkload() throws {
        let s = try XCTUnwrap(DemoScenarioCatalog.scenario("tariffChanged"))
        let catalog = TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: s.userTariffs(today: today))
        let pace = PaceEstimate.estimate(entries: [], platform: "migros_hemen", now: Date())
        let workload = WorkloadSpec.from(pace: pace, goal: s.goal)
        let rows = TariffComparison.rows(workload: workload, profile: try XCTUnwrap(s.profile), catalog: catalog,
                                         fuel: fuel(s), day: today)
        XCTAssertEqual(TariffComparison.switchSuggestion(rows: rows)?.platformCode, "yemeksepeti")
    }
}
