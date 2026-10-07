import Foundation

/// Canli Etkinlik guncelleme sikligi: dakikada bir veya 100 metrede bir (en sik 15 sn);
/// dusuk guc modunda yalnizca 3 dakikada bir.
struct LiveActivityThrottle {
    var normalInterval: TimeInterval = 60
    var lowPowerInterval: TimeInterval = 180
    var distanceStep: Double = 100
    var minimumGap: TimeInterval = 15

    func shouldUpdate(lastUpdate: Date?, lastDistanceMeters: Double, now: Date, distanceMeters: Double, isLowPower: Bool) -> Bool {
        guard let lastUpdate else { return true }
        let elapsed = now.timeIntervalSince(lastUpdate)
        if isLowPower { return elapsed >= lowPowerInterval }
        if elapsed >= normalInterval { return true }
        return elapsed >= minimumGap && distanceMeters - lastDistanceMeters >= distanceStep
    }
}
