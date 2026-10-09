import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class PlanValidatorTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    /// 2026-10-12 Pazartesi
    private var day: Date { t(0) }
    private func t(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: hour, minute: minute))!
    }
    private func b(_ code: String, _ s: Int, _ sm: Int = 0, e: Int, em: Int = 0) -> PlanBlock {
        PlanBlock(platformCode: code, start: t(s, sm), end: t(e, em))
    }

    private func validator(rules: [PlatformRule] = [], configure: (inout WorkProfile) -> Void = { _ in }) -> PlanValidator {
        var p = WorkProfile()
        p.platforms = ["getir", "trendyol_go", "yemeksepeti"].map {
            PlatformProfile(code: $0, isActive: true, courierModel: .esnaf, offeredHourlyRate: nil)
        }
        p.availability = [1: [TimeRange(startMinute: 9 * 60, endMinute: 23 * 60)]]
        configure(&p)
        return PlanValidator(calendar: calendar, rules: RuleSet(rules: rules), profile: p)
    }

    private func rule(_ id: String, _ platform: String, _ kind: RuleKind, category: RuleCategory = .slotSystem,
                      status: RuleStatus = .verified, params: RuleParams = RuleParams()) -> PlatformRule {
        PlatformRuleTests.rule(id, platform: platform, category: category, kind: kind, params: params, status: status)
    }

    func testValidPlan() {
        XCTAssertEqual(validator().validate([b("getir", 10, e: 12), b("trendyol_go", 12, 20, e: 14)], day: day), [])
    }

    func testOverlapAndSwitchBuffer() {
        let v = validator()
        XCTAssertEqual(v.validate([b("getir", 10, e: 12), b("trendyol_go", 11, e: 13)], day: day), [.overlap("getir", "trendyol_go")])
        XCTAssertEqual(v.validate([b("getir", 10, e: 12), b("trendyol_go", 12, 10, e: 13)], day: day),
                       [.switchTooShort(from: "getir", to: "trendyol_go", minutes: 20)])
        XCTAssertEqual(v.validate([b("getir", 10, e: 12), b("getir", 12, e: 13)], day: day), [])
    }

    func testInactiveUnknownAndOutsideAvailability() {
        let v = validator { $0.platforms[0].isActive = false }
        XCTAssertEqual(v.validate([b("getir", 10, e: 11)], day: day), [.platformInactive("getir")])
        XCTAssertEqual(v.validate([b("migros_hemen", 10, e: 11)], day: day), [.platformInactive("migros_hemen")])
        XCTAssertEqual(validator().validate([b("trendyol_go", 7, e: 10)], day: day), [.outsideAvailability("trendyol_go")])
    }

    func testMaxHours() {
        let v = validator { $0.maxHoursPerDay = 3 }
        XCTAssertEqual(v.validate([b("getir", 10, e: 14)], day: day), [.exceedsMaxHours(4, max: 3)])
    }

    func testEnforcedSlotShiftGranularityAndMinDaily() {
        let rules = [
            rule("s", "yemeksepeti", .slotRequired),
            rule("v", "getir", .shiftBased),
            rule("g", "trendyol_go", .slotGranularityMinutes, params: RuleParams(minutes: 30)),
            rule("m", "trendyol_go", .minDailyHours, category: .minHours, params: RuleParams(hours: 3)),
        ]
        let v = validator(rules: rules)
        XCTAssertEqual(v.validate([b("yemeksepeti", 10, e: 11)], day: day), [.needsReservation("yemeksepeti")])
        XCTAssertEqual(v.validate([b("getir", 10, e: 11)], day: day), [.outsideShift("getir")])
        XCTAssertEqual(v.validate([b("trendyol_go", 10, 10, e: 13, em: 10)], day: day), [.offGranularity("trendyol_go", minutes: 30)])
        XCTAssertEqual(v.validate([b("trendyol_go", 10, e: 12)], day: day), [.belowMinDaily("trendyol_go", hours: 3)])

        let withSlot = validator(rules: rules) {
            $0.reserved = [ReservedBlock(platformCode: "yemeksepeti", start: self.t(10), end: self.t(11)),
                           ReservedBlock(platformCode: "yemeksepeti", start: self.t(11), end: self.t(12))]
        }
        XCTAssertEqual(withSlot.validate([b("yemeksepeti", 10, e: 12)], day: day), [])
    }

    func testUnverifiedRulesAreNotEnforced() {
        let v = validator(rules: [rule("s", "yemeksepeti", .slotRequired, status: .unverified)])
        XCTAssertEqual(v.validate([b("yemeksepeti", 10, e: 11)], day: day), [])
        XCTAssertEqual(v.uncertainties([b("yemeksepeti", 10, e: 11)], day: day).map(\.ruleID), ["s"])
    }

    func testReservedNotPlannedWithCancelNoticeAndOverlap() {
        let rules = [rule("c", "trendyol_go", .slotCancelNoticeHours, category: .cancellation, status: .unverified, params: RuleParams(hours: 10))]
        let v = validator(rules: rules) {
            $0.reserved = [ReservedBlock(platformCode: "trendyol_go", start: self.t(18), end: self.t(20)),
                           ReservedBlock(platformCode: "getir", start: self.t(19), end: self.t(21))]
        }
        let issues = v.validate([b("getir", 19, e: 21)], day: day)
        XCTAssertTrue(issues.contains(.reservedNotPlanned("trendyol_go", cancelNoticeHours: 10)))
        XCTAssertTrue(issues.contains(.reservedOverlap))
        let msg = PlanIssue.reservedNotPlanned("trendyol_go", cancelNoticeHours: 10).message { $0 }
        XCTAssertTrue(msg.contains("10 sa önce"))
        XCTAssertTrue(PlanIssue.reservedNotPlanned("x", cancelNoticeHours: nil).message { $0 }.contains("bilmiyoruz"))
    }

    func testExclusivityUncertaintyOnlyForMultiPlatformPlans() {
        let rules = [rule("ex", "getir", .unknownTerm, category: .exclusivity, status: .unverified)]
        let v = validator(rules: rules)
        XCTAssertEqual(v.uncertainties([b("getir", 10, e: 11)], day: day), [])
        XCTAssertEqual(v.uncertainties([b("getir", 10, e: 11), b("trendyol_go", 12, e: 13)], day: day).map(\.ruleID), ["ex"])
    }

    func testEnforcedExclusiveSameDay() {
        let v = validator(rules: [rule("ex", "getir", .exclusiveSameDay, category: .exclusivity)])
        XCTAssertEqual(v.validate([b("getir", 10, e: 11), b("trendyol_go", 12, e: 13)], day: day), [.exclusiveConflict("getir")])
    }

    func testWeeklyPeakNote() {
        let peak = rule("p", "trendyol_go", .peakWeeklyHours, category: .minHours, status: .disputed,
                        params: RuleParams(hours: 20, fromHour: 18, toHour: 22))
        let notes = validator(rules: [peak]).weeklyNotes([b("trendyol_go", 17, e: 21)], day: day) { _ in "Trendyol GO" }
        XCTAssertEqual(notes, ["Trendyol GO: haftalık 18:00–22:00 arası 20 sa yükümlülük (kaynaklar çelişkili). Bu planda 3 sa."])
    }

    func testRegionAndModelFiltering() {
        var r = rule("s", "yemeksepeti", .slotRequired)
        r.region = "İstanbul"
        let v = validator(rules: [r]) { $0.region = "Ankara/Sincan" }
        XCTAssertEqual(v.validate([b("yemeksepeti", 10, e: 11)], day: day), [])
        var m = rule("s2", "yemeksepeti", .slotRequired)
        m.courierModel = .payroll
        XCTAssertEqual(validator(rules: [m]).validate([b("yemeksepeti", 10, e: 11)], day: day), [])
    }
}
