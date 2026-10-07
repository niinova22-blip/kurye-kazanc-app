import SwiftUI
import SwiftData

/// Ilk acilis: arac tipi -> sik kullanilan platformlar -> konum bilgisi -> istege bagli anonim paylasim.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var location
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @State private var viewModel = OnboardingViewModel()
    @State private var errorMessage: String?
    @State private var showConsent = false
    @AppStorage(AppPreferences.dataSharingOptInKey) private var dataSharingOptIn = false
    @AppStorage(AppPreferences.dataSharingConsentDateKey) private var consentTimestamp: Double = 0

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            stepDots(current: vm.step)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch vm.step {
                    case .vehicle: vehicleStep
                    case .platforms: platformsStep
                    case .location: locationStep
                    case .sharing: sharingStep
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 12) {
                Button(vm.isLastStep ? "Başla" : "Devam") {
                    if vm.isLastStep { finish() } else { withAnimation { vm.next() } }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!vm.canContinue)
                .opacity(vm.canContinue ? 1 : 0.5)
                .accessibilityIdentifier("onboarding.next")

                if vm.step != .vehicle {
                    Button("Geri") { withAnimation { vm.back() } }
                        .accessibilityIdentifier("onboarding.back")
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showConsent) {
            DataSharingConsentView {
                dataSharingOptIn = true
                consentTimestamp = Date.now.timeIntervalSince1970
            }
        }
        .alert("Kaydedilemedi", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Adimlar

    private func stepDots(current: OnboardingViewModel.Step) -> some View {
        HStack(spacing: 8) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.self) { step in
                Circle()
                    .fill(step == current ? Theme.accent : Color(.tertiaryLabel))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Adım \(current.rawValue + 1) / \(OnboardingViewModel.Step.allCases.count)")
    }

    private var vehicleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Neyle çalışıyorsun?")
                .font(.title.bold())
            Text("Km başına yakıt ve bakım maliyetini tahmin etmek için kullanılır; ayarlardan değiştirebilirsin.")
                .foregroundStyle(.secondary)
            ForEach(VehicleType.allCases) { type in
                SelectableRow(
                    title: type.displayName,
                    subtitle: type.defaultCostPerKm > 0
                        ? "Varsayılan: \(Formatters.currency(type.defaultCostPerKm))/km"
                        : "Gider tahmini yok",
                    systemImage: type.symbolName,
                    isSelected: viewModel.vehicleType == type
                ) {
                    viewModel.vehicleType = type
                }
                .accessibilityIdentifier("onboarding.vehicle.\(type.rawValue)")
            }
        }
    }

    private var platformsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hangi platformlarda?")
                .font(.title.bold())
            Text("Birden fazla seçebilirsin. Kazanç eklerken bunlar önce gösterilir.")
                .foregroundStyle(.secondary)
            ForEach(platforms) { platform in
                SelectableRow(
                    title: platform.name,
                    subtitle: nil,
                    systemImage: viewModel.selectedPlatformCodes.contains(platform.code) ? "checkmark.square.fill" : "square",
                    isSelected: viewModel.selectedPlatformCodes.contains(platform.code)
                ) {
                    viewModel.togglePlatform(platform.code)
                }
                .accessibilityIdentifier("onboarding.platform.\(platform.code)")
            }
        }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
            Text("Konum yalnızca vardiyada")
                .font(.title.bold())
            Text("Vardiyayı başlattığında mesafeni ölçer, bitirince durur. Kayıtlara yalnızca ilçe eklenir.")
                .foregroundStyle(.secondary)

            if location.isAuthorized {
                Label("Konum izni verildi", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Button {
                    location.requestWhenInUseAuthorization()
                } label: {
                    Label("Konum iznini ver", systemImage: "location")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding.requestLocation")
                Text("İstersen şimdi geçip daha sonra Profil'den verebilirsin.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sharingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
            Text("Bölgendeki kuryelerle karşılaştır")
                .font(.title.bold())
            Text("Anonim paylaşıma katılırsan, topluluk özellikleri açıldığında ilçendeki saat başı ortalama net kazancı ve en yoğun saatleri görürsün. Yalnızca ekran görüntüsüyle doğrulanmış kazançlar kullanılır; adın ve tam konumun asla paylaşılmaz.")
                .foregroundStyle(.secondary)
            if dataSharingOptIn {
                Label("Katıldın — Profil'den istediğin an kapatabilirsin.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Button("Anonim paylaşıma katıl") { showConsent = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding.sharing")
                Text("İstersen geçebilirsin; uygulama paylaşım olmadan da tam çalışır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func finish() {
        do {
            try viewModel.complete(in: modelContext, platforms: platforms)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SelectableRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Theme.accent.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension VehicleType {
    var symbolName: String {
        switch self {
        case .motorcycle: "motorcycle"
        case .scooter: "scooter"
        case .bicycle: "bicycle"
        case .car: "car"
        case .onFoot: "figure.walk"
        }
    }
}
