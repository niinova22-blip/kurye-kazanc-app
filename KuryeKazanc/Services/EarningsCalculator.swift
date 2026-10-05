import Foundation

/// Hesaplamada kullanilan, SwiftData'dan bagimsiz kazanc verisi (birim testlerde model container gerektirmez).
struct EarningEntry: Equatable {
    var start: Date
    var end: Date
    var gross: Double
    var bonus: Double
    var distanceKm: Double
    var platformCode: String?
}

/// Hesaplamada kullanilan, SwiftData'dan bagimsiz gider verisi.
struct ExpenseEntry: Equatable {
    var type: ExpenseType
    var amount: Double
}

/// Bir zaman araligi (gun, hafta, ay) icin hesaplanmis ozet.
struct EarningsSummary: Equatable {
    var grossEarnings: Double
    var bonusEarnings: Double
    var manualExpenses: Double
    var estimatedExpenses: Double
    var workDuration: TimeInterval
    var distanceKm: Double

    var totalEarnings: Double { grossEarnings + bonusEarnings }
    var totalExpenses: Double { manualExpenses + estimatedExpenses }
    var netEarnings: Double { totalEarnings - totalExpenses }
    var workHours: Double { workDuration / 3600 }

    /// Net TL/saat. Calisma suresi yoksa `nil` (sifira bolme yerine "—" gosterilir).
    var netPerHour: Double? {
        guard workDuration > 0 else { return nil }
        return netEarnings / workHours
    }

    var usesEstimatedExpenses: Bool { estimatedExpenses > 0 }

    static let empty = EarningsSummary(
        grossEarnings: 0, bonusEarnings: 0, manualExpenses: 0,
        estimatedExpenses: 0, workDuration: 0, distanceKm: 0
    )

    static func + (lhs: EarningsSummary, rhs: EarningsSummary) -> EarningsSummary {
        EarningsSummary(
            grossEarnings: lhs.grossEarnings + rhs.grossEarnings,
            bonusEarnings: lhs.bonusEarnings + rhs.bonusEarnings,
            manualExpenses: lhs.manualExpenses + rhs.manualExpenses,
            estimatedExpenses: lhs.estimatedExpenses + rhs.estimatedExpenses,
            workDuration: lhs.workDuration + rhs.workDuration,
            distanceKm: lhs.distanceKm + rhs.distanceKm
        )
    }
}

extension Sequence where Element == EarningsSummary {
    var total: EarningsSummary { reduce(.empty, +) }
}

/// Net kazanc hesaplama kurallari.
///
/// Net TL/saat = (brut kazanc + bonus - giderler) / toplam calisma suresi
///
/// Kurallar:
/// 1. Calisma suresi, kayitlarin zaman araliklarinin BIRLESIMIDIR. Kurye ayni anda birden fazla
///    platformda calisabilir (or. Trendyol GO + Getir); cakisan saatler iki kez sayilmaz.
/// 2. Gider = manuel giderler + (gerekiyorsa) km basina otomatik tahmin.
///    Otomatik tahmin yalnizca yakit+bakimi kapsar; ayni donemde manuel yakit veya bakim gideri
///    girilmisse tahmin uygulanmaz (cift sayim olmaz). Lastik/amortisman/diger her zaman eklenir.
struct EarningsCalculator {
    /// Km basina yakit + bakim maliyeti (TL).
    var costPerKm: Double
    /// Otomatik tahmin kapali ise yalnizca manuel giderler kullanilir.
    var autoEstimateEnabled: Bool = true

    func summarize(earnings: [EarningEntry], expenses: [ExpenseEntry]) -> EarningsSummary {
        let gross = earnings.reduce(0) { $0 + $1.gross }
        let bonus = earnings.reduce(0) { $0 + $1.bonus }
        let distance = earnings.reduce(0) { $0 + max(0, $1.distanceKm) }
        let manual = expenses.reduce(0) { $0 + max(0, $1.amount) }

        return EarningsSummary(
            grossEarnings: gross,
            bonusEarnings: bonus,
            manualExpenses: manual,
            estimatedExpenses: estimatedExpense(distanceKm: distance, manualExpenses: expenses),
            workDuration: Self.mergedDuration(of: earnings.map { (start: $0.start, end: $0.end) }),
            distanceKm: distance
        )
    }

    func estimatedExpense(distanceKm: Double, manualExpenses: [ExpenseEntry]) -> Double {
        guard autoEstimateEnabled, costPerKm > 0, distanceKm > 0 else { return 0 }
        let hasManualPerKmExpense = manualExpenses.contains { $0.type.isCoveredByPerKmEstimate }
        return hasManualPerKmExpense ? 0 : distanceKm * costPerKm
    }

    /// Cakisan araliklari birlestirerek toplam sureyi hesaplar.
    static func mergedDuration(of intervals: [(start: Date, end: Date)]) -> TimeInterval {
        let valid = intervals
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }

        var total: TimeInterval = 0
        var current: (start: Date, end: Date)?

        for interval in valid {
            if let c = current, interval.start <= c.end {
                current = (start: c.start, end: max(c.end, interval.end))
            } else {
                if let c = current { total += c.end.timeIntervalSince(c.start) }
                current = interval
            }
        }
        if let c = current { total += c.end.timeIntervalSince(c.start) }
        return total
    }

    /// Birden fazla gunu kapsayan donem (hafta/ay) icin ozet.
    /// Gider tahmini kurali GUN BAZINDA uygulanir: bir gun manuel yakit girilmisse yalnizca o gunun tahmini duser.
    func summarizeByDay(
        earnings: [(day: Date, entry: EarningEntry)],
        expenses: [(day: Date, entry: ExpenseEntry)]
    ) -> [Date: EarningsSummary] {
        let earningsByDay = Dictionary(grouping: earnings, by: { $0.day })
        let expensesByDay = Dictionary(grouping: expenses, by: { $0.day })
        let allDays = Set(earningsByDay.keys).union(expensesByDay.keys)

        var result: [Date: EarningsSummary] = [:]
        for day in allDays {
            result[day] = summarize(
                earnings: earningsByDay[day]?.map { $0.entry } ?? [],
                expenses: expensesByDay[day]?.map { $0.entry } ?? []
            )
        }
        return result
    }

    /// Platform koduna gore toplam kazanc (brut + bonus). Platformu olmayan kayitlar "other" altinda toplanir.
    static func totalsByPlatform(_ earnings: [EarningEntry]) -> [String: Double] {
        earnings.reduce(into: [:]) { result, entry in
            result[entry.platformCode ?? "other", default: 0] += entry.gross + entry.bonus
        }
    }
}

// MARK: - SwiftData modellerinden donusum

extension EarningRecord {
    var entry: EarningEntry {
        EarningEntry(
            start: startTime, end: endTime, gross: grossEarning, bonus: bonus,
            distanceKm: distanceKm, platformCode: platform?.code
        )
    }
}

extension ExpenseRecord {
    var entry: ExpenseEntry { ExpenseEntry(type: type, amount: amount) }
}
