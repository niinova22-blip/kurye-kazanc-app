import Foundation

/// Kazanc kaydinin ne kadar guvenilir oldugu. Topluluk istatistiklerine yalnizca `verified` girer;
/// kisisel analizlerde tum seviyeler kullanilir (seviye yalnizca rozet olarak gorunur).
enum VerificationLevel: String, Codable, CaseIterable {
    /// Elle girildi.
    case manual
    /// Ekran goruntusunden okundu ama kullanici okunan tutar/tarih/platform/paketi degistirdi.
    case ocrEdited
    /// Ekran goruntusunden okundu, degistirilmedi; ancak kontrollerden biri gecmedi (or. sablon kalibrasyonda).
    case ocrUnverified
    /// Tum kontrollerden gecti.
    case verified

    var countsForCommunity: Bool { self == .verified }

    var displayName: String {
        switch self {
        case .manual: "Elle girildi"
        case .ocrEdited: "Ekran görüntüsü, düzenlendi"
        case .ocrUnverified: "Ekran görüntüsü"
        case .verified: "Doğrulandı"
        }
    }

    /// Kayit anindaki son seviye.
    /// - Parameter userEditedReadValues: Ekrandan okunan degerlerden biri degistirildi mi? (Saatler ekranda olmadigindan sayilmaz.)
    static func resolve(isFromScreenshot: Bool, userEditedReadValues: Bool, candidate: VerificationLevel) -> VerificationLevel {
        guard isFromScreenshot else { return .manual }
        if userEditedReadValues { return .ocrEdited }
        return candidate == .verified ? .verified : .ocrUnverified
    }
}
