import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class RegionRefreshPolicyTests: XCTestCase {
    private let policy = RegionRefreshPolicy()
    private let besiktas = GeoPoint(latitude: 41.0422, longitude: 29.0083)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func moved(_ meters: Double) -> GeoPoint {
        // Enlemde 1 derece ~ 111 km
        GeoPoint(latitude: besiktas.latitude + meters / 111_000, longitude: besiktas.longitude)
    }

    func testFirstFixAlwaysResolves() {
        XCTAssertTrue(policy.shouldResolve(lastPoint: nil, lastAt: nil, point: besiktas, now: start))
    }

    func testSmallMoveDoesNotResolve() {
        XCTAssertFalse(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: moved(200),
                                            now: start.addingTimeInterval(300)))
    }

    func testLargeMoveResolvesAfterMinimumGap() {
        XCTAssertTrue(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: moved(800),
                                           now: start.addingTimeInterval(90)))
    }

    func testLargeMoveWaitsForMinimumGap() {
        // Geocoder kisitlamasi: dakikada birden sik sorulmaz
        XCTAssertFalse(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: moved(2_000),
                                            now: start.addingTimeInterval(20)))
    }

    func testStationaryLongTimeRefreshesSlowly() {
        // Bolge sinirinda bekleyen kurye: 10 dk'da bir yeniden bakilir (kucuk hareket yeter)
        XCTAssertTrue(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: moved(150),
                                           now: start.addingTimeInterval(601)))
        XCTAssertFalse(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: besiktas,
                                            now: start.addingTimeInterval(601)))
    }

    func testUnresolvedPlaceRetriesEveryMinute() {
        XCTAssertFalse(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: besiktas,
                                            now: start.addingTimeInterval(30), hasPlace: false))
        XCTAssertTrue(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: besiktas,
                                           now: start.addingTimeInterval(61), hasPlace: false))
    }

    func testClockMovedBackResolves() {
        XCTAssertTrue(policy.shouldResolve(lastPoint: besiktas, lastAt: start, point: moved(800),
                                           now: start.addingTimeInterval(-120)))
    }

    func testRegionMoveSuggestsNewPaketTaxiTier() {
        // 1. bolgede (Besiktas) baslayip 2.–3. bolgeye (Bagcilar) gecince tarife bolgesi degisir
        let profile = CourierTariffProfile(platformCode: "pt_restoran", regionTier: "r1", seniorityYears: nil,
                                           vehicleType: nil, flags: [])
        let suggestion = RegionResolver.suggest(province: "İstanbul", district: "Bağcılar", profile: profile)
        XCTAssertEqual(suggestion?.regionTier, "r23")
        XCTAssertEqual(suggestion?.changed, true)
    }
}
