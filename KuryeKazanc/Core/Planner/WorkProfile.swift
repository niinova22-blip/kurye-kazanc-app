import Foundation

/// Gun icinde dakika araligi (0 ... 1440). Bitis baslangictan kucukse (gece yarisini asan) 1440'ta kesilir.
struct TimeRange: Codable, Equatable, Hashable {
    var startMinute: Int
    var endMinute: Int

    /// Gun icine kirpilmis gecerli aralik; bos ise nil.
    var clamped: TimeRange? {
        let s = max(0, min(1440, startMinute))
        var e = endMinute <= startMinute ? 1440 : endMinute
        e = max(0, min(1440, e))
        return e > s ? TimeRange(startMinute: s, endMinute: e) : nil
    }

    func contains(start: Int, end: Int) -> Bool {
        guard let c = clamped else { return false }
        return start >= c.startMinute && end <= c.endMinute
    }
}

/// Kullanicinin bir platformdaki hesabi.
struct PlatformProfile: Codable, Equatable, Identifiable {
    var code: String
    /// Hesap acik ve calisma izni var.
    var isActive: Bool
    var courierModel: CourierModel
    /// Platformun kullaniciya sundugu saatlik ortalama (kullanici girer; tarife uydurulmaz). Kayit yoksa tahminde kullanilir.
    var offeredHourlyRate: Double?

    var id: String { code }
}

/// Kullanicinin aldigi slot ya da vardiya.
struct ReservedBlock: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var platformCode: String
    var start: Date
    var end: Date
}

/// Kurye calisma profili. Kullanici verisidir; dogrulanmis kurallardan ayri saklanir.
struct WorkProfile: Codable, Equatable {
    var platforms: [PlatformProfile] = []
    /// "Ankara/Sincan" bicimi; kurallarin bolge eslesmesinde kullanilir.
    var region: String?
    /// Hafta gunu (1 = Pazartesi ... 7 = Pazar) -> uygun araliklar. Bos gun = calisilmaz.
    var availability: [Int: [TimeRange]] = [:]
    var reserved: [ReservedBlock] = []
    var costPerKm: Double = 0
    /// Vergi orani (0 ... 1), brute uygulanir.
    var taxRate: Double = 0
    /// Aylik Bag-Kur / SGK primi.
    var monthlySocialSecurity: Double = 0
    /// Muhasebe vb. diger aylik sabit giderler.
    var monthlyOtherFixed: Double = 0
    var dailyNetTarget: Double?
    var maxHoursPerDay: Double = 10
    /// Platform degistirirken gecen sure (dakika).
    var switchBufferMinutes: Int = 20
    /// Kural id -> kullanicinin kendi sozlesmesine gore karari.
    var ruleConfirmations: [String: RuleConfirmation] = [:]

    /// Aylik sabit giderlerin gunluk payi (ayda 26 is gunu).
    static let workDaysPerMonth = 26.0
    var dailyFixedCost: Double { (max(0, monthlySocialSecurity) + max(0, monthlyOtherFixed)) / Self.workDaysPerMonth }

    init() {}

    /// Eski kayitlarda olmayan alanlar varsayilanla doldurulur.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WorkProfile()
        platforms = try c.decodeIfPresent([PlatformProfile].self, forKey: .platforms) ?? d.platforms
        region = try c.decodeIfPresent(String.self, forKey: .region)
        availability = try c.decodeIfPresent([Int: [TimeRange]].self, forKey: .availability) ?? d.availability
        reserved = try c.decodeIfPresent([ReservedBlock].self, forKey: .reserved) ?? d.reserved
        costPerKm = try c.decodeIfPresent(Double.self, forKey: .costPerKm) ?? d.costPerKm
        taxRate = try c.decodeIfPresent(Double.self, forKey: .taxRate) ?? d.taxRate
        monthlySocialSecurity = try c.decodeIfPresent(Double.self, forKey: .monthlySocialSecurity) ?? d.monthlySocialSecurity
        monthlyOtherFixed = try c.decodeIfPresent(Double.self, forKey: .monthlyOtherFixed) ?? d.monthlyOtherFixed
        dailyNetTarget = try c.decodeIfPresent(Double.self, forKey: .dailyNetTarget)
        maxHoursPerDay = try c.decodeIfPresent(Double.self, forKey: .maxHoursPerDay) ?? d.maxHoursPerDay
        switchBufferMinutes = try c.decodeIfPresent(Int.self, forKey: .switchBufferMinutes) ?? d.switchBufferMinutes
        ruleConfirmations = try c.decodeIfPresent([String: RuleConfirmation].self, forKey: .ruleConfirmations) ?? [:]
    }

    func platform(_ code: String) -> PlatformProfile? { platforms.first { $0.code == code } }

    var activePlatformCodes: [String] { platforms.filter(\.isActive).map(\.code) }

    /// Gunun uygun araliklari (kirpilmis).
    func ranges(weekday: Int) -> [TimeRange] {
        (availability[weekday] ?? []).compactMap(\.clamped)
    }

    func isAvailable(weekday: Int, start: Int, end: Int) -> Bool {
        ranges(weekday: weekday).contains { $0.contains(start: start, end: end) }
    }
}
