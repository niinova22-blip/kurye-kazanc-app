import Foundation

/// Ayrintili dokumun gruplari.
enum PayDetailCategory: String, CaseIterable, Identifiable {
    case packages, distance, hourly, fixed, bonus, other, side

    var id: String { rawValue }

    var title: String {
        switch self {
        case .packages: "Paketlerden"
        case .distance: "Mesafe ve km"
        case .hourly: "Saatlik ödeme"
        case .fixed: "Sabit ücret"
        case .bonus: "Bonuslar"
        case .other: "Diğer"
        case .side: "Yan haklar (nakit değil)"
        }
    }

    var symbol: String {
        switch self {
        case .packages: "shippingbox.fill"
        case .distance: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .hourly: "clock.fill"
        case .fixed: "banknote.fill"
        case .bonus: "gift.fill"
        case .other: "plus.circle.fill"
        case .side: "heart.circle.fill"
        }
    }
}

/// Dokumdeki tek satir: donem tutari ve gune dusen payi.
struct PayDetailRow: Identifiable, Equatable {
    var id: String
    var category: PayDetailCategory
    var label: String
    /// Or. "312 paket × 64,50 TL" ya da "65.223 TL ÷ 26 gün".
    var quantityText: String?
    /// Hesaplanan donemdeki tutar (plan icin ay, vardiya icin gun).
    var periodAmount: Money
    var perDay: Money
    /// Motorun donem toplamina katmadigi, gune bolunerek eklenen tahmin (or. gunluk kayitta aylik sabit ucret payi).
    var isEstimate: Bool = false
}

/// Kazancin kalem kalem dokumu: paketlerden, km'den, sabit ucretin gune dusen payindan, bonuslardan.
struct PayDetail: Equatable {
    var rows: [PayDetailRow]
    /// Donemdeki is gunu (gune bolme icin).
    var days: Int

    var categories: [PayDetailCategory] {
        PayDetailCategory.allCases.filter { category in rows.contains { $0.category == category } }
    }

    func rows(in category: PayDetailCategory) -> [PayDetailRow] { rows.filter { $0.category == category } }

    func total(_ category: PayDetailCategory) -> Money { rows(in: category).map(\.periodAmount).sum() }
    func totalPerDay(_ category: PayDetailCategory) -> Money { rows(in: category).map(\.perDay).sum() }

    /// Nakit toplam (yan haklar haric), tahmini paylar dahil.
    var periodTotal: Money { rows.filter { $0.category != .side }.map(\.periodAmount).sum() }
    var perDayTotal: Money { rows.filter { $0.category != .side }.map(\.perDay).sum() }
    var hasEstimates: Bool { rows.contains { $0.isEstimate } }
}

enum PayDetailBuilder {
    static func category(of line: PayLine) -> PayDetailCategory {
        if line.itemKey.hasPrefix("distance.") || line.itemKey.hasPrefix("km.") { return .distance }
        switch line.type {
        case .singlePackage, .combinedPackage, .surgeMultiplier: return .packages
        case .perKm: return .distance
        case .hourly: return .hourly
        case .fixed: return .fixed
        case .dailyBonus, .weeklyBonus, .monthlyBonus, .referralBonus: return .bonus
        case .inKindSupport, .fuelEquipmentSupport: return line.isCash ? .other : .side
        default: return .other
        }
    }

