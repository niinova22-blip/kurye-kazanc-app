import Foundation

/// Kalibrasyon orneginden kisisel veriyi siler (spec 4.4): IBAN, telefon, TC kimlik no, e-posta.
/// Tutarlar ve etiketler korunur.
enum CalibrationMasker {
    private static let patterns: [String] = [
        // IBAN: TR + 24 hane (bosluklu veya bitisik)
        "TR\\s?\\d{2}(?:\\s?\\d){22}",
        // E-posta
        "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
        // Telefon: +90 veya 0 ile baslayan 10 haneli mobil/sabit
        "(?:\\+90\\s?|0)\\(?\\d{3}\\)?[\\s-]?\\d{3}[\\s-]?\\d{2}[\\s-]?\\d{2}",
        // TC kimlik no: 11 hane
        "(?<!\\d)\\d{11}(?!\\d)",
    ]

    static func mask(_ text: String) -> String {
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "***")
        }
        return result
    }
}
