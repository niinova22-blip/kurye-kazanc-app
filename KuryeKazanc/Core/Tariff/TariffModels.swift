import Foundation

// Tarife veri modeli (Katman A). Sunucudaki `tariff_versions` / `tariff_items` tablolariyla ayni alanlar (snake_case JSON).
// Tarifeler koda gomulu sabitler degildir: gomulu JSON yalnizca baslangic/ornek kaydidir (BundledTariffs),
// sunucudan yayimlanan surumler ve kullanicinin kendi girdigi tarifeler ayni modeli kullanir.

/// Tarife kalemi turu.
enum TariffItemType: String, Codable, CaseIterable {
    case singlePackage = "single_package"
    case combinedPackage = "combined_package"
    case perKm = "per_km"
    case hourly
    case fixed
    case dailyBonus = "daily_bonus"
    case weeklyBonus = "weekly_bonus"
    case monthlyBonus = "monthly_bonus"
    case surgeMultiplier = "surge_multiplier"
    case fuelEquipmentSupport = "fuel_equipment_support"
    case tip
    case referralBonus = "referral_bonus"
    case deduction
    case inKindSupport = "in_kind_support"
    case otherPayment = "other_payment"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TariffItemType(rawValue: raw) ?? .otherPayment
    }

    var displayName: String {
        switch self {
        case .singlePackage: "Tekli paket ücreti"
        case .combinedPackage: "Birleşen paket ücreti"
        case .perKm: "Kilometre ücreti"
        case .hourly: "Saatlik ücret"
        case .fixed: "Sabit ücret"
        case .dailyBonus: "Günlük bonus"
        case .weeklyBonus: "Haftalık bonus"
        case .monthlyBonus: "Aylık bonus"
        case .surgeMultiplier: "Yoğunluk çarpanı"
        case .fuelEquipmentSupport: "Yakıt / ekipman desteği"
        case .tip: "Bahşiş"
        case .referralBonus: "Referans bonusu"
        case .deduction: "Kesinti"
        case .inKindSupport: "Ayni destek"
        case .otherPayment: "Diğer ek ödeme"
        }
    }

    var isBonus: Bool {
        switch self {
        case .dailyBonus, .weeklyBonus, .monthlyBonus, .referralBonus: true
        default: false
        }
    }
}

/// Kalemin birimi.
enum TariffUnit: String, Codable {
    case package, km, hour, day, week, month, multiplier, flat

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TariffUnit(rawValue: raw) ?? .flat
    }

    var suffix: String {
        switch self {
        case .package: "/paket"
        case .km: "/km"
        case .hour: "/sa"
        case .day: "/gün"
        case .week: "/hafta"
        case .month: "/ay"
        case .multiplier: "×"
        case .flat: ""
        }
    }
}

/// Kalemin nasil hesaplandigi.
enum CalculationMethod: String, Codable {
    /// tutar × miktar (paket, km, saat).
    case perUnit = "per_unit"
    /// Kosul saglaninca sabit tutar.
    case flat
    /// Sayac [alt, ust] araligindaysa kademe tutari (bonus kademeleri). Ust esik dahil.
    case tier
    /// Kademeli birim ucret (or. aylik paket sayisina gore paket basi ucret). Uygulama bicimi tarife ayarinda.
    case tierRate = "tier_rate"
    /// Mesafe bandi [alt, ust) km; bant uygulama bicimi tarife ayarinda (dilimli / tum mesafe).
    case distanceBand = "distance_band"
    /// Carpan (yogunluk); yalnizca kullanici girisiyle.
    case multiplier
    /// Saatlik garanti: garanti × saat − garantiye tabi gelir (fark odemesi).
    case guaranteeTopUp = "guarantee_top_up"
    /// Teslimat mesafesi [alt, ust] km araligindaysa teslimat basina sabit ek odeme (Paket Taxi 4–6 km +25 TL).
    /// Bir teslimat birden cok banda uyarsa alt esigi kucuk olan band gecerlidir (6 km tam: 4–6 km bandi).
    case deliveryBand = "delivery_band"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CalculationMethod(rawValue: raw) ?? .flat
    }
}

