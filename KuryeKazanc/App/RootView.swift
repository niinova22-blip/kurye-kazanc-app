import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PayrollModel.self) private var payroll
    @Environment(SyncCoordinator.self) private var sync
    @Environment(ProStore.self) private var pro
    @Environment(LiveShiftController.self) private var liveShift
    @AppStorage(AppPreferences.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(AppPreferences.hasSeenIntroV18Key) private var hasSeenIntro = false
    @AppStorage(AppPreferences.startFirmKey) private var startFirm = ""
    @AppStorage(AppPreferences.hasChosenAccountModeKey) private var hasChosenAccountMode = false
    @State private var showsIntroReplay = false

    /// Akis: hesap (Apple ile giris / misafir, 1.11) -> firma secimi -> tanitim (bir kez, firmaya gore) -> 1.14 Pro kapisi
    /// (10 gun ucretsiz deneme; bitince Pro sart) -> tarife sorulari, yakit, hedef -> konum -> sekmeler. Daha once firma
    /// secmis kullanici yeni tanitimi bir kez gorur.
    var body: some View {
        Group {
            if ModelContainerFactory.isUsingFallbackStore {
                StoreUnavailableView()
            } else if !hasChosenAccountMode && !payroll.state.hasChosenFirm && startFirm.isEmpty {
                AccountWelcomeView { hasChosenAccountMode = true }
                    .transition(.opacity)
            } else if !payroll.state.hasChosenFirm && startFirm.isEmpty {
                FirmWelcomeView { startFirm = $0 }
                    .transition(.opacity)
            } else if !hasSeenIntro {
                IntroView(mode: .firstRun, firmCode: payroll.tariffProfile?.platformCode ?? startFirm) { hasSeenIntro = true }
                    .transition(.opacity)
            } else if pro.blocksApp && !liveShift.isActive {
                // Suren vardiya bitirilebilsin diye kapi vardiya bitince gelir
                ProPaywallView(context: pro.access == .expired ? .trialEnded : .trialStart)
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
        .animation(.easeInOut, value: hasChosenAccountMode)
        .animation(.easeInOut, value: pro.blocksApp)
        .environment(\.showIntro, ShowIntroAction { showsIntroReplay = true })
        .fullScreenCover(isPresented: $showsIntroReplay) {
            IntroView(mode: .replay, firmCode: payroll.tariffProfile?.platformCode) { showsIntroReplay = false }
        }
        // 1.14: kilitli ozellige dokunulunca (Bugun, Profil, widget, Kisayollar) Pro satin alma ekrani
        .sheet(item: paywallBinding) { feature in
            ProPaywallView(feature: feature)
        }
        .task {
            DataSeeder.seedPlatformsIfNeeded(in: modelContext)
            payroll.migrateLegacyGoal(defaults: .standard)
            // 1.9: Getir / Trendyol GO secenler firmayi yeniden secer
            if payroll.migrateTo19() { startFirm = "" }
            retireAnonymousSharing(defaults: .standard)
            // 1.12.1: ayni gunde birden cok vardiyasi olan gunler gun toplamiyla bir kez yeniden paylastirilir
            if !UserDefaults.standard.bool(forKey: "payroll.daySplit.v1") {
                payroll.rebalanceAllDays(context: modelContext)
                UserDefaults.standard.set(true, forKey: "payroll.daySplit.v1")
            }
        }
    }
}

extension RootView {
    var paywallBinding: Binding<ProFeature?> {
        Binding(get: { pro.paywallRequest }, set: { pro.paywallRequest = $0 })
    }

    /// 1.8: anonim kazanc / konum paylasimi (topluluk ortalamalari icindi) kaldirildi. Acik birakanlarin rizasi bir kez
    /// geri alinir ve bekleyen gonderimler silinir; uygulama artik kurye ortalamasi kullanmiyor.
    func retireAnonymousSharing(defaults: UserDefaults) {
        // 1.13: kalibrasyon ekrani 1.10'da kalkti; acik kalan riza da kapatilir (bekleyen ornekler gonderilmez)
        if defaults.bool(forKey: AppPreferences.calibrationOptInKey) {
            defaults.set(false, forKey: AppPreferences.calibrationOptInKey)
            sync.calibrationConsentChanged(enabled: false)
        }
        guard defaults.bool(forKey: AppPreferences.dataSharingOptInKey)
            || defaults.bool(forKey: AppPreferences.locationSharingOptInKey) else { return }
        defaults.set(false, forKey: AppPreferences.dataSharingOptInKey)
        defaults.set(0.0, forKey: AppPreferences.dataSharingConsentDateKey)
        defaults.set(false, forKey: AppPreferences.locationSharingOptInKey)
        defaults.set(0.0, forKey: AppPreferences.locationSharingConsentDateKey)
        sync.sharingConsentChanged(enabled: false)
    }
}

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Calendar.current.startOfDay(for: .now)
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TodayView(day: today)
                .id(today) // Gun degisince sorgular yeni gunle yeniden kurulur
                .tabItem { Label("Bugün", systemImage: "sun.max") }
                .tag(0)
            EarningsTabView()
                .tabItem { Label("Kazanç", systemImage: "turkishlirasign.circle") }
                .tag(1)
            FirmsView()
                .tabItem { Label("Firmalar", systemImage: "building.2") }
                .tag(2)
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(3)
        }
        // 1.12.1: sekme degisiminde hafif titresim
        .onChange(of: tab) { _, _ in Haptics.selection() }
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

/// Kalici veri deposu bu oturumda acilamadi (bkz. ModelContainerFactory.isUsingFallbackStore). Kayitlar silinmedi;
/// gecici depoya yazilip kaybolmasinlar diye ekranlar acilmaz, uygulamayi yeniden acmak yeterli.
private struct StoreUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.rotation")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
            Text("Verilerin hazırlanıyor")
                .font(.title2.bold())
            Text("Telefon yeniden başladıktan sonra kilit açılmadan uygulama arka planda çalıştı. Kayıtların yerinde; uygulamayı uygulama değiştiriciden kapatıp yeniden açman yeterli.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
