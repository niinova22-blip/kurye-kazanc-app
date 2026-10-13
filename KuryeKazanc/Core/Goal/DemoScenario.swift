import Foundation

struct DemoWorkDay: Equatable {
    /// 0 = bugun, negatif = gecmis gun.
    var dayOffset: Int
    var startHour: Int
    var hours: Decimal
    var packages: Int
    var km: Decimal
}

struct DemoFuelPrice: Equatable {
    var dayOffset: Int
    var price: Money
}

/// Test surumundeki "senaryo yukle": telefondaki veritabanini gercekci, tekrarlanabilir veriyle doldurur.
struct DemoScenario: Identifiable, Equatable {
    var id: String
    var title: String
    var summary: String
    var profile: CourierTariffProfile?
    var goal: GoalSpec?
    var consumption: Decimal?
    var fuelPrices: [DemoFuelPrice]
    var workDays: [DemoWorkDay]
    var resetsOnboarding: Bool = false

    /// Senaryonun kullanici tarifeleri (yalnizca `tariffChanged`; ornek, gercek tarife degil). Tarihler bugune goredir.
    func userTariffs(today: String) -> [TariffVersion] {
        guard id == "tariffChanged",
              var base = BundledTariffs.all.first(where: { $0.id == "yemeksepeti-esnaf-v3" }) else { return [] }
        base.origin = .user
        base.sourceNote = "Test senaryosu (örnek)"
        func make(_ suffix: String, number: Int, from: Int, until: Int?, factor: Decimal) -> TariffVersion {
            var v = base
            v.id = "demo-ys-\(suffix)"
            v.versionNumber = 100 + number
            v.effectiveFrom = DemoScenarioCatalog.day(offset: from, from: today)
            v.effectiveUntil = until.map { DemoScenarioCatalog.day(offset: $0, from: today) }
            v.items = base.items.map { item in
                var i = item
                i.id = "demo-\(suffix)-\(item.id)"
                i.versionID = v.id
                if i.isCash { i.amount = Money(Money.round(item.amount.value * factor)) }
                return i
            }
            return v
        }
        let v1 = make("v1", number: 1, from: -60, until: -20, factor: 2)
        let v2 = make("v2", number: 2, from: -20, until: nil, factor: Decimal(string: "2.16")!) // 2 × 1,08
        return [v1, v2]
    }
}

enum DemoScenarioCatalog {
    static func day(offset: Int, from today: String) -> String {
        guard let date = RuleDay.date(today) else { return today }
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        let shifted: Date = c.date(byAdding: .day, value: offset, to: date) ?? date
        let parts = c.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Sabit tohumlu basit uretec (her calistirmada ayni veri).
    struct Generator {
        var state: UInt64
        mutating func next(_ range: ClosedRange<Int>) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int((state >> 33) % span)
        }
    }

    /// Bugunden geriye `count` is gunu; `skipEvery` verilirse her o kadar gunde bir izin gunu atlanir.
    static func workDays(count: Int, skipEvery: Int?, packages: ClosedRange<Int>, rate: Decimal, kmPerPackage: Decimal,
                         seed: UInt64) -> [DemoWorkDay] {
        var g = Generator(state: seed)
        var result: [DemoWorkDay] = []
        var offset = 0
        while result.count < count {
            if let skip = skipEvery, offset % skip == skip - 1 {
                offset += 1
                continue
            }
            let p: Int = g.next(packages)
            let hours: Decimal = Money.round(Decimal(p) / rate, scale: 1)
            result.append(DemoWorkDay(dayOffset: -offset, startHour: 10 + g.next(0...2), hours: hours, packages: p,
                                      km: Decimal(p) * kmPerPackage))
            offset += 1
        }
        return result
    }

    static let all: [DemoScenario] = [
        DemoScenario(
            id: "paketTaxi30", title: "Paket Taxi Migros Hemen · 30 gün",
            summary: "1. bölge, kadın istihdam desteği, aylık 110.000 TL net hedef; hedefe giden kurye.",
            profile: CourierTariffProfile(platformCode: "migros_hemen", regionTier: "r1", seniorityYears: 1, vehicleType: nil,
                                          flags: ["woman_employment"]),
            goal: GoalSpec(amount: Money(110_000), period: .month), consumption: 3,
            fuelPrices: [DemoFuelPrice(dayOffset: -90, price: Money(41)), DemoFuelPrice(dayOffset: -60, price: Money(42)),
                         DemoFuelPrice(dayOffset: -30, price: Money(44)), DemoFuelPrice(dayOffset: -3, price: Money(45))],
            workDays: workDays(count: 26, skipEvery: 7, packages: 34...44, rate: Decimal(string: "4.2")!,
                               kmPerPackage: Decimal(string: "3.5")!, seed: 17)
        ),
        DemoScenario(
            id: "yemeksepetiBehind", title: "Yemeksepeti · hedefin gerisinde",
            summary: "İstanbul, 14 gün düşük paket hızı; aylık 100.000 TL net hedef için ek gün gerekir.",
            profile: CourierTariffProfile(platformCode: "yemeksepeti", regionTier: "ys_istanbul", seniorityYears: nil,
                                          vehicleType: nil, flags: []),
            goal: GoalSpec(amount: Money(100_000), period: .month, daysPerWeek: 5, maxHoursPerDay: 8), consumption: 3,
            fuelPrices: [DemoFuelPrice(dayOffset: -10, price: Money(45))],
            workDays: workDays(count: 14, skipEvery: nil, packages: 12...18, rate: Decimal(string: "2.2")!, kmPerPackage: 3, seed: 29)
        ),
        DemoScenario(
            id: "tariffChanged", title: "Tarife değişti + yakıt arttı",
            summary: "Yemeksepeti örnek tarifesi +%8, yakıt +%11; Firmalar ekranında bildirim ve ✓ uyumlu işareti.",
            profile: CourierTariffProfile(platformCode: "pt_migros", regionTier: "r23", seniorityYears: 0, vehicleType: nil,
                                          flags: []),
            goal: GoalSpec(amount: Money(80_000), period: .month), consumption: 3,
            fuelPrices: [DemoFuelPrice(dayOffset: -65, price: Money(40)),
                         DemoFuelPrice(dayOffset: -25, price: Money(Decimal(string: "44.4")!))],
            workDays: workDays(count: 10, skipEvery: nil, packages: 30...40, rate: 4, kmPerPackage: 3, seed: 41)
        ),
        DemoScenario(
            id: "fresh", title: "Yeni kullanıcı",
            summary: "Boş veri; tanıtım ve kurulum baştan başlar.",
            profile: nil, goal: nil, consumption: nil, fuelPrices: [], workDays: [], resetsOnboarding: true
        ),
    ]

    static func scenario(_ id: String) -> DemoScenario? { all.first { $0.id == id } }
}
