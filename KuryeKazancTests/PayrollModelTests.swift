import XCTest
import SwiftData
@testable import KuryeKazanc

/// Tarife istemcisi: sunucu cevabi ya da hata (nil) dondurur.
private final class FakeTariffClient: SupabaseServing {
    var versions: [TariffVersion]?
    var events: [TariffChangeEvent] = []
    private(set) var eventPlatforms: [String] = []
    var session: AuthSession? { nil }

    init(versions: [TariffVersion]?) { self.versions = versions }

    func fetchTariffVersions() async -> [TariffVersion]? { versions }
    func fetchTariffEvents(platform: String) async -> [TariffChangeEvent]? {
        eventPlatforms.append(platform)
        return events.filter { $0.platformCode == platform }
    }
    func submitShift(_ p: ShiftPayload) async -> OutboxResult { .ok }
    func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult { .ok }
    func fetchTemplates() async -> [OCRTemplate]? { nil }
    func communityHeatmap(province: String, district: String) async -> [CommunityCell]? { nil }
    func communitySummary(province: String, district: String) async -> CommunitySummary? { nil }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession { throw SupabaseError.network }
    func uploadBackup(_ payload: Data) async throws {}
    func downloadBackup() async throws -> Data? { nil }
    func deleteMyData() async throws {}
    func signOut() {}
}

