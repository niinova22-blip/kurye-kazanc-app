import Foundation

/// Ayni hedefe giden baska bir yol: daha az toplam saat, daha az gun ya da kademe bonusuyla daha yuksek net.
struct GoalAlternative: Identifiable, Equatable {
    enum Kind: String, Equatable {
        /// Haftalik gun sayisini degistir (ayni hedef).
        case days
        /// Gunluk / haftalik bonus esigini hedefle; hedefe daha az gunde ulas.
        case bonusPace
        /// Bir sonraki aylik kademeye cik; ek bonusla neti artir.
        case nextTier
        /// Paketlerin bir kismini daha yuksek ucretli aksam bandinda yap.
        case evening
    }

    var id: String
    var kind: Kind
    var title: String
    var detail: String
    var daysPerWeek: Int
    var packagesPerDay: Int
    var hoursPerDay: Decimal
    /// Ayda toplam calisma saati.
    var monthlyHours: Decimal
    /// Aylik net (yakit dusulmus).
    var net: Money
    /// Mevcut plana gore ayda kac saat daha az (negatif: daha fazla).
    var hoursSaved: Decimal
    /// Mevcut plana gore aylik net farki.
    var extraNet: Money

    /// Saat basina net (ayda calisilan saat uzerinden).
    var netPerHour: Money {
        guard monthlyHours > 0 else { return .zero }
        return Money(Money.round(net.value / monthlyHours))
    }
}

/// Secilen hedef icin alternatif senaryolar. Hepsi ayni tarife ve ayni hizla hesaplanir; yalnizca hedefe ulasan
/// (ya da kademe atlayarak neti belirgin artiran) yollar onerilir. En fazla `limit` oneri, en cok saat kazandirandan.
enum GoalAlternatives {
    /// Gunde calisilabilecek ust sinir (oneriler bunu asmaz).
    static let maxHoursPerDay: Decimal = 12

    static func suggest(base: GoalPlan, planner: GoalPlanner, profile: CourierTariffProfile, pace: PaceEstimate,
                        day: String, limit: Int = 3) -> [GoalAlternative] {
        guard pace.packagesPerHour > 0 else { return [] }
        let baseHours: Decimal = base.reachability == .alreadyMet ? 0 : base.hoursPerDay * Decimal(base.workDays)
        let baseReached: Bool = base.reachability == .reachable || base.reachability == .alreadyMet
        guard base.reachability != .alreadyMet else { return [] }

        var found: [GoalAlternative] = []
        found += dayOptions(base: base, planner: planner, profile: profile, pace: pace, day: day, baseHours: baseHours,
                            baseReached: baseReached)
        if let bonus = bonusPaceOption(base: base, planner: planner, profile: profile, pace: pace, day: day,
                                       baseHours: baseHours, baseReached: baseReached) {
            found.append(bonus)
        }
        if let tier = nextTierOption(base: base, planner: planner, profile: profile, pace: pace, day: day, baseHours: baseHours) {
            found.append(tier)
        }
        if let evening = eveningOption(base: base, planner: planner, profile: profile, pace: pace, day: day,
                                       baseHours: baseHours, baseReached: baseReached) {
            found.append(evening)
        }
        let sorted: [GoalAlternative] = found.sorted { a, b in
            if a.hoursSaved != b.hoursSaved { return a.hoursSaved > b.hoursSaved }
            return a.extraNet > b.extraNet
        }
        return Array(sorted.prefix(limit))
    }

    // MARK: - Gun sayisi

    private static func dayOptions(base: GoalPlan, planner: GoalPlanner, profile: CourierTariffProfile, pace: PaceEstimate,
                                   day: String, baseHours: Decimal, baseReached: Bool) -> [GoalAlternative] {
        guard base.goal.period != .day else { return [] }
        var options: [GoalAlternative] = []
        for days in [5, 6, 7] where days != base.goal.daysPerWeek {
            let goal = GoalSpec(amount: base.goal.amount, period: base.goal.period, daysPerWeek: days,
                                maxHoursPerDay: max(base.goal.maxHoursPerDay, maxHoursPerDay))
            guard case let .success(plan) = planner.plan(goal: goal, profile: profile, pace: pace, day: day),
                  plan.reachability == .reachable, plan.hoursPerDay <= maxHoursPerDay else { continue }
            let hours: Decimal = plan.hoursPerDay * Decimal(plan.workDays)
            let saved: Decimal = baseHours - hours
            let fewerDays: Bool = days < base.goal.daysPerWeek
            // Daha az gun: gunluk sure makul kalmali. Daha cok gun: ya ulasilamayan hedefi ulasilir yapmali ya da gunu kisaltmali.
            if baseReached {
                if fewerDays, plan.hoursPerDay > base.goal.maxHoursPerDay { continue }
                if !fewerDays, base.hoursPerDay - plan.hoursPerDay < 1 { continue }
            }
            let title: String = "Haftada \(days) gün çalış"
            let detail: String
            if fewerDays {
                detail = "Günde \(plan.packagesPerDay) paket, yaklaşık \(Formatters.decimalText(plan.hoursPerDay)) saat; haftada \(base.goal.daysPerWeek - days) gün daha fazla izin."
            } else if !baseReached {
                detail = "Günde \(plan.packagesPerDay) paket, yaklaşık \(Formatters.decimalText(plan.hoursPerDay)) saatle hedefe ulaşırsın."
            } else {
                detail = "Günler kısalır: günde \(plan.packagesPerDay) paket, yaklaşık \(Formatters.decimalText(plan.hoursPerDay)) saat."
            }
            options.append(alternative("days.\(days)", .days, title, detail, plan: plan, baseHours: baseHours, base: base))
        }
        return options
    }

