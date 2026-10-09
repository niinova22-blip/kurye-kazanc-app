import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class CommunityModelsTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testCellsDecode() throws {
        let json = #"[{"weekday":5,"hour":20,"per_hour":410.5,"couriers":8,"shifts":12},{"weekday":1,"hour":0,"per_hour":300,"couriers":5,"shifts":5}]"#
        let cells = try decode([CommunityCell].self, json)
        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(cells[0], CommunityCell(weekday: 5, hour: 20, perHour: 410.5, couriers: 8, shifts: 12))
        XCTAssertEqual(cells[1].perHour, 300)
    }

    func testEmptyCells() throws {
        XCTAssertTrue(try decode([CommunityCell].self, "[]").isEmpty)
    }

    func testSummaryDecodeFull() throws {
        let json = #"""
        {"per_hour":355.25,"couriers":9,
         "platforms":[{"code":"getir","per_hour":380,"per_package":41.5,"couriers":6},{"code":"uber","per_hour":300.1,"per_package":null,"couriers":5}],
         "best":[{"weekday":5,"hour":20,"per_hour":410,"couriers":7,"shifts":9}]}
        """#
        let s = try decode(CommunitySummary.self, json)
        XCTAssertEqual(s.perHour, 355.25)
        XCTAssertEqual(s.couriers, 9)
        XCTAssertEqual(s.platforms.count, 2)
        XCTAssertEqual(s.platforms[0].code, "getir")
        XCTAssertEqual(s.platforms[0].perPackage, 41.5)
        XCTAssertNil(s.platforms[1].perPackage)
        XCTAssertEqual(s.best.first?.hour, 20)
        XCTAssertFalse(s.isInsufficient)
    }

    func testSummaryMissingPerHour() throws {
        let s = try decode(CommunitySummary.self, #"{"platforms":[],"best":[]}"#)
        XCTAssertNil(s.perHour)
        XCTAssertNil(s.couriers)
        XCTAssertTrue(s.isInsufficient)
    }

    func testSummaryMissingArraysDefaultEmpty() throws {
        let s = try decode(CommunitySummary.self, "{}")
        XCTAssertTrue(s.platforms.isEmpty)
        XCTAssertTrue(s.best.isEmpty)
    }

    func testOwnPerHourUsesGrossPlusBonusOverMergedHours() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let a = EarningEntry(start: start, end: start.addingTimeInterval(3600), gross: 300, bonus: 50,
                             distanceKm: 10, platformCode: nil, packageCount: nil)
        let b = EarningEntry(start: start.addingTimeInterval(7200), end: start.addingTimeInterval(10800), gross: 250, bonus: 0,
                             distanceKm: 5, platformCode: nil, packageCount: nil)
        XCTAssertEqual(CommunityComparison.ownPerHour([a, b])!, 300, accuracy: 0.001)
        XCTAssertNil(CommunityComparison.ownPerHour([]))
    }

    func testPercentDifference() {
        XCTAssertEqual(CommunityComparison.percentDifference(own: 440, community: 400)!, 10, accuracy: 0.001)
        XCTAssertEqual(CommunityComparison.percentDifference(own: 300, community: 400)!, -25, accuracy: 0.001)
        XCTAssertNil(CommunityComparison.percentDifference(own: 300, community: 0))
    }
}
