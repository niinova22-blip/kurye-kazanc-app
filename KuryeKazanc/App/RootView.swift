import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // TODO(onboarding): hasCompletedOnboarding false ise once OnboardingView gosterilecek (sonraki adim).
        DashboardView()
            .task {
                DataSeeder.seedPlatformsIfNeeded(in: modelContext)
            }
    }
}
