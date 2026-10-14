import Foundation

/// Tarihli gider (rapor girdisi; SwiftData `ExpenseRecord`'dan uretilir).
struct DatedExpense: Equatable {
    var day: String
    var category: ExpenseType
    var amount: Money
}

/// Ayin hakedis panosu (ortak kartlar).
///
/// 1.10 duzeltmesi: "Bu ay tahmini brüt" aylik sabit ucretin tamamini icerir; saat basi degerler ise yalnizca
/// calisilan gunlere dusen payi kullanir (yoksa 1 gunluk saate 55.000 TL bolunup "61.000 TL/sa" cikiyordu).
/// Net, elle yakit gideri yoksa km'den yakit tahminini de duser (Bugun ekraniyla ayni kural).
struct PayrollDashboard: Equatable {
    var period: PeriodResult
    var expenses: Money
    var paymentDifference: Money?
    /// Km'den yakit tahmini (elle yakit gideri girildiyse sifir).
    var fuel: Money = .zero
    var monthWorkDays: Int = 26

    var estimatedGross: Money { period.gross }
    var estimatedNet: Money { period.gross - expenses - fuel }
    var packages: Int { period.packages }
    /// Su ana kadar hak edilen brut: aylik kalemlerin calisilan gunlere dusen payi dahil.
    var earnedSoFar: Money { period.earnedGross(monthWorkDays: monthWorkDays) }
    var grossPerHour: Money? { period.grossPerHour(monthWorkDays: monthWorkDays) }
    var netPerHour: Money? {
        guard period.hours >= PeriodResult.minimumRatedHours else { return nil }
        return Money(Money.round((earnedSoFar - expenses - fuel).value / period.hours))
    }
    /// En yakin bonus hedefi.
    var nextBonus: BonusProgress? {
        period.progress.filter { $0.remaining > 0 }.min { $0.remaining < $1.remaining }
    }
}

/// Gider ve net kazanc raporlari.
struct ExpenseReport: Equatable {
    struct Month: Equatable, Identifiable {
        var month: String
        var gross: Money
        var expenses: Money
        var net: Money { gross - expenses }
        var id: String { month }
    }

    var total: Money
    var byCategory: [ExpenseType: Money]
    var byDay: [String: Money]
    var perPackageNet: Money?
    var perHourNet: Money?
    var costPerKm: Money?
    var gross: Money
    var net: Money { gross - total }
    var trend: [Month]

    /// - Parameters:
    ///   - logs: Rapor donemindeki kayitlar (gunluk + donem).
    ///   - expenses: Ayni donemin giderleri.
    ///   - allLogs/allExpenses: Aylik trend (son `months` ay) icin.
    static func build(logs: [WorkLog], expenses: [DatedExpense], allLogs: [WorkLog], allExpenses: [DatedExpense],
                      lastMonth: String, months: Int = 6) -> ExpenseReport {
        var byCategory: [ExpenseType: Money] = [:]
        var byDay: [String: Money] = [:]
        for expense in expenses {
            byCategory[expense.category, default: .zero] += expense.amount
            byDay[expense.day, default: .zero] += expense.amount
        }
        let total: Money = expenses.map(\.amount).sum()
        let gross: Money = logs.map(\.gross).sum()
        let packages: Int = logs.map { $0.input.periodPackages ?? $0.input.totalPackages }.reduce(0, +)
        let hours: Decimal = logs.map(\.input.hours).reduce(Decimal(0), +)
        let km: Decimal = logs.map(\.input.distanceKm).reduce(Decimal(0), +)
        let net: Money = gross - total
        let perPackage: Money? = packages > 0 ? Money(net.value / Decimal(packages)) : nil
        let perHour: Money? = hours > 0 ? Money(net.value / hours) : nil
        let perKm: Money? = km > 0 ? Money(total.value / km) : nil

        var trend: [Month] = []
        for month in previousMonths(from: lastMonth, count: months) {
            let monthGross: Money = allLogs.filter { $0.startDay.hasPrefix(month) }.map(\.gross).sum()
            let monthExpenses: Money = allExpenses.filter { $0.day.hasPrefix(month) }.map(\.amount).sum()
            trend.append(Month(month: month, gross: monthGross, expenses: monthExpenses))
        }
        return ExpenseReport(total: total, byCategory: byCategory, byDay: byDay, perPackageNet: perPackage,
                             perHourNet: perHour, costPerKm: perKm, gross: gross, trend: trend)
    }

