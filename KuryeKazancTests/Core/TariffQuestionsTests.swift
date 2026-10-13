import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class TariffQuestionsTests: XCTestCase {
    private let catalog = TariffCatalog.merged(bundled: TariffFixtures.bundled, remote: [], user: [])

    func testPaketTaxiAsksRegionSeniorityAndWomanFlag() {
        let q = TariffQuestions.required(platform: "migros_hemen", catalog: catalog, day: "2026-10-13")
        XCTAssertEqual(q.regionTiers, ["plus", "standard"])
        XCTAssertTrue(q.asksSeniority)
        XCTAssertEqual(q.flags, ["woman_employment"])
        XCTAssertTrue(q.vehicleTypes.isEmpty)
    }

    func testGetirAsksVehicle() {
        let q = TariffQuestions.required(platform: "getir", catalog: catalog, day: "2026-10-13")
        XCTAssertEqual(q.vehicleTypes, ["car", "motorcycle"])
        XCTAssertTrue(q.regionTiers.isEmpty)
    }

    func testUnknownPlatformHasNoQuestions() {
        XCTAssertTrue(TariffQuestions.required(platform: "uber", catalog: catalog, day: "2026-10-13").isEmpty)
    }

    func testDisplayNames() {
        XCTAssertEqual(TariffQuestions.regionName("r1"), "1. bölge")
        XCTAssertEqual(TariffQuestions.regionName("ys_group3"), "3. grup iller")
        XCTAssertEqual(TariffQuestions.flagName("woman_employment"), "Kadın istihdam desteğinden yararlanıyorum")
        XCTAssertEqual(TariffQuestions.vehicleName("motorcycle"), "Motosiklet")
    }
}
