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
        /// 1.12: paket sayilan (canli) vardiyada paket sayisi; nil ise yalnizca sure/km vardiyasi (eski surumler de nil).
        var packages: Int? = nil
        /// Canli vardiyanin su ana kadarki brutu (tarifeyle).
        var shiftGross: Double? = nil
    }

    var start: Date
    var isAuto: Bool
}