/// Verinin guvenilirlik etiketi. Arayuzde kullanici girisi ile dogrulanmis veri gorsel olarak ayrilir.
enum ConfidenceStatus: String, Codable, Comparable {
    case verified
    case userEntered = "user_entered"
    case needsVerification = "needs_verification"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ConfidenceStatus(rawValue: raw) ?? .needsVerification
    }

    var displayName: String {
        switch self {
        case .verified: "Doğrulanmış"
        case .userEntered: "Kullanıcı tarafından girildi"
        case .needsVerification: "Doğrulama gerekli"
        }
    }

    /// Siralama: dogrulanmis > kullanici > dogrulama gerekli (en zayif olani belirleyicidir).
    private var rank: Int {
        switch self {
        case .verified: 2
        case .userEntered: 1
        case .needsVerification: 0
        }
    }

    static func < (lhs: ConfidenceStatus, rhs: ConfidenceStatus) -> Bool { lhs.rank < rhs.rank }

    /// Hesaba katilabilir mi (dogrulanmis ya da kullanicinin kendi beyani).
    var isTrusted: Bool { self != .needsVerification }
}

/// Gunduz / gece paket ayrimi.
enum TimeBand: String, Codable {
    case day, night, any
}

/// Kalemin uygulanma kosullari. Bos alan "kosul yok" demektir.
struct EligibilityConditions: Codable, Equatable {
    var timeBand: TimeBand? = nil
    /// Takvim haftanin gunleri (1 = Pazar ... 7 = Cumartesi).
    var weekdays: [Int]? = nil
    /// Paket Taxi bolge kademesi ("plus" / "standard").
    var regionTier: String? = nil
    /// Kullanicinin isaretlemesi gereken uygunluk (or. "weekly_performance", "woman_employment", "referral").
    var requiresFlag: String? = nil
    /// Kidem yili esigi (Paket Taxi kidem tarifesi) [alt, ust).
    var minSeniorityYears: Int? = nil
    var maxSeniorityYears: Int? = nil

    enum CodingKeys: String, CodingKey {
        case timeBand = "time_band"
        case weekdays
        case regionTier = "region_tier"
        case requiresFlag = "requires_flag"
        case minSeniorityYears = "min_seniority_years"
        case maxSeniorityYears = "max_seniority_years"
    }
}

/// Ayni gruptaki kalemler nasil birlesir.
enum StackingRule: String, Codable {
    /// Her uygun kalem eklenir.
    case additive
    /// Ayni gruptan yalnizca biri uygulanir (kademe tablosu); hangisi oldugu tarife ayarindan.
    case exclusiveGroup = "exclusive_group"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StackingRule(rawValue: raw) ?? .additive
    }
}

