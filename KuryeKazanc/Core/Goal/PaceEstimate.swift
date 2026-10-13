import Foundation

/// Kuryenin secili firmadaki hizi: son 8 haftanin kayitlarindan paket/saat ve km/paket.
/// En az 5 paketli kayit ve 10 saat yoksa varsayilan kullanilir ve `isAssumed` isaretlenir.
struct PaceEstimate: Equatable {
    var packagesPerHour: Decimal
    var kmPerPackage: Decimal
    var isAssumed: Bool
    var sampleCount: Int

    static let defaultPackagesPerHour: Decimal = Decimal(string: "2.5")!
    static let defaultKmPerPackage: Decimal = Decimal(string: "3.5")!
    static let windowDays: Double = 56
    static let minimumSamples = 5
    static let minimumHours: Decimal = 10

    static func estimate(entries: [EarningEntry], platform: String, now: Date,
                         defaults: (packagesPerHour: Decimal, kmPerPackage: Decimal)? = nil) -> PaceEstimate {
        let fallbackRate: Decimal = defaults?.packagesPerHour ?? defaultPackagesPerHour
        let fallbackKm: Decimal = defaults?.kmPerPackage ?? defaultKmPerPackage
        let cutoff: Date = now.addingTimeInterval(-windowDays * 86_400)
        let usable: [EarningEntry] = entries.filter { entry in
            guard entry.platformCode == platform, entry.start >= cutoff, entry.end > entry.start else { return false }
            guard let packages = entry.packageCount else { return false }
            return packages > 0
        }
        var packages: Decimal = 0
        var hours: Decimal = 0
        var km: Decimal = 0
        for entry in usable {
            packages += Decimal(entry.packageCount ?? 0)
            hours += Decimal(entry.end.timeIntervalSince(entry.start) / 3600)
            km += Decimal(entry.distanceKm)
        }
        guard usable.count >= minimumSamples, hours >= minimumHours, packages > 0 else {
            return PaceEstimate(packagesPerHour: fallbackRate, kmPerPackage: fallbackKm, isAssumed: true, sampleCount: usable.count)
        }
        let rate: Decimal = Money.round(packages / hours, scale: 1)
        let kmPer: Decimal = km > 0 ? Money.round(km / packages, scale: 1) : fallbackKm
        return PaceEstimate(packagesPerHour: rate, kmPerPackage: kmPer, isAssumed: false, sampleCount: usable.count)
    }
}
