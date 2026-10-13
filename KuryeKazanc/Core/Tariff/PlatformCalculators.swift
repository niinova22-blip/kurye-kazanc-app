import Foundation

// Platforma ozgu hesaplayicilar. Her biri yalnizca kendi platformunun kalemlerini isler; tutarlar tarifeden gelir.
// Belirsiz kurallar (km bandi uygulamasi, esik uygulamasi, sabit ucret dayanagi, garanti) tarife ayarindan okunur
// ve ayar dogrulanmamissa alternatif sonuc uyari olarak gosterilir.

/// Ortak paket ve km yardimcilari.
enum PackagePay {
    /// Gunduz / gece tekli paketler. Gece kalemi yoksa gunduz/genel kalem kullanilir (uyari ile).
    static func singles(_ b: inout PayBuilder) {
        let singles: [TariffItem] = b.items(.singlePackage).filter { $0.method == .perUnit }
        let dayItem: TariffItem? = singles.first { $0.conditions.timeBand == .day } ?? singles.first { ($0.conditions.timeBand ?? .any) == .any }
        let nightItem: TariffItem? = singles.first { $0.conditions.timeBand == .night }
        b.consume(singles)
        let input: PayInput = b.input
        if let nightItem {
            if let dayItem { b.perUnit(dayItem, quantity: Decimal(input.dayPackages)) }
            b.perUnit(nightItem, quantity: Decimal(input.nightPackages))
        } else if let dayItem {
            b.perUnit(dayItem, quantity: Decimal(input.singlePackages))
        } else if input.singlePackages > 0 {
            b.note(.missing, "Tarifede paket ücreti yok; paketler hesaplanmadı.")
        }
    }

    static func combined(_ b: inout PayBuilder) {
        let items: [TariffItem] = b.items(.combinedPackage)
        b.consume(items)
        guard let item = items.first else {
            if b.input.combinedPackages > 0 { b.note(.missing, "Tarifede birleşen paket ücreti yok; birleşen paketler hesaplanmadı.") }
            return
        }
        b.perUnit(item, quantity: Decimal(b.input.combinedPackages))
    }

    /// Duz km ucreti (toplam km × ucret).
    static func flatKm(_ b: inout PayBuilder) {
        let items: [TariffItem] = b.items(.perKm).filter { $0.method == .perUnit }
        b.consume(items)
        guard let item = items.first else { return }
        b.perUnit(item, quantity: b.input.distanceKm)
    }

    /// Mesafe bantli km ucreti. Teslimat bazli mesafe yoksa toplam km teslimat sayisina bolunerek tahmin edilir.
    static func bandedKm(_ b: inout PayBuilder) {
        let bands: [TariffItem] = b.items(.perKm).filter { $0.method == .distanceBand }
            .sorted { ($0.lowerThreshold ?? 0) < ($1.lowerThreshold ?? 0) }
        b.consume(bands)
        guard !bands.isEmpty else { return }
        let input: PayInput = b.input
        var distances: [Decimal] = input.deliveryDistancesKm
        if distances.isEmpty, let total = input.totalKm, total > 0 {
            let trips: Int = max(1, input.singlePackages)
            let average: Decimal = Money.round(total / Decimal(trips), scale: 3)
            distances = Array(repeating: average, count: trips)
            b.note(.estimate, "Teslimat başına mesafe girilmedi; toplam \(total) km, \(trips) teslimata eşit bölündü (ortalama \(average) km).")
        }
        guard !distances.isEmpty else { return }
        let method: KmMethod = b.version.settings.kmMethod ?? .slab
        let primary: KmBandResult = KmBands.price(distances, bands: bands, method: method)
        for (index, band) in bands.enumerated() {
            let km: Decimal = primary.kmPerBand[index]
            guard km > 0 else { continue }
            b.add(PayLine(id: band.key, itemID: band.id, itemKey: band.key, type: .perKm, label: band.label,
                          quantity: Money.round(km, scale: 2), unit: .km, rate: band.amount, amount: band.amount * km,
                          amountUpper: band.amountUpper.map { $0 * km }, confidence: band.confidence))
        }
        if primary.unpricedKm > 0 {
            b.note(.needsVerification, "\(Money.round(primary.unpricedKm, scale: 2)) km tarifede tanımlı olmayan bir mesafe aralığına düştü (ara kademe bilinmiyor); ücretlendirilmedi.")
        }
        if !b.version.settings.confidence(of: "km_method").isTrusted {
            let other: KmMethod = method == .slab ? .wholeDistance : .slab
            let alt: KmBandResult = KmBands.price(distances, bands: bands, method: other)
            if alt.total != primary.total {
                let name: String = other == .slab ? "dilimli" : "tüm mesafe tek kademeden"
                b.alternative("Km primi uygulama biçimi doğrulanmadı; \(name) uygulanırsa brüt %ALT% TL.", delta: alt.total - primary.total)
            }
        }
    }
}

