import Foundation

/// Turkce yazilmis sayilari (1.234,56 / 1234,5 / 12.50 / ₺ 850 TL) Double'a cevirir.
/// Hem form girislerinde hem OCR ciktisinda kullanilir.
enum TurkishNumberParser {
    static func parseDecimal(_ input: String) -> Double? {
        var text = input
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: "TL", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "TRY", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { return nil }

        let lastComma = text.lastIndex(of: ",")
        let lastDot = text.lastIndex(of: ".")

        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            // Sonda olan ayirac ondaliktir: "1.234,56" veya "1,234.56"
            if comma > dot {
                text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                text = text.replacingOccurrences(of: ",", with: "")
            }
        case (_?, nil):
            // Turkcede virgul ondalik ayiracidir
            if text.filter({ $0 == "," }).count > 1 {
                text = text.replacingOccurrences(of: ",", with: "")
            } else {
                text = text.replacingOccurrences(of: ",", with: ".")
            }
        case (nil, _?):
            // "1.234" binlik, "12.50" ondalik
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count > 2 || parts.last?.count == 3 {
                text = text.replacingOccurrences(of: ".", with: "")
            }
        case (nil, nil):
            break
        }

        guard text.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil else { return nil }
        return Double(text)
    }

    static func parseInt(_ input: String) -> Int? {
        let digits = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return Int(digits)
    }

    /// Form alanina geri yazmak icin: 1250.5 -> "1250,5"
    static func format(_ value: Double) -> String {
        value.formatted(.number.locale(Formatters.locale).grouping(.never).precision(.fractionLength(0...2)))
    }
}
