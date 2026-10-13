import Foundation

/// Hesaplamanin kapsadigi donem.
enum PaySpan: String, Codable, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: "Gün"
        case .week: "Hafta"
        case .month: "Ay"
        }
    }

    /// Kademe kaleminin birimi bu donemle mi hesaplanir.
    var unit: TariffUnit {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        }
    }
}

/// Kuryenin girdigi degerler. Dort giris yontemi (hizli, detayli, donem, odeme karsilastirma) ayni yapiyi
/// farkli ayrinti duzeyinde doldurur; hepsi ayni motor ve ayni tarife surumuyle hesaplanir.
struct PayInput: Codable, Equatable {
    var platformCode: String
    var span: PaySpan = .day
    /// yyyy-MM-dd (dahil).
    var startDay: String
    /// yyyy-MM-dd (dahil).
    var endDay: String
    var workModel: String = "esnaf"
    var regionID: String? = nil
    /// "motorcycle" / "car" (Getir motorlu / aracli tarifesi).
    var vehicleType: String? = nil

    var dayPackages: Int = 0
    var nightPackages: Int = 0
    var combinedPackages: Int = 0
    /// Teslimat basina mesafeler (detayli kayit). Bos ise `totalKm` kullanilir.
    var deliveryDistancesKm: [Decimal] = []
    var totalKm: Decimal? = nil
    var hours: Decimal = 0

    var tips: Money = .zero
    var referralConditionsMet: Bool = false
    var referralAmount: Money? = nil
    /// Kullanicinin girdigi yogunluk carpani ve uygulandigi paket sayisi. Otomatik carpan yoktur.
    var surgeMultiplier: Decimal? = nil
    var surgePackages: Int = 0
    /// Uygunluk isaretleri ("weekly_performance", "woman_employment", ...).
    var flags: [String] = []
    /// Isarete bagli kalemde kullanicinin bildigi gercek tutar (or. haftalik performans bonusu 750 TL).
    var flagAmounts: [String: Money] = [:]

    /// Cuma-Cumartesi-Pazar paket toplami (Getir hafta sonu bonusu).
    var weekendPackages: Int? = nil
    /// Donem toplam paket (aylik kademe / haftalik bonus). nil: bu kayittaki paketler.
    var periodPackages: Int? = nil
    /// Donem hesabinda gunluk bonus kademesine ulasilan gun sayisi (kalem anahtari -> gun).
    var bonusTierDays: [String: Int] = [:]
    /// Paket Taxi bolgesi ("r1" / "r23" / "r4") ve kidem yili.
    var regionTier: String? = nil
    var seniorityYears: Int? = nil
    /// Gunluk calisma suresi (Paket Taxi Restoran 9–12 saat tarifesi).
    var contractHours: Int? = nil
    /// Donem hesabinda calisilan gun (gunluk paket primi icin; nil: bilinmiyor).
    var workDays: Int? = nil
    /// Teslimatlarin gun / saat dagilimi (Yemeksepeti saat saat ucret). Bos ise gunduz / aksam paketlerinden tahmin.
    var deliverySlots: [DeliverySlot] = []

    var extraPayments: Money = .zero
    var deductions: Money = .zero
    var advances: Money = .zero

