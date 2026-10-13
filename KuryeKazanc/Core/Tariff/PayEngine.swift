import Foundation

/// Yayimlanmis tarife surumlerinin kumesi ve dogru surumun secimi.
/// Onaysiz (taslak, dogrulama bekleyen, reddedilen, geri cekilen) surumler hesaplamaya hic girmez.
struct TariffCatalog: Equatable {
    var versions: [TariffVersion]

    init(versions: [TariffVersion]) {
        self.versions = versions
    }

    /// Gomulu + sunucu + kullanici surumleri. Ayni kimlikte sunucu gomuluyu ezer.
    /// Sunucu bir platform icin surum yayimladiysa o platformun gomulu surumleri kullanilmaz
    /// (gomulu kayit yalnizca sunucuya ulasilamadiginda yedektir).
    static func merged(bundled: [TariffVersion], remote: [TariffVersion], user: [TariffVersion]) -> TariffCatalog {
        let remotePlatforms: Set<String> = Set(remote.filter { $0.approvalStatus.isUsableForCalculation }.map(\.platformCode))
        var byID: [String: TariffVersion] = [:]
        for version in bundled where !remotePlatforms.contains(version.platformCode) {
            byID[version.id] = version
        }
        for version in remote { byID[version.id] = version }
        for version in user { byID[version.id] = version }
        return TariffCatalog(versions: byID.values.sorted { $0.id < $1.id })
    }

    /// Platformun bu gun hesaplamada kullanilabilecek surumleri.
    func usable(platform: String, day: String) -> [TariffVersion] {
        versions.filter { $0.platformCode == platform && $0.approvalStatus.isUsableForCalculation && $0.covers(day: day) }
    }

    /// Girdiye uyan tek surum: once kullanici surumu, sonra en ozel kapsam (bolge, arac, calisma modeli),
    /// sonra en yeni surum numarasi.
    func version(for input: PayInput) -> Result<TariffVersion, PayError> {
        let day: String = input.startDay
        var candidates: [TariffVersion] = usable(platform: input.platformCode, day: day)
        candidates = candidates.filter { matches($0.workModel, input.workModel, wildcard: "any") }
        candidates = candidates.filter { $0.regionID == nil || $0.regionID == input.regionID }
        let vehicleScoped: [TariffVersion] = candidates.filter { $0.vehicleType != nil }
        if input.vehicleType == nil, !vehicleScoped.isEmpty, vehicleScoped.count == candidates.count {
            return .failure(.ambiguousScope("araç tipi"))
        }
        candidates = candidates.filter { $0.vehicleType == nil || $0.vehicleType == input.vehicleType }
        guard !candidates.isEmpty else { return .failure(.noTariff(platform: input.platformCode, day: day)) }
        let sorted: [TariffVersion] = candidates.sorted { a, b in
            let sa: Int = score(a, input), sb: Int = score(b, input)
            if sa != sb { return sa > sb }
            if a.versionNumber != b.versionNumber { return a.versionNumber > b.versionNumber }
            if a.effectiveFrom != b.effectiveFrom { return a.effectiveFrom > b.effectiveFrom }
            return a.id < b.id
        }
        return .success(sorted[0])
    }

    private func matches(_ value: String, _ wanted: String, wildcard: String) -> Bool {
        value == wildcard || wanted == wildcard || value == wanted
    }

    private func score(_ v: TariffVersion, _ input: PayInput) -> Int {
        var s = 0
        if v.origin == .user { s += 100 }
        if v.regionID != nil, v.regionID == input.regionID { s += 10 }
        if v.vehicleType != nil, v.vehicleType == input.vehicleType { s += 5 }
        if v.workModel == input.workModel { s += 1 }
        return s
    }

    /// Platformun bugunku (en yeni) yayinda surumu, girdi yoksa kapsam aranmadan.
    func current(platform: String, day: String, vehicleType: String? = nil) -> TariffVersion? {
        var input = PayInput(platformCode: platform, startDay: day)
        input.vehicleType = vehicleType
        if case let .success(version) = version(for: input) { return version }
        return usable(platform: platform, day: day).max { $0.versionNumber < $1.versionNumber }
    }
}

/// Bir hesaplama sirasinda satirlari, yan haklari ve uyarilari biriktirir.
struct PayBuilder {
    let version: TariffVersion
    let input: PayInput
    /// Kalemlerin gecerliligine bakilan gun.
    let day: String
    private(set) var lines: [PayLine] = []
    private(set) var sideBenefits: [PayLine] = []
    private(set) var notices: [PayNotice] = []
    private(set) var progress: [BonusProgress] = []
    /// Platform hesaplayicisinin isledigi kalemler; kalanlar ortak kurallarla islenir.
    private(set) var consumed: Set<String> = []

