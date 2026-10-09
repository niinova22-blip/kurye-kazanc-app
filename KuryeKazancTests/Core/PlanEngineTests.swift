import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class PlanEngineTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    /// 2026-10-12 Pazartesi
    private var day: Date { at(10, 12, 0) }
    private func at(_ month: Int, _ d: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: hour, minute: minute))!
    }

    /// Son 5 Pazartesi ayni saatlerde kayit.
    private func mondays(_ code: String, from: Int, to: Int, perHour: Double, kmPerHour: Double = 0) -> [EarningEntry] {
        [(10, 5), (9, 28), (9, 21), (9, 14), (9, 7)].map { m, d in
            let hours = Double(to - from)
            return EarningEntry(start: at(m, d, from), end: at(m, d, to), gross: perHour * hours, bonus: 0,
                                distanceKm: kmPerHour * hours, platformCode: code, packageCount: nil)
        }
    }

    private func profile(_ codes: [String], from: Int = 9, to: Int = 23, maxHours: Double = 10) -> WorkProfile {
        var p = WorkProfile()
        p.platforms = codes.map { PlatformProfile(code: $0, isActive: true, courierModel: .esnaf, offeredHourlyRate: nil) }
        p.availability = [1: [TimeRange(startMinute: from * 60, endMinute: to * 60)]]
        p.maxHoursPerDay = maxHours
        return p
    }

    private func engine(_ p: WorkProfile, _ entries: [EarningEntry], rules: [PlatformRule] = []) -> PlanEngine {
        PlanEngine(calendar: calendar, rules: RuleSet(rules: rules), profile: p, entries: entries)
    }

    private func rule(_ id: String, _ platform: String, _ kind: RuleKind, category: RuleCategory = .slotSystem,
                      status: RuleStatus = .verified, checked: String = "2026-10-01", params: RuleParams = RuleParams()) -> PlatformRule {
        PlatformRuleTests.rule(id, platform: platform, category: category, kind: kind, params: params, status: status, checked: checked)
    }

    func testMostProfitablePicksBetterPlatformAndRespectsMaxHours() {
        let entries = mondays("getir", from: 10, to: 14, perHour: 200) + mondays("trendyol_go", from: 18, to: 22, perHour: 300)
        let result = engine(profile(["getir", "trendyol_go"], maxHours: 8), entries).propose(day: day)
        let best = result.proposals.first { $0.kind == .mostProfitable }!
        XCTAssertEqual(best.estimate.hours, 8, accuracy: 0.01)
        XCTAssertTrue(best.blocks.contains { $0.platformCode == "trendyol_go" })
        XCTAssertGreaterThanOrEqual(best.estimate.grossMid, 4 * 300 + 4 * 200 - 0.01)
        XCTAssertTrue(best.isValid, "\(best.issues)")
        for p in result.proposals { XCTAssertTrue(p.isValid, "\(p.kind): \(p.issues)") }
    }

    func testLowRiskUsesOnlyWellSupportedHours() {
        let entries = mondays("getir", from: 10, to: 14, perHour: 200)
        let result = engine(profile(["getir"]), entries).propose(day: day)
        let most = result.proposals.first { $0.kind == .mostProfitable }!
        XCTAssertGreaterThan(most.estimate.hours, 4) // platform geneli tahminle diger saatler de doldurulur
        XCTAssertEqual(most.confidence, .low)
        let low = result.proposals.first { $0.kind == .lowRisk }!
        XCTAssertEqual(low.blocks, [PlanBlock(platformCode: "getir", start: at(10, 12, 10), end: at(10, 12, 14))])
        XCTAssertEqual(low.confidence, .high)
    }

    func testFewerHoursStaysWithinRatio() {
        let entries = mondays("getir", from: 9, to: 23, perHour: 200)
        let result = engine(profile(["getir"], maxHours: 10), entries).propose(day: day)
        let fewer = result.proposals.first { $0.kind == .fewerHours }!
        XCTAssertLessThanOrEqual(fewer.estimate.hours, 6.001)
    }

    func testNoDataGivesNoProposalAndExplains() {
        let result = engine(profile(["getir"]), []).propose(day: day)
        XCTAssertTrue(result.proposals.isEmpty)
        XCTAssertNotNil(result.message)
        XCTAssertNotNil(result.excluded["getir"])
    }

    func testOfferedRateUsedWhenNoHistoryButLowConfidence() {
        var p = profile(["getir"], from: 10, to: 12)
        p.platforms[0].offeredHourlyRate = 150
        let best = engine(p, []).propose(day: day).proposals.first { $0.kind == .mostProfitable }!
        XCTAssertEqual(best.estimate.grossMid, 300, accuracy: 0.01)
        XCTAssertEqual(best.confidence, .low)
        XCTAssertTrue(best.reasons[0].contains("girdiğin"))
    }

    func testEstimateSeparatesVehicleFixedAndTax() {
        var p = profile(["getir"], from: 10, to: 12)
        p.costPerKm = 2
        p.taxRate = 0.2
        p.monthlySocialSecurity = 2600
        let best = engine(p, mondays("getir", from: 10, to: 12, perHour: 200, kmPerHour: 10)).propose(day: day).proposals[0]
        let e = best.estimate
        XCTAssertEqual(e.grossMid, 400, accuracy: 0.01)
        XCTAssertEqual(e.vehicleCost, 40, accuracy: 0.01)
        XCTAssertEqual(e.fixedCost, 100, accuracy: 0.01)
        XCTAssertEqual(e.netMid, 260, accuracy: 0.01)
        XCTAssertEqual(e.tax, 80, accuracy: 0.01)
        XCTAssertEqual(e.afterTaxMid, 180, accuracy: 0.01)
        XCTAssertEqual(e.km, 20, accuracy: 0.01)
        XCTAssertEqual(e.netPerHour!, 130, accuracy: 0.01)
    }

    func testVerifiedSlotRuleExcludesPlatformWithoutReservation() {
        let entries = mondays("yemeksepeti", from: 10, to: 14, perHour: 300)
        let rules = [rule("ys-slot", "yemeksepeti", .slotRequired)]
        let result = engine(profile(["yemeksepeti"]), entries, rules: rules).propose(day: day)
        XCTAssertTrue(result.proposals.isEmpty)
        XCTAssertTrue(result.excluded["yemeksepeti"]!.contains("slot"))
    }

    func testReservedSlotIsAlwaysInPlan() {
        let entries = mondays("yemeksepeti", from: 10, to: 14, perHour: 100) + mondays("getir", from: 9, to: 23, perHour: 300)
        var p = profile(["yemeksepeti", "getir"])
        p.reserved = [ReservedBlock(platformCode: "yemeksepeti", start: at(10, 12, 12), end: at(10, 12, 14))]
        let rules = [rule("ys-slot", "yemeksepeti", .slotRequired)]
        let result = engine(p, entries, rules: rules).propose(day: day)
        for proposal in result.proposals {
            XCTAssertTrue(proposal.blocks.contains { $0.platformCode == "yemeksepeti" && $0.start == at(10, 12, 12) && $0.end == at(10, 12, 14) }, "\(proposal.kind)")
            XCTAssertFalse(proposal.blocks.contains { $0.platformCode == "yemeksepeti" && $0.start != at(10, 12, 12) })
            XCTAssertTrue(proposal.isValid, "\(proposal.kind): \(proposal.issues)")
        }
    }

    func testUnverifiedRuleMakesPlanNotConfirmedUntilUserDecides() {
        let entries = mondays("trendyol_go", from: 18, to: 22, perHour: 300)
        let rules = [rule("tgo-slot", "trendyol_go", .slotRequired, status: .disputed)]
        var p = profile(["trendyol_go"])
        let first = engine(p, entries, rules: rules).propose(day: day).proposals[0]
        XCTAssertTrue(first.isValid) // dogrulanmamis kural kisit olarak uygulanmaz
        XCTAssertFalse(first.isConfirmed)
        XCTAssertEqual(first.uncertainties.map(\.ruleID), ["tgo-slot"])
        XCTAssertTrue(first.notes[0].hasPrefix("Kesin öneri değil"))

        p.ruleConfirmations["tgo-slot"] = .notApplicable
        XCTAssertTrue(engine(p, entries, rules: rules).propose(day: day).proposals[0].isConfirmed)
    }

    func testStaleVerifiedRuleBlocksConfirmedProposal() {
        let entries = mondays("getir", from: 10, to: 14, perHour: 200)
        let rules = [rule("getir-shift", "getir", .shiftBased, checked: "2026-05-01")]
        let proposal = engine(profile(["getir"]), entries, rules: rules).propose(day: day).proposals[0]
        XCTAssertFalse(proposal.isConfirmed)
        XCTAssertEqual(proposal.uncertainties.first?.status, .stale)
    }

    func testExclusiveSameDayUsesSinglePlatform() {
        let entries = mondays("getir", from: 10, to: 14, perHour: 200) + mondays("trendyol_go", from: 18, to: 22, perHour: 300)
        let rules = [rule("ex", "getir", .exclusiveSameDay, category: .exclusivity)]
        let result = engine(profile(["getir", "trendyol_go"]), entries, rules: rules).propose(day: day)
        for proposal in result.proposals {
            XCTAssertEqual(Set(proposal.blocks.map(\.platformCode)).count, 1, "\(proposal.kind)")
        }
    }

    func testBundledRulesNeverGiveConfirmedPlanForMultiPlatform() {
        let entries = mondays("getir", from: 10, to: 14, perHour: 200) + mondays("trendyol_go", from: 18, to: 22, perHour: 300)
        let e = PlanEngine(calendar: calendar, rules: RuleSet(rules: BundledRules.all), profile: profile(["getir", "trendyol_go"]), entries: entries)
        let result = e.propose(day: day)
        XCTAssertFalse(result.proposals.isEmpty)
        for proposal in result.proposals { XCTAssertFalse(proposal.isConfirmed, "\(proposal.kind)") }
        let best = result.proposals[0]
        if best.blocks.contains(where: { $0.platformCode == "trendyol_go" }) {
            XCTAssertTrue(best.notes.contains { $0.contains("18:00–22:00") })
        }
    }

    func testSavedPlanRevalidatesWhenRulesOrProfileChange() {
        let entries = mondays("getir", from: 10, to: 14, perHour: 200)
        var p = profile(["getir"])
        let e = engine(p, entries)
        let proposal = e.propose(day: day).proposals[0]
        let saved = e.save(proposal, day: day)
        XCTAssertEqual(saved.day, "2026-10-12")
        let same = e.check(saved)
        XCTAssertFalse(same.rulesChanged)
        XCTAssertTrue(same.isConfirmed)

        let changed = engine(p, entries, rules: [rule("getir-shift", "getir", .shiftBased)]).check(saved)
        XCTAssertTrue(changed.rulesChanged)
        XCTAssertTrue(changed.issues.contains(.outsideShift("getir")))

        p.platforms[0].isActive = false
        XCTAssertTrue(engine(p, entries).check(saved).issues.contains(.platformInactive("getir")))
    }

    func testNoActivePlatform() {
        let result = engine(WorkProfile(), []).propose(day: day)
        XCTAssertTrue(result.proposals.isEmpty)
        XCTAssertTrue(result.message!.contains("aktif platform"))
    }
}
