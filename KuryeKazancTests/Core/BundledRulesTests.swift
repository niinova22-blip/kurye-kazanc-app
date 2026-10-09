import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class BundledRulesTests: XCTestCase {
    func testDecodesWithUniqueIDs() {
        XCTAssertGreaterThanOrEqual(BundledRules.all.count, 40)
        XCTAssertEqual(Set(BundledRules.all.map(\.id)).count, BundledRules.all.count)
    }

    /// Kullanicinin istedigi her baslik (sozlesme, slot secimi/iptali/devri, tarife, hakedis, askı, itiraz, coklu platform)
    /// her ana platform icin ya bilinen bir kuralla ya da `unknownTerm` ile temsil edilir.
    func testEveryMainPlatformCoversRequestedTopics() {
        let topics: [RuleCategory] = [.workModel, .slotSystem, .cancellation, .slotTransfer, .pay, .payout, .performance, .appeal, .exclusivity]
        for platform in ["trendyol_go", "yemeksepeti", "getir", "migros_hemen"] {
            let rules = BundledRules.all.filter { $0.platformCode == platform }
            for topic in topics {
                XCTAssertTrue(rules.contains { $0.category == topic }, "\(platform) icin \(topic) yok")
            }
        }
    }

    func testOnlyOfficialSourcesAreVerifiedAndEveryKnownRuleHasSource() {
        for rule in BundledRules.all {
            if rule.status == .verified { XCTAssertEqual(rule.sourceKind, .official, rule.id) }
            if rule.kind != .unknownTerm { XCTAssertNotNil(rule.sourceURL, rule.id) }
            if rule.kind == .unknownTerm { XCTAssertLessThanOrEqual(rule.confidence, 0.3, rule.id) }
        }
    }

    func testConstraintParamsPresent() {
        for rule in BundledRules.all {
            switch rule.kind {
            case .peakWeeklyHours:
                XCTAssertNotNil(rule.params.fromHour, rule.id)
                XCTAssertNotNil(rule.params.toHour, rule.id)
                XCTAssertNotNil(rule.params.hours, rule.id)
            case .slotGranularityMinutes: XCTAssertNotNil(rule.params.minutes, rule.id)
            case .slotCancelNoticeHours, .minDailyHours: XCTAssertNotNil(rule.params.hours, rule.id)
            default: break
            }
        }
    }
}
