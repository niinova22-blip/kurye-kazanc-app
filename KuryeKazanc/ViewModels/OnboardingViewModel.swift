import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case vehicle, platforms, location
    }

    var step: Step = .vehicle
    var vehicleType: VehicleType = .motorcycle
    var selectedPlatformCodes: Set<String> = []
    /// 1.7: firma kurulumda secildiyse platform adimi atlanir.
    private(set) var skipsPlatforms = false
    /// 1.8: arac kurulumda (yakit adiminda) secildiyse arac adimi da atlanir; yalnizca konum kalir.
    private(set) var skipsVehicle = false

    func preselect(firm code: String, vehicle: VehicleType? = nil) {
        selectedPlatformCodes = [code]
        skipsPlatforms = true
        if let vehicle {
            vehicleType = vehicle
            skipsVehicle = true
            if step == .vehicle { step = .location }
        }
    }

    var canContinue: Bool {
        step == .platforms ? !selectedPlatformCodes.isEmpty : true
    }

    var isLastStep: Bool { step == .location }

    /// Gosterilen ilk adim (geri dugmesi gizlenir).
    var isFirstStep: Bool { visibleSteps.first == step }

    /// Atlanmayan adimlar (ilerleme noktalari icin).
    var visibleSteps: [Step] {
        Step.allCases.filter { !(($0 == .platforms && skipsPlatforms) || ($0 == .vehicle && skipsVehicle)) }
    }

    func next() {
        let steps: [Step] = visibleSteps
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    func back() {
        let steps: [Step] = visibleSteps
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
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
