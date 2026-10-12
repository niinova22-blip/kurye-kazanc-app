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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.location)
                .environment(environment.workSession)
                .environment(environment.scanner)
                .environment(environment.autoShift)
                .environment(environment.sync)
                .environment(environment.account)
                .environment(environment.payroll)
                .environment(environment.tariffs)
                .task {
                    // Acilis: sablonlar (12 saatte bir) ve bekleyen gonderimler. Riza yoksa ag yok.
                    await syncNow()
                }
                .onChange(of: scenePhase) { _, phase in
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
        let sync: SyncCoordinator = environment.sync
        await sync.refreshTemplatesIfNeeded()
        await sync.refreshRulesIfNeeded()
        // Tarifeler: basarisizlikta son bilinen / gomulu tarife kullanilir; hesaplama aga bagli degil
        await environment.tariffs.refreshIfNeeded()
        await environment.payroll.refreshNotices()
        await sync.flush()
    }
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
