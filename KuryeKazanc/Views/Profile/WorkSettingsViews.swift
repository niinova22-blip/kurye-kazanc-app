import SwiftUI
import SwiftData

/// Saatte kac paket: kurulum ve Profil > Çalışma hızın ayni seciciyi kullanir.
struct PaceStepper: View {
    @Binding var value: Decimal
    let identifier: String

    var body: some View {
        DecimalStepper(title: "Hızın", value: $value, range: PaceEstimate.userRange, step: Decimal(string: "0.1")!,
                       unit: "paket/sa", identifier: identifier)
    }
}

/// Profil > Çalışma hızın (1.12): plan ve hedef hesaplarinin dayandigi paket / saat.
struct PaceSettingsView: View {
    @Environment(PayrollModel.self) private var payroll
    @Query private var records: [EarningRecord]
    @State private var pace: Decimal = PaceEstimate.defaultPackagesPerHour
    @State private var loaded = false

    var body: some View {
        let measured: PaceEstimate = payroll.measuredPace(entries: records.map(\.entry))
        List {
            Section {
                PaceStepper(value: $pace, identifier: "paceSettings.pace")
                    .onChange(of: pace) { _, value in
                        if loaded { payroll.setPackagesPerHour(value) }
                    }
            } header: {
                Text("Saatte kaç paket atıyorsun?")
            } footer: {
                Text("Hedefe kaç saatte ve kaç günde ulaşacağın, Bugün'deki günlük hedef ve bildirimler bu hızla hesaplanır.")
            }
            Section("Kayıtlarına göre") {
                if measured.isAssumed {
                    Text("Henüz yeterli kayıt yok (son 8 haftada en az 5 kayıt ve 10 saat gerekir).")
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Ölçülen hız", value: "\(Formatters.decimalText(measured.packagesPerHour)) paket/sa")
                    if measured.packagesPerHour != pace {
                        Button("Ölçülen hızı kullan") { pace = measured.packagesPerHour }
                            .accessibilityIdentifier("paceSettings.useMeasured")
                    }
                }
            }
        }
        .navigationTitle("Çalışma hızın")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            pace = payroll.state.packagesPerHour ?? PaceEstimate.defaultPackagesPerHour
            // onChange ilk atamada tetiklenmesin
            DispatchQueue.main.async { loaded = true }
        }
    }
}

/// Profil > Çalıştığın bölge (1.12): vardiya konumdan bulur; elle hesap yapan kullanici buradan degistirir.
struct RegionSettingsView: View {
    @Environment(PayrollModel.self) private var payroll
    @Environment(LocationService.self) private var location
    @State private var message: String?
    @State private var isLocating = false

    private var platform: String { payroll.tariffProfile?.platformCode ?? "" }
    private var tiers: [String] { payroll.questions(for: platform).regionTiers }

    var body: some View {
        List {
            if tiers.isEmpty {
                Section {
                    Text("Bu firmanın tarifesi bölgeye göre değişmiyor.").foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(tiers, id: \.self) { tier in
                        Button { choose(tier) } label: { row(tier) }
                            .accessibilityIdentifier("regionSettings.\(tier)")
                    }
                } header: {
                    Text(PayrollModel.platformName(platform))
                } footer: {
                    Text("Elle hesap ve plan bu bölgenin ücretiyle yapılır. Vardiya başlayınca konumundan yeniden bulunur.")
                }
                Section {
                    Button(action: locate) {
                        HStack {
                            Label("Konumumdan bul", systemImage: "location")
                            if isLocating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLocating)
                    .accessibilityIdentifier("regionSettings.locate")
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Çalıştığın bölge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ tier: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(TariffQuestions.regionName(tier)).foregroundStyle(.primary)
                let detail: String = TariffQuestions.regionDetail(tier)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
            }
            Spacer()
            if payroll.state.regionTier == tier {
                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
            }
        }
    }

    private func choose(_ tier: String) {
        payroll.setRegionTier(tier)
        message = nil
        Haptics.selection()
    }

    private func locate() {
        isLocating = true
        Task { @MainActor in
            defer { isLocating = false }
            guard let place = await location.currentRegion() else {
                message = location.isAuthorized ? "Konum bulunamadı, listeden seç." : "Konum izni yok, listeden seç."
                return
            }
            guard let profile = payroll.tariffProfile,
                  let suggestion = RegionResolver.suggest(province: place.province, district: place.district,
                                                          neighborhood: place.neighborhood, profile: profile) else {
                message = "\(place.displayText): bölge bulunamadı, listeden seç."
                return
            }
            payroll.applyRegion(suggestion)
            if suggestion.needsRegionChoice {
                message = "\(place.displayText): semtin kesin değil, listeden seç."
            } else {
                message = suggestion.message ?? "\(place.displayText): bölgen zaten doğru."
            }
        }
    }
}
