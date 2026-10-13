import XCTest
import SwiftData
@testable import KuryeKazanc

@MainActor
final class DemoScenarioLoaderTests: XCTestCase {
    private var container: ModelContainer!
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        container = ModelContainerFactory.make(inMemory: true)
        DataSeeder.seedPlatformsIfNeeded(in: container.mainContext)
        suiteName = "DemoScenarioLoaderTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        container = nil
    }

    private func makeModel() -> PayrollModel {
        let tariffs = TariffSyncService(client: nil, defaults: defaults, fileURL: nil)
        return PayrollModel(store: PayrollStore(fileURL: nil), tariffs: tariffs)
    }

    func testLoadAndClearKeepsRealRecords() throws {
        let context = container.mainContext
        let real = EarningRecord(startTime: .now, endTime: .now.addingTimeInterval(3600), platform: nil, grossEarning: 100,
                                 bonus: 0, distanceKm: 5, packageCount: 2, source: .manual)
        context.insert(real)
        try context.save()
        let payroll = makeModel()
        payroll.chooseFirm("getir", regionTier: nil, seniorityYears: nil, vehicleType: "motorcycle", flags: [])
        let loader = DemoScenarioLoader(payroll: payroll, context: context, defaults: defaults)
        XCTAssertTrue(loader.hasRealData)

        loader.load(try XCTUnwrap(DemoScenarioCatalog.scenario("paketTaxi30")))
        XCTAssertEqual(payroll.tariffProfile?.platformCode, "migros_hemen")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EarningRecord>()), 27)
        XCTAssertEqual(payroll.state.fuel.entries.count, 4)
        XCTAssertEqual(payroll.state.demoLogIDs.count, 26)

        loader.clear()
        let remaining = try context.fetch(FetchDescriptor<EarningRecord>())
        XCTAssertEqual(remaining.map(\.id), [real.id])
        XCTAssertTrue(payroll.state.demoLogIDs.isEmpty)
        XCTAssertTrue(payroll.state.logs.isEmpty)
        // Senaryo oncesi firma geri gelir
        XCTAssertEqual(payroll.tariffProfile?.platformCode, "getir")
        XCTAssertTrue(payroll.state.fuel.entries.isEmpty)
    }

    func testTariffChangedScenarioAddsAndRemovesUserTariffs() throws {
        let payroll = makeModel()
        let loader = DemoScenarioLoader(payroll: payroll, context: container.mainContext, defaults: defaults)
        loader.load(try XCTUnwrap(DemoScenarioCatalog.scenario("tariffChanged")))
        XCTAssertEqual(payroll.state.userTariffs.filter { $0.id.hasPrefix("demo-") }.count, 2)
        loader.clear()
        XCTAssertTrue(payroll.state.userTariffs.isEmpty)
    }
}
