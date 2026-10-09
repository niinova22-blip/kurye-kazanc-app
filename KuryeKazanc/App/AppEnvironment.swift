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
    let scanner: ScreenshotScanner
    let autoShift: AutoShiftCoordinator
    let sync: SyncCoordinator
    let account: AccountService

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
        let templates: @MainActor () -> [OCRTemplate] = { sync.mergedTemplates() }
        if let testDefaults {
            scanner = ScreenshotScanner(defaults: testDefaults, templates: templates)
        } else {
            scanner = ScreenshotScanner(library: PhotoKitScreenshotLibrary(), templates: templates)
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
        // Canli Etkinlik "Vardiyayi bitir": iOS uygulamayi arka planda soguk baslatsa da bagli olsun.
        // Form acilamaz: ozet bekleyen vardiya olur, "Vardiya bitti" bildirimi kazanc formuna goturur.
        ShiftIntentBridge.endShift = { [weak self] in
            _ = self?.autoShift.endShiftToPending()
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
