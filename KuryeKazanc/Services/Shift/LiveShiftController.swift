import Foundation
import CoreLocation
import Observation
import SwiftData
import UserNotifications

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
    /// 1.12: widget / bildirimden "vardiya ekranini ac" istegi; Bugun ekrani tuketir.
    var presentationRequested = false

    @ObservationIgnored private let autoShift: AutoShiftCoordinator
    @ObservationIgnored private let workSession: WorkSessionManager
    @ObservationIgnored private let location: LocationService
    @ObservationIgnored private let payroll: PayrollModel
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let clock: () -> Date
    /// Otomatik bitiste kayit icin (uygulama arka planda olabilir, gorunum yok).
    @ObservationIgnored var contextProvider: (() -> ModelContext?)?

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
        autoShift.liveShiftChanged()
        Task { await locateStart() }
    }

    /// 1.12: otomatik vardiya basladi; paketler kilit ekranindan sayilabilsin diye canli vardiya da baslar.
    func startFromAutoShift() {
        guard shift == nil else { return }
        start()
    }

    /// Kilit ekrani / widget "+1 paket": vardiya yoksa once baslatir. Donus: yeni paket sayisi.
    @discardableResult
    func addPackageFromOutside() -> Int? {
        if shift == nil { start() }
        return recordDelivery()?.count
    }

    /// Widget "Vardiya": vardiya yoksa baslatir ve canli vardiya ekraninin acilmasini ister.
    func openFromWidget() {
        if shift == nil { start() }
        if shift != nil { presentationRequested = true }
    }

    /// Canli Etkinlik icin anlik durum.
    func activitySnapshot() -> (packages: Int, gross: Double, region: String?)? {
        guard let shift else { return nil }
        let gross: Double = liveEstimate()?.gross.doubleValue ?? 0
        let region: String = WidgetPublisher.regionText(place: shift.district ?? shift.province, tier: payroll.state.regionTier)
        return (shift.packageCount, gross, region.isEmpty ? nil : region)
    }

    /// Otomatik vardiya 20 dk duraganlikla bitti. Paket varsa vardiya hesaplanip kaydedilir (true), yoksa canli vardiya
    /// kapanir ve normal "Vardiya bitti" akisi surer (false).
    func handleAutoShiftFinished(_ summary: WorkSessionSummary) -> Bool {
        guard let current = shift else { return false }
        defer { clear() }
        guard current.packageCount > 0, let context = contextProvider?(),
              let input = input(end: summary.end, km: summary.distanceKm) else { return false }
        let log: WorkLog? = payroll.save(input, method: .shift, start: current.start, end: summary.end,
                                          recordKm: summary.distanceKm, context: context)
        guard let log else { return false }
        let gross: String = " · brüt \(PayFormat.tl(log.result.gross))"
        let content = UNMutableNotificationContent()
        content.title = "Vardiya bitti, kaydedildi"
        content.body = "\(current.packageCount) paket\(gross). 20 dakikadır durduğun için vardiya kendiliğinden kapandı."
        content.sound = AppSounds.notificationSound
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "shift.autoSaved.\(current.start.timeIntervalSince1970)",
                                                                     content: content, trigger: nil))
        return true
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
        autoShift.liveShiftChanged()
        guard let profile = payroll.tariffProfile,
              let suggestion = RegionResolver.suggest(province: place.province, district: place.district,
                                                      neighborhood: place.neighborhood, profile: profile) else { return }
        payroll.applyRegion(suggestion)
        regionMessage = suggestion.message
        needsRegionChoice = suggestion.needsRegionChoice
    }

    func chooseRegion(_ tier: String) {
        payroll.setRegionTier(tier)
        needsRegionChoice = false
        regionMessage = "\(TariffQuestions.regionName(tier)) ücreti kullanılıyor."
    }

    /// Konumdan bulunamazsa sorulacak bolgeler (tarifedeki).
    var regionChoices: [String] {
        payroll.questions(for: platformCode).regionTiers
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
                                                 day: payroll.day(now), calendar: calendar)
        let feedback = ShiftTapFeedback(id: delivery.id, zone: zone, count: current.packageCount)
        lastFeedback = feedback
        autoShift.liveShiftChanged()
        return feedback
    }

    func undoLast() {
        guard var current = shift, current.undoLast() != nil else { return }
        shift = current
        persist()
        lastFeedback = nil
        autoShift.liveShiftChanged()
    }

    // MARK: - Canli tahmin ve bitis

    private var currentVersion: TariffVersion? {
        payroll.currentVersion(platform: platformCode)
    }

    private func input(end: Date, km: Double?) -> PayInput? {
        guard let shift, let base = payroll.baseInput(day: payroll.day(shift.start)) else { return nil }
        return ShiftPayInput.make(shift: shift, end: end, gpsKm: km.map { Decimal($0) }, base: base, version: currentVersion,
                                  calendar: calendar)
    }

    /// Su ana kadarki paketlerle hesap (motor ayni; kayit yapilmaz).
    func liveEstimate() -> PayBreakdown? {
        // 1.12.1: bugunun diger kayitlariyla birlikte (gunluk prim kademesi gunun toplamina gore); deger bu vardiyanin payi
        guard let input = input(end: clock(), km: workSession.sessionDistanceKm),
              case let .success(result) = payroll.dayShare(input) else { return nil }
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

    /// Otomatik vardiya iptal edildi (vardiya altyapisi zaten kapandi): yalnizca paket durumu silinir.
    func dropAfterAutoCancel() {
        guard shift != nil else { return }
        clear()
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
        publishWidget()
    }

    /// Widget: suren vardiyanin paketleri ve bolgesi (kilit ekranindan +1'de uygulama acilmadan da guncellenir).
    private func publishWidget() {
        let current: LiveShift? = shift
        let tier: String? = payroll.state.regionTier
        let firm: String = payroll.tariffProfile.map { PayrollModel.platformName($0.platformCode) } ?? ""
        WidgetPublisher.publish { snapshot in
            snapshot.isShiftActive = current != nil
            snapshot.shiftPackages = current?.packageCount ?? 0
            snapshot.shiftStart = current?.start
            if !firm.isEmpty { snapshot.firm = firm }
            if let current {
                snapshot.region = WidgetPublisher.regionText(place: current.district ?? current.province, tier: tier)
            }
        }
    }
}

extension GeoPoint {
    init(_ location: CLLocation) {
        self.init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}
