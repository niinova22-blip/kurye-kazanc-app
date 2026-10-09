import Foundation
import ActivityKit

/// Vardiya Canli Etkinligi. Uygulama ve KuryeLiveActivity eklentisi bu dosyayi birlikte derler.
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceKm: Double
        var todayNet: Double
        var netPerHour: Double?
        /// Dolu ise vardiya bitti: ozet gosterilir.
        var endedAt: Date?
    }

    var start: Date
    var isAuto: Bool
}