struct KmBandResult {
    var kmPerBand: [Decimal]
    var unpricedKm: Decimal
    var total: Money
}

enum KmBands {
    /// Bantlar [alt, ust) km. Dilimli: her km kendi bandinda. Tum mesafe: teslimatin tamami dustugu bandin ucretiyle.
    static func price(_ distances: [Decimal], bands: [TariffItem], method: KmMethod) -> KmBandResult {
        var perBand: [Decimal] = Array(repeating: 0, count: bands.count)
        var unpriced: Decimal = 0
        for distance in distances where distance > 0 {
            switch method {
            case .slab:
                var covered: Decimal = 0
                for (index, band) in bands.enumerated() {
                    let lower: Decimal = band.lowerThreshold ?? 0
                    let upper: Decimal = band.upperThreshold ?? distance
                    let portion: Decimal = max(0, min(distance, upper) - lower)
                    if portion > 0 {
                        perBand[index] += portion
                        covered += portion
                    }
                }
                unpriced += max(0, distance - covered)
            case .wholeDistance:
                if let index = bands.firstIndex(where: { band in
                    let lower: Decimal = band.lowerThreshold ?? 0
                    if distance < lower { return false }
                    if let upper = band.upperThreshold, distance >= upper { return false }
                    return true
                }) {
                    perBand[index] += distance
                } else {
                    unpriced += distance
                }
            }
        }
        var total = Money.zero
        for (index, band) in bands.enumerated() { total += band.amount * perBand[index] }
        return KmBandResult(kmPerBand: perBand, unpricedKm: unpriced, total: total)
    }
}

// MARK: - Yemeksepeti Express

/// Tekli + birlesen paket; saatlik garanti yalnizca dogrulanmis / kullanici onayli ise fark odemesi olarak eklenir.
/// 2026 tarifesinde paket ucreti gun ve saat bandina gore (Pzt–Per / Cuma / Cumartesi / Pazar × 6 saat bandi);
/// Pazar aksam ve gece ek odemeleri de gun / saatle eslesir. Bahsis ayri, referans yalnizca kosul saglaninca.
struct YemeksepetiCalculator: PayCalculator {
    let platformCode = "yemeksepeti"

    func apply(_ b: inout PayBuilder) {
        if TimedPackages.isTimed(b) {
            TimedPackages.apply(&b)
        } else {
            PackagePay.singles(&b)
        }
        PackagePay.combined(&b)
        PackagePay.flatKm(&b)
        applyGuarantee(&b)
    }

    /// Fark odemesi = garanti × saat − garantiye tabi gelir (paket ucretleri). Bahsis ve referans garantiye tabi degil.
    private func applyGuarantee(_ b: inout PayBuilder) {
        let items: [TariffItem] = b.items(method: .guaranteeTopUp)
        b.consume(items)
        guard let item = items.first, b.input.hours > 0 else { return }
        let guaranteed: Money = item.amount * b.input.hours
        let subject: [PayLine] = b.lines.filter { $0.type == .singlePackage || $0.type == .combinedPackage }
        let incomeLow: Money = subject.map(\.low).sum()
        let incomeHigh: Money = subject.map(\.high).sum()
        let topUpLow: Money = Money.max(.zero, guaranteed - incomeHigh)
        let topUpHigh: Money = Money.max(.zero, guaranteed - incomeLow)
        let trusted: Bool = item.confidence.isTrusted
        let note: String = "Garanti \(guaranteed) TL (\(item.amount) TL × \(b.input.hours) sa) − paket geliri \(incomeLow) TL"
        // Satir tutari: alt gelirle (topUpHigh) birlikte brut alt siniri = max(garanti, alt gelir) olur
        b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: .hourly, label: "Saatlik garanti fark ödemesi",
                      quantity: b.input.hours, unit: .hour, rate: item.amount, amount: topUpHigh,
                      amountUpper: topUpLow != topUpHigh ? topUpLow : nil, confidence: item.confidence,
                      included: trusted, note: note))
        if !trusted, !topUpHigh.isZero {
            b.alternative("Saatlik garanti kuralı doğrulanmadı (tarife doğrulaması gerekli); fark ödemesi \(topUpHigh) TL hesaba katılmadı. Kural geçerliyse brüt %ALT% TL.",
                          delta: topUpHigh, kind: .needsVerification)
        }
    }
}

