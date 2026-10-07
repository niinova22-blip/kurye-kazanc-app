import SwiftUI
import SwiftData

@main
struct KuryeKazancApp: App {
    private let container: ModelContainer
    @State private var location: LocationService
    @State private var workSession: WorkSessionManager
    @State private var scanner: ScreenshotScanner

    init() {
        let launch = LaunchOptions.current
        if launch.resetsDefaults, let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        container = ModelContainerFactory.make(inMemory: launch.isUITesting)
        if launch.loadsSampleData {
            SampleData.insert(into: container.mainContext)
        }
        // UI testlerinde konum kapali: simulatorde izin diyalogu testleri kilitlemesin
        let location = LocationService(isEnabled: !launch.isUITesting)
        _location = State(initialValue: location)
        _workSession = State(initialValue: WorkSessionManager(location: location))
        // UI testlerinde ayri (bos) tercih alani: tarama kapali, fotograf izni sorulmaz
        _scanner = State(initialValue: launch.isUITesting
            ? ScreenshotScanner(defaults: UserDefaults(suiteName: "ui-tests") ?? .standard)
            : ScreenshotScanner(library: PhotoKitScreenshotLibrary()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(location)
                .environment(workSession)
                .environment(scanner)
                .task { workSession.resumeIfNeeded() }
        }
        .modelContainer(container)
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
