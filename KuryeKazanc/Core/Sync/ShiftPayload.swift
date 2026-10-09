import Foundation

/// Sunucuya giden vardiya (spec 3). Kisi/konum bilgisi yok: il/ilce, hafta gunu, 15 dk dilim, yuvarlanmis km.
struct ShiftPayload: Codable, Equatable {
    var clientRecordID: String
    var platformCode: String
    var province: String?
    var district: String?
    var vehicle: String
    var weekday: Int
    var startSlot: Int
    var durationMin: Int
    var gross: Double
    var bonus: Double
    var packages: Int?
    var distanceKm: Double
    var level: String
    var templateID: String?
    var templateVersion: Int?
    var textHash: String

    enum CodingKeys: String, CodingKey {
        case clientRecordID = "client_record_id"
        case platformCode = "platform_code"
        case province, district, vehicle, weekday
        case startSlot = "start_slot"
        case durationMin = "duration_min"
        case gross, bonus, packages
        case distanceKm = "distance_km"
        case level
        case templateID = "template_id"
        case templateVersion = "template_version"
        case textHash = "text_hash"
    }
}

enum ShiftPayloadBuilder {
    static let sendableLevels: Set<String> = ["verified", "ocrUnverified"]

    static func make(
        recordID: UUID, platformCode: String?, province: String?, district: String?, vehicle: String,
        start: Date, end: Date, gross: Double, bonus: Double, packages: Int?, distanceKm: Double,
        level: String, templateID: String?, templateVersion: Int?, textHash: String, calendar: Calendar
    ) -> ShiftPayload? {
        guard sendableLevels.contains(level) else { return nil }
        guard let platformCode, platformCode != "other", !platformCode.isEmpty else { return nil }
        guard !textHash.isEmpty, end > start else { return nil }

        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: start)
        // Pazartesi = 1 ... Pazar = 7
        let weekday = ((parts.weekday ?? 2) + 5) % 7 + 1
        let slot = (parts.hour ?? 0) * 4 + (parts.minute ?? 0) / 15
        let minutes = Int((end.timeIntervalSince(start) / 60).rounded())
        let roundedKm = (max(0, distanceKm) * 2).rounded() / 2

        return ShiftPayload(
            clientRecordID: recordID.uuidString.lowercased(), platformCode: platformCode,
            province: province, district: district, vehicle: vehicle, weekday: weekday, startSlot: slot,
            durationMin: minutes, gross: gross, bonus: bonus, packages: packages, distanceKm: roundedKm,
            level: level, templateID: templateID, templateVersion: templateVersion, textHash: textHash
        )
    }
}
