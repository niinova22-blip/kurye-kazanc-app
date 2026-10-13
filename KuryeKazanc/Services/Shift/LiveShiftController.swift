import Foundation
import CoreLocation
import Observation
import SwiftData

/// Dokunustan hemen sonra gosterilen geri bildirim: "4–6 km bandı · 1 paket eklendi".
struct ShiftTapFeedback: Equatable, Identifiable {
    var id: UUID
    var zone: DeliveryZone
    var count: Int
}

/// Canli vardiya: "Vardiya başlat" -> her teslimde ekrana dokunma -> "Vardiyayı bitir" (otomatik hesap ve kayit).
/// Sure ve km mevcut vardiya altyapisiyla (WorkSessionManager + Canli Etkinlik) olculur; paketler zaman ve konumla
/// saklanir. Suren vardiya UserDefaults'ta JSON olarak durur: uygulama kapansa da paketler kaybolmaz.
@MainActor
@Observable
final class LiveShiftController {
    private(set) var shift: LiveShift?
    private(set) var lastFeedback: ShiftTapFeedback?
    /// Konumdan bolge degisikligi ("İzmir: haftalık bonus hesaba katıldı").
    private(set) var regionMessage: String?
    /// Paket Taxi Istanbul / Ankara: Plus mi standart mi kullanicidan secilmeli.
    private(set) var needsRegionChoice = false

    @ObservationIgnored private let autoShift: AutoShiftCoordinator
    @ObservationIgnored private let workSession: WorkSessionManager
    @ObservationIgnored private let location: LocationService
    @ObservationIgnored private let payroll: PayrollModel
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let clock: () -> Date

    init(autoShift: AutoShiftCoordinator, workSession: WorkSessionManager, location: LocationService, payroll: PayrollModel,
         defaults: UserDefaults = .standard, calendar: Calendar = .current, clock: @escaping () -> Date = { Date() }) {
        self.autoShift = autoShift
        self.workSession = workSession
        self.location = location
        self.payroll = payroll
        self.defaults = defaults
        self.calendar = calendar
        self.clock = clock
        if let data = defaults.data(forKey: AppPreferences.liveShiftKey),
           let saved = try? JSONDecoder().decode(LiveShift.self, from: data) {
            shift = saved
        }
        // Vardiya altyapisi kapanmissa (or. cihaz yeniden basladi) paketler korunur, olcum yeniden baslar
        if shift != nil, !workSession.isWorking { autoShift.startManualShift() }
    }

    var isActive: Bool { shift != nil }
    var packageCount: Int { shift?.packageCount ?? 0 }

    var platformCode: String { shift?.platformCode ?? payroll.tariffProfile?.platformCode ?? "" }

    // MARK: - Baslat

    func start() {
        guard shift == nil, let code = payroll.tariffProfile?.platformCode else { return }
        if location.authorizationStatus == .notDetermined { location.requestWhenInUseAuthorization() }
        if !workSession.isWorking { autoShift.startManualShift() }
        shift = LiveShift(platformCode: code, start: workSession.sessionStart ?? clock())
        lastFeedback = nil
        regionMessage = nil
        needsRegionChoice = false
        persist()
        Task { await locateStart() }
    }

    /// Cikis noktasi ve il: bolgeye bagli tarife secimleri konumdan yapilir.
    private func locateStart() async {
        guard let here = await location.requestCurrentLocation() else { return }
        if shift?.startPoint == nil, shift?.deliveries.isEmpty == true {
            shift?.startPoint = GeoPoint(here)
            persist()
        }
        guard let place = await location.region(for: here) else { return }
        shift?.province = place.province
        shift?.district = place.district
        persist()
        guard let profile = payroll.tariffProfile,
              let suggestion = RegionResolver.suggest(province: place.province, profile: profile) else { return }
        payroll.applyRegion(suggestion)
        regionMessage = suggestion.message
        needsRegionChoice = suggestion.needsRegionChoice
    }

    func chooseRegion(_ tier: String) {
        payroll.setRegionTier(tier)
        needsRegionChoice = false
        regionMessage = tier == "plus" ? "Plus bölge ücreti kullanılıyor." : "Standart bölge ücreti kullanılıyor."
    }

    // MARK: - Teslimat

    /// Paket birakildi: zaman + (son 5 dakikadaki) konum kaydedilir, paketin tarifedeki bandi dondurulur.
    @discardableResult
    func recordDelivery() -> ShiftTapFeedback? {
        guard var current = shift else { return nil }
        let now: Date = clock()
        var point: GeoPoint?
        if let last = location.lastLocation, now.timeIntervalSince(last.timestamp) < 300 { point = GeoPoint(last) }
        let delivery: ShiftDelivery = current.addDelivery(at: now, point: point, calendar: calendar)
        shift = current
        persist()
        let zone: DeliveryZone = ShiftZones.zone(for: delivery, platform: current.platformCode, version: currentVersion,
                                                 day: payroll.day(now))
        let feedback = ShiftTapFeedback(id: delivery.id, zone: zone, count: current.packageCount)
        lastFeedback = feedback
        return feedback
    }

    func undoLast() {
        guard var current = shift, current.undoLast() != nil else { return }
        shift = current
        persist()
        lastFeedback = nil
    }

    // MARK: - Canli tahmin ve bitis

    private var currentVersion: TariffVersion? {
        payroll.currentVersion(platform: platformCode)
    }

    private func input(end: Date, km: Double?) -> PayInput? {
        guard let shift, let base = payroll.baseInput(day: payroll.day(shift.start)) else { return nil }
        return ShiftPayInput.make(shift: shift, end: end, gpsKm: km.map { Decimal($0) }, base: base, version: currentVersion)
    }

    /// Su ana kadarki paketlerle hesap (motor ayni; kayit yapilmaz).
    func liveEstimate() -> PayBreakdown? {
        guard let input = input(end: clock(), km: workSession.sessionDistanceKm),
              case let .success(result) = payroll.calculate(input) else { return nil }
        return result
    }

    var liveDistanceKm: Double { workSession.sessionDistanceKm }

    /// Vardiyayi bitirir, otomatik hesaplayip kaydeder. Paket yoksa kayit yapilmaz (nil).
    func finish(context: ModelContext) -> WorkLog? {
        guard let current = shift else { return nil }
        let summary: WorkSessionSummary? = autoShift.endShift()
        let end: Date = summary?.end ?? clock()
        let km: Double? = summary?.distanceKm
        defer { clear() }
        guard current.packageCount > 0, let input = input(end: end, km: km) else { return nil }
        return payroll.save(input, method: .shift, start: current.start, end: end, recordKm: km, context: context)
    }

    /// Yanlislikla baslayan vardiya: kayit yapilmadan kapatilir.
    func discard() {
        guard shift != nil else { return }
        _ = autoShift.endShift()
        clear()
    }

    private func clear() {
        shift = nil
        lastFeedback = nil
        regionMessage = nil
        needsRegionChoice = false
        persist()
    }

    private func persist() {
        if let shift, let data = try? JSONEncoder().encode(shift) {
            defaults.set(data, forKey: AppPreferences.liveShiftKey)
        } else {
            defaults.removeObject(forKey: AppPreferences.liveShiftKey)
        }
    }
}

extension GeoPoint {
    init(_ location: CLLocation) {
        self.init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}