    // MARK: - Gunluk / haftalik bonus esigi

    /// Gun birimli kademe (or. gunluk 42 paket bonusu) ya da haftalik kademe: esige gore gunluk paket sabitlenir,
    /// hedefe yeten en az gun bulunur. Mevcut plandan az saat tutan en iyi secenek.
    private static func bonusPaceOption(base: GoalPlan, planner: GoalPlanner, profile: CourierTariffProfile,
                                        pace: PaceEstimate, day: String, baseHours: Decimal, baseReached: Bool) -> GoalAlternative? {
        guard base.goal.period != .day,
              let version = planner.engine.catalog.versions.first(where: { $0.id == base.breakdown.tariffVersionID }) else { return nil }
        let items: [TariffItem] = version.activeItems(on: day)
        let maxPerDay: Int = NSDecimalNumber(decimal: pace.packagesPerHour * maxHoursPerDay).intValue
        var perDayTargets: Set<Int> = []
        for item in items {
            guard let lower = item.lowerThreshold else { continue }
            let threshold: Int = PayEngine.decimalInt(lower)
            if GoalPlanner.isPlannableTier(item, unit: .day, flags: profile.flags) {
                perDayTargets.insert(threshold)
            } else if GoalPlanner.isPlannableTier(item, unit: .week, flags: profile.flags), item.conditions.weekdays == nil {
                for days in 1...7 { perDayTargets.insert(Int((Double(threshold) / Double(days)).rounded(.up))) }
            }
        }
        let target: Money = base.goal.monthlyTarget()
        var best: GoalAlternative?
        for perDay in perDayTargets.sorted() where perDay > base.packagesPerDay && perDay <= maxPerDay {
            for days in 1...7 {
                let workDays: Int = GoalSpec.monthWorkDays(daysPerWeek: days)
                guard case let .success(eval) = planner.evaluate(packages: perDay * workDays, profile: profile, pace: pace,
                                                                 day: day, daysPerWeek: days),
                      !(eval.net < target) else { continue }
                let hoursPerDay: Decimal = GoalPlanner.roundUpToHalf(Decimal(perDay) / pace.packagesPerHour)
                let hours: Decimal = hoursPerDay * Decimal(workDays)
                let saved: Decimal = baseHours - hours
                guard !baseReached || saved > 0 else { break }
                if let current = best, current.hoursSaved >= saved { break }
                let bonusText: String = eval.breakdown.lines.contains { $0.type == .dailyBonus } ? "günlük bonusu" : "haftalık bonusu"
                best = GoalAlternative(
                    id: "bonus.\(perDay)", kind: .bonusPace, title: "Günde \(perDay) paket yap, \(bonusText) al",
                    detail: "Haftada \(days) gün, günde yaklaşık \(Formatters.decimalText(hoursPerDay)) saat yeter; bonus sayesinde hedefe daha az günde ulaşırsın.",
                    daysPerWeek: days, packagesPerDay: perDay, hoursPerDay: hoursPerDay, monthlyHours: hours, net: eval.net,
                    hoursSaved: saved, extraNet: eval.net - base.net)
                break
            }
        }
        return best
    }

    // MARK: - Sonraki aylik kademe

