import Foundation
import CoreLocation
import Observation

/// Biten bir "Calisiyorum" oturumunun ozeti -> kazanc formunu on doldurur.
struct WorkSessionSummary: Equatable {
    var start: Date
    var end: Date
    var distanceKm: Double
    var lastLocation: CLLocation?
}

/// "Calisiyorum" modu. Durum UserDefaults'ta tutulur; uygulama kapanip acilsa da oturum devam eder.
@MainActor
@Observable
final class WorkSessionManager {
    private(set) var isWorking: Bool
    private(set) var sessionStart: Date?

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
    }

    var sessionDistanceKm: Double { location.sessionDistanceMeters / 1000 }

    /// Uygulama yeniden acildiginda suren oturumun konum takibini surdurur.
    func resumeIfNeeded() {
        if isWorking, !location.isTracking {
            location.startTracking(resetDistance: false)
        }
    }

    func start(now: Date = .now) {
        guard !isWorking else { return }
        isWorking = true
        sessionStart = now
        persist()
        location.startTracking(resetDistance: true)
    }

    @discardableResult
    func stop(now: Date = .now) -> WorkSessionSummary? {
        guard isWorking, let start = sessionStart else { return nil }
        let lastLocation = location.lastLocation
        let km = location.stopTracking()
        isWorking = false
        sessionStart = nil
        persist()
        return WorkSessionSummary(start: start, end: max(now, start), distanceKm: km, lastLocation: lastLocation)
    }

    private func persist() {
        defaults.set(isWorking, forKey: AppPreferences.isWorkingKey)
        defaults.set(sessionStart, forKey: AppPreferences.workSessionStartKey)
    }
}
