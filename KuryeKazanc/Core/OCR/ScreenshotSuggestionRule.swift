import Foundation

/// Otomatik taramanin bir ekran goruntusunu "kazanc ekrani" olarak onermesi icin kosullar.
/// Yalnizca platform adinin gecmesi yetmez (bildirim, sohbet, kampanya ekrani olabilir):
/// - platform taninmali,
/// - o platformun gomulu sablonunun parmak izi esigi gecilmeli,
/// - okunan toplam pozitif olmali.
enum ScreenshotSuggestionRule {
    static func qualifies(_ parsed: ParsedEarning) -> Bool {
        guard parsed.platformCode != nil else { return false }
        guard parsed.totalEarning > 0 else { return false }
        guard let templateID = parsed.templateID else { return false }
        guard let template = BundledTemplates.template(id: templateID) else { return false }
        return parsed.fingerprintMatches >= template.minFingerprintMatches
    }
}
