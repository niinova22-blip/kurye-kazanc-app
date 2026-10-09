import Foundation

/// Bir platformun kazanc ekrani sablonu. JSON olarak tanimlanir: uygulamaya gomulu kopya (BundledTemplates)
/// ve 1.3'ten itibaren sunucudan indirilen guncel surumler. Etiketler normalize bicimdedir (bkz. TextNormalizer).
///
/// ONEMLI: Gercek ekran ornekleri toplanana kadar tum sablonlar `calibrating` durumundadir;
/// `calibrating` sablonla okunan kayit asla `verified` olmaz.
struct OCRTemplate: Codable, Equatable {
    enum Status: String, Codable { case calibrating, active }
    enum Period: String, Codable { case day, week, order, unknown }
    /// Ekran tipi: ozet (toplam + adet), liste (satirlar toplanir), siparis karti (tek siparis).
    enum Layout: String, Codable { case summary, list, orderCard }

    var id: String
    var version: Int
    var status: Status
    var platformCode: String
    var detectionKeywords: [String]
    /// Kazanc ekranina ozgu sabit metinler (baslik, sekme adi...). Dogrulama icin en az `minFingerprintMatches` tanesi gorulmeli.
    var fingerprint: [String]
    var minFingerprintMatches: Int
    /// Listeler ONCELIK SIRASINDADIR: daha ozgul etiket once.
    var totalLabels: [String]
    var bonusLabels: [String]
    var packageLabels: [String]
    /// Ekrandaki "toplam" bonusu da iceriyor mu? Iceriyorsa brut = toplam - bonus.
    var totalIncludesBonus: Bool
    /// Paket basi ucret araligi (TL); ic tutarlilik kontrolu icin. Bilinmiyorsa nil.
    var minPackageFee: Double?
    var maxPackageFee: Double?
    var dayLabels: [String]
    var weekLabels: [String]
    // 1.4a: JSON'da yoksa varsayilan (eski sunucu sablonlari bozulmaz)
    var layout: Layout = .summary
    var durationLabels: [String] = []
    /// `list` tipinde toplanacak satirlarin etiketi.
    var rowLabels: [String] = []
    /// Ekrandaki tutarlar KDV haric (yalnizca bilgi).
    var amountsExcludeVAT: Bool = false

    func fingerprintMatches(in normalizedText: String) -> Int {
        fingerprint.filter { TextPatterns.containsWord($0, in: normalizedText) }.count
    }

    /// Haftalik ifade gunluk ifadeden onceliklidir ("Bugun" haftalik ekranda da gorunebilir).
    func period(in normalizedText: String) -> Period {
        if weekLabels.contains(where: { TextPatterns.containsWord($0, in: normalizedText) }) { return .week }
        if dayLabels.contains(where: { TextPatterns.containsWord($0, in: normalizedText) }) { return .day }
        return .unknown
    }
}

extension OCRTemplate {
    enum CodingKeys: String, CodingKey {
        case id, version, status, platformCode, detectionKeywords, fingerprint, minFingerprintMatches
        case totalLabels, bonusLabels, packageLabels, totalIncludesBonus, minPackageFee, maxPackageFee
        case dayLabels, weekLabels, layout, durationLabels, rowLabels, amountsExcludeVAT
    }

    /// Uye-bazli init korunsun diye uzantida. Yeni alanlar yoksa varsayilan; bilinmeyen layout -> summary.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        version = try c.decode(Int.self, forKey: .version)
        status = try c.decode(Status.self, forKey: .status)
        platformCode = try c.decode(String.self, forKey: .platformCode)
        detectionKeywords = try c.decode([String].self, forKey: .detectionKeywords)
        fingerprint = try c.decode([String].self, forKey: .fingerprint)
        minFingerprintMatches = try c.decode(Int.self, forKey: .minFingerprintMatches)
        totalLabels = try c.decode([String].self, forKey: .totalLabels)
        bonusLabels = try c.decode([String].self, forKey: .bonusLabels)
        packageLabels = try c.decode([String].self, forKey: .packageLabels)
        totalIncludesBonus = try c.decode(Bool.self, forKey: .totalIncludesBonus)
        minPackageFee = try c.decodeIfPresent(Double.self, forKey: .minPackageFee)
        maxPackageFee = try c.decodeIfPresent(Double.self, forKey: .maxPackageFee)
        dayLabels = try c.decode([String].self, forKey: .dayLabels)
        weekLabels = try c.decode([String].self, forKey: .weekLabels)
        let layoutRaw = try c.decodeIfPresent(String.self, forKey: .layout)
        layout = layoutRaw.flatMap(Layout.init(rawValue:)) ?? .summary
        durationLabels = try c.decodeIfPresent([String].self, forKey: .durationLabels) ?? []
        rowLabels = try c.decodeIfPresent([String].self, forKey: .rowLabels) ?? []
        amountsExcludeVAT = try c.decodeIfPresent(Bool.self, forKey: .amountsExcludeVAT) ?? false
    }
}
