import Foundation

/// Uygulama genelinde Turkce bicimlendirme. Cihaz dili ne olursa olsun TL ve tr_TR kullanilir.
enum Formatters {
    static let locale = Locale(identifier: "tr_TR")

    static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "TRY").locale(locale).precision(.fractionLength(0...2)))
    }

    /// 1.700 (binlik ayracli tam sayi).
    static func groupedInt(_ value: Int) -> String {
        value.formatted(.number.locale(locale).grouping(.automatic))
    }

    static func perHour(_ value: Double?) -> String {
        guard let value else { return "—" }
        return currency(value) + "/sa"
    }

    static func distance(_ km: Double) -> String {
        km.formatted(.number.locale(locale).precision(.fractionLength(0...1))) + " km"
    }

    /// 3 sa 25 dk
    static func duration(_ interval: TimeInterval) -> String {
        // NaN / sonsuz / negatif sure (bozuk kayit, saat geri alinmasi) Int donusumunde cokme yapmasin
        guard interval.isFinite, interval > 0 else { return "0 dk" }
        let totalMinutes = Int(min(interval, 10_000 * 3600) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, let m): return "\(m) dk"
        case (let h, 0): return "\(h) sa"
        default: return "\(hours) sa \(minutes) dk"
        }
    }

    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    static func longDay(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().locale(locale).day().month(.wide).weekday(.wide))
    }

    /// Duzenlenebilir alan icin ondalik metin: binlik ayraci yok, ondalik virgul, en fazla 2 hane (yarim yukari).
    static func decimalText(_ value: Decimal) -> String {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.maximumFractionDigits = 2
        return f.string(from: NSDecimalNumber(decimal: rounded)) ?? NSDecimalNumber(decimal: rounded).stringValue
    }
}
