import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class PlatformRuleTests: XCTestCase {
    static func rule(
        _ id: String, platform: String = "trendyolgo", category: RuleCategory = .slotSystem, kind: RuleKind = .slotRequired,
        params: RuleParams = RuleParams(), status: RuleStatus = .verified, checked: String = "2026-10-01",
        validFrom: String? = nil, validTo: String? = nil, model: CourierModel = .any, region: String? = nil,
        version: Int = 1, previousID: String? = nil
    ) -> PlatformRule {
        PlatformRule(
            id: id, platformCode: platform, category: category, kind: kind, params: params, description: id,
            sourceURL: nil, sourceKind: .secondary, publishedOn: nil, lastCheckedOn: checked, validFrom: validFrom,
            validTo: validTo, status: status, confidence: 0.5, courierModel: model, region: region,
            version: version, previousID: previousID
        )
    }

    func testStaleAfterNinetyDaysWithoutCheck() {
        let r = Self.rule("a", checked: "2026-07-01")
        XCTAssertEqual(r.effectiveStatus(today: "2026-09-29"), .verified) // 90 gun
        XCTAssertEqual(r.effectiveStatus(today: "2026-09-30"), .stale)
    }

    func testExpiredRuleIsStale() {
        XCTAssertEqual(Self.rule("a", validTo: "2026-10-09").effectiveStatus(today: "2026-10-10"), .stale)
        XCTAssertEqual(Self.rule("a", validTo: "2026-10-10").effectiveStatus(today: "2026-10-10"), .verified)
    }

    func testAppliesByPlatformModelRegionAndStartDate() {
        let r = Self.rule("a", model: .esnaf, region: "Ankara")
        XCTAssertTrue(r.applies(platform: "trendyolgo", model: .esnaf, region: "Ankara/Sincan", today: "2026-10-10"))
        XCTAssertTrue(r.applies(platform: "trendyolgo", model: .esnaf, region: "Ankara", today: "2026-10-10"))
        XCTAssertFalse(r.applies(platform: "trendyolgo", model: .esnaf, region: "Ankaraxx", today: "2026-10-10"))
        XCTAssertFalse(r.applies(platform: "trendyolgo", model: .esnaf, region: nil, today: "2026-10-10"))
        XCTAssertFalse(r.applies(platform: "trendyolgo", model: .payroll, region: "Ankara", today: "2026-10-10"))
        XCTAssertFalse(r.applies(platform: "getir", model: .esnaf, region: "Ankara", today: "2026-10-10"))
        XCTAssertTrue(Self.rule("g", platform: "*").applies(platform: "getir", model: .esnaf, region: nil, today: "2026-10-10"))
        XCTAssertFalse(Self.rule("f", validFrom: "2026-11-01").applies(platform: "trendyolgo", model: .esnaf, region: nil, today: "2026-10-10"))
    }

    func testUserConfirmationsAndEnforcement() {
        let set = RuleSet(rules: [
            Self.rule("verified"),
            Self.rule("unverified", status: .unverified),
            Self.rule("rejected", status: .unverified),
            Self.rule("confirmed", status: .disputed),
        ])
        let eff = set.effectiveRules(
            platform: "trendyolgo", model: .esnaf, region: nil, today: "2026-10-10",
            confirmations: ["rejected": .notApplicable, "confirmed": .applies]
        )
        let byID = Dictionary(uniqueKeysWithValues: eff.map { ($0.rule.id, $0) })
        XCTAssertNil(byID["rejected"])
        XCTAssertTrue(byID["verified"]!.isEnforced)
        XCTAssertFalse(byID["verified"]!.isUncertain)
        XCTAssertFalse(byID["unverified"]!.isEnforced)
        XCTAssertTrue(byID["unverified"]!.isUncertain)
        XCTAssertTrue(byID["confirmed"]!.isEnforced)
        XCTAssertFalse(byID["confirmed"]!.isUncertain)
    }

    func testUnknownTermIsUncertainEvenIfVerifiedUntilUserConfirms() {
        let set = RuleSet(rules: [Self.rule("u", category: .cancellation, kind: .unknownTerm, status: .verified)])
        let eff = set.effectiveRules(platform: "trendyolgo", model: .esnaf, region: nil, today: "2026-10-10", confirmations: [:])
        XCTAssertTrue(eff[0].isUncertain)
        XCTAssertFalse(eff[0].isEnforced)
        let confirmed = set.effectiveRules(platform: "trendyolgo", model: .esnaf, region: nil, today: "2026-10-10", confirmations: ["u": .applies])
        XCTAssertFalse(confirmed[0].isUncertain)
    }

    func testInfoRuleOutsidePlanningCategoryIsNotUncertain() {
        let set = RuleSet(rules: [Self.rule("p", category: .payout, kind: .info, status: .unverified)])
        let eff = set.effectiveRules(platform: "trendyolgo", model: .esnaf, region: nil, today: "2026-10-10", confirmations: [:])
        XCTAssertFalse(eff[0].isUncertain)
    }

    func testStaleVerifiedRuleIsNotEnforcedAndUncertain() {
        let set = RuleSet(rules: [Self.rule("s", checked: "2026-01-01")])
        let eff = set.effectiveRules(platform: "trendyolgo", model: .esnaf, region: nil, today: "2026-10-10", confirmations: [:])
        XCTAssertEqual(eff[0].status, .stale)
        XCTAssertFalse(eff[0].isEnforced)
        XCTAssertTrue(eff[0].isUncertain)
    }

    func testLatestDropsSupersededVersions() {
        let set = RuleSet(rules: [
            Self.rule("old"),
            Self.rule("new", version: 2, previousID: "old"),
            Self.rule("same", version: 1),
            Self.rule("same", version: 3),
        ])
        XCTAssertEqual(set.latest.map(\.id), ["new", "same"])
        XCTAssertEqual(set.latest.last?.version, 3)
    }

    func testVersionChangesWhenRuleChanges() {
        let a = RuleSet(rules: [Self.rule("a")])
        var b = a
        XCTAssertEqual(a.version, b.version)
        b.rules[0].status = .disputed
        XCTAssertNotEqual(a.version, b.version)
        XCTAssertEqual(RuleSet(rules: [Self.rule("x"), Self.rule("y")]).version, RuleSet(rules: [Self.rule("y"), Self.rule("x")]).version)
    }

    func testDecodesServerRowAndUnknownEnumValues() throws {
        let json = """
        [{"id":"tgo-peak","platform_code":"trendyolgo","category":"minHours","kind":"peakWeeklyHours",
          "params":{"from_hour":18,"to_hour":22,"hours":20},"description":"d","source_url":"https://x",
          "source_kind":"secondary","published_on":"2026-03-01","last_checked_on":"2026-10-10",
          "valid_from":null,"valid_to":null,"status":"unverified","confidence":0.6,"courier_model":"esnaf",
          "region":null,"version":1,"previous_id":null},
         {"id":"n","platform_code":"getir","category":"brandNew","kind":"brandNewKind","params":{},
          "description":"d","source_url":null,"source_kind":"user","published_on":null,"last_checked_on":"2026-10-10",
          "valid_from":null,"valid_to":null,"status":"verified","confidence":1,"courier_model":"any",
          "region":null,"version":1,"previous_id":null}]
        """
        let rules = try JSONDecoder().decode([PlatformRule].self, from: Data(json.utf8))
        XCTAssertEqual(rules[0].params, RuleParams(minutes: nil, hours: 20, fromHour: 18, toHour: 22))
        XCTAssertEqual(rules[0].kind, .peakWeeklyHours)
        XCTAssertEqual(rules[1].kind, .info)
        XCTAssertEqual(rules[1].category, .other)
    }

    func testRuleDayHelpers() {
        XCTAssertEqual(RuleDay.days(from: "2026-02-28", to: "2026-03-01"), 1)
        XCTAssertNil(RuleDay.days(from: "bozuk", to: "2026-03-01"))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let d = cal.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 23, minute: 30))!
        XCTAssertEqual(RuleDay.string(d, calendar: cal), "2026-10-10")
    }
}
