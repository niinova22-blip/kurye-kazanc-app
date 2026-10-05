import Foundation
import SwiftData

/// Tek bir calisma vardiyasi / platform icin kazanc kaydi.
///
/// Anonim paylasima uygun tasarim:
/// - Kisiye ozgu hicbir alan (isim, telefon, Courier iliskisi) yok.
/// - Ham GPS koordinati SAKLANMAZ; yalnizca il/ilce/semt seviyesinde bolge tutulur.
/// - `anonymousDeviceID`: cihazda uretilmis rastgele UUID (bkz. `AnonymousDeviceID`). V1'de hicbir yere gonderilmez.
@Model
final class EarningRecord {
    @Attribute(.unique) var id: UUID
    var anonymousDeviceID: UUID

    /// Kaydin ait oldugu gun (gun baslangicina normalize edilir).
    var date: Date
    var startTime: Date
    var endTime: Date

    var platform: Platform?

    // Bolge (CLGeocoder reverse geocoding ile otomatik doldurulur)
    var province: String?      // il
    var district: String?      // ilce
    var neighborhood: String?  // semt / mahalle

    var grossEarning: Double
    var bonus: Double
    var distanceKm: Double
    /// Paket/siparis sayisi (OCR ile okunabiliyor; opsiyonel).
    var packageCount: Int?

    var sourceRaw: String
    var createdAt: Date

    var source: EarningSource {
        get { EarningSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /// Duzenlemede baslangic/bitis degisince gun alanini da gunceller.
    func updateInterval(start: Date, end: Date, calendar: Calendar = .current) {
        startTime = start
        endTime = end
        date = calendar.startOfDay(for: start)
    }

    /// Calisma suresi (saniye). Bitis baslangictan once ise 0.
    var duration: TimeInterval { max(0, endTime.timeIntervalSince(startTime)) }

    /// Brut + bonus.
    var totalEarning: Double { grossEarning + bonus }

    init(
        id: UUID = UUID(),
        anonymousDeviceID: UUID = AnonymousDeviceID.current,
        startTime: Date,
        endTime: Date,
        platform: Platform? = nil,
        province: String? = nil,
        district: String? = nil,
        neighborhood: String? = nil,
        grossEarning: Double,
        bonus: Double = 0,
        distanceKm: Double = 0,
        packageCount: Int? = nil,
        source: EarningSource = .manual,
        createdAt: Date = .now,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.anonymousDeviceID = anonymousDeviceID
        self.date = calendar.startOfDay(for: startTime)
        self.startTime = startTime
        self.endTime = endTime
        self.platform = platform
        self.province = province
        self.district = district
        self.neighborhood = neighborhood
        self.grossEarning = grossEarning
        self.bonus = bonus
        self.distanceKm = distanceKm
        self.packageCount = packageCount
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
    }
}
