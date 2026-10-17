import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class FuelCostModelTests: XCTestCase {
    private func settings(_ prices: [(String, Int)], consumption: Decimal? = 3) -> FuelSettings {
        FuelSettings(entries: prices.map { FuelPriceEntry(day: $0.0, pricePerUnit: Money($0.1), type: .gasoline) },
                     consumptionPer100Km: consumption)
    }

    func testUsesLatestPriceOnOrBeforeDay() {
        let model = FuelCostModel(settings: settings([("2026-09-01", 40), ("2026-10-01", 45)]), vehicleType: "motorcycle",
                                  fallbackCostPerKm: Money(2))
        XCTAssertEqual(model.price(on: "2026-09-15")?.pricePerUnit, Money(40))
        XCTAssertEqual(model.price(on: "2026-10-05")?.pricePerUnit, Money(45))
        // 100 km × 3 L/100 km × 45 = 135
        XCTAssertEqual(model.cost(km: 100, on: "2026-10-05"), Money(135))
    }

    func testBeforeFirstEntryUsesEarliestPrice() {
        let model = FuelCostModel(settings: settings([("2026-10-01", 45)]), vehicleType: nil, fallbackCostPerKm: Money(2))
        XCTAssertEqual(model.price(on: "2026-01-01")?.pricePerUnit, Money(45))
    }

    func testFallbackWithoutPrice() {
        let model = FuelCostModel(settings: FuelSettings(), vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
        XCTAssertFalse(model.hasPrice)
        XCTAssertEqual(model.cost(km: 10, on: "2026-10-05"), Money(20))
    }

    func testDefaultConsumptionByVehicle() {
        XCTAssertEqual(FuelCostModel.defaultConsumption(vehicleType: "motorcycle"), Decimal(string: "2.5"))
        XCTAssertEqual(FuelCostModel.defaultConsumption(vehicleType: "car"), Decimal(string: "6.5"))
        XCTAssertEqual(FuelCostModel(settings: settings([], consumption: nil), vehicleType: "car",
                                     fallbackCostPerKm: Money(2)).consumption, Decimal(string: "6.5"))
    }

    func testStaleness() {
        let model = FuelCostModel(settings: settings([("2026-10-01", 45)]), vehicleType: nil, fallbackCostPerKm: Money(2))
        XCTAssertFalse(model.isStale(today: "2026-10-08"))
        XCTAssertTrue(model.isStale(today: "2026-10-09"))
        XCTAssertTrue(FuelCostModel(settings: FuelSettings(), vehicleType: nil, fallbackCostPerKm: Money(2)).isStale(today: "2026-10-09"))
    }

    func testPercentChangeBetweenDays() {
        let model = FuelCostModel(settings: settings([("2026-08-01", 40), ("2026-09-20", 44)]), vehicleType: nil,
                                  fallbackCostPerKm: Money(2))
        XCTAssertEqual(model.change(from: "2026-08-10", to: "2026-10-01"), 10)
        XCTAssertNil(FuelCostModel(settings: FuelSettings(), vehicleType: nil, fallbackCostPerKm: Money(2))
            .change(from: "2026-08-10", to: "2026-10-01"))
    }
}
