import Foundation

/// Bir platformun kazanc ekrani sablonu. JSON olarak tanimlanir: uygulamaya gomulu kopya (BundledTemplates)
/// ve 1.3'ten itibaren sunucudan indirilen guncel surumler. Etiketler normalize bicimdedir (bkz. TextNormalizer).
///
/// ONEMLI: Gercek ekran ornekleri toplanana kadar tum sablonlar `calibrating` durumundadir;
/// `calibrating` sablonla okunan kayit asla `verified` olmaz.
struct OCRTemplate: Codable, Equatable {
    enum Status: String, Codable { case calibrating, active }
    enum Period: String, Codable { case day, week, unknown }

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
