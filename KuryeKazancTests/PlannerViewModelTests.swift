import XCTest
@testable import KuryeKazanc

@MainActor
final class PlannerViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    override func setUp() {
        super.setUp()
        suiteName = "PlannerViewModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// 2026-10-12 Pazartesi
    private func at(_ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var entries: [EarningEntry] {
        [(10, 5), (9, 28), (9, 21), (9, 14), (9, 7)].map { m, d in
            EarningEntry(start: at(m, d, 10), end: at(m, d, 14), gross: 800, bonus: 0, distanceKm: 40,
                         platformCode: "getir", packageCount: 10)
        }
    }

    private func makeModel(rules: [PlatformRule] = []) -> PlannerViewModel {
        PlannerViewModel(rules: RuleSet(rules: rules), entries: entries, defaults: defaults, calendar: calendar, day: at(10, 12, 9))
    }

    func testInitialProfileActivatesRecentlyUsedPlatformsAndUsesSettings() {
        defaults.set(3.0, forKey: AppPreferences.costPerKmKey)
        defaults.set(1500.0, forKey: AppPreferences.dailyGoalKey)
        let model = makeModel()
        XCTAssertEqual(model.profile.activePlatformCodes, ["getir"])
        XCTAssertEqual(model.profile.costPerKm, 3)
        XCTAssertEqual(model.profile.dailyNetTarget, 1500)
        XCTAssertEqual(model.profile.availability.count, 7)
        XCTAssertFalse(model.profile.platforms.contains { $0.code == "other" })
    }

    func testPlanProducesProposalAndChoosingPersistsAndRevalidates() {
        let model = makeModel()
        model.plan()
        let proposal: PlanProposal = try! XCTUnwrap(model.result?.proposals.first)
        XCTAssertTrue(proposal.blocks.allSatisfy { $0.platformCode == "getir" })

        model.choose(proposal)
        XCTAssertTrue(model.savedPlanIsForDay)
        XCTAssertEqual(model.savedPlanCheck?.isConfirmed, true)

        // Yeni oturum: kayitli plan okunur; kural degisince yeniden denetlenir
        let rule: PlatformRule = PlatformRule(
            id: "getir-shift", platformCode: "getir", category: .slotSystem, kind: .shiftBased, params: RuleParams(),
            description: "vardiya", sourceURL: nil, sourceKind: .official, publishedOn: nil, lastCheckedOn: "2026-10-10",
            validFrom: nil, validTo: nil, status: .verified, confidence: 1, courierModel: .any, region: nil, version: 1, previousID: nil
        )
        let next = makeModel(rules: [rule])
        next.checkSavedPlan()
        XCTAssertEqual(next.savedPlanCheck?.rulesChanged, true)
        XCTAssertEqual(next.savedPlanCheck?.issues, [.outsideShift("getir")])

        next.clearSavedPlan()
        XCTAssertNil(WorkProfileStore.loadPlan(defaults))
    }

    func testConfirmationIsPersistedAndRemovesUncertainty() {
        let unknown: PlatformRule = PlatformRule(
            id: "getir-model", platformCode: "getir", category: .workModel, kind: .unknownTerm, params: RuleParams(),
            description: "bilinmiyor", sourceURL: nil, sourceKind: .secondary, publishedOn: nil, lastCheckedOn: "2026-10-10",
            validFrom: nil, validTo: nil, status: .unverified, confidence: 0, courierModel: .any, region: nil, version: 1, previousID: nil
        )
        let model = makeModel(rules: [unknown])
        model.plan()
        XCTAssertEqual(model.result?.proposals.first?.isConfirmed, false)

        model.setConfirmation(.applies, ruleID: "getir-model")
        XCTAssertEqual(model.result?.proposals.first?.isConfirmed, true)
        XCTAssertEqual(WorkProfileStore.load(defaults)?.ruleConfirmations["getir-model"], .applies)

        model.setConfirmation(nil, ruleID: "getir-model")
        XCTAssertEqual(model.result?.proposals.first?.isConfirmed, false)
    }

    func testBundledRulesProduceNonConfirmedPlanWithSources() {
        let model = makeModel(rules: BundledRules.all)
        model.plan()
        let proposal: PlanProposal? = model.result?.proposals.first
        XCTAssertNotNil(proposal)
        XCTAssertEqual(proposal?.isConfirmed, false)
        XCTAssertTrue(proposal?.uncertainties.contains { $0.ruleID == "getir-shift" } ?? false)
    }
}