/// Tarife kalemi. Her kalemin kendi gecerlilik donemi vardir: yalnizca km ucreti degisince
/// tum tarife yeniden olusturulmaz, yeni kalem eskisinin yerine tarihli olarak eklenir.
struct TariffItem: Codable, Equatable, Identifiable {
    var id: String
    var versionID: String
    /// Surumler arasi sabit anahtar (or. "package.day"); degisiklik tespiti bununla eslestirir.
    var key: String
    var type: TariffItemType
    var label: String
    var amount: Money
    /// Aralik verilen kalemlerde ust tutar (or. birlesen paket 27–41,50 TL). nil: tek tutar.
    var amountUpper: Money? = nil
    var currency: String = "TRY"
    var unit: TariffUnit
    var lowerThreshold: Decimal? = nil
    var upperThreshold: Decimal? = nil
    var method: CalculationMethod
    var conditions: EligibilityConditions = EligibilityConditions()
    var stacking: StackingRule = .additive
    /// Ayni `exclusive_group` kalemlerini birlestirir (or. "daily_bonus").
    var group: String? = nil
    /// yyyy-MM-dd; nil surumun baslangici.
    var effectiveFrom: String? = nil
    /// yyyy-MM-dd, haric; nil acik uclu.
    var effectiveUntil: String? = nil
    var confidence: ConfidenceStatus
    /// false: nakit hakedise eklenmez (yan haklar, ayni destek).
    var isCash: Bool = true
    var note: String? = nil
    /// Geri cekilen kalem hesaplamaya girmez (gecmis kayitlar dondurulmus sonucunu korur).
    var withdrawn: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "tariff_item_id"
        case versionID = "tariff_version_id"
        case key = "item_key"
        case type = "item_type"
        case label, amount, currency, unit, note, withdrawn
        case group = "item_group"
        case amountUpper = "amount_upper"
        case lowerThreshold = "lower_threshold"
        case upperThreshold = "upper_threshold"
        case method = "calculation_method"
        case conditions = "eligibility_conditions"
        case stacking = "stacking_rule"
        case effectiveFrom = "effective_from"
        case effectiveUntil = "effective_until"
        case confidence = "confidence_status"
        case isCash = "is_cash"
    }

    init(
        id: String, versionID: String, key: String, type: TariffItemType, label: String, amount: Money,
        amountUpper: Money? = nil, unit: TariffUnit, lowerThreshold: Decimal? = nil, upperThreshold: Decimal? = nil,
        method: CalculationMethod, conditions: EligibilityConditions = EligibilityConditions(),
        stacking: StackingRule = .additive, group: String? = nil, effectiveFrom: String? = nil,
        effectiveUntil: String? = nil, confidence: ConfidenceStatus, isCash: Bool = true, note: String? = nil
    ) {
        self.id = id
        self.versionID = versionID
        self.key = key
        self.type = type
        self.label = label
        self.amount = amount
        self.amountUpper = amountUpper
        self.unit = unit
        self.lowerThreshold = lowerThreshold
        self.upperThreshold = upperThreshold
        self.method = method
        self.conditions = conditions
        self.stacking = stacking
        self.group = group
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.confidence = confidence
        self.isCash = isCash
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        versionID = try c.decode(String.self, forKey: .versionID)
        key = try c.decode(String.self, forKey: .key)
        type = try c.decode(TariffItemType.self, forKey: .type)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? type.displayName
        amount = try c.decodeIfPresent(Money.self, forKey: .amount) ?? .zero
        amountUpper = try c.decodeIfPresent(Money.self, forKey: .amountUpper)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "TRY"
        unit = try c.decodeIfPresent(TariffUnit.self, forKey: .unit) ?? .flat
        lowerThreshold = try c.decodeIfPresent(Money.self, forKey: .lowerThreshold)?.value
        upperThreshold = try c.decodeIfPresent(Money.self, forKey: .upperThreshold)?.value
        method = try c.decodeIfPresent(CalculationMethod.self, forKey: .method) ?? .flat
        conditions = try c.decodeIfPresent(EligibilityConditions.self, forKey: .conditions) ?? EligibilityConditions()
        stacking = try c.decodeIfPresent(StackingRule.self, forKey: .stacking) ?? .additive
        group = try c.decodeIfPresent(String.self, forKey: .group)
        effectiveFrom = try c.decodeIfPresent(String.self, forKey: .effectiveFrom)
        effectiveUntil = try c.decodeIfPresent(String.self, forKey: .effectiveUntil)
        confidence = try c.decodeIfPresent(ConfidenceStatus.self, forKey: .confidence) ?? .needsVerification
        isCash = try c.decodeIfPresent(Bool.self, forKey: .isCash) ?? true
        note = try c.decodeIfPresent(String.self, forKey: .note)
        withdrawn = try c.decodeIfPresent(Bool.self, forKey: .withdrawn) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(versionID, forKey: .versionID)
        try c.encode(key, forKey: .key)
        try c.encode(type, forKey: .type)
        try c.encode(label, forKey: .label)
        try c.encode(amount, forKey: .amount)
        try c.encodeIfPresent(amountUpper, forKey: .amountUpper)
        try c.encode(currency, forKey: .currency)
        try c.encode(unit, forKey: .unit)
        try c.encodeIfPresent(lowerThreshold.map { Money($0) }, forKey: .lowerThreshold)
        try c.encodeIfPresent(upperThreshold.map { Money($0) }, forKey: .upperThreshold)
        try c.encode(method, forKey: .method)
        try c.encode(conditions, forKey: .conditions)
        try c.encode(stacking, forKey: .stacking)
        try c.encodeIfPresent(group, forKey: .group)
        try c.encodeIfPresent(effectiveFrom, forKey: .effectiveFrom)
        try c.encodeIfPresent(effectiveUntil, forKey: .effectiveUntil)
        try c.encode(confidence, forKey: .confidence)
        try c.encode(isCash, forKey: .isCash)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encode(withdrawn, forKey: .withdrawn)
    }

    /// Kalem bu gun gecerli mi: [effectiveFrom, effectiveUntil) ve geri cekilmemis.
    func isActive(on day: String) -> Bool {
        guard !withdrawn else { return false }
        if let effectiveFrom, day < effectiveFrom { return false }
        if let effectiveUntil, day >= effectiveUntil { return false }
        return true
    }

    /// Tutar araligi metni: "27,00 – 41,50".
    var isRange: Bool { amountUpper.map { $0 != amount } ?? false }
}

