import Foundation

/// OCR metnini karsilastirilabilir hale getirir: kucuk harf (Turkce kurallariyla) + Turkce harfler ASCII'ye.
/// "TOPLAM KAZANÇ" / "Toplam Kazanç" / "TOPLAM KAZANC" -> "toplam kazanc"
enum TextNormalizer {
    private static let folding: [Character: Character] = [
        "ı": "i", "ğ": "g", "ü": "u", "ş": "s", "ö": "o", "ç": "c",
        "â": "a", "î": "i", "û": "u",
    ]

    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased(with: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "\u{0307}", with: "") // "İ" baska yerelde "i̇" olabilir
        let folded = String(lowered.map { folding[$0] ?? $0 })
        // Coklu bosluklari tek bosluga indir
        return folded.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }
}

/// Regex yardimcilari. Tum girdiler normalize edilmis satirlardir.
enum TextPatterns {
    // 1.234,56 | 1234,56 | 1234 | 12.50 (ondalik nokta)  — tarih ve saatler once temizlenir
    private static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<![\d.,])(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+,\d{1,2}|\d+\.\d{1,2}(?!\d)|\d+)(?![\d.,]*\d)"#
    )
    private static let countRegex = try! NSRegularExpression(pattern: #"(?<![\d.,])(\d{1,4})(?![\d.,]*\d)"#)
    private static let numericDateRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,2})[./-](\d{1,2})[./-](\d{4}|\d{2})(?!\d)"#
    )
    private static let timeRegex = try! NSRegularExpression(pattern: #"(?<!\d)\d{1,2}:\d{2}(?::\d{2})?(?!\d)"#)
    private static let months = [
        "ocak", "subat", "mart", "nisan", "mayis", "haziran",
        "temmuz", "agustos", "eylul", "ekim", "kasim", "aralik",
    ]
    private static let monthDateRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,2})\s*(ocak|subat|mart|nisan|mayis|haziran|temmuz|agustos|eylul|ekim|kasim|aralik)(?:\s*(\d{4}))?"#
    )

    static func hasCurrencyMarker(_ line: String) -> Bool {
        line.contains("₺") || containsWord("tl", in: line) || containsWord("try", in: line)
    }

    static func containsLetters(_ line: String, minimum: Int) -> Bool {
        line.filter(\.isLetter).count >= minimum
    }

    static func containsWord(_ word: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        return text.range(of: #"(?<![\p{L}\d])"# + escaped + #"(?![\p{L}\d])"#, options: .regularExpression) != nil
    }

    /// Tarih ve saat kaliplarini satirdan cikarir ki "05.10" tutar sanilmasin.
    static func strippingDatesAndTimes(_ line: String) -> String {
        var result = line
        for regex in [numericDateRegex, monthDateRegex, timeRegex] {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: " ")
        }
        return result
    }

    static func allAmounts(in line: String) -> [Double] {
        let cleaned = strippingDatesAndTimes(line)
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        return amountRegex.matches(in: cleaned, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: cleaned) else { return nil }
            return TurkishNumberParser.parseDecimal(String(cleaned[r]).replacingOccurrences(of: " ", with: ""))
        }
    }

    static func firstAmount(in line: String) -> Double? {
        allAmounts(in: line).first
    }

    private static func counts(in line: String) -> [Int] {
        let cleaned = strippingDatesAndTimes(line)
        guard !hasCurrencyMarker(cleaned) else { return [] }
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        return countRegex.matches(in: cleaned, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: cleaned) else { return nil }
            return Int(cleaned[r])
        }.filter { $0 < 1000 }
    }

    static func firstCount(in line: String) -> Int? { counts(in: line).first }
    static func lastCount(in line: String) -> Int? { counts(in: line).last }

    static func numericDate(in line: String, calendar: Calendar) -> Date? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = numericDateRegex.firstMatch(in: line, range: range),
              let day = int(match, 1, line), let month = int(match, 2, line), var year = int(match, 3, line)
        else { return nil }
        if year < 100 { year += 2000 }
        return makeDate(day: day, month: month, year: year, calendar: calendar)
    }

    static func monthNameDate(in line: String, referenceDate: Date, calendar: Calendar) -> Date? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = monthDateRegex.firstMatch(in: line, range: range),
              let day = int(match, 1, line),
              let monthRange = Range(match.range(at: 2), in: line),
              let monthIndex = months.firstIndex(of: String(line[monthRange]))
        else { return nil }

        let month = monthIndex + 1
        if let year = int(match, 3, line) {
            return makeDate(day: day, month: month, year: year, calendar: calendar)
        }
        // Yil yoksa: referans yili; gelecege dusuyorsa bir onceki yil
        let refYear = calendar.component(.year, from: referenceDate)
        guard let candidate = makeDate(day: day, month: month, year: refYear, calendar: calendar) else { return nil }
        if candidate > referenceDate {
            return makeDate(day: day, month: month, year: refYear - 1, calendar: calendar)
        }
        return candidate
    }

    private static func int(_ match: NSTextCheckingResult, _ group: Int, _ line: String) -> Int? {
        guard match.range(at: group).location != NSNotFound,
              let r = Range(match.range(at: group), in: line) else { return nil }
        return Int(line[r])
    }

    private static func makeDate(day: Int, month: Int, year: Int, calendar: Calendar) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month), (2000...2100).contains(year) else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day else { return nil } // 31.02 gibi gecersizleri ele
        return calendar.startOfDay(for: date)
    }
}
