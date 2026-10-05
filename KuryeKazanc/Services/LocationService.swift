import Foundation
import CoreLocation
import Observation

/// Ilce/semt seviyesinde bolge. Ham koordinat SAKLANMAZ (anonimlik).
struct PlaceRegion: Equatable {
    var province: String?
    var district: String?
    var neighborhood: String?

    var displayText: String {
        [neighborhood, district, province].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// CoreLocation sarmalayicisi.
///
/// Pil tuketimini sinirlamak icin SUREKLI takip YOKTUR: konum guncellemeleri yalnizca
/// `startTracking()` (= "Calisiyorum" modu) ile baslar, `stopTracking()` ile tamamen durur.
/// Kayitlara bolge eklemek icin tek seferlik `requestLocation()` kullanilir.
@MainActor
@Observable
final class LocationService: NSObject {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isTracking = false
    private(set) var sessionDistanceMeters: Double
    private(set) var lastLocation: CLLocation?

    /// UI testlerinde (simulatorde izin diyalogu testleri kilitlemesin diye) kapatilir.
    let isEnabled: Bool

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private let geocoder = CLGeocoder()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastAcceptedLocation: CLLocation?
    @ObservationIgnored private var pendingStart = false
    @ObservationIgnored private var oneShotContinuations: [CheckedContinuation<CLLocation?, Never>] = []

    static let distanceKey = "workSessionDistanceMeters"

    init(isEnabled: Bool = true, defaults: UserDefaults = .standard) {
        let manager = CLLocationManager()
        self.manager = manager
        self.isEnabled = isEnabled
        self.defaults = defaults
        self.sessionDistanceMeters = defaults.double(forKey: Self.distanceKey)
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .otherNavigation
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25
        manager.pausesLocationUpdatesAutomatically = true
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var hasAlwaysAuthorization: Bool { authorizationStatus == .authorizedAlways }

    // MARK: - Izinler

    func requestWhenInUseAuthorization() {
        guard isEnabled else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// "Her zaman" izni. iOS once "Uygulamayi kullanirken" iznini ister; bu cagri yukseltme ister.
    func requestAlwaysAuthorization() {
        guard isEnabled else { return }
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestAlwaysAuthorization()
        }
    }

    // MARK: - Calisiyorum modu

    /// - Parameter resetDistance: Yeni oturumda true; uygulama yeniden acilip oturum devam ederken false.
    func startTracking(resetDistance: Bool) {
        guard isEnabled else { return }
        if resetDistance {
            sessionDistanceMeters = 0
            defaults.set(0.0, forKey: Self.distanceKey)
        }
        lastAcceptedLocation = nil

        switch authorizationStatus {
        case .notDetermined:
            pendingStart = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break // Izin reddedildi: sure tutulur, mesafe tutulmaz. Ayarlar ekrani yonlendirir.
        }
    }

    /// Takibi durdurur ve oturum mesafesini (km) dondurur.
    @discardableResult
    func stopTracking() -> Double {
        pendingStart = false
        if isTracking {
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            manager.showsBackgroundLocationIndicator = false
            isTracking = false
        }
        let km = sessionDistanceMeters / 1000
        sessionDistanceMeters = 0
        defaults.set(0.0, forKey: Self.distanceKey)
        return km
    }

    private func beginUpdates() {
        pendingStart = false
        // UIBackgroundModes=location oldugu icin, on planda baslatilan takip arka planda da surer.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        isTracking = true
    }

    // MARK: - Tek seferlik konum ve bolge

    func requestCurrentLocation() async -> CLLocation? {
        guard isEnabled else { return nil }
        if let last = lastLocation, Date.now.timeIntervalSince(last.timestamp) < 120 {
            return last
        }
        guard isAuthorized else {
            if authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
            return nil
        }
        return await withCheckedContinuation { continuation in
            oneShotContinuations.append(continuation)
            if oneShotContinuations.count == 1 {
                manager.requestLocation()
            }
        }
    }

    /// CLGeocoder ile reverse geocoding -> il / ilce / semt.
    func region(for location: CLLocation) async -> PlaceRegion? {
        guard isEnabled else { return nil }
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                location, preferredLocale: Locale(identifier: "tr_TR")
            )
            guard let place = placemarks.first else { return nil }
            return PlaceRegion(
                province: place.administrativeArea,
                district: place.subAdministrativeArea ?? place.locality,
                neighborhood: place.subLocality
            )
        } catch {
            return nil
        }
    }

    func currentRegion() async -> PlaceRegion? {
        guard let location = await requestCurrentLocation() else { return nil }
        return await region(for: location)
    }

    // MARK: - Delege islemleri (ana aktor)

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if pendingStart, status == .authorizedWhenInUse || status == .authorizedAlways {
            beginUpdates()
        } else if status == .denied || status == .restricted {
            pendingStart = false
            resumeOneShot(with: nil)
        }
    }

    fileprivate func handle(locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastLocation = latest
        resumeOneShot(with: latest)

        guard isTracking else { return }
        for location in locations {
            accumulateDistance(with: location)
        }
    }

    fileprivate func handleFailure() {
        resumeOneShot(with: nil)
    }

    /// Gurultulu konumlari eleyerek mesafe biriktirir.
    private func accumulateDistance(with location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 50 else { return }
        guard let previous = lastAcceptedLocation else {
            lastAcceptedLocation = location
            return
        }
        let meters = location.distance(from: previous)
        let seconds = location.timestamp.timeIntervalSince(previous.timestamp)
        guard seconds > 0 else { return }
        // 160 km/sa ustu siçramalar GPS hatasidir
        guard meters / seconds < 45 else { return }
        // Yerinde beklerken olusan titresimi sayma
        guard meters >= 10 else { return }

        sessionDistanceMeters += meters
        defaults.set(sessionDistanceMeters, forKey: Self.distanceKey)
        lastAcceptedLocation = location
    }

    private func resumeOneShot(with location: CLLocation?) {
        let continuations = oneShotContinuations
        oneShotContinuations.removeAll()
        continuations.forEach { $0.resume(returning: location) }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handleAuthorizationChange(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handle(locations: locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.handleFailure() }
    }
}