    init(version: TariffVersion, input: PayInput) {
        self.version = version
        self.input = input
        self.day = input.startDay
    }

    var items: [TariffItem] { version.activeItems(on: day) }

    func items(_ type: TariffItemType) -> [TariffItem] {
        items.filter { $0.type == type }
    }

    func items(method: CalculationMethod) -> [TariffItem] {
        items.filter { $0.method == method }
    }

    mutating func consume(_ item: TariffItem) { consumed.insert(item.id) }
    mutating func consume(_ items: [TariffItem]) { for item in items { consumed.insert(item.id) } }

    mutating func add(_ line: PayLine) {
        lines.append(line)
        if let id = line.itemID { consumed.insert(id) }
    }

    mutating func addSide(_ line: PayLine) {
        sideBenefits.append(line)
        if let id = line.itemID { consumed.insert(id) }
    }

    mutating func note(_ kind: PayNoticeKind, _ message: String) {
        notices.append(PayNotice(kind: kind, message: message))
    }

    /// Alternatif yorumlu uyari. `template` icindeki %ALT%, tum satirlar eklendikten sonra (brut + fark) ile doldurulur.
    mutating func alternative(_ template: String, delta: Money, kind: PayNoticeKind = .ambiguity) {
        notices.append(PayNotice(kind: kind, message: template, alternativeDelta: delta))
    }

    /// Alternatif farklarini kesin brutle cozer.
    mutating func resolveAlternatives(gross: Money) {
        for index in notices.indices {
            guard let delta = notices[index].alternativeDelta else { continue }
            let alt: Money = gross + delta
            notices[index].alternativeGross = alt
            notices[index].alternativeDelta = nil
            notices[index].message = notices[index].message.replacingOccurrences(of: PayNotice.alternativePlaceholder, with: alt.description)
        }
    }

    mutating func addProgress(_ p: BonusProgress) { progress.append(p) }

    /// Satirlar su anki haliyle brut.
    var currentGross: Money {
        lines.filter { $0.included && $0.isCash && $0.type != .tip && $0.type != .deduction }.map(\.low).sum()
    }

    /// Kalem × miktar. Miktar 0 ise satir eklenmez ama kalem islenmis sayilir.
    @discardableResult
    mutating func perUnit(_ item: TariffItem, quantity: Decimal, label: String? = nil, keySuffix: String = "") -> PayLine? {
        consume(item)
        guard quantity > 0 else { return nil }
        let line = PayLine(
            id: item.key + keySuffix, itemID: item.id, itemKey: item.key, type: item.type, label: label ?? item.label,
            quantity: quantity, unit: item.unit, rate: item.amount, amount: item.amount * quantity,
            amountUpper: item.amountUpper.map { $0 * quantity }, confidence: item.confidence, isCash: item.isCash
        )
        add(line)
        if item.confidence == .needsVerification, item.isRange {
            note(.needsVerification, "\(item.label): tutar aralık olarak biliniyor (\(item.amount)–\(item.amountUpper ?? item.amount) TL); alt sınır kullanıldı.")
        }
        return line
    }

    /// Kosullar bu girdi icin saglaniyor mu (bolge kademesi, kidem, uygunluk isareti).
    func isEligible(_ item: TariffItem) -> Bool {
        let c = item.conditions
        if let tier = c.regionTier, tier != input.regionTier { return false }
        if let flag = c.requiresFlag, !input.has(flag: flag) { return false }
        if let min = c.minSeniorityYears {
            guard let years = input.seniorityYears, years >= min else { return false }
        }
        if let max = c.maxSeniorityYears {
            guard let years = input.seniorityYears, years < max else { return false }
        }
        return true
    }
}

/// Platforma ozgu hesaplayici. Her platform ayri, test edilebilir bir tur; yeni platform eklemek digerlerini etkilemez.
protocol PayCalculator {
    var platformCode: String { get }
    /// Platforma ozgu kalemleri isler (paket, km, saatlik, garanti, sabit ucret...). Bonus kademeleri, yan haklar,
    /// referans ve kesinti gibi ortak kalemler motor tarafindan sonra islenir.
    func apply(_ builder: inout PayBuilder)
}

/// Hakedis motoru: dogru tarife surumunu secer, platform hesaplayicisini ve ortak kurallari calistirir.
struct PayEngine {
    var catalog: TariffCatalog
    var calculators: [String: PayCalculator]
    var clock: () -> Date = { Date() }

