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

    /// Suren vardiyanin paketleri gun gun (gece yarisini gecen vardiyada iki gun).
    func packagesByDay() -> [String: Int] {
        guard let shift else { return [:] }
        var result: [String: Int] = [:]
        for delivery in shift.deliveries { result[payroll.day(delivery.at), default: 0] += 1 }
        return result
    }

    /// Suren vardiyanin bugune dusen paketleri.
    var packagesToday: Int { packagesByDay()[payroll.day(clock())] ?? 0 }
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
        let gross: Double = liveShiftGross()?.doubleValue ?? 0
        let region: String = WidgetPublisher.regionText(place: shift.district ?? shift.province, tier: payroll.state.regionTier)
        return (shift.packageCount, gross, region.isEmpty ? nil : region)
    }

    /// Otomatik vardiya 20 dk duraganlikla bitti. Paket varsa vardiya hesaplanip kaydedilir (true), yoksa canli vardiya
    /// kapanir ve normal "Vardiya bitti" akisi surer (false).
    func handleAutoShiftFinished(_ summary: WorkSessionSummary) -> Bool {
        guard let current = shift else { return false }
        defer { clear() }
        guard current.packageCount > 0, let context = contextProvider?() else { return false }
        let saved = saveParts(dayParts(end: summary.end, km: summary.distanceKm), context: context)
        guard saved.last != nil else { return false }
        let gross: String = " · brüt \(PayFormat.tl(saved.gross))"
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

    /// 1.12.2 gun dongusu: vardiya takvim gunlerine bolunur (gece yarisini gecen paketler ertesi gunun primine).
    private func dayParts(end: Date, km: Double?) -> [ShiftPayInput.DayPart] {
        guard let shift, let base = payroll.baseInput(day: payroll.day(shift.start)) else { return [] }
        return ShiftPayInput.makeByDay(shift: shift, end: end, gpsKm: km.map { Decimal($0) }, base: base,
                                       version: currentVersion, calendar: calendar)
    }

    /// Gun parcalarini ayri kayit olarak kaydeder (her biri kendi gununun diger vardiyalariyla paylastirilir).
    private func saveParts(_ parts: [ShiftPayInput.DayPart], context: ModelContext) -> (last: WorkLog?, gross: Money) {
        var last: WorkLog?
        var gross: Money = .zero
        for part in parts {
            let km: Double? = part.input.totalKm.map { NSDecimalNumber(decimal: $0).doubleValue }
            if let log = payroll.save(part.input, method: .shift, start: part.start, end: part.end, recordKm: km, context: context) {
                last = log
                gross = gross + log.result.gross
            }
        }
        return (last, gross)
    }

    /// Bugune dusen kisim (bugunun diger kayitlariyla birlikte; deger bu vardiyanin bugunku payi). Bugun ekrani kullanir.
    func liveEstimate() -> PayBreakdown? {
        let today: String = payroll.day(clock())
        guard let part = dayParts(end: clock(), km: workSession.sessionDistanceKm).last(where: { $0.day == today }),
              case let .success(result) = payroll.dayShare(part.input) else { return nil }
        return result
    }

    /// Vardiyanin tamami (gece yarisini gectiyse iki gunun paylari toplami): vardiya ekrani ve kilit ekrani.
    func liveShiftGross() -> Money? {
        let parts = dayParts(end: clock(), km: workSession.sessionDistanceKm)
        guard !parts.isEmpty else { return nil }
        var total: Money = .zero
        for part in parts {
            guard case let .success(result) = payroll.dayShare(part.input) else { return nil }
            total = total + result.gross
        }
        return total
    }

    var liveDistanceKm: Double { workSession.sessionDistanceKm }

    /// Vardiyayi bitirir, otomatik hesaplayip kaydeder. Paket yoksa kayit yapilmaz (nil).
    func finish(context: ModelContext) -> WorkLog? {
        guard let current = shift else { return nil }
        let summary: WorkSessionSummary? = autoShift.endShift()
        let end: Date = summary?.end ?? clock()
        let km: Double? = summary?.distanceKm
        defer { clear() }
        guard current.packageCount > 0 else { return nil }
        return saveParts(dayParts(end: end, km: km), context: context).last
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
