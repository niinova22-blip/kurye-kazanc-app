import Foundation

/// Secilen firmanin tarifesindeki kosullardan turetilen kurulum sorulari. Tarifede olmayan soru sorulmaz.
struct TariffQuestions: Equatable {
    var regionTiers: [String] = []
    var asksSeniority: Bool = false
    var flags: [String] = []
    var vehicleTypes: [String] = []
    /// Paket Taxi Restoran: gunluk calisma suresi secenekleri (9, 10, 11, 12).
    var contractHours: [Int] = []

    var isEmpty: Bool { regionTiers.isEmpty && !asksSeniority && flags.isEmpty && vehicleTypes.isEmpty && contractHours.isEmpty }

    /// Kisinin kendisine ait (donemden donem degismeyen) isaretler. "weekly_performance", "referral" gibi
    /// donemlik basari kosullari kurulumda sorulmaz ve plana girmez.
    static let profileFlags: Set<String> = ["woman_employment"]

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
        var hours: Set<Int> = []
        for version in versions {
            if let vehicle = version.vehicleType { vehicles.insert(vehicle) }
            for item in version.activeItems(on: day) {
                let c = item.conditions
                if let tier = c.regionTier { tiers.insert(tier) }
                if let flag = c.requiresFlag, profileFlags.contains(flag) { flags.insert(flag) }
                if c.minSeniorityYears != nil || c.maxSeniorityYears != nil { seniority = true }
                for h in c.contractHours ?? [] { hours.insert(h) }
            }
        }
        return TariffQuestions(regionTiers: tiers.sorted(), asksSeniority: seniority, flags: flags.sorted(),
                               vehicleTypes: vehicles.sorted(), contractHours: hours.sorted())
    }

    static func regionName(_ tier: String) -> String {
        switch tier {
        case "r1": "1. bölge"
        case "r23": "2. ve 3. bölge"
        case "r4": "4. bölge"
        case "ys_istanbul": "İstanbul"
        case "ys_ankara_izmir": "Ankara / İzmir"
        case "ys_group3": "3. grup iller"
        case "ys_other": "Diğer iller"
        case "plus": "Plus bölge"
        case "standard": "Standart bölge"
        default: tier
        }
    }

    /// Bolgenin kapsadigi yerler (secim ekraninda alt yazi).
    static func regionDetail(_ tier: String) -> String {
        switch tier {
        case "r1": "İstanbul: Beşiktaş, Şişli, Levent, Maslak, Uskumruköy, Ortaköy, Kağıthane, Eyüp, Sarıyer, Kadıköy, Sultangazi. Ankara: Beytepe, Angora, Bilkent, Çayyolu, Ümitköy, İncek, Yaşamkent, Konutkent."
        case "r23": "İstanbul ve Ankara'nın 1. bölge dışı ilçeleri; İzmir, Antalya, Kocaeli, Bursa, Sakarya."
        case "r4": "1., 2. ve 3. bölge dışında kalan iller ve ilçeler."
        case "ys_istanbul": "İstanbul"
        case "ys_ankara_izmir": "Ankara ve İzmir"
        case "ys_group3": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum"
        case "ys_other": "Diğer tüm iller"
        default: ""
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