    static let standardCalculators: [PayCalculator] = [
        TrendyolGoCalculator(), GetirCalculator(), YemeksepetiCalculator(), PaketTaxiCalculator(),
    ]

    init(catalog: TariffCatalog, calculators: [PayCalculator] = PayEngine.standardCalculators, clock: @escaping () -> Date = { Date() }) {
        self.catalog = catalog
        var map: [String: PayCalculator] = [:]
        for calculator in calculators { map[calculator.platformCode] = calculator }
        self.calculators = map
        self.clock = clock
    }

    func calculate(_ input: PayInput) -> Result<PayBreakdown, PayError> {
        switch catalog.version(for: input) {
        case let .success(version): return calculate(input, version: version)
        case let .failure(error): return .failure(error)
        }
    }

    /// Belirli bir surumle hesaplar (gecmis kaydin kendi surumuyle yeniden gosterimi / acik yeniden hesaplama).
    func calculate(_ input: PayInput, version: TariffVersion) -> Result<PayBreakdown, PayError> {
        guard let calculator = calculators[input.platformCode] else { return .failure(.unsupportedPlatform(input.platformCode)) }
        guard version.platformCode == input.platformCode else {
            return .failure(.platformMismatch(expected: input.platformCode, got: version.platformCode))
        }
        var builder = PayBuilder(version: version, input: input)
        calculator.apply(&builder)
        PayEngine.applyCommonItems(&builder)
        PayEngine.applyUserAmounts(&builder)
        PayEngine.noteItemChanges(&builder)
        builder.resolveAlternatives(gross: builder.currentGross)
        if version.verificationStatus != .verified {
            builder.note(.needsVerification, "Bu tarife sürümü (\(version.label)) \(version.verificationStatus.displayName.lowercased()); sonuç tahminidir.")
        }
        let breakdown = PayBreakdown(
            platformCode: input.platformCode, tariffVersionID: version.id, tariffVersionLabel: version.label,
            tariffOrigin: version.origin, tariffVerification: version.verificationStatus, span: input.span,
            startDay: input.startDay, endDay: input.endDay, computedAt: clock(), lines: builder.lines,
            sideBenefits: builder.sideBenefits, notices: builder.notices, progress: builder.progress,
            extraPayments: input.extraPayments, deductions: input.deductions, advances: input.advances
        )
        return .success(breakdown)
    }

    // MARK: - Ortak kurallar

