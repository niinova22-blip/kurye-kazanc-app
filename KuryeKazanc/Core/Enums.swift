import Foundation

/// Kuryenin kullandigi arac tipi.
enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case motorcycle
    case scooter
    case bicycle
    case car
    case onFoot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .motorcycle: "Motosiklet"
        case .scooter: "Elektrikli scooter"
        case .bicycle: "Bisiklet"
        case .car: "Otomobil"
        case .onFoot: "Yaya"
        }
    }

    /// Km basina varsayilan yakit + bakim maliyeti (TL). Kullanici ayarlardan degistirebilir.
    /// Degerler kaba baslangic tahminidir; gercek cihaz testlerinde kuryelerden gelen geri bildirimle guncellenmeli.
    var defaultCostPerKm: Double {
        switch self {
        case .motorcycle: 2.5
        case .scooter: 0.6
        case .bicycle: 0.2
        case .car: 6.0
        case .onFoot: 0
        }
    }
}

/// Kazanc kaydinin nereden geldigi.
enum EarningSource: String, Codable, CaseIterable {
    case ocr
    case manual
}

/// Gider tipi.
enum ExpenseType: String, Codable, CaseIterable, Identifiable {
    case fuel
    case maintenance
    case tire
    // 1.6: hakedis raporlari icin ek kategoriler (ham deger olarak saklanir, goc gerekmez)
    case insurance
    case phone
    case equipment
    case depreciation
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fuel: "Yakıt / elektrik"
        case .maintenance: "Bakım-onarım"
        case .tire: "Lastik"
        case .insurance: "Sigorta"
        case .phone: "Telefon-internet"
        case .equipment: "Ekipman"
        case .depreciation: "Amortisman"
        case .other: "Diğer"
        }
    }

    /// Km basina otomatik tahminin kapsadigi tipler (yakit + bakim).
    /// Bu tiplerde manuel kayit varsa o gun icin otomatik tahmin kullanilmaz (cift sayimi onlemek icin).
    var isCoveredByPerKmEstimate: Bool {
        self == .fuel || self == .maintenance
    }
}
