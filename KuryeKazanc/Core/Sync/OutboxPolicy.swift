import Foundation

/// Sunucu yaniti (submit_shift / submit_calibration) ve ag hatalari.
enum OutboxResult: String, Codable {
    case ok
    case duplicate
    case rateLimited = "rate_limited"
    case invalid
    case transient
}

enum OutboxPolicy {
    /// Kalici sonuc: oge kuyruktan duser.
    static func isFinal(_ result: OutboxResult) -> Bool {
        result == .ok || result == .duplicate || result == .invalid
    }

    /// Ussel bekleme: 1 dk, 2 dk, 4 dk ... en fazla 6 saat.
    static func nextAttempt(after failures: Int, now: Date) -> Date {
        let exponent = max(0, min(failures - 1, 20))
        let seconds = min(60 * pow(2.0, Double(exponent)), 21_600)
        return now.addingTimeInterval(seconds)
    }

    /// Gunluk sinir: sunucu gunu UTC'ye gore sayar (init.sql); ertesi UTC gece yarisi + 5 dk.
    static func nextDay(after now: Date) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? utc.timeZone
        let tomorrow = utc.date(byAdding: .day, value: 1, to: utc.startOfDay(for: now)) ?? now
        return tomorrow.addingTimeInterval(300)
    }
}
