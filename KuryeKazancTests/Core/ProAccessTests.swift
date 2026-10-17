import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ProAccessTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func tx(_ product: ProProduct, expires: TimeInterval? = nil, revoked: Bool = false) -> ProTransactionInfo {
        ProTransactionInfo(productID: product.id, expirationDate: expires.map { now.addingTimeInterval($0) },
                           revocationDate: revoked ? now : nil)
    }

    func testNoTransactionsIsFree() {
        let entitlement = ProEntitlement.resolve([], now: now)
        XCTAssertEqual(entitlement, .none)
        XCTAssertFalse(entitlement.isActive(now: now))
    }

    func testActiveMonthly() {
        let entitlement = ProEntitlement.resolve([tx(.monthly, expires: 3600)], now: now)
        XCTAssertEqual(entitlement.product, .monthly)
        XCTAssertTrue(entitlement.isActive(now: now))
        XCTAssertFalse(entitlement.isActive(now: now.addingTimeInterval(7200)))
    }

    func testExpiredAndRevokedAreIgnored() {
        let entitlement = ProEntitlement.resolve([tx(.monthly, expires: -10), tx(.yearly, expires: 9999, revoked: true)],
                                                 now: now)
        XCTAssertFalse(entitlement.isActive(now: now))
    }

    func testLatestSubscriptionWins() {
        let entitlement = ProEntitlement.resolve([tx(.monthly, expires: 100), tx(.yearly, expires: 50_000)], now: now)
        XCTAssertEqual(entitlement.product, .yearly)
    }

    func testLifetimeWinsAndNeverExpires() {
        let entitlement = ProEntitlement.resolve([tx(.yearly, expires: 50_000), tx(.lifetime)], now: now)
        XCTAssertEqual(entitlement.product, .lifetime)
        XCTAssertTrue(entitlement.isActive(now: now.addingTimeInterval(10 * 365 * 86_400)))
    }

    func testRevokedLifetimeIsIgnored() {
        XCTAssertFalse(ProEntitlement.resolve([tx(.lifetime, revoked: true)], now: now).isActive(now: now))
    }

    func testUnknownProductIgnored() {
        let unknown = ProTransactionInfo(productID: "com.other.app.pro", expirationDate: nil, revocationDate: nil)
        XCTAssertEqual(ProEntitlement.resolve([unknown], now: now), .none)
    }

    func testCodableRoundTrip() throws {
        let entitlement = ProEntitlement(product: .yearly, expiresAt: now)
        let data = try JSONEncoder().encode(entitlement)
        XCTAssertEqual(try JSONDecoder().decode(ProEntitlement.self, from: data), entitlement)
    }

    func testDisplayOrderCoversAllProducts() {
        XCTAssertEqual(Set(ProProduct.displayOrder), Set(ProProduct.allCases))
        XCTAssertEqual(ProProduct.allCases.filter { !$0.isSubscription }, [.lifetime])
    }

    // MARK: - 10 gunluk deneme

    private func trial(startedAgo days: Double, revoked: Bool = false) -> ProTransactionInfo {
        ProTransactionInfo(productID: ProTrial.productID, expirationDate: nil, revocationDate: revoked ? now : nil,
                           purchaseDate: now.addingTimeInterval(-days * 86_400))
    }

    func testTrialProductIsNotPro() {
        XCTAssertEqual(ProEntitlement.resolve([trial(startedAgo: 1)], now: now), .none)
    }

    func testTrialStartIsEarliestTrialPurchase() {
        let start = ProTrial.startDate(in: [trial(startedAgo: 2), trial(startedAgo: 5, revoked: true), tx(.monthly, expires: 10)])
        XCTAssertEqual(start, now.addingTimeInterval(-5 * 86_400))
        XCTAssertNil(ProTrial.startDate(in: [tx(.lifetime)]))
    }

    func testNoTrialMeansTrialAvailable() {
        XCTAssertEqual(ProAccess.resolve(entitlement: .none, trialStart: nil, now: now), .trialAvailable)
        XCTAssertFalse(ProAccess.trialAvailable.hasAccess)
    }

    func testTrialLastsTenDays() {
        let start = now.addingTimeInterval(-9.5 * 86_400)
        let access = ProAccess.resolve(entitlement: .none, trialStart: start, now: now)
        XCTAssertEqual(access, .trial(endsAt: start.addingTimeInterval(10 * 86_400)))
        XCTAssertTrue(access.hasAccess)
        XCTAssertEqual(access.trialDaysLeft(now: now), 1)
        XCTAssertEqual(ProAccess.resolve(entitlement: .none, trialStart: now, now: now).trialDaysLeft(now: now), 10)
    }

    func testTrialEndsAfterTenDays() {
        let access = ProAccess.resolve(entitlement: .none, trialStart: now.addingTimeInterval(-10 * 86_400), now: now)
        XCTAssertEqual(access, .expired)
        XCTAssertFalse(access.hasAccess)
        XCTAssertNil(access.trialDaysLeft(now: now))
    }

    func testPaidWinsOverTrial() {
        let paid = ProEntitlement(product: .yearly, expiresAt: now.addingTimeInterval(3600))
        XCTAssertEqual(ProAccess.resolve(entitlement: paid, trialStart: now.addingTimeInterval(-30 * 86_400), now: now), .pro)
        XCTAssertEqual(ProAccess.resolve(entitlement: paid, trialStart: nil, now: now), .pro)
    }
}