@MainActor
final class PayrollModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var defaults: UserDefaults!
    private var suiteName: String = ""
    private let now: Date = {
        var c = Calendar.current
        c.timeZone = .current
        return c.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 18))!
    }()

    override func setUp() async throws {
        container = ModelContainerFactory.make(inMemory: true)
        DataSeeder.seedPlatformsIfNeeded(in: context)
        suiteName = "PayrollModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        container = nil
    }

    private func makeModel(client: (any SupabaseServing)? = nil) -> PayrollModel {
        let tariffs = TariffSyncService(client: client, defaults: defaults, fileURL: nil, clock: { self.now })
        return PayrollModel(store: PayrollStore(fileURL: nil), tariffs: tariffs, clock: { self.now })
    }

    /// 1.12.1: ayni gunun vardiyalari gun toplamiyla (2.–3. bolge, 10 + 8 + 7 = 25 paket -> 24–27 primi 760 TL);
    /// bir vardiya silinince kalanlar yeniden paylastirilir ve kazanc kayitlari guncellenir.
    func testShiftsOnSameDayShareDailyTier() throws {
        let model = makeModel()
        model.chooseFirm("pt_migros", regionTier: "r23", seniorityYears: nil, vehicleType: nil, flags: [])
        var logs: [WorkLog] = []
        for packages in [10, 8, 7] {
            var input = try XCTUnwrap(model.baseInput(day: "2026-10-07"))
            input.dayPackages = packages
            input.hours = 2
            logs.append(try XCTUnwrap(model.save(input, method: .shift, context: context)))
        }
        let total: Money = model.logs.map(\.gross).sum()
        XCTAssertEqual(total, Money(760))
        let recordSum: Double = try context.fetch(FetchDescriptor<EarningRecord>()).map { $0.grossEarning + $0.bonus }.reduce(0, +)
        XCTAssertEqual(recordSum, 760, accuracy: 0.001)

        // Ilk vardiya silinir: 8 + 7 = 15 paket, 16 altinda prim yok
        model.delete(logs[0], context: context)
        XCTAssertEqual(model.logs.map(\.gross).sum(), .zero)
        let remaining: Double = try context.fetch(FetchDescriptor<EarningRecord>()).map { $0.grossEarning + $0.bonus }.reduce(0, +)
        XCTAssertEqual(remaining, 0, accuracy: 0.001)
    }

    func testSavingDailyLogCreatesLinkedEarningRecord() throws {
        let model = makeModel()
        model.select(platform: "yemeksepeti")
        var input = try XCTUnwrap(model.baseInput(day: "2026-10-07")) // Carsamba
        input.dayPackages = 20
        input.hours = 8
        input.tips = Money(50)
        let log = try XCTUnwrap(model.save(input, method: .shift, context: context))
        // 20 × 59 TL (Pzt–Per 12:00–14:59) + gunluk 20–22 paket bonusu 150 TL
        XCTAssertEqual(log.gross, Money(1_330))
        let records = try context.fetch(FetchDescriptor<EarningRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, log.earningRecordID)
        XCTAssertEqual(records.first?.platform?.code, "yemeksepeti")
        XCTAssertEqual(records.first?.bonus ?? 0, 150, accuracy: 0.001)
        XCTAssertEqual(records.first?.grossEarning ?? 0, 1230, accuracy: 0.001) // 1.180 paket + 50 bahsis
        XCTAssertEqual(records.first?.packageCount, 20)

        model.delete(log, context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<EarningRecord>()).isEmpty)
        XCTAssertTrue(model.logs.isEmpty)
    }

    func testPeriodLogDoesNotCreateEarningRecordAndOverlapIsRejected() throws {
        let model = makeModel()
        model.select(platform: "yemeksepeti")
        var daily = try XCTUnwrap(model.baseInput(day: "2026-10-06"))
        daily.dayPackages = 10
        XCTAssertNotNil(model.save(daily, method: .detailed, context: context))
        var period = try XCTUnwrap(model.baseInput(day: "2026-10-05", span: .week, end: "2026-10-11"))
        period.dayPackages = 100
        XCTAssertNil(model.save(period, method: .period, context: context))
        XCTAssertNotNil(model.lastError)
        XCTAssertEqual(try context.fetch(FetchDescriptor<EarningRecord>()).count, 1)
    }

    func testPlatformSwitchKeepsLogsAndUsesOnlySelectedTariff() throws {
        let model = makeModel()
        model.select(platform: "pt_migros")
        var migros = try XCTUnwrap(model.baseInput(day: "2026-10-06"))
        migros.dayPackages = 20
        migros.hours = 9
        let saved = try XCTUnwrap(model.save(migros, method: .manual, context: nil))
        model.select(platform: "migros_hemen")
        XCTAssertEqual(model.currentVersion()?.platformCode, "migros_hemen")
        XCTAssertEqual(model.state.logs.first { $0.id == saved.id }?.result.tariffVersionID, "pt_migros-esnaf-v1")
        let input = try XCTUnwrap(model.baseInput(day: "2026-10-07"))
        XCTAssertEqual(input.platformCode, "migros_hemen")
    }

    func testTariffRefreshFailureKeepsLastKnownTariff() async throws {
        var remote = BundledTariffs.all.first { $0.id == "yemeksepeti-esnaf-v3" }!
        remote.id = "tgo-remote-v2"
        remote.versionNumber = 9
        remote.origin = .remote
        let client = FakeTariffClient(versions: [remote])
        let model = makeModel(client: client)
        model.select(platform: "yemeksepeti")
        await model.tariffs.refreshIfNeeded(force: true)
        XCTAssertEqual(model.currentVersion()?.id, "tgo-remote-v2")

        client.versions = nil
        await model.tariffs.refreshIfNeeded(force: true)
        XCTAssertTrue(model.tariffs.lastAttemptFailed)
        XCTAssertEqual(model.currentVersion()?.id, "tgo-remote-v2", "hata eski tarifeyi silmez")
        client.versions = []
        await model.tariffs.refreshIfNeeded(force: true)
        XCTAssertEqual(model.currentVersion()?.id, "tgo-remote-v2", "bos yanit eldeki tarifeyi silmez")
    }

    func testCalculationWorksWithoutServer() throws {
        let model = makeModel(client: nil)
        model.select(platform: "yemeksepeti")
        var input = try XCTUnwrap(model.baseInput(day: "2026-10-07"))
        input.dayPackages = 4
        guard case let .success(breakdown) = model.calculate(input) else { return XCTFail("gomulu tarifeyle hesaplanmali") }
        XCTAssertEqual(breakdown.gross, Money(236)) // 2026 tarifesi: 4 × 59 TL (gunduz paket)
        XCTAssertEqual(breakdown.tariffOrigin, .bundled)
    }

    func testNoticesOnlyForActivePlatform() async throws {
        let client = FakeTariffClient(versions: nil)
        let change = TariffItemChange(kind: .changed, itemKey: "hourly", label: "Saatlik", oldAmount: Money(50), newAmount: Money(55))
        client.events = [
            TariffChangeEvent(id: "1", platformCode: "yemeksepeti", tariffVersionID: "v", kind: "published", effectiveFrom: "2026-11-01",
                              verification: "needs_verification", sourceType: "news", sourceURL: nil, changes: [change], createdAt: "2026-10-07"),
            TariffChangeEvent(id: "2", platformCode: "pt_migros", tariffVersionID: "v", kind: "published", effectiveFrom: "2026-11-01",
                              verification: "verified", sourceType: "official_announcement", sourceURL: nil, changes: [change], createdAt: "2026-10-07"),
        ]
        let model = makeModel(client: client)
        model.select(platform: "yemeksepeti")
        await model.refreshNotices()
        XCTAssertEqual(client.eventPlatforms, ["yemeksepeti"])
        XCTAssertEqual(model.state.notices.map(\.id), ["1"])
        XCTAssertTrue(model.state.notices[0].title.contains("doğrulama bekliyor"))
        XCTAssertEqual(model.unreadNoticeCount, 1)
        await model.refreshNotices()
        XCTAssertEqual(model.state.notices.count, 1, "ayni olay ikinci kez bildirilmez")
        model.markNoticesRead()
        XCTAssertEqual(model.unreadNoticeCount, 0)
    }

    func testDashboardUsesMonthExpenses() throws {
        let model = makeModel()
        model.select(platform: "yemeksepeti")
        var input = try XCTUnwrap(model.baseInput(day: "2026-10-07"))
        input.dayPackages = 10
        input.hours = 5
        _ = model.save(input, method: .manual, context: nil)
        let expenses = [DatedExpense(day: "2026-10-07", category: .fuel, amount: Money(145)),
                        DatedExpense(day: "2026-09-30", category: .fuel, amount: Money(999))]
        let dashboard = try XCTUnwrap(model.dashboard(expenses: expenses, month: now))
        XCTAssertEqual(dashboard.estimatedGross, Money(590)) // 10 × 59 TL
        XCTAssertEqual(dashboard.expenses, Money(145))
        XCTAssertEqual(dashboard.estimatedNet, Money(445))
        XCTAssertEqual(dashboard.netPerHour, Money(89))
    }

    // MARK: - 1.7

    func testChooseFirmStoresProfileAndGoalPlan() throws {
        let model = makeModel()
        model.chooseFirm("migros_hemen", regionTier: "r1", seniorityYears: 1, vehicleType: nil, flags: ["woman_employment"])
        model.setGoal(GoalSpec(amount: Money(100_000), period: .month))
        model.setConsumption(3)
        model.addFuelPrice(Money(45), type: .gasoline, on: now)
        XCTAssertEqual(model.tariffProfile?.platformCode, "migros_hemen")
        XCTAssertEqual(model.tariffProfile?.flags, ["woman_employment"])
        let result = try XCTUnwrap(model.goalPlan(entries: [], fallbackCostPerKm: 2))
        guard case let .success(plan) = result else { return XCTFail("\(result)") }
        XCTAssertTrue(plan.pace.isAssumed)
        XCTAssertGreaterThan(plan.monthlyPackages, 0)
        XCTAssertFalse(plan.usesFuelFallback)
    }

    func testGoalPlanNilWithoutFirmOrGoal() {
        let model = makeModel()
        XCTAssertNil(model.goalPlan(entries: [], fallbackCostPerKm: 2))
        model.chooseFirm("yemeksepeti", regionTier: "ys_istanbul", seniorityYears: nil, vehicleType: nil, flags: [])
        XCTAssertNil(model.goalPlan(entries: [], fallbackCostPerKm: 2))
    }

    func testLegacyWeeklyGoalMigrates() {
        let model = makeModel()
        defaults.set(15_000.0, forKey: AppPreferences.weeklyGoalKey)
        model.migrateLegacyGoal(defaults: defaults)
        XCTAssertEqual(model.goal, GoalSpec(amount: Money(15_000), period: .week))
        XCTAssertEqual(defaults.double(forKey: AppPreferences.weeklyGoalKey), 0)
        model.setGoal(GoalSpec(amount: Money(1), period: .month))
        model.migrateLegacyGoal(defaults: defaults)
        XCTAssertEqual(model.goal?.amount, Money(1))
    }

    func testSwitchSuggestionShownOnce() {
        let model = makeModel()
        model.chooseFirm("migros_hemen", regionTier: "r4", seniorityYears: 0, vehicleType: nil, flags: [])
        let scenario = DemoScenarioCatalog.scenario("tariffChanged")!
        for version in scenario.userTariffs(today: model.today) { _ = model.saveUserTariff(version, activate: true) }
        let workload = WorkloadSpec(packagesPerDay: 32, hoursPerDay: 8, kmPerPackage: 3, daysPerMonth: 26)
        let suggestion = model.pendingSwitchSuggestion(workload: workload, fallbackCostPerKm: 2)
        XCTAssertEqual(suggestion?.platformCode, "yemeksepeti")
        if let suggestion { model.markSwitchSeen(suggestion) }
        XCTAssertNil(model.pendingSwitchSuggestion(workload: workload, fallbackCostPerKm: 2))
    }

    func testSwitchNotificationOnlyOnce() {
        let model = makeModel()
        model.chooseFirm("migros_hemen", regionTier: "r4", seniorityYears: 0, vehicleType: nil, flags: [])
        XCTAssertNil(model.switchSuggestionToNotify(entries: [], fallbackCostPerKm: 2)) // taban
        for version in DemoScenarioCatalog.scenario("tariffChanged")!.userTariffs(today: model.today) {
            _ = model.saveUserTariff(version, activate: true)
        }
        XCTAssertNotNil(model.switchSuggestionToNotify(entries: [], fallbackCostPerKm: 2))
        XCTAssertNil(model.switchSuggestionToNotify(entries: [], fallbackCostPerKm: 2))
    }

    func testFirstSwitchEvaluationIsSilent() {
        let model = makeModel()
        model.chooseFirm("migros_hemen", regionTier: "r4", seniorityYears: 0, vehicleType: nil, flags: [])
        // Kurulum: taban kaydedilir, bildirim yok
        XCTAssertNil(model.switchSuggestionToNotify(entries: [], fallbackCostPerKm: 2))
        for version in DemoScenarioCatalog.scenario("tariffChanged")!.userTariffs(today: model.today) {
            _ = model.saveUserTariff(version, activate: true)
        }
        // Tarife degisti: oneri bir kez
        XCTAssertNotNil(model.switchSuggestionToNotify(entries: [], fallbackCostPerKm: 2))
    }

    // MARK: - 1.9

    func testMigrationResetsRemovedFirmAndMapsOldRegions() {
        let removed = makeModel()
        removed.chooseFirm("getir", regionTier: nil, seniorityYears: nil, vehicleType: "motorcycle", flags: [])
        XCTAssertTrue(removed.migrateTo19())
        XCTAssertFalse(removed.state.hasChosenFirm)

        let plus = makeModel()
        plus.chooseFirm("migros_hemen", regionTier: "plus", seniorityYears: 1, vehicleType: nil, flags: [])
        XCTAssertFalse(plus.migrateTo19())
        XCTAssertEqual(plus.state.regionTier, "r1")

        let ys = makeModel()
        ys.chooseFirm("yemeksepeti", regionTier: nil, seniorityYears: nil, vehicleType: nil, flags: ["ys_ankara_izmir"])
        ys.migrateTo19()
        XCTAssertEqual(ys.state.regionTier, "ys_ankara_izmir")
        XCTAssertTrue(ys.state.flags.isEmpty)
    }

    func testRestoranProfileUsesContractHoursAndFixedShare() throws {
        let model = makeModel()
        model.chooseFirm("pt_restoran", regionTier: "r1", seniorityYears: 2, vehicleType: nil, flags: [], contractHours: 10)
        let input = try XCTUnwrap(model.baseInput(day: "2026-10-07"))
        XCTAssertEqual(input.contractHours, 10)
        // 77.370 sabit + 2.250 kidem primi, 26 gune: gunluk pay
        XCTAssertEqual(model.fixedShareToday(), Money(Money.round(Decimal(77_370) / 26)) + Money(Money.round(Decimal(2_250) / 26)))
        XCTAssertEqual(model.questions(for: "pt_restoran").contractHours, [9, 10, 11, 12])
    }
}