/// Tarife surumunun is akisi durumu. Hesaplama motoru yalnizca `published` (ve tarih araliginda kalan `expired`) surumleri kullanir.
enum ApprovalStatus: String, Codable, CaseIterable {
    case draft
    case pendingVerification = "pending_verification"
    case needsMoreSources = "needs_more_sources"
    case approved
    case published
    case rejected
    case expired
    case withdrawn

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ApprovalStatus(rawValue: raw) ?? .draft
    }

    var displayName: String {
        switch self {
        case .draft: "Taslak"
        case .pendingVerification: "Doğrulama bekliyor"
        case .needsMoreSources: "Ek kaynak gerekli"
        case .approved: "Onaylandı"
        case .published: "Yayında"
        case .rejected: "Reddedildi"
        case .expired: "Süresi doldu"
        case .withdrawn: "Geri çekildi"
        }
    }

    /// Hesaplamaya girebilir mi.
    var isUsableForCalculation: Bool { self == .published || self == .expired }
}

/// Surumun genel dogrulama durumu.
enum VerificationState: String, Codable {
    case verified, partial, unverified

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VerificationState(rawValue: raw) ?? .unverified
    }

    var displayName: String {
        switch self {
        case .verified: "Doğrulanmış"
        case .partial: "Kısmen doğrulanmış"
        case .unverified: "Doğrulanmamış"
        }
    }
}

/// Kaynak turu (oncelik sirasina gore).
enum TariffSourceType: String, Codable {
    case officialAnnouncement = "official_announcement"
    case officialChannel = "official_channel"
    case officialDocument = "official_document"
    case news
    case userUpload = "user_upload"
    case courierReports = "courier_reports"
    case userEntered = "user_entered"
    case seed

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TariffSourceType(rawValue: raw) ?? .seed
    }

    var displayName: String {
        switch self {
        case .officialAnnouncement: "Resmî duyuru"
        case .officialChannel: "Resmî kurye kanalı"
        case .officialDocument: "Resmî belge"
        case .news: "Sektör haberi"
        case .userUpload: "Kullanıcı yüklemesi"
        case .courierReports: "Kurye bildirimleri"
        case .userEntered: "Kullanıcı girişi"
        case .seed: "Başlangıç / örnek kayıt"
        }
    }
}

/// Surum nereden geldi.
enum TariffOrigin: String, Codable {
    case bundled, remote, user
}

// MARK: - Tarife ayarlari (belirsiz kurallar acikca yapilandirilir)

/// Km bantlari nasil uygulanir.
enum KmMethod: String, Codable {
    /// Dilimli: her km kendi bandinin ucretiyle.
    case slab
    /// Tum mesafe, mesafenin dustugu bandin ucretiyle.
    case wholeDistance = "whole_distance"
}

/// Ayni gruptaki bonus kademeleri.
enum BonusStacking: String, Codable {
    /// Yalnizca ulasilan en yuksek kademe.
    case highestOnly = "highest_only"
    /// Ulasilan tum kademeler toplanir.
    case cumulative
}

/// Kademeli birim ucretin esik asilinca uygulanisi.
enum ThresholdApplication: String, Codable {
    /// Esik asilinca yeni ucret tum paketlere.
    case allUnits = "all_units"
    /// Yeni ucret yalnizca esigin ustundeki paketlere.
    case aboveThresholdOnly = "above_threshold_only"
}

/// Paket Taxi sabit ucret dayanagi.
enum FixedPayBasis: String, Codable {
    case region, seniority
    /// Ikisi birlikte (yalnizca dogrulanmissa secilmeli).
    case both
}

struct TariffSettings: Codable, Equatable {
    var kmMethod: KmMethod? = nil
    var bonusStacking: BonusStacking? = nil
    var thresholdApplication: ThresholdApplication? = nil
    var fixedPayBasis: FixedPayBasis? = nil
    /// Sabit ucretin kapsadigi aylik paket sayisi (mukerrer sayimi onler). nil: kapsamaz.
    var fixedCoversPackages: Int? = nil
    /// Ayar anahtari ("km_method", ...) -> guven. Listede olmayan ayar dogrulama gerekli sayilir.
    var confidence: [String: ConfidenceStatus] = [:]

    enum CodingKeys: String, CodingKey {
        case kmMethod = "km_method"
        case bonusStacking = "bonus_stacking"
        case thresholdApplication = "threshold_application"
        case fixedPayBasis = "fixed_pay_basis"
        case fixedCoversPackages = "fixed_covers_packages"
        case confidence
    }

