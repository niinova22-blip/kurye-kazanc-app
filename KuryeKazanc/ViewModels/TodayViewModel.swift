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

    /// Vardiya surerken canli net TL/saat tahmini: bugunun neti / (kayitli calisma + gecen vardiya suresi).
    /// Toplam 15 dakikadan azsa anlamsiz oldugundan nil.
    static func liveNetPerHour(todayNet: Double, workedSeconds: TimeInterval, elapsed: TimeInterval) -> Double? {
        let totalSeconds = max(0, workedSeconds) + max(0, elapsed)
        let hours = totalSeconds / 3600
        // Henuz kazanc yokken "~0 TL/saat" gostermek yaniltici
        guard hours >= 0.25, todayNet > 0 else { return nil }
        return todayNet / hours
    }

    /// Ice aktarma sonrasi kullaniciya gosterilecek kisa bildirimler (okunamayan / zaten kayitli gorseller).
    static func importNotices(failures: Int, duplicates: Int) -> [String] {
        var notices: [String] = []
        if failures > 0 {
            notices.append("\(failures) görsel okunamadı. Kazanç ekranının görüntüsünü paylaştığından emin ol.")
        }
        if duplicates == 1 {
            notices.append("Bu ekran görüntüsü zaten eklenmiş.")
        } else if duplicates > 1 {
            notices.append("\(duplicates) ekran görüntüsü zaten eklenmiş.")
        }
        return notices
    }
}
