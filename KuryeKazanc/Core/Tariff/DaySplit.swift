import Foundation

/// 1.12.1: ayni gunun birden fazla gunluk kaydi (birkac vardiya, vardiya + elle hesap) tek gun gibi hesaplanir.
///
/// Gunluk esikli kalemler (gunluk paket primi kademeleri, "21. paketten itibaren" primi, gunluk bonus) gunun TOPLAM
/// paketine baglidir. Eskiden her kayit kendi paketleriyle ayri hesaplaniyordu: 10 + 8 + 7 = 25 paketlik gunde 24–27 primi
/// yerine bir vardiyaya 16–19 primi yaziliyordu. Simdi k. kaydin payi = hesap(1..k kayitlarin toplami) − hesap(1..k−1):
/// paylarin toplami her zaman gunun toplam hesabina esittir, her kayit yalnizca kendi kattigi farki tasir.
enum DaySplit {
    /// Kayitlarin girdilerini gun toplamina cevirir. Tercihler (bolge, kidem, arac...) en son kayittan alinir.
    static func combine(_ inputs: [PayInput]) -> PayInput? {
        guard var total = inputs.last else { return nil }
        guard inputs.count > 1 else { return total }
        total.dayPackages = inputs.map(\.dayPackages).reduce(0, +)
        total.nightPackages = inputs.map(\.nightPackages).reduce(0, +)
        total.combinedPackages = inputs.map(\.combinedPackages).reduce(0, +)
        total.surgePackages = inputs.map(\.surgePackages).reduce(0, +)
        total.hours = inputs.map(\.hours).reduce(0, +)
        // Teslimat bazli mesafe ancak hepsinde varsa birlesir; yoksa toplam km
        let everyHasList: Bool = inputs.allSatisfy { !$0.deliveryDistancesKm.isEmpty || $0.totalPackages == 0 }
        if everyHasList, inputs.contains(where: { !$0.deliveryDistancesKm.isEmpty }) {
            total.deliveryDistancesKm = inputs.flatMap(\.deliveryDistancesKm)
            total.totalKm = nil
        } else {
            total.deliveryDistancesKm = []
            let anyKm: Bool = inputs.contains { $0.totalKm != nil || !$0.deliveryDistancesKm.isEmpty }
            total.totalKm = anyKm ? inputs.map(\.distanceKm).reduce(0, +) : nil
        }
        // Saat dagilimi: canli vardiyada her paket kendi saatiyle. Saati olmayan kayit (elle hesap) varsa onun paketleri
        // motorun tahminiyle ayni saate yazilir (gunduz 12:00, aksam 18:00) ki vardiyalarin gercek saatleri kaybolmasin.
        if inputs.contains(where: { !$0.deliverySlots.isEmpty }) {
            total.deliverySlots = inputs.flatMap { input -> [DeliverySlot] in
                guard input.deliverySlots.isEmpty, input.totalPackages > 0 else { return input.deliverySlots }
                return estimatedSlots(input)
            }
        } else {
            total.deliverySlots = []
        }
        total.tips = inputs.map(\.tips).sum()
        total.extraPayments = inputs.map(\.extraPayments).sum()
        total.deductions = inputs.map(\.deductions).sum()
        total.advances = inputs.map(\.advances).sum()
        total.referralConditionsMet = inputs.contains { $0.referralConditionsMet }
        total.flags = Array(Set(inputs.flatMap(\.flags))).sorted()
        var amounts: [String: Money] = [:]
        for input in inputs {
            for (key, value) in input.flagAmounts { amounts[key] = value }
        }
        total.flagAmounts = amounts
        total.weekendPackages = nil
        total.periodPackages = nil
        total.bonusTierDays = [:]
        total.workDays = nil
        return total
    }

    /// `total` sonucundan `previous` sonucunu satir satir cikarir (ayni kimlikli satirlar). Onceki hesapta olup toplamda
    /// olmayan nakit satir (or. ust kademeye gecilince dusen alt kademe primi) eksi satir olarak kalir.
    static func difference(total: PayBreakdown, previous: PayBreakdown?) -> PayBreakdown {
        guard let previous else { return total }
        var result = total
        let previousLines: [String: PayLine] = Dictionary(previous.lines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var lines: [PayLine] = []
        var seen: Set<String> = []
        for line in total.lines {
            seen.insert(line.id)
            guard let before = previousLines[line.id] else {
                lines.append(line)
                continue
            }
            guard counts(line) || counts(before) else { continue }
            var share = line
            share.amount = line.amount - before.amount
            if line.amountUpper != nil || before.amountUpper != nil {
                share.amountUpper = (line.amountUpper ?? line.amount) - (before.amountUpper ?? before.amount)
            }
            if line.rate != nil, let now = line.quantity, let then = before.quantity {
                share.quantity = now - then
            }
            if share.amount.isZero, (share.amountUpper ?? .zero).isZero { continue }
            lines.append(share)
        }
        for before in previous.lines where !seen.contains(before.id) && counts(before) {
            var reversed = before
            reversed.amount = Money.zero - before.amount
            reversed.amountUpper = before.amountUpper.map { Money.zero - $0 }
            // Ayni etiket: gun dokumunde onceki kayittaki satirla toplanip sifirlanir
            reversed.note = "Önceki kayıtta sayılmıştı; gün toplamı üst kademeye geçti."
            lines.append(reversed)
        }
        result.lines = lines
        result.extraPayments = total.extraPayments - previous.extraPayments
        result.deductions = total.deductions - previous.deductions
        result.advances = total.advances - previous.advances
        return result
    }

    /// Kronolojik kayitlarin paylari. `calculate` gun toplami girdisini hesaplar (kaydin tarife surumuyle).
    /// Herhangi bir hesap basarisizsa nil.
    static func shares(inputs: [PayInput], calculate: (_ combined: PayInput, _ index: Int) -> PayBreakdown?) -> [PayBreakdown]? {
        var result: [PayBreakdown] = []
        var previous: PayBreakdown?
        for index in inputs.indices {
            guard let combined = combine(Array(inputs[0...index])),
                  let total = calculate(combined, index) else { return nil }
            var share = difference(total: total, previous: previous)
            share.startDay = inputs[index].startDay
            share.endDay = inputs[index].endDay
            result.append(share)
            previous = total
        }
        return result
    }

    private static func counts(_ line: PayLine) -> Bool { line.included && line.isCash }

    /// Saati bilinmeyen kaydin paketleri: gunduz (ve birlesik) 12:00, aksam 18:00 (motorun tahmin kuraliyla ayni).
    static func estimatedSlots(_ input: PayInput) -> [DeliverySlot] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let weekday: Int = RuleDay.date(input.startDay).map { calendar.component(.weekday, from: $0) } ?? 2
        var slots: [DeliverySlot] = []
        let dayCount: Int = input.dayPackages + input.combinedPackages
        if dayCount > 0 { slots.append(DeliverySlot(weekday: weekday, hour: 12, count: dayCount)) }
        if input.nightPackages > 0 { slots.append(DeliverySlot(weekday: weekday, hour: 18, count: input.nightPackages)) }
        return slots
    }
}