    /// Aylik kademe (Paket Taxi 1.700 paket bonusu gibi): ulasilabiliyorsa ek paket basina net kazanc belirgin yuksekse.
    private static func nextTierOption(base: GoalPlan, planner: GoalPlanner, profile: CourierTariffProfile,
                                       pace: PaceEstimate, day: String, baseHours: Decimal) -> GoalAlternative? {
        guard let progress = base.breakdown.progress.first(where: { $0.unit == .month && $0.target > base.monthlyPackages })
        else { return nil }
        let threshold: Int = progress.target
        let workDays: Int = base.workDays
        guard workDays > 0 else { return nil }
        let perDay: Int = Int((Double(threshold) / Double(workDays)).rounded(.up))
        let hoursPerDay: Decimal = GoalPlanner.roundUpToHalf(Decimal(perDay) / pace.packagesPerHour)
        guard hoursPerDay <= maxHoursPerDay,
              case let .success(eval) = planner.evaluate(packages: threshold, profile: profile, pace: pace, day: day,
                                                         daysPerWeek: base.goal.daysPerWeek) else { return nil }
        let extraNet: Money = eval.net - base.net
        let extraPackages: Int = threshold - base.monthlyPackages
        guard extraNet.value > 0, extraPackages > 0 else { return nil }
        // Ek paket basina net, mevcut planin paket basina netinden belirgin (≥ %50) yuksek olmali
        let basePerPackage: Decimal = base.monthlyPackages > 0 ? base.packageIncome.value / Decimal(base.monthlyPackages) : 0
        let extraPerPackage: Decimal = extraNet.value / Decimal(extraPackages)
        guard extraPerPackage > basePerPackage * Decimal(string: "1.5")! || basePerPackage == 0 else { return nil }
        let hours: Decimal = hoursPerDay * Decimal(workDays)
        return GoalAlternative(
            id: "tier.\(threshold)", kind: .nextTier, title: "Ayda \(Formatters.groupedInt(threshold)) pakete çık",
            detail: "\(Formatters.groupedInt(extraPackages)) paket daha (günde \(perDay) paket, yaklaşık \(Formatters.decimalText(hoursPerDay)) saat) ile \(progress.label.lowercased()) kazanılır; ayda \(Formatters.currency(extraNet.doubleValue)) daha fazla net.",
            daysPerWeek: base.goal.daysPerWeek, packagesPerDay: perDay, hoursPerDay: hoursPerDay, monthlyHours: hours,
            net: eval.net, hoursSaved: baseHours - hours, extraNet: extraNet)
    }

    // MARK: - Aksam bandi

    /// Tarifede gece / aksam paket ucreti gunduzden yuksekse: paketlerin yarisi aksam bandinda yapilirsa gereken paket.
    private static func eveningOption(base: GoalPlan, planner: GoalPlanner, profile: CourierTariffProfile, pace: PaceEstimate,
                                      day: String, baseHours: Decimal, baseReached: Bool) -> GoalAlternative? {
        guard planner.nightShare == 0,
              let version = planner.engine.catalog.versions.first(where: { $0.id == base.breakdown.tariffVersionID }) else { return nil }
        let singles: [TariffItem] = version.activeItems(on: day).filter { $0.type == .singlePackage && $0.method == .perUnit }
        guard let dayItem = singles.first(where: { $0.conditions.timeBand == .day }),
              let nightItem = singles.first(where: { $0.conditions.timeBand == .night }),
              nightItem.amount > dayItem.amount else { return nil }
        var evening = planner
        evening.nightShare = Decimal(string: "0.5")!
        guard case let .success(plan) = evening.plan(goal: base.goal, profile: profile, pace: pace, day: day),
              plan.reachability == .reachable else { return nil }
        let hours: Decimal = plan.hoursPerDay * Decimal(plan.workDays)
        let saved: Decimal = baseHours - hours
        guard !baseReached || plan.monthlyPackages < base.monthlyPackages else { return nil }
        let fewer: Int = base.monthlyPackages - plan.monthlyPackages
        let rate: String = Formatters.currency(nightItem.amount.doubleValue)
        let detail: String = fewer > 0
            ? "Paketlerinin yarısını paket başı \(rate) ödenen akşam/gece saatlerinde yaparsan ayda \(Formatters.groupedInt(fewer)) paket daha az yeter; günde \(plan.packagesPerDay) paket."
            : "Paketlerinin yarısını paket başı \(rate) ödenen akşam/gece saatlerinde yaparsan hedefe ulaşırsın; günde \(plan.packagesPerDay) paket."
        return GoalAlternative(
            id: "evening", kind: .evening, title: "Yoğun akşam saatlerinde çalış", detail: detail,
            daysPerWeek: plan.goal.daysPerWeek, packagesPerDay: plan.packagesPerDay, hoursPerDay: plan.hoursPerDay,
            monthlyHours: hours, net: plan.net, hoursSaved: saved, extraNet: plan.net - base.net)
    }

    private static func alternative(_ id: String, _ kind: GoalAlternative.Kind, _ title: String, _ detail: String,
                                    plan: GoalPlan, baseHours: Decimal, base: GoalPlan) -> GoalAlternative {
        let hours: Decimal = plan.hoursPerDay * Decimal(plan.workDays)
        return GoalAlternative(id: id, kind: kind, title: title, detail: detail, daysPerWeek: plan.goal.daysPerWeek,
                               packagesPerDay: plan.packagesPerDay, hoursPerDay: plan.hoursPerDay, monthlyHours: hours,
                               net: plan.net, hoursSaved: baseHours - hours, extraNet: plan.net - base.net)
    }
}