    init(
        kmMethod: KmMethod? = nil, bonusStacking: BonusStacking? = nil, thresholdApplication: ThresholdApplication? = nil,
        fixedPayBasis: FixedPayBasis? = nil, fixedCoversPackages: Int? = nil, confidence: [String: ConfidenceStatus] = [:]
    ) {
        self.kmMethod = kmMethod
        self.bonusStacking = bonusStacking
        self.thresholdApplication = thresholdApplication
        self.fixedPayBasis = fixedPayBasis
        self.fixedCoversPackages = fixedCoversPackages
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kmMethod = try? c.decodeIfPresent(KmMethod.self, forKey: .kmMethod)
        bonusStacking = try? c.decodeIfPresent(BonusStacking.self, forKey: .bonusStacking)
        thresholdApplication = try? c.decodeIfPresent(ThresholdApplication.self, forKey: .thresholdApplication)
        fixedPayBasis = try? c.decodeIfPresent(FixedPayBasis.self, forKey: .fixedPayBasis)
        fixedCoversPackages = try c.decodeIfPresent(Int.self, forKey: .fixedCoversPackages)
        confidence = (try? c.decodeIfPresent([String: ConfidenceStatus].self, forKey: .confidence)) ?? [:]
    }

    func confidence(of key: String) -> ConfidenceStatus {
        confidence[key] ?? .needsVerification
    }
}

/// Tarife surumu: bir platformun bir calisma modeli / bolge / arac tipi icin gecerli ucret kurallari.
struct TariffVersion: Codable, Equatable, Identifiable {
    var id: String
    var platformCode: String
    var workModel: String
    var regionID: String? = nil
    var vehicleType: String? = nil
    var versionNumber: Int
    /// Kalem duzeyinde yayimlanan degisikliklerin sayaci.
    var revision: Int = 0
    var effectiveFrom: String
    var effectiveUntil: String? = nil
    var createdAt: String
    var sourceType: TariffSourceType
    var verificationStatus: VerificationState
    var approvalStatus: ApprovalStatus
    var approvedAt: String? = nil
    var approvedBy: String? = nil
    var changeSummary: String? = nil
    var settings: TariffSettings = TariffSettings()
    var items: [TariffItem]
    var origin: TariffOrigin = .bundled
    /// Kullanici tarifelerinde zorunlu kaynak aciklamasi (or. "Getir sözleşmem, Ekim 2026").
    var sourceNote: String? = nil

    enum CodingKeys: String, CodingKey {
        case id = "tariff_version_id"
        case platformCode = "platform_id"
        case workModel = "work_model"
        case regionID = "region_id"
        case vehicleType = "vehicle_type"
        case versionNumber = "version_number"
        case revision
        case effectiveFrom = "effective_from"
        case effectiveUntil = "effective_until"
        case createdAt = "created_at"
        case sourceType = "source_type"
        case verificationStatus = "verification_status"
        case approvalStatus = "approval_status"
        case approvedAt = "approved_at"
        case approvedBy = "approved_by"
        case changeSummary = "change_summary"
        case settings, items, origin
        case sourceNote = "source_note"
    }