// MARK: - Paket Taxi / Migros Hemen

/// Aylik sabit ucret (bolge ya da kidem; otomatik toplanmaz) + aylik paket kademesine gore paket basi performans ucreti
/// (eski tarife) ya da aylik paket bonusu (ortak kademe kurali) + teslimat basi mesafe ek odemesi.
/// Sabit ucretin kapsadigi paketler varsa tekrar ucretlendirilmez.
struct PaketTaxiCalculator: PayCalculator {
    /// Paket Taxi'nin uc kolu ayni kurallarla: "pt_restoran", "pt_migros", "migros_hemen" (Migros Hemen).
    var platformCode: String = "migros_hemen"

    func apply(_ b: inout PayBuilder) {
        applyFixed(&b)
        applyPerformance(&b)
        DailyPackageRates.apply(&b)
        DeliveryBands.apply(&b)
    }

    private func applyFixed(_ b: inout PayBuilder) {
        let fixed: [TariffItem] = b.items(.fixed)
        b.consume(fixed)
        guard !fixed.isEmpty else { return }
        guard b.input.span == .month else {
            b.note(.deferred, "Aylık sabit ücret ay sonunda, dönem özetinde hesaplanır.")
            return
        }
        // Kosulsuz sabit ucret (Migros / Migros Hemen: tum bolgelerde ayni)
        for item in fixed where item.conditions.regionTier == nil && item.conditions.minSeniorityYears == nil
            && item.conditions.contractHours == nil && item.isCash && b.isEligible(item) {
            addFixed(item, included: true, in: &b)
        }
        let regionItems: [TariffItem] = fixed.filter { $0.conditions.regionTier != nil }
        let seniorityItems: [TariffItem] = fixed.filter { $0.conditions.minSeniorityYears != nil }
        if fixed.contains(where: { $0.conditions.contractHours != nil }), b.input.contractHours == nil {
            b.note(.missing, "Günlük çalışma süresi (9–12 saat) seçilmedi; sabit ücret bulunamadı.")
        }
        let region: TariffItem? = regionItems.first { b.isEligible($0) }
        let seniority: TariffItem? = seniorityItems.first { b.isEligible($0) }
        let basis: FixedPayBasis = b.version.settings.fixedPayBasis ?? .region
        let trusted: Bool = b.version.settings.confidence(of: "fixed_pay_basis").isTrusted

        if !regionItems.isEmpty, b.input.regionTier == nil {
            b.note(.missing, "Bölge seçilmedi (1., 2.–3. ya da 4. bölge).")
        }
        if !seniorityItems.isEmpty, b.input.seniorityYears == nil, basis != .region {
            b.note(.missing, "Kıdem yılı girilmedi.")
        }
        let useRegion: Bool = basis == .region || basis == .both
        let useSeniority: Bool = basis == .seniority || basis == .both
        if let region { addFixed(region, included: useRegion, in: &b) }
        if let seniority { addFixed(seniority, included: useSeniority, in: &b) }

        if !trusted, let region, let seniority, basis != .both {
            let delta: Money = basis == .region ? seniority.amount - region.amount : region.amount - seniority.amount
            let altName: String = basis == .region ? "kıdem tarifesi" : "bölge tarifesi"
            b.alternative("Bölge ücreti ile kıdem tarifesinin birlikte mi alternatif mi olduğu doğrulanmadı; toplanmadı. \(altName) geçerliyse brüt %ALT% TL.", delta: delta)
        }
    }

