import Foundation

/// "Ayni is" girdisi: Firmalar ekraninda her firmanin tarifesiyle hesaplanir.
struct WorkloadSpec: Codable, Equatable {
    var packagesPerDay: Int
    var hoursPerDay: Decimal
    var kmPerPackage: Decimal
    var daysPerMonth: Int

    static func from(pace: PaceEstimate, goal: GoalSpec?) -> WorkloadSpec {
        let days: Int = goal?.monthWorkDays ?? 26
        let hours: Decimal = 8
        let perDay: Int = NSDecimalNumber(decimal: Money.round(pace.packagesPerHour * hours, scale: 0)).intValue
        return WorkloadSpec(packagesPerDay: perDay, hoursPerDay: hours, kmPerPackage: pace.kmPerPackage, daysPerMonth: days)
    }

    var monthlyPackages: Int { packagesPerDay * daysPerMonth }
    /// Ayda gun -> haftada gun (26 -> 6), 1...7.
    var daysPerWeek: Int { min(7, max(1, Int((Double(daysPerMonth) * 12 / 52).rounded()))) }
    var monthlyHours: Decimal { hoursPerDay * Decimal(daysPerMonth) }

    /// Planlayicinin hiz bicimine cevrim.
    var pace: PaceEstimate {
        let rate: Decimal = hoursPerDay > 0 ? Decimal(packagesPerDay) / hoursPerDay : 0
        return PaceEstimate(packagesPerHour: rate, kmPerPackage: kmPerPackage, isAssumed: false, sampleCount: 0)
    }
}

struct FirmComparisonRow: Equatable, Identifiable {
    var platformCode: String
    var isCurrent: Bool
    var gross: Money
    var sideIncome: Money
    var fuel: Money
    var net: Money
    var netPerHour: Money?
    var differenceFromCurrent: Money?
    var versionID: String
    var versionLabel: String
    var effectiveFrom: String
    var assumptions: [String]
    var breakdown: PayBreakdown
    var id: String { platformCode }
}

struct SwitchSuggestion: Equatable {
    var platformCode: String
    var extraNet: Money
    /// Ayni surum ciftinde bir kez bildirmek icin.
    var key: String
}

/// Firmalar karsilastirmasi. Ucret yalnizca tarifeden; kurye ortalamasi kullanilmaz.
enum TariffComparison {
    /// Diger firmalar: en dusuk kidem (gecerse bu kademeden baslar); bolge kademesi kendi kademen, o firmada yoksa
    /// sabit ucreti en dusuk kademe. Kendi firman: kendi bilgilerin.
    static func comparisonProfile(for platform: String, own: CourierTariffProfile, catalog: TariffCatalog,
                                  day: String) -> (CourierTariffProfile, [String]) {
        if platform == own.platformCode { return (own, []) }
        var notes: [String] = []
        let items: [TariffItem] = (catalog.current(platform: platform, day: day)?.activeItems(on: day)) ?? []
        // Bolge: kendi bolgen o firmada varsa ayni; yoksa (firmalar arasi kodlar farkli) en dusuk ucretli bolge
        let tiers: Set<String> = Set(items.compactMap(\.conditions.regionTier))
        var tier: String? = nil
        if !tiers.isEmpty {
            if let mine = own.regionTier, tiers.contains(mine) {
                tier = mine
            } else {
                tier = lowestTier(tiers, items: items)
                notes.append("en düşük ücretli bölgeyle")
            }
        }
        var hours: Int? = nil
        let hourOptions: [Int] = Array(Set(items.flatMap { $0.conditions.contractHours ?? [] })).sorted()
        if !hourOptions.isEmpty {
            hours = own.contractHours.flatMap { hourOptions.contains($0) ? $0 : nil } ?? (hourOptions.contains(10) ? 10 : hourOptions.first)
            if own.contractHours == nil { notes.append("günde \(hours ?? 0) saatle") }
        }
        if items.contains(where: { $0.conditions.minSeniorityYears != nil }) {
            notes.append("kıdem primi olmadan")
        }
        let profile = CourierTariffProfile(platformCode: platform, regionTier: tier, seniorityYears: 0, vehicleType: nil,
                                           flags: own.flags, contractHours: hours)
        return (profile, notes)
    }

    /// Ayni kosulu tasiyan kalemlerin toplami en dusuk bolge (Paket Taxi 4. bolge, Yemeksepeti diger iller).
    static func lowestTier(_ tiers: Set<String>, items: [TariffItem]) -> String? {
        tiers.min { a, b in
            let sa: Money = items.filter { $0.conditions.regionTier == a }.map(\.amount).sum()
            let sb: Money = items.filter { $0.conditions.regionTier == b }.map(\.amount).sum()
            return sa == sb ? a < b : sa < sb
        }
    }

