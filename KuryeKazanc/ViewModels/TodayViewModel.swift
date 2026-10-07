import Foundation

/// Bugun ekrani ozet hesabi.
///
/// Kayitlar View'da `@Query` ile canli izlenir (SwiftData degisikliklerinde otomatik yenilenir);
/// burada saf `EarningsCalculator` ile ozete donusturulur. Vardiya `WorkSessionManager`'dadir.
enum TodayViewModel {
    static func summary(
        earnings: [EarningRecord],
        expenses: [ExpenseRecord],
        costPerKm: Double,
        autoEstimate: Bool
    ) -> EarningsSummary {
        EarningsCalculator(costPerKm: costPerKm, autoEstimateEnabled: autoEstimate)
            .summarize(earnings: earnings.map(\.entry), expenses: expenses.map(\.entry))
    }

    /// Haftalik net hedef ilerlemesi (gun gun ozetlenir ki yakit girilen gunlerde tahmin dusulmesin).
    static func weekGoal(
        target: Double,
        earnings: [EarningRecord],
        expenses: [ExpenseRecord],
        calculator: EarningsCalculator
    ) -> GoalProgress {
        let daily = calculator.summarizeByDay(
            earnings: earnings.map { (day: $0.date, entry: $0.entry) },
            expenses: expenses.map { (day: $0.date, entry: $0.entry) }
        )
        return GoalProgress(target: target, achieved: daily.values.total.netEarnings)
    }
}
