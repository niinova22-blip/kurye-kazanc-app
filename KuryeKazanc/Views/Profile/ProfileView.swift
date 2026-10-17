import SwiftUI
import SwiftData
import CoreLocation

/// Profil sekmesi: hesap, Pro, sik kullanilan ayarlar (firma, hedef, arac ve yakit, bildirimler), "Diğer ayarlar", veri.
/// 1.15 sade: bolge, hiz, ses, tanitimlar, konum, otomatik vardiya ve Gelismis "Diğer ayarlar" altina tasindi.
/// 1.13: kullanilmayan "Ad" ve ikinci "Araç" secimi kaldirildi (arac: Araç ve yakıt).
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncCoordinator.self) private var sync
    @Environment(AccountService.self) private var account
    @Environment(PayrollModel.self) private var payroll

    @State private var showsFirmSetup = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                AccountSection()
                ProSection()
                settingsSection
                dataSection
                aboutSection
            }
            .dismissesKeyboard()
            .navigationTitle("Profil")
            .sheet(isPresented: $showsFirmSetup) {
                SetupFlowView(firmOnly: true) { showsFirmSetup = false }
            }
            .confirmationDialog(
                "Tüm kazanç ve gider kayıtları silinecek. Bu işlem geri alınamaz.",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Tüm kayıtları sil", role: .destructive, action: deleteAllRecords)
                Button("Vazgeç", role: .cancel) {}
            }
        }
    }

    // MARK: - Ayarlar

    private var settingsSection: some View {
        Section("Ayarlar") {
            Button {
                showsFirmSetup = true
            } label: {
                LabeledContent("Çalıştığım firma",
                               value: PayrollModel.platformName(payroll.tariffProfile?.platformCode ?? "—"))
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("profile.firm")
            NavigationLink { GoalPlanView() } label: {
                Label("Hedef ve plan", systemImage: "target")
            }
            .accessibilityIdentifier("profile.goal")
            NavigationLink { FuelSettingsView() } label: {
                Label("Araç ve yakıt", systemImage: "fuelpump")
            }
            .accessibilityIdentifier("profile.fuel")
            NavigationLink { NotificationSettingsView() } label: {
                Label("Bildirimler", systemImage: "bell.badge")
            }
            .accessibilityIdentifier("profile.notifications")
            NavigationLink { OtherSettingsView() } label: {
                Label("Diğer ayarlar", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("profile.more")
        }
    }

    // MARK: - Veri

    private var dataSection: some View {
        Section {
            Button("Tüm kayıtları sil", role: .destructive) { showDeleteConfirmation = true }
                .accessibilityIdentifier("settings.deleteAll")
        } footer: {
            Text("Yalnızca bu telefondaki kayıtları siler.")
        }
    }

    private var aboutSection: some View {
        Section("Hakkında") {
            LabeledContent("Sürüm", value: appVersion)
            NavigationLink("Gizlilik ve KVKK") {
                PrivacyView()
            }
            .accessibilityIdentifier("profile.privacy")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private func deleteAllRecords() {
        try? modelContext.deleteAllRecords()
        // Silinen kayitlarin bekleyen gonderimleri de dusulur (sunucudakiler icin "Verilerimi sil")
        sync.allRecordsDeleted()
        // Bos veri otomatik yedekle sunucudaki yedegi ezmesin
        account.localRecordsCleared()
    }
}

/// Profil > Diğer ayarlar: bolge, calisma hizi, ses ve titresim, tanitimlar, konum, otomatik vardiya, Gelismis.
struct OtherSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(LocationService.self) private var location
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro
    @State private var showsShiftTutorial = false

    var body: some View {
        Form {
            Section {
                NavigationLink { RegionSettingsView() } label: {
                    LabeledContent {
                        Text(payroll.state.regionTier.map(TariffQuestions.regionName) ?? "Seçilmedi")
                    } label: {
                        Label("Çalıştığın bölge", systemImage: "map")
                    }
                }
                .accessibilityIdentifier("profile.region")
                NavigationLink { PaceSettingsView() } label: {
                    LabeledContent {
                        Text("\(Formatters.decimalText(payroll.state.packagesPerHour ?? PaceEstimate.defaultPackagesPerHour)) paket/sa")
                    } label: {
                        Label("Çalışma hızın", systemImage: "gauge.with.dots.needle.67percent")
                    }
                }
                .accessibilityIdentifier("profile.pace")
                NavigationLink { FeedbackSettingsView() } label: {
                    Label("Ses ve titreşim", systemImage: "speaker.wave.2")
                }
                .accessibilityIdentifier("profile.feedback")
                Button { showIntro() } label: {
                    Label("Tanıtımı izle", systemImage: "play.circle")
                }
                .accessibilityIdentifier("profile.intro")
                Button { showsShiftTutorial = true } label: {
                    Label("Vardiya tanıtımını izle", systemImage: "hand.tap")
                }
                .accessibilityIdentifier("profile.shiftTutorial")
                .fullScreenCover(isPresented: $showsShiftTutorial) {
                    ShiftTutorialView(mode: .replay) { showsShiftTutorial = false }
                }
            }
            locationSection
            AutoShiftSection()
            Section {
                NavigationLink { AdvancedView() } label: {
                    Label("Gelişmiş", systemImage: "gearshape.2")
                }
                .accessibilityIdentifier("profile.advanced")
            }
        }
        .navigationTitle("Diğer ayarlar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var locationSection: some View {
        Section {
            LabeledContent("Konum izni", value: locationStatusText)
                .accessibilityIdentifier("settings.locationStatus")
            switch location.authorizationStatus {
            case .notDetermined:
                Button("Konum iznini ver") { location.requestWhenInUseAuthorization() }
            case .authorizedWhenInUse:
                Button("Arka plan konum iznini ver (Her Zaman)") { location.requestAlwaysAuthorization() }
            case .denied, .restricted:
                Button("iOS Ayarları'nı aç") { openSystemSettings() }
            default:
                EmptyView()
            }
        } header: {
            Text("Konum")
        } footer: {
            Text("Yalnızca vardiyada km ve bölge için kullanılır.")
        }
    }

    private var locationStatusText: String {
        switch location.authorizationStatus {
        case .authorizedAlways: "Her zaman"
        case .authorizedWhenInUse: "Uygulamayı kullanırken"
        case .denied: "Reddedildi"
        case .restricted: "Kısıtlı"
        case .notDetermined: "Sorulmadı"
        default: "Bilinmiyor"
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
