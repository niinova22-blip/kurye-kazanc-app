import Foundation

enum RuleCategory: String, Codable, CaseIterable {
    /// Sozlesme ve calisma modeli (esnaf / araci / bordrolu, ek protokoller).
    case workModel
    case account
    /// Slot / vardiya secimi.
    case slotSystem
    /// Slotun baska kuryeye devri.
    case slotTransfer
    case minHours
    /// Slot / vardiya iptali.
    case cancellation
    case region
    /// Ucret ve bonus tarifesi.
    case pay
    /// Hakedis donemi, fatura, odeme dokumu.
    case payout
    /// Performans uyarisi, hesap askisi.
    case performance
    /// Itiraz ve yeniden etkinlestirme.
    case appeal
    /// Coklu platform calisma.
    case exclusivity
    case other

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RuleCategory(rawValue: raw) ?? .other
    }

    var displayName: String {
        switch self {
        case .workModel: "Sözleşme ve çalışma modeli"
        case .account: "Hesap"
        case .slotSystem: "Slot / vardiya seçimi"
        case .slotTransfer: "Slot devri"
        case .minHours: "Asgari çalışma"
        case .cancellation: "Slot iptali"
        case .region: "Bölge"
        case .pay: "Ücret ve bonus"
        case .payout: "Hakediş ve ödeme"
        case .performance: "Performans ve hesap askısı"
        case .appeal: "İtiraz ve yeniden etkinleştirme"
        case .exclusivity: "Çoklu platform"
        case .other: "Diğer"
        }
    }

    /// Bu kategoride bilinmeyen bir kosul plani kesin olmaktan cikarir.
    var affectsPlanning: Bool {
        switch self {
        case .slotSystem, .cancellation, .minHours, .exclusivity, .workModel, .region: true
        default: false
        }
    }
}

/// Motorun okuyabildigi kural turu. `info` plani etkilemez, yalnizca gosterilir.
enum RuleKind: String, Codable, CaseIterable {
    /// Platformda yalnizca rezerve slotta calisilabilir.
    case slotRequired
    /// Slot adimi (params.minutes); blok sinirlari bu adima oturur.
    case slotGranularityMinutes
    /// Slot iptali icin en az kac saat once (params.hours).
    case slotCancelNoticeHours
    /// Haftalik yogun saat yukumlulugu (params.fromHour, toHour, hours).
    case peakWeeklyHours
    /// Gunluk en az calisma (params.hours).
    case minDailyHours
    /// Vardiya duzeni: yalnizca kullanicinin girdigi vardiyada calisilir.
    case shiftBased
    /// Ayni anda baska platformda calisilamaz.
    case exclusiveSameTime
    /// Ayni gun baska platformda calisilamaz.
    case exclusiveSameDay
    case info
    /// Kamuya acik kaynak bulunamadi; kosul kuryenin sozlesmesinde / uygulamasinda. Kullanici onaylayana kadar belirsiz.
    case unknownTerm

    /// Bilinmeyen deger gelirse (sunucu yeni tur eklediyse) `info` sayilir; plan etkilenmez ama kural gosterilir.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RuleKind(rawValue: raw) ?? .info
    }

    /// Plani kisitlayan turler.
    var isConstraint: Bool {
        switch self {
        case .slotRequired, .slotGranularityMinutes, .minDailyHours, .shiftBased, .exclusiveSameTime, .exclusiveSameDay: true
        case .slotCancelNoticeHours, .peakWeeklyHours, .info, .unknownTerm: false
        }
    }
}

enum RuleSourceKind: String, Codable {
    case official, secondary, user
}

enum RuleStatus: String, Codable {
    case verified, unverified, disputed, stale

    var displayName: String {
        switch self {
        case .verified: "Doğrulandı"
        case .unverified: "Doğrulanmadı"
        case .disputed: "Kaynaklar çelişkili"
        case .stale: "Güncelliği bilinmiyor"
        }
    }
}

enum CourierModel: String, Codable, CaseIterable, Identifiable {
    case esnaf, intermediary, payroll, any

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .esnaf: "Esnaf kurye (kendi şirketim)"
        case .intermediary: "Aracı firma üzerinden"
        case .payroll: "Bordrolu"
        case .any: "Hepsi"
        }
    }
}

struct RuleParams: Codable, Equatable {
    var minutes: Int? = nil
    var hours: Double? = nil
    var fromHour: Int? = nil
    var toHour: Int? = nil

    enum CodingKeys: String, CodingKey {
        case minutes, hours
        case fromHour = "from_hour"
        case toHour = "to_hour"
    }
}

/// Kaynakli, surumlu platform kurali (sunucu `platform_rules`). Tarihler `yyyy-MM-dd`.
struct PlatformRule: Codable, Equatable, Identifiable {
    var id: String
    /// Platform kodu; `*` tum platformlar.
    var platformCode: String
    var category: RuleCategory
    var kind: RuleKind
    var params: RuleParams
    var description: String
    var sourceURL: String?
    var sourceKind: RuleSourceKind
    var publishedOn: String?
    var lastCheckedOn: String
    var validFrom: String?
    var validTo: String?
    var status: RuleStatus
    var confidence: Double
    var courierModel: CourierModel
    /// "Ankara" ya da "Ankara/Sincan"; nil her yer.
    var region: String?
    var version: Int
    var previousID: String?

