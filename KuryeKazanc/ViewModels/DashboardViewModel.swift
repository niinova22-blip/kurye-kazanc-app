import Foundation
import Observation

/// Ana ekran durumu: gunluk ozet hesabi ve "Calisiyorum" modu.
///
/// Kayitlar View'da `@Query` ile canli izlenir (SwiftData degisikliklerinde otomatik yenilenir);
/// ViewModel bunlari alip saf `EarningsCalculator` ile ozete donusturur.
@MainActor
@Observable
final class DashboardViewModel {
    private let defaults: UserDefaults

    private(set) var isWorking: Bool
    private(set) var workSessionStart: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isWorking = defaults.bool(forKey: AppPreferences.isWorkingKey)
        self.workSessionStart = defaults.object(forKey: AppPreferences.workSessionStartKey) as? Date
    }

    // MARK: - Ozet

    func summary(
        earnings: [EarningRecord],
        expenses: [ExpenseRecord],
        costPerKm: Double,
        autoEstimate: Bool
    ) -> EarningsSummary {
        EarningsCalculator(costPerKm: costPerKm, autoEstimateEnabled: autoEstimate)
            .summarize(earnings: earnings.map(\.entry), expenses: expenses.map(\.entry))
    }

    // MARK: - Calisiyorum modu

    func toggleWorking(now: Date = .now) {
        isWorking.toggle()
        workSessionStart = isWorking ? now : nil
        defaults.set(isWorking, forKey: AppPreferences.isWorkingKey)
        defaults.set(workSessionStart, forKey: AppPreferences.workSessionStartKey)
        // TODO(konum): LocationService.startWorkSession()/stopWorkSession() burada cagrilacak.
        // Arka plan takibi yalnizca bu mod acikken calisir (pil tuketimini sinirlamak icin).
    }
}
