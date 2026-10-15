import SwiftUI
import SwiftData

@main
struct KuryeKazancApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    /// Ortak nesne grafigi (bkz. AppEnvironment): sifirlama ve test ayarlari orada uygulanir.
    private let environment: AppEnvironment

    init() {
        environment = AppEnvironment.shared
        KuryeTips.configure(isUITesting: LaunchOptions.current.isUITesting)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(.rounded)
                .tint(Theme.accent)
                .environment(environment.location)
                .environment(environment.workSession)
                .environment(environment.scanner)
                .environment(environment.autoShift)
                .environment(environment.sync)
                .environment(environment.account)
                .environment(environment.payroll)
                .environment(environment.tariffs)
                .environment(environment.liveShift)
                .task {
                    // Hatirlatmalar ayarlara gore yeniden kurulur (izin geri alindiysa sessizce dusmez)
                    await ReminderScheduler.shared.refreshStatus()
                    ReminderScheduler.shared.reschedule()
                    // Acilis: sablonlar (12 saatte bir) ve bekleyen gonderimler. Riza yoksa ag yok.
                    await syncNow()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 1.12: ekran kilitlenirken / arka plana gecerken suren vardiyanin Canli Etkinligi kesin acik olsun:
                    // kilit ekranina kendiliginden duser (ActivityKit istegi yalnizca uygulama gorunurken basarili olur)
                    if phase == .inactive {
                        environment.autoShift.ensureLiveActivity()
                        return
                    }
                    // On plana donus: Ayarlar'da verilen izinler ve suren vardiya yeniden degerlendirilir
                    guard phase == .active else { return }
                    let autoShift = environment.autoShift
                    Task { @MainActor in
                        await autoShift.handleWake()
                        // Arka planda baslayan vardiyanin Canli Etkinligi acilamamis olabilir: simdi istenir
                        autoShift.ensureLiveActivity()
                    }
                    Task { await syncNow() }
                }
        }
        .modelContainer(environment.container)
    }

    /// Once sablonlar ve planlama kurallari, sonra kuyruk. Ust uste cagrilar koordinatorde tek calismaya iner.
    @MainActor
    private func syncNow() async {
        // On plana her donuste cagrilir: ust uste binen calismalar (yavas ag) ayni durumu iki kez degistirmesin
        guard !SyncGate.isRunning else { return }
        SyncGate.isRunning = true
        defer { SyncGate.isRunning = false }
        let sync: SyncCoordinator = environment.sync
        await sync.refreshTemplatesIfNeeded()
        await sync.refreshRulesIfNeeded()
        // Tarifeler: basarisizlikta son bilinen / gomulu tarife kullanilir; hesaplama aga bagli degil
        await environment.tariffs.refreshIfNeeded()
        await environment.payroll.refreshNotices()
        ReminderScheduler.shared.tariffNotices(unread: environment.payroll.unreadNoticeCount)
        await notifyTariffSwitchIfNeeded()
        await sync.flush()
    }
}

extension KuryeKazancApp {
    /// Tarife esitlemesinden sonra baska bir firma belirgin sekilde daha kazancli hale geldiyse bir kez bildirir.
    @MainActor
    private func notifyTariffSwitchIfNeeded() async {
        let records: [EarningRecord] = (try? environment.container.mainContext.fetch(FetchDescriptor<EarningRecord>())) ?? []
        let costPerKm: Double = UserDefaults.standard.object(forKey: AppPreferences.costPerKmKey) as? Double
            ?? AppPreferences.defaultCostPerKm
        guard let suggestion = environment.payroll.switchSuggestionToNotify(entries: records.map(\.entry),
                                                                             fallbackCostPerKm: costPerKm) else { return }
        await TariffSwitchNotifier.notify(suggestion)
    }
}

@MainActor
private enum SyncGate {
    static var isRunning = false
}

/// Test/CI icin baslatma argumanlari. XCUITest `app.launchArguments` ile bunlari gecer.
struct LaunchOptions {
    var isUITesting: Bool
    var loadsSampleData: Bool
    var resetsDefaults: Bool
    /// "-firm <kod>": UI testleri kurulumu atlayip bu firmayla baslar.
    var firm: String? = nil

    static var current: LaunchOptions {
        let args = ProcessInfo.processInfo.arguments
        var firm: String? = nil
        if let index = args.firstIndex(of: "-firm"), index + 1 < args.count { firm = args[index + 1] }
        return LaunchOptions(
            isUITesting: args.contains("-ui-testing"),
            loadsSampleData: args.contains("-sample-data"),
            resetsDefaults: args.contains("-reset-defaults"),
            firm: firm
        )
    }
}