    static func rows(workload: WorkloadSpec, profile own: CourierTariffProfile, catalog: TariffCatalog, fuel: FuelCostModel,
                     day: String) -> [FirmComparisonRow] {
        let planner = GoalPlanner(engine: PayEngine(catalog: catalog), fuel: fuel)
        let hours: Decimal = workload.monthlyHours
        var rows: [FirmComparisonRow] = []
        for platform in PayPlatform.all where platform.isActive {
            let (profile, notes) = comparisonProfile(for: platform.code, own: own, catalog: catalog, day: day)
            guard case let .success(e) = planner.evaluate(packages: workload.monthlyPackages, profile: profile,
                                                          pace: workload.pace, day: day,
                                                          daysPerWeek: workload.daysPerWeek) else { continue }
            let version: TariffVersion? = catalog.versions.first { $0.id == e.breakdown.tariffVersionID }
            rows.append(FirmComparisonRow(
                platformCode: platform.code, isCurrent: platform.code == own.platformCode, gross: e.gross,
                sideIncome: e.sideIncome, fuel: e.fuel, net: e.net,
                netPerHour: hours > 0 ? Money(Money.round(e.net.value / hours)) : nil, differenceFromCurrent: nil,
                versionID: e.breakdown.tariffVersionID, versionLabel: e.breakdown.tariffVersionLabel,
                effectiveFrom: version?.effectiveFrom ?? "", assumptions: notes, breakdown: e.breakdown))
        }
        let current: FirmComparisonRow? = rows.first { $0.isCurrent }
        var others: [FirmComparisonRow] = rows.filter { !$0.isCurrent }.sorted { $1.net < $0.net }
        guard let current else { return others }
        for index in others.indices { others[index].differenceFromCurrent = others[index].net - current.net }
        return [current] + others
    }

    /// Baska bir firma kendi firmandan en az `threshold` (yuzde) daha fazla net veriyorsa.
    static func switchSuggestion(rows: [FirmComparisonRow], threshold: Decimal = 5) -> SwitchSuggestion? {
        guard let current = rows.first(where: { $0.isCurrent }), current.net.value > 0 else { return nil }
        let limit: Decimal = current.net.value * (1 + threshold / 100)
        guard let best = rows.filter({ !$0.isCurrent }).max(by: { $0.net < $1.net }), best.net.value >= limit else { return nil }
        return SwitchSuggestion(platformCode: best.platformCode, extraNet: best.net - current.net,
                                key: "\(best.versionID)|\(current.versionID)")
    }
}

enum TariffFuelVerdict: Equatable {
    /// Tarife yakitla ayni yonde degisti.
    case consistent
    /// Yakit belirgin degisti ama tarife ters yonde / hic degismedi.
    case check
    /// Yakit belirgin degismedi.
    case neutral
}

/// Son iki yayimlanmis tarife surumu arasindaki degisim ile ayni araliktaki yakit degisimi. Dogrulama durumunu degistirmez.
struct TariffFuelCorrelation: Equatable {
    var platformCode: String
    var fromDay: String
    var toDay: String
    var tariffChange: Decimal
    var fuelChange: Decimal
    var verdict: TariffFuelVerdict

    static let fuelThreshold: Decimal = 3

    /// Karsilastirilan oran: en dusuk esikli paket basi ucret; yoksa en yuksek sabit ucret; yoksa saatlik ucret.
    static func referenceRate(_ version: TariffVersion) -> Money? {
        let items: [TariffItem] = version.items.filter { !$0.withdrawn }
        let packages: [TariffItem] = items.filter { $0.type == .singlePackage }
            .sorted { ($0.lowerThreshold ?? 0) < ($1.lowerThreshold ?? 0) }
        if let first = packages.first { return first.amount }
        if let fixed = items.filter({ $0.type == .fixed }).max(by: { $0.amount < $1.amount }) { return fixed.amount }
        return items.first { $0.type == .hourly }?.amount
    }

    static func evaluate(platform: String, catalog: TariffCatalog, fuel: FuelCostModel, today: String) -> TariffFuelCorrelation? {
        guard fuel.hasPrice else { return nil }
        let versions: [TariffVersion] = catalog.versions
            .filter { $0.platformCode == platform && $0.approvalStatus.isUsableForCalculation && $0.effectiveFrom <= today }
            .sorted { a, b in
                if a.effectiveFrom != b.effectiveFrom { return a.effectiveFrom < b.effectiveFrom }
                return a.versionNumber < b.versionNumber
            }
        guard versions.count >= 2 else { return nil }
        let old: TariffVersion = versions[versions.count - 2]
        let new: TariffVersion = versions[versions.count - 1]
        guard let a = referenceRate(old), let b = referenceRate(new),
              let tariff = Money.percentChange(from: a, to: b),
              let fuelChange = fuel.change(from: old.effectiveFrom, to: new.effectiveFrom) else { return nil }
        let t: Decimal = Money.round(tariff, scale: 0)
        let f: Decimal = Money.round(fuelChange, scale: 0)
        let verdict: TariffFuelVerdict
        if f >= fuelThreshold {
            verdict = t > 0 ? .consistent : .check
        } else if f <= -fuelThreshold {
            verdict = t > 0 ? .check : .consistent
        } else {
            verdict = .neutral
        }
        return TariffFuelCorrelation(platformCode: platform, fromDay: old.effectiveFrom, toDay: new.effectiveFrom,
                                     tariffChange: t, fuelChange: f, verdict: verdict)
    }
}
