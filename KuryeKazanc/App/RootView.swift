import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PayrollModel.self) private var payroll
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(AppPreferences.hasSeenIntroV17Key) private var hasSeenIntro = false
    @State private var showsIntroReplay = false

    /// Akis: tanitim (bir kez) -> firma ve hedef kurulumu -> arac/konum/paylasim -> sekmeler.
    var body: some View {
        Group {
            if !hasSeenIntro {
                IntroView(mode: .firstRun) { hasSeenIntro = true }
            } else if !payroll.state.hasChosenFirm {
                SetupFlowView {}
            } else if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: hasSeenIntro)
        .environment(\.showIntro, ShowIntroAction { showsIntroReplay = true })
        .fullScreenCover(isPresented: $showsIntroReplay) {
            IntroView(mode: .replay) { showsIntroReplay = false }
        }
        .task {
            DataSeeder.seedPlatformsIfNeeded(in: modelContext)
            payroll.migrateLegacyGoal(defaults: .standard)
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
            PayrollView()
                .tabItem { Label("Hakediş", systemImage: "turkishlirasign.circle") }
            AnalysisView()
                .tabItem { Label("Analiz", systemImage: "chart.bar.xaxis") }
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