    init(platformCode: String, span: PaySpan = .day, startDay: String, endDay: String? = nil) {
        self.platformCode = platformCode
        self.span = span
        self.startDay = startDay
        self.endDay = endDay ?? startDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        platformCode = try c.decode(String.self, forKey: .platformCode)
        span = try c.decodeIfPresent(PaySpan.self, forKey: .span) ?? .day
        startDay = try c.decode(String.self, forKey: .startDay)
        endDay = try c.decodeIfPresent(String.self, forKey: .endDay) ?? startDay
        workModel = try c.decodeIfPresent(String.self, forKey: .workModel) ?? "esnaf"
        regionID = try c.decodeIfPresent(String.self, forKey: .regionID)
        vehicleType = try c.decodeIfPresent(String.self, forKey: .vehicleType)
        dayPackages = try c.decodeIfPresent(Int.self, forKey: .dayPackages) ?? 0
        nightPackages = try c.decodeIfPresent(Int.self, forKey: .nightPackages) ?? 0
        combinedPackages = try c.decodeIfPresent(Int.self, forKey: .combinedPackages) ?? 0
        deliveryDistancesKm = try c.decodeIfPresent([Decimal].self, forKey: .deliveryDistancesKm) ?? []
        totalKm = try c.decodeIfPresent(Decimal.self, forKey: .totalKm)
        hours = try c.decodeIfPresent(Decimal.self, forKey: .hours) ?? 0
        tips = try c.decodeIfPresent(Money.self, forKey: .tips) ?? .zero
        referralConditionsMet = try c.decodeIfPresent(Bool.self, forKey: .referralConditionsMet) ?? false
        referralAmount = try c.decodeIfPresent(Money.self, forKey: .referralAmount)
        surgeMultiplier = try c.decodeIfPresent(Decimal.self, forKey: .surgeMultiplier)
        surgePackages = try c.decodeIfPresent(Int.self, forKey: .surgePackages) ?? 0
        flags = try c.decodeIfPresent([String].self, forKey: .flags) ?? []
        flagAmounts = try c.decodeIfPresent([String: Money].self, forKey: .flagAmounts) ?? [:]
        weekendPackages = try c.decodeIfPresent(Int.self, forKey: .weekendPackages)
        periodPackages = try c.decodeIfPresent(Int.self, forKey: .periodPackages)
        bonusTierDays = try c.decodeIfPresent([String: Int].self, forKey: .bonusTierDays) ?? [:]
        regionTier = try c.decodeIfPresent(String.self, forKey: .regionTier)
        seniorityYears = try c.decodeIfPresent(Int.self, forKey: .seniorityYears)
        contractHours = try c.decodeIfPresent(Int.self, forKey: .contractHours)
        workDays = try c.decodeIfPresent(Int.self, forKey: .workDays)
        deliverySlots = try c.decodeIfPresent([DeliverySlot].self, forKey: .deliverySlots) ?? []
        extraPayments = try c.decodeIfPresent(Money.self, forKey: .extraPayments) ?? .zero
        deductions = try c.decodeIfPresent(Money.self, forKey: .deductions) ?? .zero
        advances = try c.decodeIfPresent(Money.self, forKey: .advances) ?? .zero
    }

    /// Tekli (gunduz + gece) paketler: her biri ayri bir teslimat yolculugu.
    var singlePackages: Int { dayPackages + nightPackages }
    /// Bonus esiklerinde sayilan tum paketler.
    var totalPackages: Int { dayPackages + nightPackages + combinedPackages }

    /// Girilen toplam mesafe (teslimat bazli liste varsa onun toplami).
    var distanceKm: Decimal {
        if !deliveryDistancesKm.isEmpty { return deliveryDistancesKm.reduce(Decimal(0), +) }
        return totalKm ?? 0
    }

    func has(flag: String) -> Bool { flags.contains(flag) }
}

/// Teslimatin gunu ve saati (Takvim: 1 = Pazar ... 7 = Cumartesi; saat 0–23) ve o saatteki paket sayisi.
struct DeliverySlot: Codable, Equatable {
    var weekday: Int
    var hour: Int
    var count: Int
}

/// Satirin ait oldugu donem duzeyi. Donem toplamlarinda ayni kalemin iki kez sayilmamasi icin kullanilir:
/// gunluk satirlar gunluk kayitlardan, haftalik/aylik satirlar o donemin toplamindan gelir.
enum PayScope: String, Codable {
    case daily, weekly, monthly
}