    /// "2026-10" -> ["2026-05", ..., "2026-10"].
    static func previousMonths(from month: String, count: Int) -> [String] {
        let parts: [Int] = month.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return [] }
        var year: Int = parts[0]
        var m: Int = parts[1]
        var result: [String] = []
        for _ in 0..<count {
            result.insert(String(format: "%04d-%02d", year, m), at: 0)
            m -= 1
            if m == 0 { m = 12; year -= 1 }
        }
        return result
    }
}

/// Farkli platform / donem karsilastirmasi ("Getir'deyken aylik ortalamam" vs "Trendyol GO'dayken").
struct PlatformComparison: Equatable, Identifiable {
    var platformCode: String
    var months: Int
    var firstDay: String
    var lastDay: String
    var gross: Money
    var packages: Int
    var hours: Decimal
    var logCount: Int

    var id: String { platformCode }
    var monthlyAverage: Money { months > 0 ? Money(gross.value / Decimal(months)) : .zero }
    var perHour: Money? { hours > 0 ? Money(gross.value / hours) : nil }
    var perPackage: Money? { packages > 0 ? Money(gross.value / Decimal(packages)) : nil }

    /// Her platformun kendi dondurulmus sonuclariyla (kendi tarife surumleri) karsilastirma; yeniden hesaplama yok.
    static func build(_ logs: [WorkLog]) -> [PlatformComparison] {
        var grouped: [String: [WorkLog]] = [:]
        for log in logs { grouped[log.platformCode, default: []].append(log) }
        var result: [PlatformComparison] = []
        for code in grouped.keys.sorted() {
            let items: [WorkLog] = grouped[code] ?? []
            let months: Set<String> = Set(items.map { String($0.startDay.prefix(7)) })
            let days: [String] = items.map(\.startDay).sorted()
            result.append(PlatformComparison(
                platformCode: code, months: months.count, firstDay: days.first ?? "", lastDay: days.last ?? "",
                gross: items.map(\.gross).sum(),
                packages: items.map { $0.input.periodPackages ?? $0.input.totalPackages }.reduce(0, +),
                hours: items.map(\.input.hours).reduce(Decimal(0), +), logCount: items.count
            ))
        }
        return result
    }
}

/// Ekonomik gosterge uyarisi (istege bagli modul). Ucreti ASLA degistirmez; yalnizca uyari uretir.
struct CostCoverage: Equatable {
    /// Paket basina ucretin paket basina yakit maliyetini karsilama orani.
    var ratio: Decimal
    var warnings: [String]

    /// - Parameters:
    ///   - perPackagePay: Tarifedeki paket basi ucret.
    ///   - fuelPricePerLiter: Kullanicinin girdigi ya da tarihli resmi kaynaktan gelen akaryakit fiyati.
    ///   - indicatorDate: Gostergenin tarihi; nil ise "guncel degil" uyarisi.
    static func evaluate(perPackagePay: Money, kmPerPackage: Decimal, litersPer100Km: Decimal, fuelPricePerLiter: Money,
                         previousRatio: Decimal? = nil, indicatorDate: String?) -> CostCoverage {
        let fuelPerPackage: Decimal = kmPerPackage * litersPer100Km / 100 * fuelPricePerLiter.value
        guard fuelPerPackage > 0 else { return CostCoverage(ratio: 0, warnings: ["Yakıt maliyeti hesaplanamadı."]) }
        let ratio: Decimal = Money.round(perPackagePay.value / fuelPerPackage)
        var warnings: [String] = []
        if indicatorDate == nil {
            warnings.append("Akaryakıt fiyatının tarihi bilinmiyor; gösterge güncel sayılmaz.")
        }
        if let previousRatio, previousRatio > 0 {
            let change: Decimal = (ratio - previousRatio) / previousRatio * 100
            if change <= -10 {
                warnings.append("Maliyet karşılama oranı düştü (\(Money.round(previousRatio)) → \(ratio)). Tarife değişmedi; yalnızca uyarıdır.")
            }
        }
        if ratio < 3 {
            warnings.append("Paket başı ücret, paket başı yakıt maliyetinin \(ratio) katı; düşük.")
        }
        return CostCoverage(ratio: ratio, warnings: warnings)
    }
}
