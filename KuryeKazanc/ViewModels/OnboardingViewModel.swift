import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case vehicle, platforms, location, sharing
    }

    var step: Step = .vehicle
    var vehicleType: VehicleType = .motorcycle
    var selectedPlatformCodes: Set<String> = []
    /// 1.7: firma kurulumda secildiyse platform adimi atlanir.
    private(set) var skipsPlatforms = false

    func preselect(firm code: String) {
        selectedPlatformCodes = [code]
        skipsPlatforms = true
    }

    var canContinue: Bool {
        step == .platforms ? !selectedPlatformCodes.isEmpty : true
    }

    var isLastStep: Bool { step == .sharing }

    func next() {
        guard var next = Step(rawValue: step.rawValue + 1) else { return }
        if next == .platforms, skipsPlatforms, let after = Step(rawValue: next.rawValue + 1) { next = after }
        step = next
    }

    func back() {
        guard var previous = Step(rawValue: step.rawValue - 1) else { return }
        if previous == .platforms, skipsPlatforms, let before = Step(rawValue: previous.rawValue - 1) { previous = before }
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
        // Isim onboarding'de sorulmaz; Profil'den degistirilebilir
        if courier.name.nilIfBlank == nil { courier.name = "Kurye" }
        courier.vehicleType = vehicleType
        courier.defaultPlatforms = chosen
        try context.save()

        defaults.set(vehicleType.defaultCostPerKm, forKey: AppPreferences.costPerKmKey)
        defaults.set(true, forKey: AppPreferences.hasCompletedOnboardingKey)
    }
}
