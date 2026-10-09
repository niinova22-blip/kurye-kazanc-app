import Foundation
import CoreLocation
import Observation

/// Biten bir "Calisiyorum" oturumunun ozeti -> kazanc formunu on doldurur.
struct WorkSessionSummary: Equatable {
    var start: Date
    var end: Date
    var distanceKm: Double
    var lastLocation: CLLocation?
    var region: PlaceRegion? = nil
}

/// Vardiyanin kaynagi. Otomatik vardiya yalnizca kurallarla biter; elle vardiya yalnizca kullanici bitirir.
enum ShiftOrigin: String {
    case manual, auto
}

/// "Calisiyorum" modu. Durum UserDefaults'ta tutulur; uygulama kapanip acilsa da oturum devam eder.
@MainActor
@Observable
final class WorkSessionManager {
    private(set) var isWorking: Bool
    private(set) var sessionStart: Date?
    private(set) var origin: ShiftOrigin?

    let location: LocationService
    @ObservationIgnored private let defaults: UserDefaults

    init(location: LocationService, defaults: UserDefaults = .standard) {
        self.location = location
        self.defaults = defaults
        self.isWorking = defaults.bool(forKey: AppPreferences.isWorkingKey)
        self.sessionStart = defaults.object(forKey: AppPreferences.workSessionStartKey) as? Date
        if isWorking, sessionStart == nil {
            // Tutarsiz durum: baslangic yoksa oturumu kapat
            isWorking = false
            defaults.set(false, forKey: AppPreferences.isWorkingKey)
        }
        if isWorking {
            let raw = defaults.string(forKey: AppPreferences.workSessionOriginKey) ?? ShiftOrigin.manual.rawValue
            origin = ShiftOrigin(rawValue: raw) ?? .manual
        }
    }

    var sessionDistanceKm: Double { location.sessionDistanceMeters / 1000 }

    /// Uygulama yeniden acildiginda suren oturumun konum takibini surdurur.
    func resumeIfNeeded() {
        if isWorking, !location.isTracking {
            location.startTracking(resetDistance: false, keepAliveWhenStationary: origin == .auto)
        }
    }

    /// - Parameter at: Otomatik vardiyada hareketin ilk goruldugu an (geri tarihli baslangic).
    func start(at date: Date = .now, origin: ShiftOrigin = .manual) {
        guard !isWorking else { return }
        isWorking = true
        sessionStart = date
        self.origin = origin
        persist()
        location.startTracking(resetDistance: true, keepAliveWhenStationary: origin == .auto)
    }

    /// - Parameter end: Otomatik vardiyada son hareket ani; nil ise `now`.
    @discardableResult
    func stop(now: Date = .now, end: Date? = nil) -> WorkSessionSummary? {
        guard isWorking, let start = sessionStart else { return nil }
        let lastLocation = location.lastLocation
        let km = location.stopTracking()
        isWorking = false
        sessionStart = nil
        origin = nil
        persist()
        let finish = max(end ?? now, start)
        return WorkSessionSummary(start: start, end: finish, distanceKm: km, lastLocation: lastLocation)
    }

    /// Yanlis baslayan otomatik vardiya: iz birakmadan kapatir.
    func cancel() {
        guard isWorking else { return }
        location.stopTracking()
        isWorking = false
        sessionStart = nil
        origin = nil
        persist()
    }

    private func persist() {
        defaults.set(isWorking, forKey: AppPreferences.isWorkingKey)
        defaults.set(sessionStart, forKey: AppPreferences.workSessionStartKey)
        defaults.set(origin?.rawValue, forKey: AppPreferences.workSessionOriginKey)
    }
}
