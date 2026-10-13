import Foundation

struct GoalLine: Equatable, Identifiable {
    var id: String
    var label: String
    var amount: Money
    var isSideBenefit: Bool
    var confidence: ConfidenceStatus
}

enum GoalReachability: Equatable {
    /// Paketsiz gelir (sabit ucret + yan haklar) hedefi zaten karsiliyor.
    case alreadyMet
    case reachable
    /// Haftada bu kadar gun calisilirsa ulasilir.
    case needsMoreDays(Int)
    /// Saat ve gun sinirinda ulasilabilecek en yuksek aylik net.
    case unreachable(maxNet: Money)
}

struct NextTierHint: Equatable {
    var threshold: Int
    var extraPackages: Int
    var extraNet: Money
    var newRate: Money
}

/// Hedef plani: secili firmanin tarifesi tersine calistirilarak bulunan en az paket / saat.
struct GoalPlan: Equatable {
    var platformCode: String
    var goal: GoalSpec
    var monthlyPackages: Int
    var packagesPerDay: Int
    var hoursPerDay: Decimal
    var workDays: Int
    var guaranteed: [GoalLine]
    var guaranteedTotal: Money
    var packageIncome: Money
    var gross: Money
    var sideIncome: Money
    var fuel: Money
    var net: Money
    var regionTier: String?
    var otherTierDelta: Money?
    var nextTier: NextTierHint?
    var pace: PaceEstimate
    var reachability: GoalReachability
    var usesFuelFallback: Bool
    var breakdown: PayBreakdown
    /// Haftalik (or. Getir hafta sonu) bonuslarin aylik karsiligi; brut icinde.
    var weeklyBonusIncome: Money = .zero

    /// Hedef donemindeki paket (haftalik/gunluk hedefte aylik plandan orantili, yukari yuvarlanir).
    func periodPackages() -> Int {
        guard goal.period != .month, workDays > 0 else { return monthlyPackages }
        let share: Double = Double(monthlyPackages) * Double(goal.periodWorkDays()) / Double(workDays)
        return Int(share.rounded(.up))
    }

    /// Hedef donemindeki net (hedef tutariyla ayni olcek).
    func periodNet() -> Money {
        guard goal.period != .month else { return net }
        let target: Money = goal.monthlyTarget()
        guard target.value > 0 else { return net }
        return Money(Money.round(goal.amount.value * net.value / target.value))
    }
}

/// Hedef → paket/saat/bolge. Hesap her zaman ay bazinda yapilir (sabit ucret ve aylik kademeler); `PayEngine`
/// paket sayisi ikili aramayla denenerek tersine calistirilir, boylece kademe ve bonus kurallari tekrar yazilmaz.
/// Paketlerin is gunlerine esit dagildigi varsayilir (gunluk ve hafta sonu bonuslari buna gore sayilir).
struct GoalPlanner {
    var engine: PayEngine
    var fuel: FuelCostModel
    static let maxPackages = 20_000

    struct Evaluation: Equatable {
        var breakdown: PayBreakdown
        var gross: Money
        var sideLines: [PayLine]
        var sideIncome: Money
        var fuel: Money
        var net: Money
        var hours: Decimal
        /// Planlayicinin esit dagilim varsayimiyla ekledigi haftalik bonus satirlari (dokumde de var).
        var weeklyBonus: [PayLine] = []
    }

    init(engine: PayEngine, fuel: FuelCostModel) {
        self.engine = engine
        self.fuel = fuel
    }

    /// Kullanicinin isaretini tasidigi, aylik, nakit olmayan yan haklar (or. kadin istihdam destegi). Kullanici karariyla
    /// hedefe dahil edilir; dogrulanmamissa sayfa altindaki notta listelenir.
    static func flaggedSideIncome(_ breakdown: PayBreakdown, version: TariffVersion?, flags: [String]) -> [PayLine] {
        guard let version else { return [] }
        return breakdown.sideBenefits.filter { line in
            guard let itemID = line.itemID, let item = version.items.first(where: { $0.id == itemID }) else { return false }
            guard let flag = item.conditions.requiresFlag, flags.contains(flag) else { return false }
            return item.unit == .month && line.amount.value > 0
        }
    }

