import Foundation

// Canli vardiya: kurye her paketi biraktiginda ekrana dokunur. Her dokunus zaman + konumla saklanir; vardiya bitince
// paketler tarifenin zaman bandina (gunduz / aksam / gece) ve mesafe bandina gore ayrilip ayni motorla hesaplanir.

/// Ileride premium olacak; simdilik herkese acik. Kapatmak icin tek yer.
enum LiveShiftFeature {
    static let requiresPremium = false
}

/// Enlem / boylam (CoreLocation'dan bagimsiz; Windows'ta test edilir).
struct GeoPoint: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    /// Kus ucusu mesafe (haversine), km.
    func distanceKm(to other: GeoPoint) -> Double {
        let radius: Double = 6371.0
        let dLat: Double = (other.latitude - latitude) * .pi / 180
        let dLon: Double = (other.longitude - longitude) * .pi / 180
        let a: Double = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return radius * 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
    }
}

/// Tek teslimat (ekrana bir dokunus).
struct ShiftDelivery: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var at: Date
    var point: GeoPoint?
    /// Cikis noktasindan (vardiyanin basladigi yer, or. magaza) tahmini yol mesafesi: kus ucusu × yol katsayisi.
    var distanceKm: Decimal?
    var band: TimeBand
}

/// Suren vardiya. Uygulama kapanip acilsa da kaybolmasin diye cihazda JSON olarak saklanir.
struct LiveShift: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var platformCode: String
    var start: Date
    /// Cikis noktasi; ilk konum gelince doldurulur.
    var startPoint: GeoPoint?
    var province: String?
    var district: String?
    var deliveries: [ShiftDelivery] = []

    var packageCount: Int { deliveries.count }

    /// Kus ucusu mesafeyi yola cevirmek icin katsayi (sehir ici tipik sapma).
    static let roadFactor: Double = 1.3

    /// Yeni teslimat: bandi ve (cikis noktasi biliniyorsa) tahmini mesafesi hesaplanir.
    mutating func addDelivery(at date: Date, point: GeoPoint?, calendar: Calendar) -> ShiftDelivery {
        if startPoint == nil, deliveries.isEmpty, let point { startPoint = point }
        var distance: Decimal?
        if let point, let origin = startPoint, origin != point {
            let km: Double = origin.distanceKm(to: point) * LiveShift.roadFactor
            distance = Money.round(Decimal(km), scale: 1)
        }
        let delivery = ShiftDelivery(at: date, point: point, distanceKm: distance,
                                     band: ShiftClock.band(at: date, platform: platformCode, calendar: calendar))
        deliveries.append(delivery)
        return delivery
    }

    @discardableResult
    mutating func undoLast() -> ShiftDelivery? {
        deliveries.popLast()
    }
}

/// Paketin zaman bandi. Tarifede gece / aksam ucreti olan firmalarda saat sinirlari burada tanimlanir.
enum ShiftClock {
    /// Yemeksepeti 2026: 18:00 sonrasi (ve 08:00 oncesi) aksam / gece ucreti. Asil ucret gun ve saat bandindan
    /// (DeliverySlot) gelir; bu ayrim yalnizca ozet ve elle girisle uyum icin.
    static func band(at date: Date, platform: String, calendar: Calendar) -> TimeBand {
        let hour: Int = calendar.component(.hour, from: date)
        switch platform {
        case "yemeksepeti": return hour >= 18 || hour < 8 ? .night : .day
        default: return .day
        }
    }

    /// Bandin kullaniciya gosterilen adi.
    static func bandName(_ band: TimeBand, platform: String) -> String {
        switch band {
        case .night: platform == "yemeksepeti" ? "Akşam bandı" : "Gece bandı"
        case .day: "Gündüz bandı"
        case .any: "Paket"
        }
    }
}

/// Dokunustan hemen sonra gosterilen "bolge": paketin tarifede hangi ucrete girdigi.
struct DeliveryZone: Equatable {
    /// Or. "4–6 km bandı", "Akşam bandı".
    var title: String
    /// Or. "+25 TL ek ödeme", "Paket başı 67,50–78,50 TL".
    var detail: String
}

