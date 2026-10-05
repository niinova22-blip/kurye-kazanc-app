import SwiftUI
import SwiftData

@main
struct KuryeKazancApp: App {
    private let container: ModelContainer

    init() {
        let launch = LaunchOptions.current
        container = ModelContainerFactory.make(inMemory: launch.isUITesting)
        if launch.loadsSampleData {
            SampleData.insert(into: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// Test/CI icin baslatma argumanlari. XCUITest `app.launchArguments` ile bunlari gecer.
struct LaunchOptions {
    var isUITesting: Bool
    var loadsSampleData: Bool

    static var current: LaunchOptions {
        let args = ProcessInfo.processInfo.arguments
        return LaunchOptions(
            isUITesting: args.contains("-ui-testing"),
            loadsSampleData: args.contains("-sample-data")
        )
    }
}