/// Hesaplama sonucundaki tek satir. Kalem kimligi ve guveni ile birlikte dondurulur (gecmis sessizce degismez).
struct PayLine: Codable, Equatable, Identifiable {
    var id: String
    var itemID: String?
    var itemKey: String
    var type: TariffItemType
    var label: String
    var quantity: Decimal? = nil
    var unit: TariffUnit? = nil
    var rate: Money? = nil
    var amount: Money
    /// Aralikli kalemde ust sinir (alt sinir `amount`).
    var amountUpper: Money? = nil
    var confidence: ConfidenceStatus
    var isCash: Bool = true
    /// false: gosterilir ama toplama girmez (dogrulanmamis garanti, alternatif yorum, yan hak).
    var included: Bool = true
    var note: String? = nil
    var scope: PayScope = .daily
    /// Gunluk tahmin; donem hesabi ayni kalemi kesinlestirince donem toplamina girmez (or. Paket Taxi taban ucret).
    var provisional: Bool = false

    init(
        id: String, itemID: String?, itemKey: String, type: TariffItemType, label: String, quantity: Decimal? = nil,
        unit: TariffUnit? = nil, rate: Money? = nil, amount: Money, amountUpper: Money? = nil, confidence: ConfidenceStatus,
        isCash: Bool = true, included: Bool = true, note: String? = nil, scope: PayScope? = nil, provisional: Bool = false
    ) {
        self.id = id
        self.itemID = itemID
        self.itemKey = itemKey
        self.type = type
        self.label = label
        self.quantity = quantity
        self.unit = unit
        self.rate = rate
        self.amount = amount
        self.amountUpper = amountUpper
        self.confidence = confidence
        self.isCash = isCash
        self.included = included
        self.note = note
        self.provisional = provisional
        if let scope {
            self.scope = scope
        } else {
            switch unit {
            case .week?: self.scope = .weekly
            case .month?: self.scope = .monthly
            default: self.scope = .daily
            }
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        itemID = try c.decodeIfPresent(String.self, forKey: .itemID)
        itemKey = try c.decode(String.self, forKey: .itemKey)
        type = try c.decode(TariffItemType.self, forKey: .type)
        label = try c.decode(String.self, forKey: .label)
        quantity = try c.decodeIfPresent(Decimal.self, forKey: .quantity)
        unit = try c.decodeIfPresent(TariffUnit.self, forKey: .unit)
        rate = try c.decodeIfPresent(Money.self, forKey: .rate)
        amount = try c.decode(Money.self, forKey: .amount)
        amountUpper = try c.decodeIfPresent(Money.self, forKey: .amountUpper)
        confidence = try c.decode(ConfidenceStatus.self, forKey: .confidence)
        isCash = try c.decodeIfPresent(Bool.self, forKey: .isCash) ?? true
        included = try c.decodeIfPresent(Bool.self, forKey: .included) ?? true
        note = try c.decodeIfPresent(String.self, forKey: .note)
        scope = try c.decodeIfPresent(PayScope.self, forKey: .scope) ?? .daily
        provisional = try c.decodeIfPresent(Bool.self, forKey: .provisional) ?? false
    }

    /// Alt senaryodaki tutar. Aralikli kalemlerde `amountUpper` ust senaryodur; garanti fark odemesi gibi gelirle ters
    /// hareket eden satirda ust senaryo tutari daha kucuk olabilir (toplamlar senaryo bazinda dogru kalir).
    var low: Money { amount }
    var high: Money { amountUpper ?? amount }
    /// Gosterim icin kucukten buyuge.
    var displayRange: (Money, Money) {
        let other: Money = amountUpper ?? amount
        return amount < other ? (amount, other) : (other, amount)
    }
}

enum PayNoticeKind: String, Codable {
    /// Kalem ya da ayar dogrulanmadi.
    case needsVerification = "needs_verification"
    /// Tarife yorumu belirsiz; alternatif sonuc gosterilir.
    case ambiguity
    /// Eksik girdi tahminle tamamlandi.
    case estimate
    /// Kalem donem sonunda hesaplanir (hafta sonu bonusu, aylik sabit ucret).
    case deferred
    /// Gerekli bilgi yok; kalem hesaplanmadi.
    case missing
    case info
}

struct PayNotice: Codable, Equatable {
    var kind: PayNoticeKind
    var message: String
    /// Alternatif yorumla brut hakedis (or. bonuslar toplanirsa).
    var alternativeGross: Money? = nil
    /// Hesaplama sirasinda alternatifin farki; motor tum satirlar eklendikten sonra `alternativeGross`'a cevirir.
    var alternativeDelta: Money? = nil

