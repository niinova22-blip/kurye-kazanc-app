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
///
/// Arka plan konum modu (UIBackgroundModes=location) YOKTUR (App Review 2.5.4): hassas GPS yalnizca
/// uygulama on plandayken gelir. Vardiya surerken uygulama arka plandayken km, "onemli konum
/// degisikligi" (~500 m) olaylariyla kabaca biriktirilir; on plana donunce GPS kaldigi yerden devam eder.
@MainActor
@Observable
final class LocationService: NSObject {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isTracking = false
    private(set) var sessionDistanceMeters: Double
    private(set) var lastLocation: CLLocation?
    private(set) var lastMovementDate: Date?
    private(set) var isMonitoringSignificantChanges = false
    /// Her konum olayinda (GPS veya onemli konum degisikligi) cagrilir: otomatik vardiya karari icin.
    @ObservationIgnored var onLocationEvent: (@MainActor () -> Void)?
    /// Konum izni degistiginde cagrilir: otomatik vardiya "Her zaman" yukseltmesini ister ve uyariyi gunceller.
    @ObservationIgnored var onAuthorizationChange: (@MainActor (CLAuthorizationStatus) -> Void)?
    /// Son anlamli hareketin olculdugu nokta (>= 50 m).
    @ObservationIgnored private var movementAnchor: CLLocation?

    /// UI testlerinde (simulatorde izin diyalogu testleri kilitlemesin diye) kapatilir.
    let isEnabled: Bool

    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private let geocoder = CLGeocoder()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastAcceptedLocation: CLLocation?
    @ObservationIgnored private var pendingStart = false
    @ObservationIgnored private var oneShotContinuations: [CheckedContinuation<CLLocation?, Never>] = []
    /// Onemli konum degisikligi izlemesini isteyenler: otomatik vardiya ve suren vardiya (arka planda kaba km).
    @ObservationIgnored private var autoShiftWantsSignificantChanges = false
    @ObservationIgnored private var trackingWantsSignificantChanges = false

    static let distanceKey = "workSessionDistanceMeters"

    init(isEnabled: Bool = true, defaults: UserDefaults = .standard) {
        let manager = CLLocationManager()
        self.manager = manager
        self.isEnabled = isEnabled
        self.defaults = defaults
        self.sessionDistanceMeters = defaults.double(forKey: Self.distanceKey)
        self.lastMovementDate = defaults.object(forKey: AppPreferences.lastMovementKey) as? Date
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
    /// - Parameter keepAliveWhenStationary: Otomatik vardiyada true: iOS durunca konumu duraklatmasin,
    ///   yoksa 20 dk duragan kalma hic olculemez (vardiya bitmez).
    func startTracking(resetDistance: Bool, keepAliveWhenStationary: Bool = false) {
        guard isEnabled else { return }
        if resetDistance {
            sessionDistanceMeters = 0
            defaults.set(0.0, forKey: Self.distanceKey)
        }
        lastAcceptedLocation = nil
        movementAnchor = nil
        manager.pausesLocationUpdatesAutomatically = !keepAliveWhenStationary
        // Yalnizca yeni vardiyada sifirla; devam ederken (uygulama yeniden acilinca) kayitli son hareket korunur,
        // yoksa 20 dk duragan sayaci her acilista basa doner.
        if resetDistance {
            markMovement(at: .now)
        }

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

    func markMovement(at date: Date) {
        lastMovementDate = date
        defaults.set(date, forKey: AppPreferences.lastMovementKey)
    }

    /// Otomatik mod: ~500 m'de bir uyandirir; uygulama kapaliysa iOS arka planda yeniden baslatir.
    func startSignificantChangeMonitoring() {
        autoShiftWantsSignificantChanges = true
        updateSignificantChangeMonitoring()
    }

    func stopSignificantChangeMonitoring() {
        autoShiftWantsSignificantChanges = false
        updateSignificantChangeMonitoring()
    }

    /// Otomatik vardiya ya da suren vardiya istiyorsa izler; ikisi de istemiyorsa durdurur.
    private func updateSignificantChangeMonitoring() {
        let wanted = autoShiftWantsSignificantChanges || trackingWantsSignificantChanges
        if wanted {
            guard isEnabled, !isMonitoringSignificantChanges,
                  CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
            manager.startMonitoringSignificantLocationChanges()
            isMonitoringSignificantChanges = true
        } else if isMonitoringSignificantChanges {
            manager.stopMonitoringSignificantLocationChanges()
            isMonitoringSignificantChanges = false
        }
    }

    /// Takibi durdurur ve oturum mesafesini (km) dondurur.
    @discardableResult
    func stopTracking() -> Double {
        pendingStart = false
        if isTracking {
            manager.stopUpdatingLocation()
            isTracking = false
        }
        trackingWantsSignificantChanges = false
        updateSignificantChangeMonitoring()
        manager.pausesLocationUpdatesAutomatically = true
        let km = sessionDistanceMeters / 1000
        sessionDistanceMeters = 0
        defaults.set(0.0, forKey: Self.distanceKey)
        return km
    }

    private func beginUpdates() {
        pendingStart = false
        // Arka plan konum modu yok: allowsBackgroundLocationUpdates true YAPILMAMALI (mod olmadan cokertir).
        // Hassas GPS on planda gelir; arka planda km onemli konum degisikligi olaylariyla kabaca surer.
        manager.startUpdatingLocation()
        isTracking = true
        trackingWantsSignificantChanges = true
        updateSignificantChangeMonitoring()
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
        onAuthorizationChange?(status)
    }

    fileprivate func handle(locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastLocation = latest
        resumeOneShot(with: latest)

        if isTracking {
            for location in locations {
                accumulateDistance(with: location)
                updateMovementAnchor(with: location)
            }
        }
        onLocationEvent?()
    }

    /// Hassas GPS noktasi (<= 50 m) mi?
    private static func isPrecise(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 50
    }

    /// Arka planda gelen kaba nokta (onemli konum degisikligi, ~100-1000 m dogruluk) ancak yer degistirme
    /// dogruluk payinin acikca ustundeyse kabul edilir; yoksa titresim km'ye eklenirdi.
    private static func isTrustedMove(to location: CLLocation, meters: Double) -> Bool {
        if isPrecise(location) { return true }
        let accuracy = location.horizontalAccuracy
        guard accuracy > 0, accuracy <= 1000 else { return false }
        return meters >= max(500, accuracy * 2)
    }

    /// 50 m'den fazla yer degistirme = anlamli hareket.
    private func updateMovementAnchor(with location: CLLocation) {
        guard let anchor = movementAnchor else {
            if Self.isPrecise(location) { movementAnchor = location }
            return
        }
        let meters = location.distance(from: anchor)
        guard Self.isTrustedMove(to: location, meters: meters) else { return }
        if meters >= 50 {
            movementAnchor = location
            markMovement(at: location.timestamp)
        }
    }

    fileprivate func handleFailure() {
        resumeOneShot(with: nil)
    }

    /// Gurultulu konumlari eleyerek mesafe biriktirir.
    private func accumulateDistance(with location: CLLocation) {
        guard let previous = lastAcceptedLocation else {
            if Self.isPrecise(location) { lastAcceptedLocation = location }
            return
        }
        let meters = location.distance(from: previous)
        guard Self.isTrustedMove(to: location, meters: meters) else { return }
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
