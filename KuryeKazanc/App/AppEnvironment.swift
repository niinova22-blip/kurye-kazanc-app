import Foundation
import SwiftData

/// Uygulamanin tek nesne grafigi. SwiftUI sahnesi, AppDelegate (arka planda yeniden baslatma,
/// bildirim eylemleri) ve Canli Etkinlik Intent'i ayni orneklere erisir.
/// `shared` tembel olusturulur: App yapisi veya didFinishLaunching hangisi once dokunursa o kurar.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let container: ModelContainer
    let location: LocationService
    let workSession: WorkSessionManager
    let autoShift: AutoShiftCoordinator
    let sync: SyncCoordinator
    let account: AccountService
    let tariffs: TariffSyncService
    let payroll: PayrollModel
    let liveShift: LiveShiftController
    let pro: ProStore

    private init() {
        let launch = LaunchOptions.current
        // UserDefaults'u okuyan her seyden ONCE: testler temiz tercihlerle baslar
        if launch.resetsDefaults, let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        let container = ModelContainerFactory.make(inMemory: launch.isUITesting)
        if launch.loadsSampleData {
            SampleData.insert(into: container.mainContext)
        }
        self.container = container
        // UI testlerinde ayri (bos) tercih alani: tarama ve otomatik vardiya kapali, izin sorulmaz
        let testDefaults: UserDefaults? = launch.isUITesting ? (UserDefaults(suiteName: "ui-tests") ?? .standard) : nil
        // Temiz baslangic test alanini da siler (or. onceki testte yarim kalan canli vardiya)
        if launch.resetsDefaults, launch.isUITesting { testDefaults?.removePersistentDomain(forName: "ui-tests") }
        // UI testlerinde konum kapali: simulatorde izin diyalogu testleri kilitlemesin
        let location = LocationService(isEnabled: !launch.isUITesting)
        self.location = location
        let workSession = WorkSessionManager(location: location)
        self.workSession = workSession
        // Sunucu: Info.plist ayari yoksa ya da UI testindeyse istemci yok; esitleme ve hesap no-op (ag yok).
        // Profildeki @AppStorage rizalari .standard'a yazdigi icin ikisi de .standard kullanir.
        var client: SupabaseClient?
        if !launch.isUITesting, let config = SupabaseConfig.fromBundle {
            client = SupabaseClient(config: config, store: KeychainStore())
        }
        let sync = SyncCoordinator(client: client, queue: OutboxQueue(fileURL: OutboxQueue.defaultFileURL()))
        self.sync = sync
        account = AccountService(client: client, syncCoordinator: sync)
        // Hakedis: UI testlerinde bellekte (dosya yok, ag yok)
        let tariffs = TariffSyncService(client: client, defaults: testDefaults ?? .standard,
                                        fileURL: launch.isUITesting ? nil : TariffSyncService.defaultFileURL())
        self.tariffs = tariffs
        let payrollStore = PayrollStore(fileURL: launch.isUITesting ? nil : PayrollModel.defaultFileURL(),
                                        writeOptions: OutboxQueue.writeOptions)
        payroll = PayrollModel(store: payrollStore, tariffs: tariffs)
        if launch.isUITesting, let firm = launch.firm {
            payroll.chooseFirm(firm, regionTier: firm == "yemeksepeti" ? "ys_istanbul" : "r1", seniorityYears: nil,
                               vehicleType: nil, flags: [], contractHours: firm == "pt_restoran" ? 10 : nil)
            if launch.loadsSampleData { payroll.setGoal(GoalSpec(amount: Money(100_000), period: .month)) }
        }
        let todaySummary = AppEnvironment.cachedTodaySummary(in: container.mainContext)
        autoShift = AutoShiftCoordinator(
            workSession: workSession,
            location: location,
            motion: CoreMotionActivityProvider(),
            notifier: ShiftNotifications(),
            liveActivity: LiveActivityController(),
            defaults: testDefaults ?? .standard,
            todayNet: { todaySummary().netEarnings },
            todayWorkedSeconds: { todaySummary().workDuration }
        )
        liveShift = LiveShiftController(autoShift: autoShift, workSession: workSession, location: location, payroll: payroll,
                                        defaults: testDefaults ?? .standard)
        // Canli Etkinlik "Vardiyayi bitir": iOS uygulamayi arka planda soguk baslatsa da bagli olsun.
        // Form acilamaz: ozet bekleyen vardiya olur, "Vardiya bitti" bildirimi kazanc formuna goturur.
        // 1.12: canli vardiya (paket sayma) suruyorsa hesaplanip kaydedilir; yoksa eski akis.
        // 1.14 Pro: UI testlerinde StoreKit yok; "-free" ile ucretsiz akis, yoksa Pro
        let pro = ProStore(defaults: testDefaults ?? .standard, override: launch.isUITesting ? !launch.isFree : nil,
                           demo: launch.isUITesting && ProcessInfo.processInfo.arguments.contains("-store-demo"))
        self.pro = pro
        let live: LiveShiftController = liveShift
        live.hasPro = { [weak pro] in pro?.isPro ?? false }
        live.onLocked = { [weak pro] feature in pro?.paywallRequest = feature }
        let shiftCoordinator: AutoShiftCoordinator = autoShift
        live.contextProvider = { container.mainContext }
        shiftCoordinator.liveShiftSnapshot = { [weak live] in live?.activitySnapshot() }
        shiftCoordinator.onAutoShiftStarted = { [weak live] in live?.startFromAutoShift() }
        shiftCoordinator.onShiftLocation = { [weak live] in live?.locationUpdated() }
        shiftCoordinator.onAutoShiftFinished = { [weak live] summary in live?.handleAutoShiftFinished(summary) ?? false }
        shiftCoordinator.onAutoShiftCancelled = { [weak live] in live?.dropAfterAutoCancel() }
        ShiftIntentBridge.endShift = { [weak live, weak shiftCoordinator] in
            if let live, live.isActive {
                _ = live.finish(context: container.mainContext)
            } else {
                _ = shiftCoordinator?.endShiftToPending()
            }
        }
        ShiftIntentBridge.requestEnd = { [weak shiftCoordinator] in shiftCoordinator?.requestEndConfirmation() }
        ShiftIntentBridge.cancelEnd = { [weak shiftCoordinator] in shiftCoordinator?.cancelEndConfirmation() }
        ShiftIntentBridge.addPackage = { [weak live] in live?.addPackageFromOutside() }
        ShiftIntentBridge.undoPackage = { [weak live] in live?.undoLast() }
        ShiftIntentBridge.openShift = { [weak live] in live?.openFromWidget() }
        // Pro bitti (abonelik sona erdi / iade): otomatik vardiya kapanir. Suren vardiya bitene kadar kalir.
        pro.onChange = { [weak shiftCoordinator] isPro in
            guard !isPro, let shiftCoordinator, shiftCoordinator.isEnabled else { return }
            shiftCoordinator.disable()
        }
    }

    /// Bugun KAYDEDILMIS kazanc/gider kayitlarinin ozeti (suren vardiya haric; onu koordinator ekler).
    static func todaySummary(in context: ModelContext) -> EarningsSummary {
        let start = Calendar.current.startOfDay(for: .now)
        let earnings = (try? context.fetch(FetchDescriptor<EarningRecord>(
            predicate: #Predicate<EarningRecord> { $0.date == start }
        ))) ?? []
        let expenses = (try? context.fetch(FetchDescriptor<ExpenseRecord>(
            predicate: #Predicate<ExpenseRecord> { $0.date == start }
        ))) ?? []
        let defaults = UserDefaults.standard
        let costPerKm = defaults.object(forKey: AppPreferences.costPerKmKey) as? Double ?? AppPreferences.defaultCostPerKm
        let autoEstimate = defaults.object(forKey: AppPreferences.autoEstimateExpensesKey) as? Bool ?? true
        return TodayViewModel.summary(
            earnings: earnings, expenses: expenses, costPerKm: costPerKm, autoEstimate: autoEstimate
        )
    }

    /// Koordinator net kazanci ve calisma suresini art arda ister: ozet kisa sure onbellekte
    /// tutulur ki ayni guncellemede iki kez sorgulanmasin.
    static func cachedTodaySummary(in context: ModelContext, ttl: TimeInterval = 1) -> () -> EarningsSummary {
        var cachedAt: Date?
        var cached: EarningsSummary?
        return {
            let now = Date()
            if let cachedAt, let cached, now.timeIntervalSince(cachedAt) < ttl {
                return cached
            }
            let summary = AppEnvironment.todaySummary(in: context)
            cachedAt = now
            cached = summary
            return summary
        }
    }
}
