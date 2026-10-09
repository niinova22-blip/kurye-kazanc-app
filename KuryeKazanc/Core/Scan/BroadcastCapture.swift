import Foundation

/// Yayin eklentisinin kabul ettigi bir kazanc ekrani: yalnizca okunan satirlar (gorsel saklanmaz).
struct BroadcastCapture: Codable, Equatable {
    var capturedAt: Date
    var lines: [RecognizedLine]
}

/// Ayni ekrani tanimlayan deger anahtari: saat/durum cubugu degisse de ayni kalir.
struct CaptureKey: Hashable {
    var templateID: String
    var totalCents: Int
    var day: Date
    var period: OCRTemplate.Period

    /// Sablon taninmadiysa ya da toplam yoksa nil (kare sayilmaz).
    init?(parsed: ParsedEarning, calendar: Calendar) {
        guard let templateID = parsed.templateID, parsed.totalEarning > 0 else { return nil }
        self.templateID = templateID
        self.totalCents = Int((parsed.totalEarning * 100).rounded())
        self.day = calendar.startOfDay(for: parsed.date)
        self.period = parsed.period
    }
}
