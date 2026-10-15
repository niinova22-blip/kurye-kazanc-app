import SwiftUI
import SwiftData
import CoreLocation

/// Profil sekmesi: hesap (Apple ile giris), ayarlar (firma, yakit, hedef, bildirimler), profil, konum, otomatik vardiya, veri.
/// 1.10: ekran goruntusu taramasi, kalibrasyon ve eski "Platformlarım" kaldirildi; gider tahmini Gelismis'e tasindi.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(LocationService.self) private var location
    @Environment(SyncCoordinator.self) private var sync
    @Environment(AccountService.self) private var account
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro

    @Query private var couriers: [Courier]

    @State private var showsFirmSetup = false
    @State private var showsShiftTutorial = false
    @State private var showDeleteConfirmation = false

    private var courier: Courier? { couriers.first }

    var body: some View {
        NavigationStack {
            Form {
                AccountSection()
                settingsSection
                profileSection
                locationSection
                AutoShiftSection()
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

    // MARK: - Profil

    private var profileSection: some View {
        Section("Profil") {
            if let courier {
                TextField("Ad", text: Binding(
                    get: { courier.name },
                    set: { courier.name = $0; try? modelContext.save() }
                ))
                Picker("Araç", selection: Binding(
                    get: { courier.vehicleType },
                    set: { courier.vehicleType = $0; try? modelContext.save() }
                )) {
                    ForEach(VehicleType.allCases) { Text($0.displayName).tag($0) }
                }
            } else {
                Text("Profil bulunamadı").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Ayarlar (1.7)

    private var settingsSection: some View {
        Section {
            Button {
                showsFirmSetup = true
            } label: {
                LabeledContent("Çalıştığım firma",
                               value: PayrollModel.platformName(payroll.tariffProfile?.platformCode ?? "—"))
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("profile.firm")
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
            NavigationLink { FuelSettingsView() } label: {
                Label("Araç ve yakıt", systemImage: "fuelpump")
            }
            .accessibilityIdentifier("profile.fuel")
            NavigationLink { GoalPlanView() } label: {
                Label("Hedef ve plan", systemImage: "target")
            }
            .accessibilityIdentifier("profile.goal")
            NavigationLink { NotificationSettingsView() } label: {
                Label("Bildirimler", systemImage: "bell.badge")
            }
            .accessibilityIdentifier("profile.notifications")
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
            NavigationLink { AdvancedView() } label: {
                Label("Gelişmiş", systemImage: "gearshape.2")
            }
            .accessibilityIdentifier("profile.advanced")
        } header: {
            Text("Ayarlar")
        } footer: {
            Text("Tüm hesaplar çalıştığın firmanın tarifesine göre yapılır.")
        }
    }

    // MARK: - Konum

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
            Text("Konum yalnızca vardiya sırasında km, bölge ve mesafe bandı için kullanılır; vardiya bitince durur. Tam konum saklanmaz.")
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

    // MARK: - Veri

    private var dataSection: some View {
        Section {
            Button("Tüm kayıtları sil", role: .destructive) { showDeleteConfirmation = true }
                .accessibilityIdentifier("settings.deleteAll")
        } footer: {
            Text("Yalnızca telefondaki kayıtları siler. Sunucudaki yedek için Hesap > “Verilerimi sil”.")
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

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func deleteAllRecords() {
        try? modelContext.deleteAllRecords()
        // Silinen kayitlarin bekleyen gonderimleri de dusulur (sunucudakiler icin "Verilerimi sil")
        sync.allRecordsDeleted()
        // Bos veri otomatik yedekle sunucudaki yedegi ezmesin
        account.localRecordsCleared()
    }
}