enum ShiftZones {
    static func zone(for delivery: ShiftDelivery, platform: String, version: TariffVersion?, day: String,
                     calendar: Calendar? = nil) -> DeliveryZone {
        guard let version else { return DeliveryZone(title: "Paket", detail: "Tarife bulunamadı") }
        let items: [TariffItem] = version.activeItems(on: day)
        let bands: [TariffItem] = items.filter { $0.method == .deliveryBand }
            .sorted { ($0.lowerThreshold ?? 0) < ($1.lowerThreshold ?? 0) }
        if !bands.isEmpty {
            guard let distance = delivery.distanceKm else {
                return DeliveryZone(title: "Mesafe ölçülemedi", detail: "Konum gelince mesafe bandı hesaplanır")
            }
            if let index = DeliveryBands.band(for: distance, in: bands) {
                let band: TariffItem = bands[index]
                return DeliveryZone(title: bandTitle(band), detail: "+\(Formatters.currency(band.amount.doubleValue)) ek ödeme · \(Formatters.decimalText(distance)) km")
            }
            let first: Decimal = bands.first?.lowerThreshold ?? 0
            return DeliveryZone(title: "0–\(Formatters.decimalText(first)) km",
                                detail: "Ek ödeme yok · \(Formatters.decimalText(distance)) km")
        }
        let singles: [TariffItem] = items.filter { $0.type == .singlePackage && $0.method == .perUnit }
        if singles.contains(where: { $0.conditions.hourFrom != nil }), let calendar {
            let weekday: Int = calendar.component(.weekday, from: delivery.at)
            let hour: Int = calendar.component(.hour, from: delivery.at)
            guard let match = singles.first(where: { $0.conditions.matches(weekday: weekday, hour: hour) }) else {
                return DeliveryZone(title: "Paket", detail: "Bu saat tarifede yok")
            }
            var amount: Money = match.amount
            var extras: [String] = []
            for extra in items where extra.type == .otherPayment && extra.method == .perUnit
                && extra.conditions.hourFrom != nil && extra.conditions.matches(weekday: weekday, hour: hour) {
                amount = amount + extra.amount
                extras.append("+\(Formatters.currency(extra.amount.doubleValue)) \(extra.label.lowercased())")
            }
            let from: Int = match.conditions.hourFrom ?? 0
            let to: Int = (match.conditions.hourTo ?? 24) - 1
            let title: String = String(format: "%02d:00–%02d:59 bandı", from, to)
            let detail: String = (["Paket başı \(Formatters.currency(amount.doubleValue))"] + extras).joined(separator: " · ")
            return DeliveryZone(title: title, detail: detail)
        }
        let hasNight: Bool = singles.contains { $0.conditions.timeBand == .night }
        let match: TariffItem? = singles.first { $0.conditions.timeBand == delivery.band }
            ?? singles.first { $0.conditions.timeBand == nil || $0.conditions.timeBand == .any }
            ?? singles.first
        let title: String = hasNight ? ShiftClock.bandName(delivery.band, platform: platform) : "Paket"
        guard let match else { return DeliveryZone(title: title, detail: "Aylık ücrete sayılır") }
        return DeliveryZone(title: title, detail: "Paket başı \(rateText(match))")
    }

    private static func bandTitle(_ band: TariffItem) -> String {
        let lower: String = Formatters.decimalText(band.lowerThreshold ?? 0)
        if let upper = band.upperThreshold { return "\(lower)–\(Formatters.decimalText(upper)) km bandı" }
        return "\(lower) km üstü bandı"
    }

    static func rateText(_ item: TariffItem) -> String {
        let low: String = Formatters.currency(item.amount.doubleValue)
        guard item.isRange, let upper = item.amountUpper else { return low }
        return "\(low)–\(Formatters.currency(upper.doubleValue))"
    }
}

/// Biten vardiyadan motor girdisi.
enum ShiftPayInput {
    /// - Parameters:
    ///   - gpsKm: Vardiya boyunca olculen toplam yol (yakit ve km ucreti icin). nil: olculemedi.
    ///   - version: Gece ucreti / mesafe bandi var mi diye bakilan tarife.
    static func make(shift: LiveShift, end: Date, gpsKm: Decimal?, base: PayInput, version: TariffVersion?,
                     calendar: Calendar = .current) -> PayInput {
        var input = base
        // Her paketin gunu ve saati: gun / saat bantli tarifede (Yemeksepeti) her paket kendi bandiyla
        var slots: [String: DeliverySlot] = [:]
        for delivery in shift.deliveries {
            let weekday: Int = calendar.component(.weekday, from: delivery.at)
            let hour: Int = calendar.component(.hour, from: delivery.at)
            slots["\(weekday).\(hour)", default: DeliverySlot(weekday: weekday, hour: hour, count: 0)].count += 1
        }
        input.deliverySlots = slots.values.sorted { ($0.weekday, $0.hour) < ($1.weekday, $1.hour) }
        let items: [TariffItem] = version?.activeItems(on: base.startDay) ?? []
        let hasNight: Bool = items.contains { $0.type == .singlePackage && $0.conditions.timeBand == .night }
        let night: Int = hasNight ? shift.deliveries.filter { $0.band == .night }.count : 0
        input.nightPackages = night
        input.dayPackages = shift.packageCount - night
        let usesBands: Bool = items.contains { $0.method == .deliveryBand }
        input.deliveryDistancesKm = usesBands ? shift.deliveries.compactMap(\.distanceKm).filter { $0 > 0 } : []
        if let gpsKm, gpsKm > 0 { input.totalKm = Money.round(gpsKm, scale: 1) }
        let seconds: Double = max(0, end.timeIntervalSince(shift.start))
        input.hours = Money.round(Decimal(seconds / 3600), scale: 2)
        return input
    }
}