    static func monthBounds(of day: String) -> (start: String, end: String) {
        let parts: [Int] = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return (day, day) }
        let year: Int = parts[0]
        let month: Int = max(1, min(12, parts[1]))
        let leap: Bool = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let lengths: [Int] = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        let last: Int = lengths[month - 1]
        return (String(format: "%04d-%02d-01", year, month), String(format: "%04d-%02d-%02d", year, month, last))
    }

    func input(packages: Int, profile: CourierTariffProfile, pace: PaceEstimate, day: String) -> PayInput {
        let bounds = GoalPlanner.monthBounds(of: day)
        var input = PayInput(platformCode: profile.platformCode, span: .month, startDay: bounds.start, endDay: bounds.end)
        input.dayPackages = packages
        input.periodPackages = packages
        input.totalKm = Decimal(packages) * pace.kmPerPackage
        input.hours = pace.packagesPerHour > 0 ? Money.round(Decimal(packages) / pace.packagesPerHour) : 0
        input.regionTier = profile.regionTier
        input.seniorityYears = profile.seniorityYears
        input.vehicleType = profile.vehicleType ?? (profile.platformCode == "getir" ? "motorcycle" : nil)
        input.flags = profile.flags
        return input
    }

    /// Tarife surumu ayin 1'ine gore degil BUGUNE gore secilir: ay ortasinda yayimlanan tarife hemen kullanilir.
    func version(for input: PayInput, day: String) -> Result<TariffVersion, PayError> {
        var lookup = input
        lookup.startDay = day
        lookup.endDay = day
        return engine.catalog.version(for: lookup)
    }

    func evaluate(packages: Int, profile: CourierTariffProfile, pace: PaceEstimate, day: String,
                  daysPerWeek: Int = 6) -> Result<Evaluation, PayError> {
        var payInput: PayInput = input(packages: packages, profile: profile, pace: pace, day: day)
        let version: TariffVersion
        switch self.version(for: payInput, day: day) {
        case let .success(value): version = value
        case let .failure(error): return .failure(error)
        }
        let week: Int = min(7, max(1, daysPerWeek))
        let workDays: Int = GoalSpec.monthWorkDays(daysPerWeek: week)
        let perDay: Int = workDays > 0 ? packages / workDays : 0
        let items: [TariffItem] = version.activeItems(on: day)
        // Gunluk kademe (or. Trendyol 42 / 82 paket): esit dagilimda her is gunu esik asilir ya da hic asilmaz
        for item in items where GoalPlanner.isPlannableTier(item, unit: .day) {
            if PayEngine.decimalInt(item.lowerThreshold) <= perDay { payInput.bonusTierDays[item.key] = workDays }
        }
        var breakdown: PayBreakdown
        switch engine.calculate(payInput, version: version) {
        case let .success(value): breakdown = value
        case let .failure(error): return .failure(error)
        }
        let weekly: [PayLine] = GoalPlanner.weeklyBonus(items: items, perDay: perDay, daysPerWeek: week, workDays: workDays)
        breakdown.lines += weekly
        let side: [PayLine] = GoalPlanner.flaggedSideIncome(breakdown, version: version, flags: profile.flags)
        let sideIncome: Money = side.map(\.amount).sum()
        let fuelCost: Money = fuel.cost(km: payInput.totalKm ?? 0, on: day)
        let net: Money = breakdown.gross + sideIncome - fuelCost
        return .success(Evaluation(breakdown: breakdown, gross: breakdown.gross, sideLines: side, sideIncome: sideIncome,
                                   fuel: fuelCost, net: net, hours: payInput.hours, weeklyBonus: weekly))
    }

    /// Planlamada sayilan kademe: nakit, kosul isareti olmayan, belirtilen birimdeki kademe kalemi.
    static func isPlannableTier(_ item: TariffItem, unit: TariffUnit) -> Bool {
        item.isCash && item.method == .tier && item.unit == unit && item.conditions.requiresFlag == nil
    }

    /// Aylik hesapta motorun donem ozetine biraktigi haftalik kademeler (or. Getir hafta sonu 40–60 paket):
    /// her grupta ulasilan en yuksek kademe × ayin hafta sayisi (is gunu / haftalik gun).
    static func weeklyBonus(items: [TariffItem], perDay: Int, daysPerWeek: Int, workDays: Int) -> [PayLine] {
        let tiers: [TariffItem] = items.filter { isPlannableTier($0, unit: .week) }
        var groups: [String: [TariffItem]] = [:]
        for item in tiers { groups[item.group ?? item.key, default: []].append(item) }
        let days: Int = max(1, daysPerWeek)
        let weeks: Decimal = Money.round(Decimal(workDays) / Decimal(days))
        var lines: [PayLine] = []
        for key in groups.keys.sorted() {
            let group: [TariffItem] = groups[key] ?? []
            let weekendDays: Int? = group.first?.conditions.weekdays?.count
            let count: Int = perDay * min(weekendDays ?? days, days)
            let reached: [TariffItem] = group.filter { tier in
                guard PayEngine.decimalInt(tier.lowerThreshold) <= count else { return false }
                if let upper = tier.upperThreshold { return count <= PayEngine.decimalInt(upper) }
                return true
            }
            guard let best = reached.max(by: { $0.amount < $1.amount }) else { continue }
            let total = Money(Money.round(best.amount.value * Decimal(workDays) / Decimal(days)))
            lines.append(PayLine(id: best.key + ".weeks", itemID: best.id, itemKey: best.key, type: best.type,
                                 label: "\(best.label) × \(Formatters.decimalText(weeks)) hafta", quantity: weeks, unit: .week,
                                 rate: best.amount, amount: total, confidence: best.confidence, scope: .monthly))
        }
        return lines
    }

    private func net(_ packages: Int, _ profile: CourierTariffProfile, _ pace: PaceEstimate, _ day: String,
                     _ daysPerWeek: Int) -> Money? {
        if case let .success(e) = evaluate(packages: packages, profile: profile, pace: pace, day: day, daysPerWeek: daysPerWeek) {
            return e.net
        }
        return nil
    }

    /// net(N) >= target olan en kucuk N (yoksa nil). net(N) dort hesaplayicida da N ile azalmaz (kademeler yalnizca artar).
    private func smallestPackages(target: Money, upTo limit: Int, _ profile: CourierTariffProfile, _ pace: PaceEstimate,
                                  _ day: String, _ daysPerWeek: Int) -> Int? {
        guard let top = net(limit, profile, pace, day, daysPerWeek), !(top < target) else { return nil }
        var low = 0
        var high = limit
        while low < high {
            let mid: Int = (low + high) / 2
            if let value = net(mid, profile, pace, day, daysPerWeek), !(value < target) { high = mid } else { low = mid + 1 }
        }
        return low
    }

    func plan(goal: GoalSpec, profile: CourierTariffProfile, pace: PaceEstimate, day: String) -> Result<GoalPlan, PayError> {
        let week: Int = goal.daysPerWeek
        let zero: Evaluation
        switch evaluate(packages: 0, profile: profile, pace: pace, day: day, daysPerWeek: week) {
        case let .success(value): zero = value
        case let .failure(error): return .failure(error)
        }
        let target: Money = goal.monthlyTarget()
        let workDays: Int = goal.monthWorkDays
        let maxPerDay: Int = NSDecimalNumber(decimal: pace.packagesPerHour * goal.maxHoursPerDay).intValue
        let capacity: Int = maxPerDay * workDays

        var packages: Int
        var reachability: GoalReachability
        if !(zero.net < target) {
            packages = 0
            reachability = .alreadyMet
        } else if let needed = smallestPackages(target: target, upTo: GoalPlanner.maxPackages, profile, pace, day, week),
                  needed <= capacity {
            packages = needed
            reachability = .reachable
        } else {
            packages = capacity
            reachability = .unreachable(maxNet: net(capacity, profile, pace, day, week) ?? zero.net)
            if goal.period != .day, goal.daysPerWeek < 7 {
                for days in (goal.daysPerWeek + 1)...7 {
                    let more: Int = maxPerDay * GoalSpec.monthWorkDays(daysPerWeek: days)
                    if let value = net(more, profile, pace, day, days), !(value < target) {
                        reachability = .needsMoreDays(days)
                        break
                    }
                }
            }
        }

        let result: Evaluation
        switch evaluate(packages: packages, profile: profile, pace: pace, day: day, daysPerWeek: week) {
        case let .success(value): result = value
        case let .failure(error): return .failure(error)
        }
        let perDay: Int = workDays > 0 ? Int((Double(packages) / Double(workDays)).rounded(.up)) : packages
        let rawHours: Decimal = pace.packagesPerHour > 0 ? Decimal(perDay) / pace.packagesPerHour : 0
        let hoursPerDay: Decimal = GoalPlanner.roundUpToHalf(rawHours)

        let base: [PayLine] = result.breakdown.lines.filter { $0.included && $0.isCash && ($0.type == .fixed || $0.type == .hourly) }
        var guaranteed: [GoalLine] = base.map {
            GoalLine(id: $0.id, label: $0.label, amount: $0.amount, isSideBenefit: false, confidence: $0.confidence)
        }
        guaranteed += result.sideLines.map {
            GoalLine(id: $0.id, label: $0.label, amount: $0.amount, isSideBenefit: true, confidence: $0.confidence)
        }
        let baseTotal: Money = base.map(\.amount).sum()
        let tierDelta: Money? = otherTierDelta(packages: packages, profile: profile, pace: pace, day: day, week: week,
                                               gross: result.gross, breakdown: result.breakdown)
        let hint: NextTierHint? = nextTier(packages: packages, result: result, profile: profile, pace: pace, day: day, week: week)

        return .success(GoalPlan(
            platformCode: profile.platformCode, goal: goal, monthlyPackages: packages, packagesPerDay: perDay,
            hoursPerDay: hoursPerDay, workDays: workDays, guaranteed: guaranteed,
            guaranteedTotal: baseTotal + result.sideIncome, packageIncome: result.gross - baseTotal, gross: result.gross,
            sideIncome: result.sideIncome, fuel: result.fuel, net: result.net, regionTier: profile.regionTier,
            otherTierDelta: tierDelta, nextTier: hint, pace: pace, reachability: reachability,
            usesFuelFallback: !fuel.hasPrice, breakdown: result.breakdown,
            weeklyBonusIncome: result.weeklyBonus.map(\.amount).sum()
        ))
    }

    static func roundUpToHalf(_ value: Decimal) -> Decimal {
        let doubled: Double = NSDecimalNumber(decimal: value * 2).doubleValue
        return Decimal(doubled.rounded(.up)) / 2
    }

    private func otherTierDelta(packages: Int, profile: CourierTariffProfile, pace: PaceEstimate, day: String, week: Int,
                                gross: Money, breakdown: PayBreakdown) -> Money? {
        guard let tier = profile.regionTier,
              let version = engine.catalog.versions.first(where: { $0.id == breakdown.tariffVersionID }) else { return nil }
        let tiers: Set<String> = Set(version.items.compactMap { $0.type == .fixed ? $0.conditions.regionTier : nil })
        guard tiers.contains(tier), tiers.count > 1 else { return nil }
        var best: Money? = nil
        for other in tiers.sorted() where other != tier {
            var alt = profile
            alt.regionTier = other
            guard case let .success(e) = evaluate(packages: packages, profile: alt, pace: pace, day: day, daysPerWeek: week)
            else { continue }
            let delta: Money = gross - e.gross
            if let current = best, abs(current.value) >= abs(delta.value) { continue }
            best = delta
        }
        return best
    }

    private func nextTier(packages: Int, result: Evaluation, profile: CourierTariffProfile, pace: PaceEstimate,
                          day: String, week: Int) -> NextTierHint? {
        guard packages > 0 else { return nil }
        let window: Int = Int((Double(packages) * 0.2).rounded(.up))
        guard let progress = result.breakdown.progress.first(where: { $0.unit == .month && $0.target > packages }),
              progress.target - packages <= window,
              case let .success(at) = evaluate(packages: progress.target, profile: profile, pace: pace, day: day, daysPerWeek: week)
        else { return nil }
        return NextTierHint(threshold: progress.target, extraPackages: progress.target - packages,
                            extraNet: at.net - result.net, newRate: progress.reward)
    }
}