    private func addFixed(_ item: TariffItem, included: Bool, in b: inout PayBuilder) {
        b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: .fixed, label: item.label, unit: .month,
                      amount: item.amount, amountUpper: item.amountUpper, confidence: item.confidence, included: included,
                      note: included ? nil : "Alternatif tarife; toplama eklenmedi."))
    }

    private func applyPerformance(_ b: inout PayBuilder) {
        let tiers: [TariffItem] = b.items(method: .tierRate).sorted { ($0.lowerThreshold ?? 0) < ($1.lowerThreshold ?? 0) }
        b.consume(tiers)
        guard let base = tiers.first else {
            // 2026 tarifesinde ayri paket basi ucret yok (sabit ucret + aylik bonus); varsa tekli/birlesen ucret islenir.
            if !b.items(.singlePackage).isEmpty { PackagePay.singles(&b) }
            if !b.items(.combinedPackage).isEmpty { PackagePay.combined(&b) }
            return
        }
        let isMonth: Bool = b.input.span == .month
        let monthCount: Int = b.input.periodPackages ?? b.input.totalPackages
        let packages: Int = b.input.totalPackages
        let covered: Int = b.version.settings.fixedCoversPackages ?? 0

        if let next = tiers.first(where: { PayEngine.decimalInt($0.lowerThreshold) > monthCount }) {
            b.addProgress(BonusProgress(itemKey: next.key, label: "\(next.label) kademesi", current: monthCount,
                                        target: PayEngine.decimalInt(next.lowerThreshold), reward: next.amount, unit: .month,
                                        confidence: next.confidence))
        }

        guard isMonth else {
            // Gunluk / haftalik kayit: kademe ay sonunda belli olur; taban ucretle tahmin
            let payable: Int = packages
            guard payable > 0 else { return }
            b.add(PayLine(id: base.key, itemID: base.id, itemKey: base.key, type: base.type, label: "\(base.label) (taban)",
                          quantity: Decimal(payable), unit: .package, rate: base.amount, amount: base.amount * payable,
                          confidence: base.confidence, provisional: true))
            b.note(.deferred, "Paket başı ücret aylık paket sayısına göre ay sonunda kesinleşir; taban ücretle hesaplandı.")
            return
        }

        let application: ThresholdApplication = b.version.settings.thresholdApplication ?? .allUnits
        let primary: Money = performancePay(tiers: tiers, count: monthCount, covered: covered, application: application, into: &b, addLines: true)
        if covered > 0 {
            b.note(.info, "Sabit ücretin kapsadığı ilk \(covered) paket ayrıca ücretlendirilmedi (mükerrer sayım yok).")
        }
        if !b.version.settings.confidence(of: "threshold_application").isTrusted {
            let other: ThresholdApplication = application == .allUnits ? .aboveThresholdOnly : .allUnits
            let alt: Money = performancePay(tiers: tiers, count: monthCount, covered: covered, application: other, into: &b, addLines: false)
            if alt != primary {
                let name: String = other == .allUnits ? "eşik aşılınca tüm paketlere" : "yalnızca eşiğin üstündeki paketlere"
                b.alternative("Kademe ücretinin uygulanışı doğrulanmadı; \(name) uygulanırsa brüt %ALT% TL.", delta: alt - primary)
            }
        }
    }

    /// Paket sirasi n = 1...count; ilk `covered` paket sabit ucrette oldugundan ucretlendirilmez.
    /// Tum paketler: ulasilan kademenin (alt esik ≤ aylik toplam) ucreti tum ucretli paketlere.
    /// Esik ustu: n. paket, alt esigi ≤ n olan en yuksek kademeden (1.100. paket ve sonrasi 40 TL gibi).
    @discardableResult
    func performancePay(tiers: [TariffItem], count: Int, covered: Int, application: ThresholdApplication,
                        into b: inout PayBuilder, addLines: Bool) -> Money {
        let payable: Int = max(0, count - covered)
        guard payable > 0 else { return .zero }
        switch application {
        case .allUnits:
            let reached: TariffItem = tiers.last { PayEngine.decimalInt($0.lowerThreshold) <= count } ?? tiers[0]
            let amount: Money = reached.amount * payable
            if addLines {
                b.add(PayLine(id: reached.key, itemID: reached.id, itemKey: reached.key, type: reached.type,
                              label: "\(reached.label) (tüm paketlere)", quantity: Decimal(payable), unit: .package,
                              rate: reached.amount, amount: amount, confidence: reached.confidence, scope: .monthly))
            }
            return amount
        case .aboveThresholdOnly:
            var total = Money.zero
            for (index, tier) in tiers.enumerated() {
                let from: Int = max(PayEngine.decimalInt(tier.lowerThreshold), 1, covered + 1)
                let nextLower: Int? = index + 1 < tiers.count ? PayEngine.decimalInt(tiers[index + 1].lowerThreshold) : nil
                let to: Int = min(count, (nextLower ?? (count + 1)) - 1)
                let units: Int = to - from + 1
                guard units > 0 else { continue }
                let amount: Money = tier.amount * units
                total += amount
                if addLines {
                    b.add(PayLine(id: tier.key, itemID: tier.id, itemKey: tier.key, type: tier.type,
                                  label: "\(tier.label) (\(from)–\(to). paket)", quantity: Decimal(units),
                                  unit: .package, rate: tier.amount, amount: amount, confidence: tier.confidence, scope: .monthly))
                }
            }
            return total
        }
    }
}

