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

    @Query private var couriers: [Courier]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @AppStorage(AppPreferences.dataSharingOptInKey) private var dataSharingOptIn = false
    @AppStorage(AppPreferences.dataSharingConsentDateKey) private var consentTimestamp: Double = 0
    @AppStorage(AppPreferences.locationSharingOptInKey) private var locationSharingOptIn = false
    @AppStorage(AppPreferences.locationSharingConsentDateKey) private var locationConsentTimestamp: Double = 0
    @AppStorage(AppPreferences.weeklyGoalKey) private var weeklyGoal = 0.0
    @AppStorage(AppPreferences.dailyGoalKey) private var dailyGoal = 0.0

    @State private var costText = ""
    @State private var weeklyGoalText = ""
    @State private var dailyGoalText = ""
    @State private var showConsentSheet = false
    @State private var showLocationConsentSheet = false
    @State private var showDeleteConfirmation = false
    @AppStorage("scanTestWindow") private var scanTestWindow = false

    private var courier: Courier? { couriers.first }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                goalsSection
                expenseSection
                locationSection
                AutoShiftSection()
                screenshotSection
                sharingSection
                AccountSection()
                CalibrationSection()
                if BuildEnvironment.showsTesterTools {
                    Section("Test araçları") {
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
            .sheet(isPresented: $showConsentSheet) {
                DataSharingConsentView {
                    dataSharingOptIn = true
                    consentTimestamp = Date.now.timeIntervalSince1970
                    // Konum yogunlugu, kazanc paylasimiyla birlikte acik gelir (riza ekraninda listelenir); ayri kapatilabilir
                    locationSharingOptIn = true
                    locationConsentTimestamp = Date.now.timeIntervalSince1970
                }
            }
            .sheet(isPresented: $showLocationConsentSheet) {
                LocationSharingConsentView {
                    locationSharingOptIn = true
                    locationConsentTimestamp = Date.now.timeIntervalSince1970
                }
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
                NavigationLink {
                    PlannerView()
                } label: {
                    Label("Çalışma profili ve plan", systemImage: "calendar.badge.clock")
                }
            } else {
                Text("Profil bulunamadı").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Hedefler

    private var goalsSection: some View {
        Section {
            goalField("Haftalık net hedef", text: $weeklyGoalText, identifier: "profile.weeklyGoal") { weeklyGoal = $0 }
            goalField("Günlük net hedef", text: $dailyGoalText, identifier: "profile.dailyGoal") { dailyGoal = $0 }
        } header: {
            Text("Hedefler")
        } footer: {
            Text("Bugün ekranındaki halka haftalık hedefi gösterir. Boş bırakırsan hedef kapalı olur.")
        }
    }

    private func goalField(_ title: String, text: Binding<String>, identifier: String, onValue: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .onChange(of: text.wrappedValue) { _, value in
                    onValue(value.nilIfBlank.flatMap(TurkishNumberParser.parseDecimal).map { max(0, $0) } ?? 0)
                }
                .accessibilityIdentifier(identifier)
            Text("₺").foregroundStyle(.secondary)
        }
    }

    // MARK: - Gider

    private var expenseSection: some View {
        Section {
            Toggle("Otomatik gider tahmini", isOn: $autoEstimate)
                .accessibilityIdentifier("settings.autoEstimate")
            HStack {
                Text("Km başına yakıt + bakım")
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
            Text("Net kazanç = brüt + bonus − giderler. Tahmin, kat edilen km × bu tutardır. Bir gün için yakıt veya bakım gideri girersen o günün tahmini kullanılmaz.")
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
            Text("Konum yalnızca “Vardiyayı başlat” ile başlattığın vardiya boyunca takip edilir (mesafe ve ilçe için), bitirince durur. “Uygulamayı kullanırken” izni de yeterlidir; vardiya ön planda başlatıldığında arka planda devam eder. Tam konum saklanmaz.")
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
                Text("Platform uygulamalarında günlük kazanç ekranının görüntüsünü al, sonra Bugün sekmesindeki “Kazanç taraması” düğmesine bas; son 24 saatin ekran görüntüleri okunur, bulunanları onaylayıp kaydedersin.")
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
            Text("Açıksa uygulama açıldığında son 48 saatin kazanç ekranı görüntüleri öneri olarak gösterilir. Görüntüler yalnızca cihazında işlenir.")
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

    // MARK: - Paylasim

    private var sharingSection: some View {
        Section {
            Toggle("Kazançlarımı anonim paylaş", isOn: Binding(
                get: { dataSharingOptIn },
                set: { newValue in
                    if newValue {
                        showConsentSheet = true // Acik onay olmadan acilmaz
                    } else {
                        // Riza anahtari ONCE yazilir; koordinator bekleyen vardiyalari buna gore siler
                        dataSharingOptIn = false
                        consentTimestamp = 0
                        locationSharingOptIn = false
                        locationConsentTimestamp = 0
                        sync.sharingConsentChanged(enabled: false)
                    }
                }
            ))
            .accessibilityIdentifier("settings.dataSharing")

            Toggle("Konum yoğunluğunu paylaş", isOn: Binding(
                get: { locationSharingOptIn },
                set: { newValue in
                    if newValue {
                        showLocationConsentSheet = true
                    } else {
                        locationSharingOptIn = false
                        locationConsentTimestamp = 0
                    }
                }
            ))
            .disabled(!dataSharingOptIn)
            .accessibilityIdentifier("profile.locationSharing")

            if dataSharingOptIn {
                LabeledContent("Son gönderim", value: lastSyncText)
                    .accessibilityIdentifier("profile.lastSync")
            }
        } header: {
            Text("Paylaşım")
        } footer: {
            Text("Açıkken, ekran görüntüsünden okunup değiştirilmeyen kazançlarının anonim vardiya özeti gönderilir; görselin kendisi, elle girilen ve düzeltilen kayıtlar gönderilmez. Kapatınca bekleyen gönderimler silinir. Konum yoğunluğu bu sürümde henüz gönderilmiyor; açarsan tercihin kaydedilir.")
        }
    }

    private var lastSyncText: String {
        guard let date = sync.lastSyncDate else { return "Henüz yok" }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Formatters.locale))
    }

    // MARK: - Veri

    private var dataSection: some View {
        Section {
            Button("Tüm kayıtları sil", role: .destructive) { showDeleteConfirmation = true }
                .accessibilityIdentifier("settings.deleteAll")
        } footer: {
            Text("Kayıtların telefonunda saklanır; Apple ile giriş yaparsan sunucuya da yedeklenir. Bu düğme yalnızca telefondaki kayıtları siler; sunucudaki veriler için Hesap ve yedek > “Verilerimi sil”i kullan.")
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
        weeklyGoalText = weeklyGoal > 0 ? TurkishNumberParser.format(weeklyGoal) : ""
        dailyGoalText = dailyGoal > 0 ? TurkishNumberParser.format(dailyGoal) : ""
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
