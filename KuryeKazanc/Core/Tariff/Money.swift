import Foundation

/// Hassas para tutari (TL). Ikili kayan nokta (Double) yerine `Decimal`; kurus (2 hane) yuvarlama.
/// JSON'da metin olarak yazilir ("64.50"); okurken sayi da kabul edilir (PostgREST numeric).
struct Money: Hashable, Comparable, Codable, CustomStringConvertible {
    private(set) var value: Decimal

    static let zero = Money(Decimal(0))

    init(_ value: Decimal) {
        self.value = Money.round(value)
    }

    init(_ int: Int) {
        self.init(Decimal(int))
    }

    /// Arayuzdeki Double tutarlar (AppStorage, SwiftData) icin; ikili gosterim kalintisi metin uzerinden temizlenir.
    init(double: Double) {
        self.init(Money.parse(String(format: "%.4f", double)) ?? Decimal(double))
    }

    /// "64.50" / "64,50" / "1.610" / "1610". Gecersizse nil.
    init?(text: String) {
        guard let decimal = Money.parse(text) else { return nil }
        self.init(decimal)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            guard let decimal = Money.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Gecersiz tutar: \(text)")
            }
            self.init(decimal)
            return
        }
        let number: Double = try container.decode(Double.self)
        // Sayidan once metne cevirmek ikili gosterim kalintisini (64.5000000001) temizler
        self.init(Money.parse(String(format: "%.4f", number)) ?? Decimal(number))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    /// Nokta ondalikli, iki haneli metin ("1610.00"). Gosterim icin `Formatters.currency(money.doubleValue)`.
    var description: String {
        var copy = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &copy, 2, .plain)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: rounded as NSDecimalNumber) ?? "\(rounded)"
    }

    var doubleValue: Double { NSDecimalNumber(decimal: value).doubleValue }
    var isZero: Bool { value == 0 }
    var isNegative: Bool { value < 0 }

    static func + (lhs: Money, rhs: Money) -> Money { Money(lhs.value + rhs.value) }
    static func - (lhs: Money, rhs: Money) -> Money { Money(lhs.value - rhs.value) }
    static func * (lhs: Money, rhs: Decimal) -> Money { Money(lhs.value * rhs) }
    static func * (lhs: Money, rhs: Int) -> Money { Money(lhs.value * Decimal(rhs)) }
    static prefix func - (m: Money) -> Money { Money(-m.value) }
    static func += (lhs: inout Money, rhs: Money) { lhs = lhs + rhs }
    static func -= (lhs: inout Money, rhs: Money) { lhs = lhs - rhs }
    static func < (lhs: Money, rhs: Money) -> Bool { lhs.value < rhs.value }

    static func max(_ a: Money, _ b: Money) -> Money { a < b ? b : a }

    /// Yuzde fark (yeni − eski) / eski × 100; eski 0 ise nil.
    static func percentChange(from old: Money, to new: Money) -> Decimal? {
        guard old.value != 0 else { return nil }
        return Money.round((new.value - old.value) / old.value * 100)
    }

    static func round(_ value: Decimal, scale: Int = 2) -> Decimal {
        var copy = value
        var result = Decimal()
        NSDecimalRound(&result, &copy, scale, .plain)
        return result
    }

    /// Turkce ya da POSIX yazimli sayi. Tek virgul ondalik; "1.610" binlik; "64.50" ondalik.
    static func parse(_ text: String) -> Decimal? {
        var t = text
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: "TL", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let comma = t.lastIndex(of: ",")
        let dot = t.lastIndex(of: ".")
        switch (comma, dot) {
        case let (c?, d?):
            if c > d {
                t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                t = t.replacingOccurrences(of: ",", with: "")
            }
        case (_?, nil):
            t = t.replacingOccurrences(of: ",", with: ".")
        case (nil, _?):
            let parts = t.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count > 2 || parts.last?.count == 3 {
                t = t.replacingOccurrences(of: ".", with: "")
            }
        case (nil, nil):
            break
        }
        guard t.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: t, locale: Locale(identifier: "en_US_POSIX"))
    }
}

extension Decimal {
    /// Sayac / km / saat gibi miktarlar icin metin cozumleme (Turkce virgul kabul).
    static func parse(_ text: String) -> Decimal? { Money.parse(text) }

    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

extension Sequence where Element == Money {
    func sum() -> Money { reduce(Money.zero, +) }
}