// MARK: - Gun / saat bantli paket ucreti

/// Paketin gunu ve saatine gore ucret (Yemeksepeti 2026). Teslimat saatleri biliniyorsa (canli vardiya) her paket kendi
/// bandiyla; bilinmiyorsa gunduz paketleri 12:00–14:59, aksam paketleri 18:00–20:59 bandiyla, donem hesabinda haftanin
/// gunlerine esit dagitilarak hesaplanir.
enum TimedPackages {
    static func isTimed(_ b: PayBuilder) -> Bool {
        b.items(.singlePackage).contains { $0.conditions.hourFrom != nil || $0.conditions.hourTo != nil }
    }

    /// (gun, saat, paket) — paket sayisi donem dagiliminda kesirli olabilir.
    static func slots(for input: PayInput) -> [(weekday: Int, hour: Int, count: Decimal)] {
        if !input.deliverySlots.isEmpty {
            return input.deliverySlots.filter { $0.count > 0 }.map { ($0.weekday, $0.hour, Decimal($0.count)) }
        }
        let dayCount = Decimal(input.dayPackages)
        let nightCount = Decimal(input.nightPackages)
        let weekdays: [Int]
        if input.span == .day, let weekday = weekday(of: input.startDay) {
            weekdays = [weekday]
        } else {
            weekdays = [2, 3, 4, 5, 6, 7, 1]
        }
        let share = Decimal(weekdays.count)
        var out: [(weekday: Int, hour: Int, count: Decimal)] = []
        for weekday in weekdays {
            if dayCount > 0 { out.append((weekday, 13, dayCount / share)) }
            if nightCount > 0 { out.append((weekday, 19, nightCount / share)) }
        }
        return out
    }

    static func weekday(of day: String) -> Int? {
        guard let date = RuleDay.date(day) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.component(.weekday, from: date)
    }

    static func apply(_ b: inout PayBuilder) {
        let singles: [TariffItem] = b.items(.singlePackage).filter { $0.method == .perUnit }
        let extras: [TariffItem] = b.items(.otherPayment).filter {
            $0.method == .perUnit && ($0.conditions.hourFrom != nil || $0.conditions.weekdays != nil)
        }
        b.consume(singles)
        b.consume(extras)
        var quantities: [String: Decimal] = [:]
        var unpriced: Decimal = 0
        for slot in slots(for: b.input) {
            if let item = singles.first(where: { $0.conditions.matches(weekday: slot.weekday, hour: slot.hour) }) {
                quantities[item.id, default: 0] += slot.count
            } else {
                unpriced += slot.count
            }
            for extra in extras where extra.conditions.matches(weekday: slot.weekday, hour: slot.hour) && b.isEligible(extra) {
                quantities[extra.id, default: 0] += slot.count
            }
        }
        for item in singles + extras {
            guard let quantity = quantities[item.id], quantity > 0 else { continue }
            b.perUnit(item, quantity: Money.round(quantity, scale: 2))
        }
        if unpriced > 0 {
            b.note(.missing, "\(Money.round(unpriced, scale: 0)) paket tarifedeki saat bantlarına uymadı; ücretlendirilmedi.")
        }
        if b.input.deliverySlots.isEmpty, b.input.totalPackages > 0 {
            b.note(.estimate, "Teslimat saatleri bilinmiyor: gündüz paketleri 12:00–14:59, akşam paketleri 18:00–20:59 ücretiyle hesaplandı. Canlı vardiyada her paket kendi saatiyle hesaplanır.")
        }
    }
}

// MARK: - Gunluk paket primi

