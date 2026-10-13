import SwiftUI
import SwiftData
import CoreLocation

/// Profil sekmesi: profil, hedefler, gider hesabi, konum izni, paylasim rizalari, hesap ve yedek, kalibrasyon, veri.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(LocationService.self) private var location
    @Environment(ScreenshotScanner.self) private var scanner
    @Environment(SyncCoordinator.self) private var sync
    @Environment(AccountService.self) private var account
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro

    @Query private var couriers: [Courier]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true

    @State private var costText = ""
    @State private var showsFirmSetup = false
    @State private var showsShiftTutorial = false
    @State private var showDeleteConfirmation = false
    @AppStorage("scanTestWindow") private var scanTestWindow = false

    private var courier: Courier? { couriers.first }

    var body: some View {
        NavigationStack {
            Form {
                settingsSection
                profileSection
                expenseSection
                locationSection
                AutoShiftSection()
                screenshotSection
                AccountSection()
                CalibrationSection()
                if BuildEnvironment.showsTesterTools {
                    Section("Test araçları") {
                        NavigationLink("Test senaryoları") { DemoScenarioView() }
                        NavigationLink("Veritabanı") { DatabaseInspectorView() }
                        NavigationLink("Tarama günlüğü") { ScanLogView() }
                        Toggle("Test: son 30 gün ve tüm fotoğraflar", isOn: $scanTestWindow)
                            .accessibilityIdentifier("profile.scanTestWindow")
                    }
                }
                dataSection
                aboutSection
            }
            .dismissesKeyboard()
            .navigationTitle("Profil")
            .onAppear(perform: loadFieldTexts)
            // Geri yukleme ayarlari degistirir (taban tarihi de degisir): alanlar yeniden okunur.
            .onChange(of: account.lastBackupDate) { _, _ in
                loadFieldTexts()
            }
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
                NavigationLink {
                    DefaultPlatformsView(courier: courier, platforms: platforms)
                } label: {
                    LabeledContent("Platformlarım", value: courier.defaultPlatforms
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map(\.name).joined(separator: ", "))
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
            NavigationLink { FuelSettingsView() } label: {
                Label("Araç ve yakıt", systemImage: "fuelpump")
            }
            .accessibilityIdentifier("profile.fuel")
            NavigationLink { GoalPlanView() } label: {
                Label("Hedef ve plan", systemImage: "target")
            }
            .accessibilityIdentifier("profile.goal")
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
        } header: {
            Text("Ayarlar")
        } footer: {
            Text("Tüm hesaplar çalıştığın firmanın tarifesine göre yapılır.")
        }
    }

    // MARK: - Gider

    private var expenseSection: some View {
        Section {
            Toggle("Otomatik gider tahmini", isOn: $autoEstimate)
                .accessibilityIdentifier("settings.autoEstimate")
            HStack {
                Text("Km başına maliyet (yedek)")
                Spacer()
                TextField("0", text: $costText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    .onChange(of: costText) { _, newValue in
                        if let value = TurkishNumberParser.parseDecimal(newValue), value >= 0 {
                            costPerKm = value
                        }
                    }
                    .accessibilityIdentifier("settings.costPerKm")
                Text("₺").foregroundStyle(.secondary)
            }
            .disabled(!autoEstimate)
            if let courier {
                Button("\(courier.vehicleType.displayName) varsayılanını kullan (\(Formatters.currency(courier.vehicleType.defaultCostPerKm)))") {
                    costPerKm = courier.vehicleType.defaultCostPerKm
                    costText = TurkishNumberParser.format(costPerKm)
                }
                .disabled(!autoEstimate)
            }
        } header: {
            Text("Gider hesaplama")
        } footer: {
            Text("Yakıt fiyatı girdiysen gider km × tüketim × fiyattır; girmediysen km × bu tutar.")
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
            Text("Arka plan konumu")
        } footer: {
            Text("Konum yalnızca otomatik vardiya sırasında (mesafe ve ilçe için) kullanılır; vardiya bitince durur. “Uygulamayı kullanırken” izni de yeterlidir. Tam konum saklanmaz.")
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

    // MARK: - Ekran goruntuleri

    private var screenshotSection: some View {
        Section {
            Toggle("Ekran görüntülerini otomatik bul", isOn: autoScanBinding)
                .accessibilityIdentifier("profile.autoScan")
            if scanner.isPermissionMissing {
                Button("Fotoğraf izni kapalı — Ayarlar'dan aç") { openSystemSettings() }
                    .accessibilityIdentifier("profile.photoPermission")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Kazanç taraması")
                Text("Firma uygulamasında kazanç ekranının görüntüsünü al; Bugün > “Kazanç taraması” son 24 saatin görüntülerini okur.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.scanInfo")
            VStack(alignment: .leading, spacing: 2) {
                Text("Kısayollar ile")
                Text("Kısayollar > Otomasyon > + > Uygulama > (platform uygulaması) > Açıldığında > Hemen Çalıştır > eylemler: Bekle (3 sn) → Ekran Görüntüsü Al → Kurye Kazanç'a ekran görüntüsü gönder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.shortcutsRecipe")
        } header: {
            Text("Ekran görüntüleri")
        } footer: {
            Text("Görüntüler yalnızca telefonunda işlenir.")
        }
    }

    /// Acmak fotograf izni ister (verilmezse kapali kalir); kapatmak taramayi durdurur.
    private var autoScanBinding: Binding<Bool> {
        Binding(
            get: { scanner.isEnabled },
            set: { newValue in
                if newValue {
                    Task { _ = await scanner.enable() }
                } else {
                    scanner.disable()
                }
            }
        )
    }

    // MARK: - Veri

    private var dataSection: some View {
        Section {
            Button("Tüm kayıtları sil", role: .destructive) { showDeleteConfirmation = true }
                .accessibilityIdentifier("settings.deleteAll")
        } footer: {
            Text("Yalnızca telefondaki kayıtları siler. Sunucudaki yedek için Hesap ve yedek > “Verilerimi sil”.")
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

    private func loadFieldTexts() {
        costText = TurkishNumberParser.format(costPerKm)
    }

    private func deleteAllRecords() {
        try? modelContext.deleteAllRecords()
        // Silinen kayitlarin bekleyen gonderimleri de dusulur (sunucudakiler icin "Verilerimi sil")
        sync.allRecordsDeleted()
        // Bos veri otomatik yedekle sunucudaki yedegi ezmesin
        account.localRecordsCleared()
    }
}

/// Profildeki varsayilan platform secimi.
private struct DefaultPlatformsView: View {
    @Environment(\.modelContext) private var modelContext
    let courier: Courier
    let platforms: [Platform]

    var body: some View {
        List(platforms) { platform in
            let isSelected = courier.defaultPlatforms.contains { $0.id == platform.id }
            Button {
                if isSelected {
                    courier.defaultPlatforms.removeAll { $0.id == platform.id }
                } else {
                    courier.defaultPlatforms.append(platform)
                }
                try? modelContext.save()
            } label: {
                HStack {
                    Text(platform.name).foregroundStyle(.primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .navigationTitle("Platformlarım")
    }
}
