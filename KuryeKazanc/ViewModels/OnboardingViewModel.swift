import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, vehicle, platforms, permissions
    }

    var step: Step = .welcome
    var name = ""
    var vehicleType: VehicleType = .motorcycle
    var selectedPlatformCodes: Set<String> = []

    var canContinue: Bool {
        switch step {
        case .welcome, .vehicle, .permissions: true
        case .platforms: !selectedPlatformCodes.isEmpty
        }
    }

    var isLastStep: Bool { step == .permissions }

    func next() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func togglePlatform(_ code: String) {
        if selectedPlatformCodes.contains(code) {
            selectedPlatformCodes.remove(code)
        } else {
            selectedPlatformCodes.insert(code)
        }
    }

    /// Profili olusturur, km basina maliyeti arac tipine gore ayarlar ve onboarding'i kapatir.
    func complete(in context: ModelContext, platforms: [Platform], defaults: UserDefaults = .standard) throws {
        let chosen = platforms
            .filter { selectedPlatformCodes.contains($0.code) }
            .sorted { $0.sortOrder < $1.sortOrder }

        let existing = (try? context.fetch(FetchDescriptor<Courier>())) ?? []
        let courier = existing.first ?? {
            let new = Courier(name: "", vehicleType: vehicleType)
            context.insert(new)
            return new
        }()
        courier.name = name.nilIfBlank ?? "Kurye"
        courier.vehicleType = vehicleType
        courier.defaultPlatforms = chosen
        try context.save()

        defaults.set(vehicleType.defaultCostPerKm, forKey: AppPreferences.costPerKmKey)
        defaults.set(true, forKey: AppPreferences.hasCompletedOnboardingKey)
    }
}
