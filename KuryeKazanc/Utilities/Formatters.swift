import Foundation

/// Uygulama genelinde Turkce bicimlendirme. Cihaz dili ne olursa olsun TL ve tr_TR kullanilir.
enum Formatters {
    static let locale = Locale(identifier: "tr_TR")

    static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "TRY").locale(locale).precision(.fractionLength(0...2)))
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
        let totalMinutes = Int((interval / 60).rounded(.down))
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
}
