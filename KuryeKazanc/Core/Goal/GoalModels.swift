import Foundation

/// Hedef donemi. Hesap her zaman aylik yapilir (sabit ucret ve aylik kademeler ay bazinda); gun/hafta aya cevrilir.
enum GoalPeriod: String, Codable, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .day: "Günlük"
        case .week: "Haftalık"
        case .month: "Aylık"
        }
    }
}

/// Kullanicinin net (yakit dusulmus) kazanc hedefi.
struct GoalSpec: Codable, Equatable {
    var amount: Money
    var period: GoalPeriod
    var daysPerWeek: Int = 6
    var maxHoursPerDay: Decimal = 10

    init(amount: Money, period: GoalPeriod, daysPerWeek: Int = 6, maxHoursPerDay: Decimal = 10) {
        self.amount = amount
        self.period = period
        self.daysPerWeek = min(7, max(1, daysPerWeek))
        self.maxHoursPerDay = maxHoursPerDay
    }

    /// Ileri uyumluluk: eksik alanlar varsayilanla okunur (yeni surumde eklenen alan eski dosyayi bozmasin).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(amount: try c.decode(Money.self, forKey: .amount),
                  period: try c.decodeIfPresent(GoalPeriod.self, forKey: .period) ?? .month,
                  daysPerWeek: try c.decodeIfPresent(Int.self, forKey: .daysPerWeek) ?? 6,
                  maxHoursPerDay: try c.decodeIfPresent(Decimal.self, forKey: .maxHoursPerDay) ?? 10)
    }

    /// Ayda calisilan gun: haftalik gun × 52 / 12, en yakin tam sayi (6 -> 26).
    var monthWorkDays: Int { GoalSpec.monthWorkDays(daysPerWeek: daysPerWeek) }

    static func monthWorkDays(daysPerWeek: Int) -> Int {
        let value: Double = Double(daysPerWeek) * 52.0 / 12.0
        return Int(value.rounded())
    }

    /// Hedefin aylik karsiligi.
    func monthlyTarget() -> Money {
        switch period {
        case .month: return amount
        case .week: return Money(Money.round(amount.value * Decimal(monthWorkDays) / Decimal(daysPerWeek)))
        case .day: return amount * monthWorkDays
        }
    }

    /// Hedef donemindeki is gunu.
    func periodWorkDays() -> Int {
        switch period {
        case .day: 1
        case .week: daysPerWeek
        case .month: monthWorkDays
        }
    }
}

/// Secilen firmanin tarifesinin ihtiyac duydugu kisisel bilgiler.
struct CourierTariffProfile: Equatable {
    var platformCode: String
    var regionTier: String?
    var seniorityYears: Int?
    var vehicleType: String?
    var flags: [String]
}

enum FuelType: String, Codable, CaseIterable, Identifiable {
    case gasoline, diesel, electric
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .gasoline: "Benzin"
        case .diesel: "Motorin"
        case .electric: "Elektrik"
        }
    }
    var unitName: String { self == .electric ? "kWh" : "L" }
}

enum FuelPriceSource: String, Codable {
    case manual, server
}

/// Tarihli yakit fiyati. Simdilik elle girilir; `server` ileride sunucudan gelecek fiyatlar icin.
struct FuelPriceEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var day: String
    var pricePerUnit: Money
    var type: FuelType
    var source: FuelPriceSource

    init(id: UUID = UUID(), day: String, pricePerUnit: Money, type: FuelType, source: FuelPriceSource = .manual) {
        self.id = id
        self.day = day
        self.pricePerUnit = pricePerUnit
        self.type = type
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
                  day: try c.decode(String.self, forKey: .day),
                  pricePerUnit: try c.decode(Money.self, forKey: .pricePerUnit),
                  type: try c.decodeIfPresent(FuelType.self, forKey: .type) ?? .gasoline,
                  source: try c.decodeIfPresent(FuelPriceSource.self, forKey: .source) ?? .manual)
    }
}

struct FuelSettings: Codable, Equatable {
    var entries: [FuelPriceEntry] = []
    /// L (ya da kWh) / 100 km. nil: arac turunun varsayilani.
    var consumptionPer100Km: Decimal? = nil

    init(entries: [FuelPriceEntry] = [], consumptionPer100Km: Decimal? = nil) {
        self.entries = entries
        self.consumptionPer100Km = consumptionPer100Km
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = try c.decodeIfPresent([FuelPriceEntry].self, forKey: .entries) ?? []
        consumptionPer100Km = try c.decodeIfPresent(Decimal.self, forKey: .consumptionPer100Km)
    }
}