    init(
        id: String, platformCode: String, workModel: String, regionID: String? = nil, vehicleType: String? = nil,
        versionNumber: Int, revision: Int = 0, effectiveFrom: String, effectiveUntil: String? = nil, createdAt: String,
        sourceType: TariffSourceType, verificationStatus: VerificationState, approvalStatus: ApprovalStatus,
        approvedAt: String? = nil, approvedBy: String? = nil, changeSummary: String? = nil,
        settings: TariffSettings = TariffSettings(), items: [TariffItem], origin: TariffOrigin = .bundled, sourceNote: String? = nil
    ) {
        self.id = id
        self.platformCode = platformCode
        self.workModel = workModel
        self.regionID = regionID
        self.vehicleType = vehicleType
        self.versionNumber = versionNumber
        self.revision = revision
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.createdAt = createdAt
        self.sourceType = sourceType
        self.verificationStatus = verificationStatus
        self.approvalStatus = approvalStatus
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
        self.changeSummary = changeSummary
        self.settings = settings
        self.items = items
        self.origin = origin
        self.sourceNote = sourceNote
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        platformCode = try c.decode(String.self, forKey: .platformCode)
        workModel = try c.decodeIfPresent(String.self, forKey: .workModel) ?? "any"
        regionID = try c.decodeIfPresent(String.self, forKey: .regionID)
        vehicleType = try c.decodeIfPresent(String.self, forKey: .vehicleType)
        versionNumber = try c.decodeIfPresent(Int.self, forKey: .versionNumber) ?? 1
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        effectiveFrom = String(try c.decode(String.self, forKey: .effectiveFrom).prefix(10))
        effectiveUntil = try c.decodeIfPresent(String.self, forKey: .effectiveUntil).map { String($0.prefix(10)) }
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        sourceType = try c.decodeIfPresent(TariffSourceType.self, forKey: .sourceType) ?? .seed
        verificationStatus = try c.decodeIfPresent(VerificationState.self, forKey: .verificationStatus) ?? .unverified
        approvalStatus = try c.decodeIfPresent(ApprovalStatus.self, forKey: .approvalStatus) ?? .draft
        approvedAt = try c.decodeIfPresent(String.self, forKey: .approvedAt)
        approvedBy = try c.decodeIfPresent(String.self, forKey: .approvedBy)
        changeSummary = try c.decodeIfPresent(String.self, forKey: .changeSummary)
        settings = try c.decodeIfPresent(TariffSettings.self, forKey: .settings) ?? TariffSettings()
        items = try c.decodeIfPresent([TariffItem].self, forKey: .items) ?? []
        origin = try c.decodeIfPresent(TariffOrigin.self, forKey: .origin) ?? .remote
        sourceNote = try c.decodeIfPresent(String.self, forKey: .sourceNote)
        for index in items.indices {
            items[index].effectiveFrom = items[index].effectiveFrom.map { String($0.prefix(10)) }
            items[index].effectiveUntil = items[index].effectiveUntil.map { String($0.prefix(10)) }
        }
    }

    /// Surum bu gun gecerli mi (onay durumu ayrica kontrol edilir).
    func covers(day: String) -> Bool {
        if day < effectiveFrom { return false }
        if let effectiveUntil, day >= effectiveUntil { return false }
        return true
    }

    /// O gun gecerli kalemler.
    func activeItems(on day: String) -> [TariffItem] {
        items.filter { $0.isActive(on: day) }
    }

    /// Kullaniciya gosterilecek surum etiketi: "v1.2".
    var label: String { revision > 0 ? "v\(versionNumber).\(revision)" : "v\(versionNumber)" }
}

/// Uygulamanin destekledigi hakedis platformu (secim ekrani karti).
struct PayPlatform: Codable, Equatable, Identifiable {
    /// Mevcut `Platform.code` ile ayni anahtar.
    var code: String
    var name: String
    var isActive: Bool
    var supportedWorkModels: [String]
    /// Hakedis modelinin kisa aciklamasi.
    var modelSummary: String
    /// Dogrulanmis logo varligi yoksa kullanilan notr simge (SF Symbols). Resmi ortaklik iddiasi yoktur.
    var symbol: String
    var monogram: String
    var lastSuccessfulCheckAt: String? = nil
    var nextScheduledCheckAt: String? = nil

    var id: String { code }

    /// Desteklenen dort platform. Kodlar uygulamadaki mevcut `Platform.defaults` ile ayni.
    static let all: [PayPlatform] = [
        PayPlatform(
            code: "trendyol_go", name: "Trendyol GO", isActive: true, supportedWorkModels: ["esnaf"],
            modelSummary: "Paket başı (gündüz/gece), birleşen paket, km primi, günlük paket bonusu.",
            symbol: "shippingbox", monogram: "TG"
        ),
        PayPlatform(
            code: "getir", name: "Getir", isActive: true, supportedWorkModels: ["esnaf"],
            modelSummary: "Saatlik ücret + paket başı + km; motorlu/araçlı ayrı tarife, hafta sonu bonusu.",
            symbol: "clock.badge.checkmark", monogram: "G"
        ),
        PayPlatform(
            code: "yemeksepeti", name: "Yemeksepeti Express", isActive: true, supportedWorkModels: ["esnaf"],
            modelSummary: "Saate ve güne göre paket ücreti, km ücreti, günlük paket bonusu; bahşiş ayrı.",
            symbol: "fork.knife", monogram: "YS"
        ),
        PayPlatform(
            code: "migros_hemen", name: "Paket Taxi / Migros Hemen", isActive: true, supportedWorkModels: ["esnaf"],
            modelSummary: "Bölgeye göre aylık sabit ücret, aylık paket bonusu, uzun teslimat ek ödemesi.",
            symbol: "calendar", monogram: "PT"
        ),
    ]

    static func named(_ code: String) -> PayPlatform? { all.first { $0.code == code } }
}
