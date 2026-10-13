import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PayrollModel.self) private var payroll
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(AppPreferences.hasSeenIntroV18Key) private var hasSeenIntro = false
    @AppStorage(AppPreferences.startFirmKey) private var startFirm = ""
    @State private var showsIntroReplay = false

    /// Akis: firma secimi (ilk ekran) -> tanitim (bir kez, firmaya gore) -> tarife sorulari, yakit, hedef ->
    /// konum -> sekmeler. Daha once firma secmis kullanici yeni tanitimi bir kez gorur.
    var body: some View {
        Group {
            if !payroll.state.hasChosenFirm && startFirm.isEmpty {
                FirmWelcomeView { startFirm = $0 }
                    .transition(.opacity)
            } else if !hasSeenIntro {
                IntroView(mode: .firstRun, firmCode: payroll.tariffProfile?.platformCode ?? startFirm) { hasSeenIntro = true }
                    .transition(.opacity)
            } else if !payroll.state.hasChosenFirm {
                SetupFlowView(initialFirm: startFirm.isEmpty ? nil : startFirm) {}
            } else if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: hasSeenIntro)
        .animation(.easeInOut, value: startFirm)
        .environment(\.showIntro, ShowIntroAction { showsIntroReplay = true })
        .fullScreenCover(isPresented: $showsIntroReplay) {
            IntroView(mode: .replay, firmCode: payroll.tariffProfile?.platformCode) { showsIntroReplay = false }
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
            EarningsTabView()
                .tabItem { Label("Kazanç", systemImage: "turkishlirasign.circle") }
            FirmsView()
                .tabItem { Label("Firmalar", systemImage: "building.2") }
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
