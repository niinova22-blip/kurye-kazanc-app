import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(LocationService.self) private var location

    @Query private var couriers: [Courier]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @AppStorage(AppPreferences.dataSharingOptInKey) private var dataSharingOptIn = false
    @AppStorage(AppPreferences.dataSharingConsentDateKey) private var consentTimestamp: Double = 0

    @State private var costText = ""
    @State private var showConsentSheet = false
    @State private var showDeleteConfirmation = false

    private var courier: Courier? { couriers.first }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                expenseSection
                locationSection
                sharingSection
                dataSection
                aboutSection
            }
            .navigationTitle("Ayarlar")
            .onAppear { costText = TurkishNumberParser.format(costPerKm) }
            .sheet(isPresented: $showConsentSheet) {
                DataSharingConsentView {
                    dataSharingOptIn = true
                    consentTimestamp = Date.now.timeIntervalSince1970
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
            } else {
                Text("Profil bulunamadı").foregroundStyle(.secondary)
            }
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
            Text("Konum yalnızca “Çalışmaya başla” ile başlattığın oturum boyunca takip edilir (mesafe ve ilçe için), bitirince durur. “Uygulamayı kullanırken” izni de yeterlidir; oturum ön planda başlatıldığında arka planda devam eder. Tam konum saklanmaz.")
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

    // MARK: - Veri paylasimi

    private var sharingSection: some View {
        Section {
            Toggle("Anonim istatistik havuzuna katıl", isOn: Binding(
                get: { dataSharingOptIn },
                set: { newValue in
                    if newValue {
                        showConsentSheet = true // Acik onay olmadan acilmaz
                    } else {
                        dataSharingOptIn = false
                        consentTimestamp = 0
                    }
                }
            ))
            .accessibilityIdentifier("settings.dataSharing")

            if dataSharingOptIn, consentTimestamp > 0 {
                LabeledContent("Onay tarihi", value: Date(timeIntervalSince1970: consentTimestamp)
                    .formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Formatters.locale)))
            }
        } header: {
            Text("Veri paylaşımı")
        } footer: {
            Text("Varsayılan olarak kapalıdır. Bu sürümde hiçbir veri cihazından gönderilmez; onayın yalnızca kaydedilir. Paylaşım ileride başladığında yalnızca isimsiz kazanç/gider rakamları ve ilçe bilgisi, rastgele bir cihaz kimliğiyle paylaşılacak. İstediğin an kapatabilirsin.")
        }
    }

    // MARK: - Veri

    private var dataSection: some View {
        Section {
            Button("Tüm kayıtları sil", role: .destructive) { showDeleteConfirmation = true }
                .accessibilityIdentifier("settings.deleteAll")
        } footer: {
            Text("Tüm veriler yalnızca bu cihazda saklanır.")
        }
    }

    private var aboutSection: some View {
        Section("Hakkında") {
            LabeledContent("Sürüm", value: appVersion)
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
        try? modelContext.delete(model: EarningRecord.self)
        try? modelContext.delete(model: ExpenseRecord.self)
        try? modelContext.save()
    }
}

/// Acik onay ekrani: ne paylasilir, ne paylasilmaz.
private struct DataSharingConsentView: View {
    @Environment(\.dismiss) private var dismiss
    let onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Anonim istatistik havuzu")
                        .font(.title2.bold())
                    Text("Amaç: kuryelerin bölge ve platform bazında gerçek net kazançlarını görebilmesi.")
                        .foregroundStyle(.secondary)

                    GroupBox("Paylaşılacaklar") {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Kazanç, bonus, gider tutarları", systemImage: "checkmark")
                            Label("Çalışma süresi, mesafe, paket sayısı", systemImage: "checkmark")
                            Label("Platform ve ilçe/semt", systemImage: "checkmark")
                            Label("Rastgele cihaz kimliği (seninle ilişkilendirilemez)", systemImage: "checkmark")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Asla paylaşılmayacaklar") {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Adın ve profil bilgilerin", systemImage: "xmark")
                            Label("Tam konumun veya güzergâhın", systemImage: "xmark")
                            Label("Telefon numarası, e-posta, Apple kimliği", systemImage: "xmark")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Bu sürümde veri gönderimi henüz yok; onayın kaydedilir. Ayarlar'dan istediğin an geri alabilirsin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Onaylıyorum") {
                        onAccept()
                        dismiss()
                    }
                    .accessibilityIdentifier("consent.accept")
                }
            }
        }
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
