import Foundation

/// Secilen firmanin tarifesindeki kosullardan turetilen kurulum sorulari. Tarifede olmayan soru sorulmaz.
struct TariffQuestions: Equatable {
    var regionTiers: [String] = []
    var asksSeniority: Bool = false
    var flags: [String] = []
    var vehicleTypes: [String] = []

    var isEmpty: Bool { regionTiers.isEmpty && !asksSeniority && flags.isEmpty && vehicleTypes.isEmpty }

    static func required(platform: String, catalog: TariffCatalog, day: String) -> TariffQuestions {
        let versions: [TariffVersion] = catalog.usable(platform: platform, day: day)
        var tiers: Set<String> = []
        var flags: Set<String> = []
        var seniority = false
        var vehicles: Set<String> = []
        for version in versions {
            if let vehicle = version.vehicleType { vehicles.insert(vehicle) }
            for item in version.activeItems(on: day) {
                let c = item.conditions
                if let tier = c.regionTier { tiers.insert(tier) }
                if let flag = c.requiresFlag { flags.insert(flag) }
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
