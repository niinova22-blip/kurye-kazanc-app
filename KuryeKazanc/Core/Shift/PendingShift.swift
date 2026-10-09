import Foundation

/// Kazanci henuz girilmemis, biten otomatik vardiya. Bolge metin olarak tutulur; koordinat saklanmaz.
struct PendingShift: Codable, Equatable, Identifiable {
    var id: UUID
    var start: Date
    var end: Date
    var distanceKm: Double
    var createdAt: Date
    var province: String?
    var district: String?
    var neighborhood: String?
}

enum PendingShiftList {
    static let maxCount = 5
    static let lifetime: TimeInterval = 86_400

    /// 24 saati gecenleri atar; en yeni once siralar ve en fazla 5 tutar.
    static func pruned(_ list: [PendingShift], now: Date) -> [PendingShift] {
        let fresh = list.filter { now.timeIntervalSince($0.createdAt) <= lifetime }
        let sorted = fresh.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(maxCount))
    }

    static func adding(_ shift: PendingShift, to list: [PendingShift], now: Date) -> [PendingShift] {
        pruned(list + [shift], now: now)
    }

    static func encode(_ list: [PendingShift]) -> Data {
        (try? JSONEncoder().encode(list)) ?? Data()
    }

    static func decode(_ data: Data?) -> [PendingShift] {
        guard let data, let list = try? JSONDecoder().decode([PendingShift].self, from: data) else { return [] }
        return list
    }
}
