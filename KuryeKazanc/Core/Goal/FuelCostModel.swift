import Foundation

/// Yakit gideri: km × tuketim (L/100 km) × o gunun fiyati. Fiyat hic girilmemisse eski km basi maliyet (yedek).
struct FuelCostModel: Equatable {
    var settings: FuelSettings
    var vehicleType: String?
    var fallbackCostPerKm: Money

    init(settings: FuelSettings, vehicleType: String?, fallbackCostPerKm: Money) {
        self.settings = settings
        self.vehicleType = vehicleType
        self.fallbackCostPerKm = fallbackCostPerKm
    }

    /// 1.15: kullaniciya sorulmayan varsayilanlar (motosiklet 2,5 L/100 km, benzin 85 TL/L).
    static func defaultConsumption(vehicleType: String?) -> Decimal {
        vehicleType == "car" ? Decimal(string: "6.5")! : Decimal(string: "2.5")!
    }

    static let defaultPrice = Money(85)

    var consumption: Decimal { settings.consumptionPer100Km ?? FuelCostModel.defaultConsumption(vehicleType: vehicleType) }

    var hasPrice: Bool { !settings.entries.isEmpty }

    private var sorted: [FuelPriceEntry] { settings.entries.sorted { $0.day < $1.day } }

    /// Gunden once ya da o gun girilmis en yeni fiyat; o gunden once hic yoksa en eski fiyat.
    func price(on day: String) -> FuelPriceEntry? {
        let entries: [FuelPriceEntry] = sorted
        return entries.last { $0.day <= day } ?? entries.first
    }

    func costPerKm(on day: String) -> Money {
        guard let entry = price(on: day) else { return fallbackCostPerKm }
        return Money(entry.pricePerUnit.value * consumption / 100)
    }

    func cost(km: Decimal, on day: String) -> Money {
        Money(Money.round(costPerKm(on: day).value * km))
    }

    /// Son fiyat `maxAgeDays` gunden eskiyse (ya da hic yoksa) guncellenmeli.
    func isStale(today: String, maxAgeDays: Int = 7) -> Bool {
        guard let last = sorted.last else { return true }
        guard let age = RuleDay.days(from: last.day, to: today) else { return true }
        return age > maxAgeDays
    }

    /// Iki gun arasindaki fiyat degisimi (yuzde). Fiyat yoksa nil.
    func change(from: String, to: String) -> Decimal? {
        guard let old = price(on: from), let new = price(on: to) else { return nil }
        return Money.percentChange(from: old.pricePerUnit, to: new.pricePerUnit)
    }
}