    enum CodingKeys: String, CodingKey {
        case id, category, kind, params, description, status, confidence, region, version
        case platformCode = "platform_code"
        case sourceURL = "source_url"
        case sourceKind = "source_kind"
        case publishedOn = "published_on"
        case lastCheckedOn = "last_checked_on"
        case validFrom = "valid_from"
        case validTo = "valid_to"
        case courierModel = "courier_model"
        case previousID = "previous_id"
    }

    /// Son kontrolden bu yana bu kadar gun gecen kural "guncelligi bilinmiyor" sayilir.
    static let staleAfterDays = 90

    /// Bugune gore durum: suresi gecmis ya da uzun suredir kontrol edilmemis kural `stale`.
    func effectiveStatus(today: String) -> RuleStatus {
        if let validTo, validTo < today { return .stale }
        if let days = RuleDay.days(from: lastCheckedOn, to: today), days > Self.staleAfterDays { return .stale }
        return status
    }

    /// Kural bu kurye modeli, bolge ve gun icin gecerli mi (henuz yururluge girmemisse hayir).
    func applies(platform: String, model: CourierModel, region userRegion: String?, today: String) -> Bool {
        guard platformCode == platform || platformCode == "*" else { return false }
        guard courierModel == .any || model == .any || courierModel == model else { return false }
        if let validFrom, validFrom > today { return false }
        if let region {
            guard let userRegion else { return false }
            guard userRegion == region || userRegion.hasPrefix(region + "/") else { return false }
        }
        return true
    }
}

/// `yyyy-MM-dd` gun metinleri (saat dilimi etkisiz, UTC takvimle hesaplanir).
enum RuleDay {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func days(from: String, to: String) -> Int? {
        guard let a = date(from), let b = date(to) else { return nil }
        return calendar.dateComponents([.day], from: a, to: b).day
    }

    /// Verilen takvimdeki gunun metni.
    static func string(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Kullanicinin kendi sozlesmesine gore bir kurala verdigi karar.
enum RuleConfirmation: String, Codable {
    /// "Sozlesmemde var" — kural dogrulanmis sayilir.
    case applies
    /// "Bende gecerli degil" — kural bu kullanici icin yok sayilir.
    case notApplicable
}

/// Bir platform icin, kullanici onaylari islenmis gecerli kural.
struct EffectiveRule: Equatable {
    var rule: PlatformRule
    var status: RuleStatus
    var confirmedByUser: Bool

    /// Kisit olarak uygulanir mi: dogrulanmis (ve guncel) ya da kullanici onayli.
    var isEnforced: Bool { rule.kind.isConstraint && (confirmedByUser || status == .verified) }
    /// Kesin oneriye engel mi (plana etkili kategoride, kullanici onaylamamis ve dogrulanmamis ya da bilinmeyen kosul).
    var isUncertain: Bool {
        guard !confirmedByUser else { return false }
        guard rule.kind.isConstraint || rule.kind == .unknownTerm || rule.category.affectsPlanning else { return false }
        return status != .verified || rule.kind == .unknownTerm
    }
}

struct RuleSet: Equatable {
    var rules: [PlatformRule]

    /// Kural kumesinin ozeti; kayitli planlar bu degisince yeniden dogrulanir.
    var version: String {
        let parts = rules.map { "\($0.id):\($0.version):\($0.status.rawValue):\($0.lastCheckedOn)" }.sorted()
        return String(SHA256.hex(parts.joined(separator: "|")).prefix(16))
    }

    /// En son surumler (ayni id'nin eski surumleri ve baska kuralin `previousID` ile isaret ettigi kurallar elenir).
    var latest: [PlatformRule] {
        let superseded = Set(rules.compactMap(\.previousID))
        var byID: [String: PlatformRule] = [:]
        for rule in rules where !superseded.contains(rule.id) {
            if let existing = byID[rule.id], existing.version >= rule.version { continue }
            byID[rule.id] = rule
        }
        return byID.values.sorted { $0.id < $1.id }
    }

    func effectiveRules(
        platform: String, model: CourierModel, region: String?, today: String,
        confirmations: [String: RuleConfirmation]
    ) -> [EffectiveRule] {
        latest
            .filter { $0.applies(platform: platform, model: model, region: region, today: today) }
            .compactMap { rule in
                switch confirmations[rule.id] {
                case .notApplicable: return nil
                case .applies: return EffectiveRule(rule: rule, status: rule.effectiveStatus(today: today), confirmedByUser: true)
                case nil: return EffectiveRule(rule: rule, status: rule.effectiveStatus(today: today), confirmedByUser: false)
                }
            }
    }
}
