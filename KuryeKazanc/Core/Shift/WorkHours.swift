import Foundation

/// Otomatik vardiyanin baslayabilecegi saatler (yerel saat). Aralik gece yarisini gecebilir (09:00-01:00).
struct WorkHours: Equatable, Codable {
    var isAlways: Bool
    /// Gun icindeki dakika (0-1439).
    var startMinute: Int
    var endMinute: Int

    static let standard = WorkHours(isAlways: false, startMinute: 9 * 60, endMinute: 60)

    /// Baslangic dahil, bitis haric. Baslangic == bitis ise tum gun.
    func contains(_ date: Date, calendar: Calendar) -> Bool {
        if isAlways || startMinute == endMinute { return true }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute < endMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data?) -> WorkHours {
        guard let data, let value = try? JSONDecoder().decode(WorkHours.self, from: data) else { return .standard }
        return value
    }
}