    /// Hesaplayicinin islemedigi kalemler: bonus kademeleri, yan haklar, referans, kesinti, isarete bagli sabit odemeler.
    static func applyCommonItems(_ b: inout PayBuilder) {
        let remaining: [TariffItem] = b.items.filter { !b.consumed.contains($0.id) }

        // Nakit olmayanlar: yan haklar ve destekler (hakedise eklenmez)
        for item in remaining where !item.isCash {
            let eligible: Bool = b.isEligible(item)
            var note: String = item.note ?? ""
            if !eligible, let flag = item.conditions.requiresFlag { note = "Koşul: \(flagName(flag)). " + note }
            b.addSide(PayLine(
                id: item.key, itemID: item.id, itemKey: item.key, type: item.type, label: item.label, unit: item.unit,
                amount: item.amount, amountUpper: item.amountUpper, confidence: item.confidence, isCash: false,
                included: false, note: note.isEmpty ? nil : note
            ))
        }

        // Bonus kademeleri (grup bazinda)
        let tiers: [TariffItem] = remaining.filter { $0.isCash && $0.method == .tier }
        var groups: [String: [TariffItem]] = [:]
        for item in tiers { groups[item.group ?? item.key, default: []].append(item) }
        for key in groups.keys.sorted() {
            applyTierGroup(groups[key] ?? [], in: &b)
        }

        // Referans bonusu: yalnizca kosullar saglandiginda
        for item in remaining where item.isCash && item.type == .referralBonus {
            b.consume(item)
            guard b.input.referralConditionsMet else {
                b.note(.info, "\(item.label): koşullar sağlandığında eklenir (işaretlenmedi).")
                continue
            }
            let amount: Money = b.input.referralAmount ?? item.amount
            guard !amount.isZero else {
                b.note(.missing, "\(item.label): tutar bilinmiyor; kendi tutarını gir.")
                continue
            }
            let confidence: ConfidenceStatus = b.input.referralAmount != nil ? .userEntered : item.confidence
            b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: .referralBonus, label: item.label,
                          amount: amount, confidence: confidence))
        }

        // Tarifedeki kesintiler: yalnizca dogrulanmis / kullanici girisi olanlar dusulur
        for item in remaining where item.isCash && item.type == .deduction {
            b.consume(item)
            let trusted: Bool = item.confidence.isTrusted && b.isEligible(item)
            b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: .deduction, label: item.label,
                          amount: item.amount, confidence: item.confidence, included: trusted,
                          note: trusted ? nil : "Doğrulanmamış kesinti düşülmedi."))
        }

        // Isarete bagli ya da donem birimli sabit odemeler (haftalik performans, yakit destegi...)
        for item in remaining where item.isCash && item.method == .flat && !b.consumed.contains(item.id) {
            b.consume(item)
            if let flag = item.conditions.requiresFlag {
                guard b.input.has(flag: flag) else { continue }
                let entered: Money? = b.input.flagAmounts[flag]
                b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: item.type, label: item.label,
                              unit: item.unit, amount: entered ?? item.amount, amountUpper: entered == nil ? item.amountUpper : nil,
                              confidence: entered != nil ? .userEntered : item.confidence))
            } else if item.unit == b.input.span.unit || item.unit == .flat {
                guard b.isEligible(item) else { continue }
                b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: item.type, label: item.label,
                              unit: item.unit, amount: item.amount, amountUpper: item.amountUpper, confidence: item.confidence))
            } else {
                b.note(.deferred, "\(item.label) (\(item.unit.suffix)) bu dönemde hesaplanmadı.")
            }
        }
    }

    /// Bonus kademe grubu. Gun birimli kademe gunluk kayitta paket sayisiyla, donem hesabinda "hedefe ulasilan gun"
    /// sayisiyla; hafta/ay birimli kademe yalnizca o donemin toplamiyla hesaplanir (gunluk kayitta ilerleme gosterilir).
    static func applyTierGroup(_ group: [TariffItem], in b: inout PayBuilder) {
        guard let first = group.first else { return }
        b.consume(group)
        let tiers: [TariffItem] = group.filter { b.isEligible($0) }.sorted { ($0.lowerThreshold ?? 0) < ($1.lowerThreshold ?? 0) }
        guard !tiers.isEmpty else { return }
        let stacking: BonusStacking = b.version.settings.bonusStacking ?? .highestOnly
        let stackingTrusted: Bool = b.version.settings.confidence(of: "bonus_stacking").isTrusted
        let unit: TariffUnit = first.unit
        let label: String = first.type.displayName

        if unit == .day, b.input.span != .day {
            applyTierDays(tiers, stacking: stacking, stackingTrusted: stackingTrusted, label: label, in: &b)
            return
        }

        let count: Int?
        let isWeekendGroup: Bool = first.conditions.weekdays != nil
        if isWeekendGroup {
            count = b.input.weekendPackages
        } else if unit == b.input.span.unit {
            count = b.input.periodPackages ?? b.input.totalPackages
        } else {
            count = b.input.periodPackages
        }

        // Ilerleme (her durumda gosterilir)
        let progressCount: Int = count ?? (unit == .day ? b.input.totalPackages : 0)
        if let next = tiers.first(where: { Int(truncating: ($0.lowerThreshold ?? 0) as NSDecimalNumber) > progressCount }) {
            b.addProgress(BonusProgress(
                itemKey: next.key, label: next.label, current: progressCount,
                target: Int(truncating: (next.lowerThreshold ?? 0) as NSDecimalNumber), reward: next.amount,
                rewardUpper: next.amountUpper, unit: unit, confidence: next.confidence
            ))
        }

        let periodMatches: Bool = unit == b.input.span.unit
        if periodMatches, count == nil {
            b.note(.missing, "\(label): hafta sonu (Cuma–Pazar) paket toplamını gir.")
            return
        }
        guard periodMatches, let count else {
            let what: String = isWeekendGroup ? "Hafta sonu (Cuma–Pazar) paket toplamı" : "\(unit == .week ? "Haftalık" : "Aylık") toplam"
            b.note(.deferred, "\(label): \(what) dönem özetinde hesaplanır.")
            return
        }

        // Ust esikli kademe (40–60 gibi) yalnizca aralikta sayilir: araliklar ortusmediginden tek kademe eslesir.
        let reached: [TariffItem] = tiers.filter { tier in
            guard decimalInt(tier.lowerThreshold) <= count else { return false }
            if let upper = tier.upperThreshold { return count <= decimalInt(upper) }
            return true
        }
        guard !reached.isEmpty else { return }
        let highest: TariffItem = reached[reached.count - 1]
        if stacking == .cumulative {
            for item in reached { addTierLine(item, in: &b) }
        } else {
            addTierLine(highest, in: &b)
        }
        if reached.count > 1, !stackingTrusted {
            let all: Money = reached.map(\.amount).sum()
            let delta: Money = stacking == .cumulative ? highest.amount - all : all - highest.amount
            let altText: String = stacking == .cumulative ? "yalnızca en yüksek kademe ödenirse" : "kademeler toplanırsa"
            b.alternative("\(label): kademelerin birlikte uygulanıp uygulanmadığı doğrulanmadı; \(altText) brüt %ALT% TL olur.", delta: delta)
        }
    }

    private static func addTierLine(_ item: TariffItem, in b: inout PayBuilder) {
        b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: item.type, label: item.label,
                      quantity: item.lowerThreshold, unit: item.unit, amount: item.amount, amountUpper: item.amountUpper,
                      confidence: item.confidence))
    }

    /// Donem hesabinda gunluk bonus: kullanici her kademeye ulastigi gun sayisini girer (ust kademe gunleri alt kademeye de dahil).
    private static func applyTierDays(_ tiers: [TariffItem], stacking: BonusStacking, stackingTrusted: Bool, label: String, in b: inout PayBuilder) {
        let days: [Int] = tiers.map { b.input.bonusTierDays[$0.key] ?? 0 }
        guard days.contains(where: { $0 > 0 }) else {
            b.note(.missing, "\(label): dönem hesabı için hedefe ulaşılan gün sayısını gir (günlük kayıtlarda kendiliğinden hesaplanır).")
            return
        }
        var cumulativeTotal = Money.zero
        var highestTotal = Money.zero
        for (index, item) in tiers.enumerated() {
            let d: Int = days[index]
            let higher: Int = index + 1 < days.count ? days[index + 1] : 0
            let exclusive: Int = max(0, d - higher)
            cumulativeTotal += item.amount * d
            highestTotal += item.amount * exclusive
            let quantity: Int = stacking == .cumulative ? d : exclusive
            guard quantity > 0 else { continue }
            b.add(PayLine(id: item.key + ".days", itemID: item.id, itemKey: item.key, type: item.type,
                          label: "\(item.label) × \(quantity) gün", quantity: Decimal(quantity), unit: .day, rate: item.amount,
                          amount: item.amount * quantity, amountUpper: item.amountUpper.map { $0 * quantity }, confidence: item.confidence))
        }
        if tiers.count > 1, !stackingTrusted, cumulativeTotal != highestTotal {
            let delta: Money = stacking == .cumulative ? highestTotal - cumulativeTotal : cumulativeTotal - highestTotal
            b.alternative("\(label): kademelerin birlikte uygulanıp uygulanmadığı doğrulanmadı; diğer yorumla brüt %ALT% TL.", delta: delta)
        }
    }

    /// Bahsis ve kullanicinin girdigi ek odeme / kesinti / avans.
    static func applyUserAmounts(_ b: inout PayBuilder) {
        if !b.input.tips.isZero {
            b.add(PayLine(id: "user.tips", itemID: nil, itemKey: "user.tips", type: .tip, label: "Bahşiş",
                          amount: b.input.tips, confidence: .userEntered, note: "Hakedişten ayrı ek ödeme olarak gösterilir."))
        }
    }

    /// Hesaplanan donemde kalem degisikligi varsa (ileri tarihli revizyon) uyar.
    static func noteItemChanges(_ b: inout PayBuilder) {
        guard b.input.endDay > b.input.startDay else { return }
        let start: String = b.input.startDay
        let end: String = b.input.endDay
        let changing: [TariffItem] = b.version.items.filter { item in
            guard let from = item.effectiveFrom else { return false }
            return from > start && from <= end
        }
        if !changing.isEmpty {
            let names: String = Array(Set(changing.map(\.label))).sorted().joined(separator: ", ")
            b.note(.info, "Dönem içinde tarife kalemi değişiyor (\(names)); dönem başındaki kalemler kullanıldı, günlük kayıtlar kendi gününün kalemiyle hesaplanır.")
        }
    }

    static func decimalInt(_ value: Decimal?) -> Int {
        Int(truncating: (value ?? 0) as NSDecimalNumber)
    }

    static func flagName(_ flag: String) -> String {
        switch flag {
        case "weekly_performance": "haftalık performans hedefi"
        case "woman_employment": "kadın istihdam desteği koşulları"
        case "referral": "referans koşulları"
        case "ys_ankara_izmir": "Ankara ya da İzmir'de çalışmak"
        default: flag
        }
    }
}
