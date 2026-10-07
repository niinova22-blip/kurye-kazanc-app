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
                .onChange(of: scenePhase) { _, phase in
                    // On plana donus: Ayarlar'da verilen izinler ve suren vardiya yeniden degerlendirilir
                    guard phase == .active else { return }
                    let autoShift = environment.autoShift
                    Task { @MainActor in
                        await autoShift.handleWake()
                        // Arka planda baslayan vardiyanin Canli Etkinligi acilamamis olabilir: simdi istenir
                        autoShift.ensureLiveActivity()
                    }
                }
        }
        .modelContainer(environment.container)
    }
}

/// Test/CI icin baslatma argumanlari. XCUITest `app.launchArguments` ile bunlari gecer.
struct LaunchOptions {
    var isUITesting: Bool
    var loadsSampleData: Bool
    var resetsDefaults: Bool

    static var current: LaunchOptions {
        let args = ProcessInfo.processInfo.arguments
        return LaunchOptions(
            isUITesting: args.contains("-ui-testing"),
            loadsSampleData: args.contains("-sample-data"),
            resetsDefaults: args.contains("-reset-defaults")
        )
    }
}
