import Foundation

/// Ana ekran ozet hesabi.
///
/// Kayitlar View'da `@Query` ile canli izlenir (SwiftData degisikliklerinde otomatik yenilenir);
/// burada saf `EarningsCalculator` ile ozete donusturulur. "Calisiyorum" modu `WorkSessionManager`'dadir.
enum DashboardViewModel {
    static func summary(
        earnings: [EarningRecord],
        expenses: [ExpenseRecord],
        costPerKm: Double,
        autoEstimate: Bool
    ) -> EarningsSummary {
        EarningsCalculator(costPerKm: costPerKm, autoEstimateEnabled: autoEstimate)
            .summarize(earnings: earnings.map(\.entry), expenses: expenses.map(\.entry))
    }
}