    /// - Parameters:
    ///   - days: Hesaplanan donemdeki is gunu (gun: 1, ay: aydaki is gunu).
    ///   - version: Gunluk / haftalik hesapta aylik sabit ucretin gune dusen payini bulmak icin tarife.
    ///   - monthWorkDays: Aylik sabit ucretin bolundugu is gunu (haftada 6 gun -> 26).
    static func make(breakdown: PayBreakdown, days: Int, version: TariffVersion? = nil, regionTier: String? = nil,
                     monthWorkDays: Int = 26, contractHours: Int? = nil, seniorityYears: Int? = nil,
                     extraRows: [PayDetailRow] = []) -> PayDetail {
        let dayCount: Int = max(1, days)
        var rows: [PayDetailRow] = []
        for line in breakdown.lines where line.included && line.type != .deduction {
            let amount: Money = line.low
            guard amount.value != 0 else { continue }
            rows.append(PayDetailRow(id: line.id, category: category(of: line), label: line.label,
                                     quantityText: quantityText(line), periodAmount: amount,
                                     perDay: divide(amount, by: dayCount)))
        }
        rows += extraRows
        let hasFixed: Bool = rows.contains { $0.category == .fixed }
        if breakdown.span != .month, !hasFixed, let version {
            rows += fixedShares(version: version, day: breakdown.startDay, regionTier: regionTier, days: dayCount,
                                monthWorkDays: max(1, monthWorkDays), contractHours: contractHours, seniorityYears: seniorityYears)
        }
        for line in breakdown.sideBenefits where line.amount.value > 0 {
            rows.append(PayDetailRow(id: "side." + line.id, category: .side, label: line.label, quantityText: nil,
                                     periodAmount: line.amount, perDay: divide(line.amount, by: dayCount)))
        }
        return PayDetail(rows: rows, days: dayCount)
    }

    /// Aylik sabit ucretin (ve kidem priminin) bu doneme dusen payi (gunluk / haftalik hesap ay sonunu beklemesin diye tahmin).
    /// Bolge, gunluk calisma suresi ve kidem kosullari kuryenin bilgileriyle eslesir; bolge bilinmiyorsa en dusuk bolge ucreti.
    static func fixedShares(version: TariffVersion, day: String, regionTier: String?, days: Int, monthWorkDays: Int,
                            contractHours: Int? = nil, seniorityYears: Int? = nil) -> [PayDetailRow] {
        let fixed: [TariffItem] = version.activeItems(on: day).filter { $0.type == .fixed && $0.unit == .month && $0.isCash }
        guard !fixed.isEmpty else { return [] }
        func hoursMatch(_ item: TariffItem) -> Bool {
            guard let hours = item.conditions.contractHours else { return true }
            guard let contractHours else { return false }
            return hours.contains(contractHours)
        }
        func seniorityMatch(_ item: TariffItem) -> Bool {
            let c = item.conditions
            guard c.minSeniorityYears != nil || c.maxSeniorityYears != nil else { return true }
            guard let years = seniorityYears else { return false }
            if let min = c.minSeniorityYears, years < min { return false }
            if let max = c.maxSeniorityYears, years >= max { return false }
            return true
        }
        let candidates: [TariffItem] = fixed.filter { hoursMatch($0) && seniorityMatch($0) }
        let regional: [TariffItem] = candidates.filter { $0.conditions.regionTier != nil }
        var chosen: [TariffItem] = candidates.filter { $0.conditions.regionTier == nil }
        var unsure = false
        if let match = regional.first(where: { $0.conditions.regionTier == regionTier }) {
            chosen.append(match)
        } else if let lowest = regional.min(by: { $0.amount < $1.amount }) {
            chosen.append(lowest)
            unsure = true
        }
        return chosen.map { item in
            let perDay: Money = divide(item.amount, by: monthWorkDays)
            let share: Money = days >= monthWorkDays ? item.amount : perDay * days
            let label: String = unsure && item.conditions.regionTier != nil ? "\(item.label) · bölge seçilmedi" : item.label
            return PayDetailRow(id: "share." + item.key, category: .fixed, label: label,
                                quantityText: "\(Formatters.currency(item.amount.doubleValue)) ÷ \(monthWorkDays) gün",
                                periodAmount: share, perDay: perDay, isEstimate: true)
        }
    }

    private static func quantityText(_ line: PayLine) -> String? {
        guard let quantity = line.quantity, let rate = line.rate else { return nil }
        let unit: String
        switch line.unit {
        case .package?: unit = "paket"
        case .km?: unit = "km"
        case .hour?: unit = "saat"
        case .day?: unit = "gün"
        default: unit = ""
        }
        return "\(Formatters.decimalText(quantity)) \(unit) × \(Formatters.currency(rate.doubleValue))"
            .replacingOccurrences(of: "  ", with: " ")
    }

    private static func divide(_ money: Money, by days: Int) -> Money {
        guard days > 0 else { return money }
        return Money(Money.round(money.value / Decimal(days)))
    }
}
