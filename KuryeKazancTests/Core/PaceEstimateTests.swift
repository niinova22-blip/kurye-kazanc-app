import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class PaceEstimateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_000_000)

    private func entry(daysAgo: Int, hours: Double, packages: Int?, km: Double, platform: String = "migros_hemen") -> EarningEntry {
        let start = now.addingTimeInterval(-Double(daysAgo) * 86_400)
        return EarningEntry(start: start, end: start.addingTimeInterval(hours * 3600), gross: 0, bonus: 0,
                            distanceKm: km, platformCode: platform, packageCount: packages)
    }

    func testUsesOwnRecordsWhenEnough() {
        let entries = (1...5).map { entry(daysAgo: $0, hours: 4, packages: 16, km: 48) }
        let pace = PaceEstimate.estimate(entries: entries, platform: "migros_hemen", now: now)
        XCTAssertFalse(pace.isAssumed)
        XCTAssertEqual(pace.packagesPerHour, 4)
        XCTAssertEqual(pace.kmPerPackage, 3)
        XCTAssertEqual(pace.sampleCount, 5)
    }

    func testFallsBackWhenTooFewRecords() {
        let entries = (1...4).map { entry(daysAgo: $0, hours: 4, packages: 16, km: 48) }
        let pace = PaceEstimate.estimate(entries: entries, platform: "migros_hemen", now: now)
        XCTAssertTrue(pace.isAssumed)
        XCTAssertEqual(pace.packagesPerHour, PaceEstimate.defaultPackagesPerHour)
        XCTAssertEqual(pace.kmPerPackage, PaceEstimate.defaultKmPerPackage)
    }

    func testIgnoresOtherPlatformsOldAndPackageless() {
        var entries = (1...5).map { entry(daysAgo: $0, hours: 4, packages: 16, km: 48) }
        entries.append(entry(daysAgo: 2, hours: 10, packages: 5, km: 5, platform: "getir"))
        entries.append(entry(daysAgo: 70, hours: 10, packages: 5, km: 5))
        entries.append(entry(daysAgo: 3, hours: 10, packages: nil, km: 5))
        XCTAssertEqual(PaceEstimate.estimate(entries: entries, platform: "migros_hemen", now: now).packagesPerHour, 4)
    }

    func testRequiresTenHours() {
        let entries = (1...5).map { entry(daysAgo: $0, hours: 1.5, packages: 6, km: 18) }
        XCTAssertTrue(PaceEstimate.estimate(entries: entries, platform: "migros_hemen", now: now).isAssumed)
    }

    func testMissingKmKeepsDefaultKmPerPackage() {
        let entries = (1...5).map { entry(daysAgo: $0, hours: 4, packages: 16, km: 0) }
        let pace = PaceEstimate.estimate(entries: entries, platform: "migros_hemen", now: now)
        XCTAssertFalse(pace.isAssumed)
        XCTAssertEqual(pace.kmPerPackage, PaceEstimate.defaultKmPerPackage)
    }

    func testCustomDefaults() {
        let pace = PaceEstimate.estimate(entries: [], platform: "getir", now: now, defaults: (3, 2))
        XCTAssertEqual(pace.packagesPerHour, 3)
        XCTAssertEqual(pace.kmPerPackage, 2)
    }
}
