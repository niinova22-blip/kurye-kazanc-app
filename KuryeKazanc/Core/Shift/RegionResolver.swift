import Foundation

/// Konumdan (il) tarifenin bolgeye bagli secimleri. Yalnizca firmanin yayimladigi kadarini otomatik yapar:
/// - Yemeksepeti: Ankara / Izmir haftalik paket bonusu.
/// - Paket Taxi: Plus bolge yalnizca Istanbul ve Ankara'da var; baska ilde standart bolge kesindir.
///   Istanbul / Ankara icinde hangi ilcelerin Plus oldugu yayimlanmadigi icin kullanicinin secimi korunur.
struct RegionSuggestion: Equatable {
    var flags: [String]
    var regionTier: String?
    /// Kullaniciya gosterilecek kisa aciklama (degisiklik yoksa nil).
    var message: String?
    /// Profil degismeli mi.
    var changed: Bool
    /// Plus / standart ayrimi icin kullanicidan secim gerekli (Istanbul / Ankara, bolge secilmemis).
    var needsRegionChoice: Bool = false
}

enum RegionResolver {
    static let ysCityFlag = "ys_ankara_izmir"

    /// "İzmir" / "IZMIR" / "izmir" -> "izmir".
    static func normalized(_ text: String) -> String {
        let lower: String = text.lowercased(with: Locale(identifier: "tr_TR"))
        let folded: String = lower.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
        return folded.replacingOccurrences(of: "ı", with: "i").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func suggest(province: String?, profile: CourierTariffProfile) -> RegionSuggestion? {
        guard let province, !province.isEmpty else { return nil }
        let city: String = normalized(province)
        var flags: [String] = profile.flags
        var tier: String? = profile.regionTier
        var message: String?
        var needsChoice = false

        switch profile.platformCode {
        case "yemeksepeti":
            let eligible: Bool = city.contains("ankara") || city.contains("izmir")
            let had: Bool = flags.contains(ysCityFlag)
            if eligible, !had {
                flags.append(ysCityFlag)
                message = "\(province): Ankara/İzmir haftalık paket bonusu hesaba katıldı."
            } else if !eligible, had {
                flags.removeAll { $0 == ysCityFlag }
                message = "\(province): Ankara/İzmir haftalık bonusu bu ilde yok, hesaptan çıkarıldı."
            }
        case "migros_hemen":
            let plusCity: Bool = city.contains("istanbul") || city.contains("ankara")
            if plusCity {
                needsChoice = tier == nil
            } else if tier != "standard" {
                tier = "standard"
                message = "\(province): Plus bölge yalnızca İstanbul ve Ankara'da; standart bölge ücreti kullanılıyor."
            }
        default:
            break
        }
        flags = Array(Set(flags)).sorted()
        let changed: Bool = flags != Array(Set(profile.flags)).sorted() || tier != profile.regionTier
        return RegionSuggestion(flags: flags, regionTier: tier, message: message, changed: changed, needsRegionChoice: needsChoice)
    }
}