/// `daily_package_rate`: bir gunde [alt, ust] sirasindaki her paket icin paket basi prim (Paket Taxi Restoran).
/// Gunluk kayitta o gunun paketleri; donem hesabinda gunluk ortalama × calisilan gun.
enum DailyPackageRates {
    static func apply(_ b: inout PayBuilder) {
        let all: [TariffItem] = b.items(method: .dailyPackageRate)
        b.consume(all)
        let items: [TariffItem] = all.filter { b.isEligible($0) }.sorted { ($0.lowerThreshold ?? 0) < ($1.lowerThreshold ?? 0) }
        guard !items.isEmpty else {
            if !all.isEmpty, b.input.totalPackages > 0 {
                b.note(.missing, "Paket primi için bölge ve günlük çalışma süresi gerekli.")
            }
            return
        }
        let total: Int = b.input.periodPackages ?? b.input.totalPackages
        let days: Int
        if b.input.span == .day {
            days = 1
        } else if let worked = b.input.workDays, worked > 0 {
            days = worked
        } else {
            days = 26
            b.note(.estimate, "Çalışılan gün bilinmediği için paket primi 26 güne eşit dağıtılarak hesaplandı.")
        }
        let perDay: Int = total / max(1, days)
        guard perDay > 0 else { return }
        for item in items {
            let lower: Int = PayEngine.decimalInt(item.lowerThreshold)
            let upper: Int = item.upperThreshold.map { PayEngine.decimalInt($0) } ?? perDay
            let units: Int = max(0, min(perDay, upper) - lower + 1)
            guard units > 0 else { continue }
            let quantity: Int = units * days
            let label: String = days > 1 ? "\(item.label) × \(days) gün" : item.label
            b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: item.type, label: label,
                          quantity: Decimal(quantity), unit: .package, rate: item.amount, amount: item.amount * quantity,
                          confidence: item.confidence, scope: .daily))
        }
        if let first = items.first, perDay < PayEngine.decimalInt(first.lowerThreshold) {
            b.addProgress(BonusProgress(itemKey: first.key, label: "Paket primi (\(PayEngine.decimalInt(first.lowerThreshold)). paketten itibaren)",
                                        current: perDay, target: PayEngine.decimalInt(first.lowerThreshold), reward: first.amount,
                                        unit: .day, confidence: first.confidence))
        }
    }
}

// MARK: - Teslimat basi mesafe ek odemesi

/// `delivery_band` kalemleri: mesafesi bandin [alt, ust] araligina dusen her teslimat icin sabit ek odeme.
/// Teslimat bazli mesafe yoksa toplam km paket sayisina bolunur (ortalama); uzun teslimatlarin payi boylece eksik kalabilir.
enum DeliveryBands {
    static func apply(_ b: inout PayBuilder) {
        let bands: [TariffItem] = b.items(method: .deliveryBand).sorted { ($0.lowerThreshold ?? 0) < ($1.lowerThreshold ?? 0) }
        b.consume(bands)
        guard !bands.isEmpty else { return }
        var counts: [Int] = Array(repeating: 0, count: bands.count)
        let input: PayInput = b.input
        if !input.deliveryDistancesKm.isEmpty {
            for distance in input.deliveryDistancesKm {
                if let index = band(for: distance, in: bands) { counts[index] += 1 }
            }
        } else if let total = input.totalKm, total > 0, input.totalPackages > 0 {
            let trips: Int = input.totalPackages
            let average: Decimal = Money.round(total / Decimal(trips), scale: 2)
            if let index = band(for: average, in: bands) { counts[index] = trips }
            b.note(.estimate, "Mesafe ek ödemesi teslimat başına ortalama \(Formatters.decimalText(average)) km ile hesaplandı; uzun teslimatların ek ödemesi gerçek mesafeyle değişir.")
        } else {
            return
        }
        for (index, item) in bands.enumerated() where counts[index] > 0 {
            b.add(PayLine(id: item.key, itemID: item.id, itemKey: item.key, type: item.type, label: item.label,
                          quantity: Decimal(counts[index]), unit: .package, rate: item.amount, amount: item.amount * counts[index],
                          amountUpper: item.amountUpper.map { $0 * counts[index] }, confidence: item.confidence, isCash: item.isCash))
        }
    }

    /// Alt esik dahil, ust esik dahil; birden cok band uyarsa ilk (alt esigi kucuk) band. Alt esigi olmayan band 0 km'den.
    static func band(for distance: Decimal, in bands: [TariffItem]) -> Int? {
        bands.firstIndex { band in
            let lower: Decimal = band.lowerThreshold ?? 0
            guard distance >= lower, distance > 0 else { return false }
            if let upper = band.upperThreshold { return distance <= upper }
            return distance > lower || lower == 0
        }
    }
}
