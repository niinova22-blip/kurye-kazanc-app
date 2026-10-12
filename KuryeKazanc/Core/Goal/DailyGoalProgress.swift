import Foundation

/// Bugun karti: aylik plandan gunluk pay ve bugun gerceklesen (secili firmadaki kayitlardan).
struct DailyGoalProgress: Equatable {
    var targetPackages: Int
    var targetHours: Decimal
    var targetNet: Money
    var packages: Int
    var net: Money

    var fraction: Double {
        guard targetPackages > 0 else { return net.value > 0 ? 1 : 0 }
        return min(1, Double(packages) / Double(targetPackages))
    }

    var remainingPackages: Int { max(0, targetPackages - packages) }

    static func today(plan: GoalPlan, entries: [EarningEntry], platform: String, day: String, fuel: FuelCostModel,
                      calendar: Calendar, now: Date) -> DailyGoalProgress {
        let todays: [EarningEntry] = entries.filter { $0.platformCode == platform && calendar.isDate($0.start, inSameDayAs: now) }
        var packages = 0
        var gross: Decimal = 0
        var km: Decimal = 0
        for entry in todays {
            packages += entry.packageCount ?? 0
            gross += Decimal(entry.gross + entry.bonus)
            km += Decimal(entry.distanceKm)
        }
        let net: Money = Money(Money.round(gross)) - fuel.cost(km: km, on: day)
        let days: Int = max(1, plan.workDays)
        let targetNet = Money(Money.round(plan.goal.monthlyTarget().value / Decimal(days)))
        return DailyGoalProgress(targetPackages: plan.packagesPerDay, targetHours: plan.hoursPerDay, targetNet: targetNet,
                                 packages: packages, net: net)
    }
}
