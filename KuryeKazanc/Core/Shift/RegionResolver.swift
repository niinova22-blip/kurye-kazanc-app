import Foundation

/// Konumdan (il / ilce / semt) tarifenin bolgesi. Yalnizca firmanin yayimladigi kadarini otomatik yapar.
/// - Paket Taxi: 1. bolge Istanbul'da Besiktas, Sisli, Levent, Maslak, Uskumrukoy, Ortakoy, Kagithane, Eyup, Sariyer,
///   Kadikoy, Sultangazi; Ankara'da Beytepe, Angora, Bilkent, Cayyolu, Umitkoy, Incek, Yasamkent, Konutkent.
///   2.–3. bolge: Istanbul ve Ankara'nin geri kalani, Izmir, Antalya, Kocaeli, Bursa, Sakarya. 4. bolge: diger iller.
/// - Yemeksepeti: haftalik bonus sehir grubuna gore (Istanbul / Ankara–Izmir / 3. grup iller / diger iller).
struct RegionSuggestion: Equatable {
    var flags: [String]
    var regionTier: String?
    /// Kullaniciya gosterilecek kisa aciklama (degisiklik yoksa nil).
    var message: String?
    /// Profil degismeli mi.
    var changed: Bool
    /// Konumdan kesin bolge bulunamadi (or. Ankara'da semt bilinmiyor): kullanicidan secim istenir.
    var needsRegionChoice: Bool = false
}

enum RegionResolver {
    static let paketTaxiCodes: Set<String> = ["pt_restoran", "pt_migros", "migros_hemen"]

    static let istanbulRegion1: [String] = ["besiktas", "sisli", "levent", "maslak", "uskumrukoy", "ortakoy", "kagithane",
                                            "eyup", "sariyer", "kadikoy", "sultangazi"]
    static let ankaraRegion1: [String] = ["beytepe", "angora", "bilkent", "cayyolu", "umitkoy", "incek", "yasamkent", "konutkent"]
    static let region23Cities: [String] = ["izmir", "antalya", "kocaeli", "bursa", "sakarya"]
    static let ysGroup3: [String] = ["kocaeli", "sakarya", "diyarbakir", "malatya", "van", "elazig", "mardin", "kahramanmaras",
                                     "erzurum"]

    /// "İzmir" / "IZMIR" / "Eyüpsultan" -> "izmir" / "eyupsultan".
    static func normalized(_ text: String) -> String {
        let lower: String = text.lowercased(with: Locale(identifier: "tr_TR"))
        let folded: String = lower.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
        return folded.replacingOccurrences(of: "ı", with: "i").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Paket Taxi bolgesi; Ankara'da semt bilinmiyorsa nil (sorulur).
    static func paketTaxiRegion(province: String, district: String?, neighborhood: String?) -> String? {
        let city: String = normalized(province)
        let place: String = [district, neighborhood].compactMap { $0 }.map(normalized).joined(separator: " ")
        if city.contains("istanbul") {
            if place.isEmpty { return nil }
            return istanbulRegion1.contains(where: { place.contains($0) }) ? "r1" : "r23"
        }
        if city.contains("ankara") {
            if ankaraRegion1.contains(where: { place.contains($0) }) { return "r1" }
            return place.isEmpty ? nil : "r23"
        }
        if region23Cities.contains(where: { city.contains($0) }) { return "r23" }
        return "r4"
    }

    static func yemeksepetiRegion(province: String) -> String {
        let city: String = normalized(province)
        if city.contains("istanbul") { return "ys_istanbul" }
        if city.contains("ankara") || city.contains("izmir") { return "ys_ankara_izmir" }
        if ysGroup3.contains(where: { city.contains($0) }) { return "ys_group3" }
        return "ys_other"
    }

    static func suggest(province: String?, district: String? = nil, neighborhood: String? = nil,
                        profile: CourierTariffProfile) -> RegionSuggestion? {
        guard let province, !province.isEmpty else { return nil }
        var flags: [String] = profile.flags
        var tier: String? = profile.regionTier
        var message: String?
        var needsChoice = false

        if profile.platformCode == "yemeksepeti" {
            let group: String = yemeksepetiRegion(province: province)
            flags.removeAll { $0 == "ys_ankara_izmir" }
            if tier != group {
                tier = group
                message = "\(province): haftalık bonus \(TariffQuestions.regionName(group)) tablosundan hesaplanıyor."
            }
        } else if paketTaxiCodes.contains(profile.platformCode) {
            if let region = paketTaxiRegion(province: province, district: district, neighborhood: neighborhood) {
                if tier != region {
                    tier = region
                    let place: String = [neighborhood, district, province].compactMap { $0 }.first ?? province
                    message = "\(place): \(TariffQuestions.regionName(region)) ücreti kullanılıyor."
                }
            } else {
                needsChoice = tier == nil
            }
        }
        flags = Array(Set(flags)).sorted()
        let changed: Bool = flags != Array(Set(profile.flags)).sorted() || tier != profile.regionTier
        return RegionSuggestion(flags: flags, regionTier: tier, message: message, changed: changed, needsRegionChoice: needsChoice)
    }
}
