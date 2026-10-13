import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class UnverifiedItemsTests: XCTestCase {
    func testCollectsNeedsVerificationLinesOnce() {
        let engine = TariffFixtures.engine(catalog: TariffCatalog.merged(bundled: TariffFixtures.bundled, remote: [], user: []))
        var input = PayInput(platformCode: "migros_hemen", span: .month, startDay: "2026-10-01", endDay: "2026-10-31")
        input.dayPackages = 900
        input.periodPackages = 900
        input.regionTier = "plus"
        input.seniorityYears = 1
        input.flags = ["woman_employment"]
        guard case let .success(b) = engine.calculate(input) else { return XCTFail() }
        let items = UnverifiedItems.from(b, platformName: "Paket Taxi")
        XCTAssertTrue(items.contains { $0.label.contains("Aylık sabit ücret") })
        XCTAssertTrue(items.contains { $0.label.contains("Kadın istihdam") })
        XCTAssertEqual(Set(items).count, items.count)
        XCTAssertTrue(items.allSatisfy { $0.detail.hasPrefix("Paket Taxi") })
        XCTAssertEqual(UnverifiedItems.merge([items, items]).count, items.count)
    }

    func testVerifiedVersionGivesNothing() {
        var version = TariffFixtures.all[0]
        version.verificationStatus = .verified
        version.items = version.items.map { var i = $0; i.confidence = .verified; return i }
        XCTAssertTrue(UnverifiedItems.from(version: version, platformName: "X").isEmpty)
    }
}
