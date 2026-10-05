import SwiftUI
import SwiftData

/// Ilk acilis: profil (isim) -> arac tipi -> sik kullanilan platformlar -> konum izni bilgisi.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var location
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @State private var viewModel = OnboardingViewModel()
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            ProgressView(value: Double(vm.step.rawValue + 1), total: Double(OnboardingViewModel.Step.allCases.count))
                .padding(.horizontal, 24)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch vm.step {
                    case .welcome: welcomeStep
                    case .vehicle: vehicleStep
                    case .platforms: platformsStep
                    case .permissions: permissionsStep
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if vm.step != .welcome {
                    Button("Geri") { withAnimation { vm.back() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("onboarding.back")
                }
                Spacer()
                Button {
                    if vm.isLastStep { finish() } else { withAnimation { vm.next() } }
                } label: {
                    Text(vm.isLastStep ? "Bitir" : "Devam")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!vm.canContinue)
                .accessibilityIdentifier("onboarding.next")
            }
            .padding(24)
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

    private var welcomeStep: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "scooter")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Kurye Kazanç'a hoş geldin")
                .font(.largeTitle.bold())
            Text("Brüt değil, **net** kazancını gör: yakıt ve bakım giderleri düşülmüş saatlik kazancın, platform platform.")
                .foregroundStyle(.secondary)
            TextField("Adın (isteğe bağlı)", text: $vm.name)
                .textFieldStyle(.roundedBorder)
                .textContentType(.givenName)
                .accessibilityIdentifier("onboarding.name")
            Text("Adın yalnızca bu cihazda kalır, hiçbir yere gönderilmez.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var vehicleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aracın ne?")
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
            Text("Hangi platformlarda çalışıyorsun?")
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

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Konum yalnızca çalışırken")
                .font(.title.bold())
            VStack(alignment: .leading, spacing: 10) {
                Label("“Çalışmaya başla” dediğinde mesafeni ölçer, bitirince durur.", systemImage: "play.circle")
                Label("Kayıtlara yalnızca ilçe/semt eklenir; tam konum saklanmaz.", systemImage: "mappin.and.ellipse")
                Label("Konum verisi cihazından çıkmaz.", systemImage: "lock")
            }
            .foregroundStyle(.secondary)

            if location.isAuthorized {
                Label("Konum izni verildi", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    location.requestWhenInUseAuthorization()
                } label: {
                    Label("Konum iznini ver", systemImage: "location")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding.requestLocation")
                Text("İstersen şimdi geçip daha sonra Ayarlar'dan verebilirsin.")
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
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
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
