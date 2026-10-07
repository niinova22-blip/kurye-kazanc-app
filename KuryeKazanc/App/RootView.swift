import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            DataSeeder.seedPlatformsIfNeeded(in: modelContext)
        }
    }
}

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Calendar.current.startOfDay(for: .now)

    var body: some View {
        TabView {
            TodayView(day: today)
                .id(today) // Gun degisince sorgular yeni gunle yeniden kurulur
                .tabItem { Label("Bugün", systemImage: "sun.max") }
            AnalysisView()
                .tabItem { Label("Analiz", systemImage: "chart.bar.xaxis") }
            CommunityView()
                .tabItem { Label("Topluluk", systemImage: "person.3") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshDay()
        }
    }

    private func refreshDay() {
        let now = Calendar.current.startOfDay(for: .now)
        if now != today { today = now }
    }
}
