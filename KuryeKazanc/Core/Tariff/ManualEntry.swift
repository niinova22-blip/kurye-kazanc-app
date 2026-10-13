import Foundation

/// "Elle hesapla": vardiyayi baslatmayi unutan ya da firmasinin uygulamasinda kazanc ekrani olmayan kurye icin
/// hatirladigi toplamlar (paket, km, sure) gun / hafta / ay olarak girilir. Hafta ve ayda paketlerin calisilan gunlere
/// esit dagildigi varsayilir: gunluk bonus kademesine ulasilan gun sayisi bu ortalamadan bulunur.
struct ManualEntry: Equatable {
    var packages: Int = 0
    /// Aksam / gece bandindaki paketler (tarifede ayri ucret varsa).
    var nightPackages: Int = 0
    var km: Decimal? = nil
    var hours: Decimal = 0
    /// Hafta / ayda calisilan gun (gunde 1).
    var days: Int = 1
    /// Getir hafta sonu bonusu icin Cuma–Pazar paketleri (bilinmiyorsa nil).
    var weekendPackages: Int? = nil

    var totalPackages: Int { packages + nightPackages }

    func input(base: PayInput, version: TariffVersion?) -> PayInput {
        var input = base
        input.dayPackages = packages
        input.nightPackages = nightPackages
        input.totalKm = km.flatMap { $0 > 0 ? $0 : nil }
        input.hours = max(0, hours)
        guard base.span != .day else { return input }
        input.periodPackages = totalPackages
        let workDays: Int = max(1, days)
        let average: Decimal = Decimal(totalPackages) / Decimal(workDays)
        var tierDays: [String: Int] = [:]
        for item in version?.activeItems(on: base.startDay) ?? [] where item.method == .tier && item.unit == .day && item.isCash {
            if let lower = item.lowerThreshold, average >= lower { tierDays[item.key] = workDays }
        }
        input.bonusTierDays = tierDays
        if let weekendPackages { input.weekendPackages = weekendPackages }
        return input
    }
}
