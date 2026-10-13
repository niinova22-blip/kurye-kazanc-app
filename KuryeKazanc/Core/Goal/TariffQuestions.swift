import Foundation

/// Secilen firmanin tarifesindeki kosullardan turetilen kurulum sorulari. Tarifede olmayan soru sorulmaz.
struct TariffQuestions: Equatable {
    var regionTiers: [String] = []
    var asksSeniority: Bool = false
    var flags: [String] = []
    var vehicleTypes: [String] = []

    var isEmpty: Bool { regionTiers.isEmpty && !asksSeniority && flags.isEmpty && vehicleTypes.isEmpty }

    /// Kisinin kendisine ait (donemden donem degismeyen) isaretler. "weekly_performance", "referral" gibi
    /// donemlik basari kosullari kurulumda sorulmaz ve plana girmez.
    static let profileFlags: Set<String> = ["woman_employment", "ys_ankara_izmir"]

    /// Yalnizca hesapta kullanilacak (en yeni) surumlerin kosullari sorulur; eski surumdeki kidem gibi kalkmis
    /// kosullar sorulmaz. Arac tipine gore ayrilan surumlerde her arac icin gecerli surum.
    static func required(platform: String, catalog: TariffCatalog, day: String) -> TariffQuestions {
        let usable: [TariffVersion] = catalog.usable(platform: platform, day: day)
        let vehicleTypes: [String] = Array(Set(usable.compactMap(\.vehicleType))).sorted()
        let versions: [TariffVersion] = vehicleTypes.isEmpty
            ? [catalog.current(platform: platform, day: day)].compactMap { $0 }
            : vehicleTypes.compactMap { catalog.current(platform: platform, day: day, vehicleType: $0) }
        var tiers: Set<String> = []
        var flags: Set<String> = []
        var seniority = false
        var vehicles: Set<String> = []
        for version in versions {
            if let vehicle = version.vehicleType { vehicles.insert(vehicle) }
            for item in version.activeItems(on: day) {
                let c = item.conditions
                if let tier = c.regionTier { tiers.insert(tier) }
                if let flag = c.requiresFlag, profileFlags.contains(flag) { flags.insert(flag) }
                if c.minSeniorityYears != nil || c.maxSeniorityYears != nil { seniority = true }
            }
        }
        return TariffQuestions(regionTiers: tiers.sorted(), asksSeniority: seniority, flags: flags.sorted(),
                               vehicleTypes: vehicles.sorted())
    }

    static func regionName(_ tier: String) -> String {
        switch tier {
        case "plus": "Plus bölge (İstanbul/Ankara Plus)"
        case "standard": "Standart bölge"
        default: tier
        }
    }

    static func flagName(_ flag: String) -> String {
        switch flag {
        case "woman_employment": "Kadın istihdam desteğinden yararlanıyorum"
        case "ys_ankara_izmir": "Ankara ya da İzmir'de çalışıyorum (haftalık paket bonusu)"
        default: flag
        }
    }

    static func vehicleName(_ type: String) -> String {
        switch type {
        case "motorcycle": "Motosiklet"
        case "car": "Otomobil"
        default: type
        }
    }
}