    /// Metindeki alternatif brut yer tutucusu.
    static let alternativePlaceholder = "%ALT%"
}

/// Bonus hedefine yakinlik.
struct BonusProgress: Codable, Equatable, Identifiable {
    var itemKey: String
    var label: String
    var current: Int
    var target: Int
    var reward: Money
    var rewardUpper: Money? = nil
    var unit: TariffUnit
    var confidence: ConfidenceStatus

    var id: String { itemKey }
    var remaining: Int { max(0, target - current) }
    var fraction: Double { target > 0 ? min(1, Double(current) / Double(target)) : 0 }
}

/// Hesaplama sonucu. Kullanilan tarife surumu, kalemler ve hesaplama zamani ile birlikte saklanir.
struct PayBreakdown: Codable, Equatable {
    var platformCode: String
    var tariffVersionID: String
    var tariffVersionLabel: String
    var tariffOrigin: TariffOrigin
    var tariffVerification: VerificationState
    var span: PaySpan
    var startDay: String
    var endDay: String
    var computedAt: Date
    var lines: [PayLine]
    /// Nakit olmayan yan haklar ve destekler (toplama girmez).
    var sideBenefits: [PayLine]
    var notices: [PayNotice]
    var progress: [BonusProgress]
    var extraPayments: Money
    var deductions: Money
    var advances: Money

    private var incomeLines: [PayLine] {
        lines.filter { $0.included && $0.isCash && $0.type != .tip && $0.type != .deduction }
    }

    /// Brut hakedis: tarife kurallarina gore uygun gelir kalemlerinin toplami (aralikli kalemlerde alt sinir).
    var gross: Money { incomeLines.map(\.low).sum() }
    var grossUpper: Money { incomeLines.map(\.high).sum() }
    var hasRange: Bool { grossUpper != gross }

    var tips: Money { lines.filter { $0.included && $0.type == .tip }.map(\.amount).sum() }
    /// Tarifeden gelen dogrulanmis kesintiler + kullanicinin girdigi kesintiler.
    var totalDeductions: Money {
        lines.filter { $0.included && $0.type == .deduction }.map(\.amount).sum() + deductions
    }

    /// Odeme oncesi tutar = brut + ek odemeler (bahsis dahil) − dogrulanmis kesinti/avans.
    var prePayment: Money { gross + tips + extraPayments - totalDeductions - advances }
    var prePaymentUpper: Money { grossUpper + tips + extraPayments - totalDeductions - advances }

    /// Tahmini net = brut − giderler (vergi/SGK gibi yukumlulukler guvenilir veriyle hesaplanamadigi icin dahil degil).
    func net(expenses: Money) -> Money { gross - expenses }

    var bonusTotal: Money { incomeLines.filter { $0.type.isBonus }.map(\.low).sum() }

    /// Sonuctaki en zayif guven (dahil edilen nakit satirlar ve surum).
    var weakestConfidence: ConfidenceStatus {
        let levels: [ConfidenceStatus] = incomeLines.map(\.confidence)
        return levels.min() ?? .needsVerification
    }

    var needsVerification: Bool {
        weakestConfidence == .needsVerification || notices.contains { $0.kind == .needsVerification }
    }
}

enum PayError: Error, Equatable {
    case unsupportedPlatform(String)
    case noTariff(platform: String, day: String)
    /// Tarife secimi icin gerekli kapsam bilgisi eksik (or. Getir'de arac tipi).
    case ambiguousScope(String)
    case platformMismatch(expected: String, got: String)

    var message: String {
        switch self {
        case let .unsupportedPlatform(code): "\(code) için hesaplama motoru yok."
        case let .noTariff(platform, day): "\(PayPlatform.named(platform)?.name ?? platform) için \(day) tarihinde yayında tarife yok."
        case let .ambiguousScope(field): "Tarife seçmek için \(field) gerekli."
        case let .platformMismatch(expected, got): "Platform uyuşmuyor (\(expected) ≠ \(got))."
        }
    }
}
