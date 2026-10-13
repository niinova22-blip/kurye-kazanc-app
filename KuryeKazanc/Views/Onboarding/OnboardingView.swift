import SwiftUI
import SwiftData

/// Kurulumun son kismi: (kurulumda secildiyse atlanan) arac tipi ve platformlar -> konum bilgisi.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var location
    @Environment(AutoShiftCoordinator.self) private var autoShift
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @Environment(PayrollModel.self) private var payroll

    @State private var viewModel = OnboardingViewModel()
    @State private var errorMessage: String?
    @State private var showAutoShiftIntro = false

    // Derleyicinin tip denetimi zaman asimina ugramasin diye govde kucuk parcalara bolundu.
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.visibleSteps.count > 1 {
                stepDots(current: viewModel.step)
                    .padding(.top, 16)
            }

            ScrollView {
                stepContent
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            bottomButtons
                .padding(24)
        }
        .onAppear {
            guard let profile = payroll.tariffProfile else { return }
            let vehicle: VehicleType? = switch profile.vehicleType ?? "" {
            case "car": .car
            case "motorcycle": .motorcycle
            default: nil
            }
            viewModel.preselect(firm: profile.platformCode, vehicle: vehicle)
        }
        .sheet(isPresented: $showAutoShiftIntro) {
            AutoShiftIntroView {
                let coordinator: AutoShiftCoordinator = autoShift
                Task { _ = await coordinator.enable() }
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

    // MARK: - Iskelet

    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch viewModel.step {
            case .vehicle: vehicleStep
            case .platforms: platformsStep
            case .location: locationStep
            }
        }
    }

    /// Alt kisimda tek elle ulasilan dugmeler.
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Button(viewModel.isLastStep ? "Başla" : "Devam") {
                advance()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!viewModel.canContinue)
            .opacity(viewModel.canContinue ? 1 : 0.5)
            .accessibilityIdentifier("onboarding.next")

            if !viewModel.isFirstStep {
                Button("Geri") { withAnimation { viewModel.back() } }
                    .accessibilityIdentifier("onboarding.back")
            }
        }
    }

    private func advance() {
        if viewModel.isLastStep {
            finish()
        } else {
            withAnimation { viewModel.next() }
        }
    }

    // MARK: - Adimlar

    private func stepDots(current: OnboardingViewModel.Step) -> some View {
        HStack(spacing: 8) {
            ForEach(viewModel.visibleSteps, id: \.self) { step in
                Circle()
                    .fill(step == current ? Theme.accent : Color(.tertiaryLabel))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Adım \((viewModel.visibleSteps.firstIndex(of: current) ?? 0) + 1) / \(viewModel.visibleSteps.count)")
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
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Konum yalnızca vardiyada")
                .font(.title.bold())
            Text("Vardiya sürerken km ve yakıtı ölçer, paketin mesafe bandını ve şehrine göre tarifeyi bulur; vardiya bitince durur. Kayıtlara yalnızca ilçe eklenir.")
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
                Text("İzin vermezsen paketler sayılır ama km, yakıt ve mesafe ek ödemesi hesaplanamaz.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            autoShiftOption
        }
        // 1.9: izin bu adima gelince dogrudan sorulur (km, yakit ve bolge tarifesi icin gerekli)
        .onAppear {
            if location.authorizationStatus == .notDetermined { location.requestWhenInUseAuthorization() }
        }
    }

    /// Istege bagli: otomatik vardiya aciklamasi; onayda izinler istenir.
    @ViewBuilder
    private var autoShiftOption: some View {
        if autoShift.isEnabled {
            Label("Otomatik vardiya açık", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
        } else {
            Button {
                showAutoShiftIntro = true
            } label: {
                Label("Otomatik vardiyayı aç (isteğe bağlı)", systemImage: "scooter")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("onboarding.autoShift")
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
                    .frame(minWidth: 28)
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
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
