import Foundation

/// Haftanin gunu (1 = Pazartesi ... 7 = Pazar) ve saat (0-23).
struct HourSlot: Hashable, Comparable {
    var weekday: Int
    var hour: Int

    static func < (lhs: HourSlot, rhs: HourSlot) -> Bool {
        (lhs.weekday, lhs.hour) < (rhs.weekday, rhs.hour)
    }
}

struct SlotStat: Equatable {
    var minutes: Double
    /// Kayit toplami - km x km basi maliyet, dilimdeki sureye orantili pay.
    var estimatedNet: Double

    var netPerHour: Double? {
        minutes > 0 ? estimatedNet / (minutes / 60) : nil
    }
}

/// Siralanmis dilim (en iyi saatler).
struct RankedSlot: Equatable {
    var slot: HourSlot
    var stat: SlotStat
}

struct PlatformStat: Equatable, Identifiable {
    var platformCode: String
    var total: Double
    var hours: Double
    var packages: Int
    var distanceKm: Double
    var estimatedNet: Double

    var id: String { platformCode }
    var netPerHour: Double? { hours > 0 ? estimatedNet / hours : nil }
    var netPerPackage: Double? { packages > 0 ? estimatedNet / Double(packages) : nil }
    var netPerKm: Double? { distanceKm > 0 ? estimatedNet / distanceKm : nil }
}

/// Kisisel analizler. Manuel giderler kayda baglanamadigindan dilimlere dagitilmaz; sonuclar "tahmini net"tir.
struct EarningsAnalytics {
    var calendar: Calendar
    var costPerKm: Double

    private func estimatedNet(_ entry: EarningEntry) -> Double {
        entry.gross + entry.bonus - max(0, entry.distanceKm) * max(0, costPerKm)
    }

    /// Pazartesi = 1 ... Pazar = 7 (takvimin firstWeekday ayarindan bagimsiz).
    private func weekday(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    func heatmap(_ entries: [EarningEntry]) -> [HourSlot: SlotStat] {
        var result: [HourSlot: SlotStat] = [:]
        for entry in entries where entry.end > entry.start {
            let totalMinutes = entry.end.timeIntervalSince(entry.start) / 60
            let net = estimatedNet(entry)
            var cursor = entry.start
            while cursor < entry.end {
                let hourStart = calendar.dateInterval(of: .hour, for: cursor)?.start ?? cursor
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? entry.end
                let segmentEnd = min(hourEnd, entry.end)
                let minutes = segmentEnd.timeIntervalSince(cursor) / 60
                let slot = HourSlot(weekday: weekday(of: cursor), hour: calendar.component(.hour, from: cursor))
                var stat = result[slot] ?? SlotStat(minutes: 0, estimatedNet: 0)
                stat.minutes += minutes
                stat.estimatedNet += net * minutes / totalMinutes
                result[slot] = stat
                cursor = segmentEnd
            }
        }
        return result
    }

    func topSlots(_ entries: [EarningEntry], limit: Int = 3, minimumMinutes: Double = 60) -> [RankedSlot] {
        Array(
            heatmap(entries)
                .filter { $0.value.minutes >= minimumMinutes }
                .map { RankedSlot(slot: $0.key, stat: $0.value) }
                .sorted { ($0.stat.netPerHour ?? 0) > ($1.stat.netPerHour ?? 0) }
                .prefix(limit)
        )
    }

    func platformStats(_ entries: [EarningEntry]) -> [PlatformStat] {
        // Derleyicinin tip cikarimi zaman asimina ugramasin diye adim adim
        let groups: [String: [EarningEntry]] = Dictionary(grouping: entries) { $0.platformCode ?? "other" }
        var stats: [PlatformStat] = []
        for (code, items) in groups {
            var total = 0.0
            var packages = 0
            var distance = 0.0
            var net = 0.0
            for item in items {
                total += item.gross + item.bonus
                packages += item.packageCount ?? 0
                distance += max(0, item.distanceKm)
                net += estimatedNet(item)
            }
            let intervals: [(start: Date, end: Date)] = items.map { (start: $0.start, end: $0.end) }
            let hours = EarningsCalculator.mergedDuration(of: intervals) / 3600
            stats.append(PlatformStat(
                platformCode: code, total: total, hours: hours, packages: packages,
                distanceKm: distance, estimatedNet: net
            ))
        }
        return stats.sorted { $0.total > $1.total }
    }

    /// Yuzde degisim; onceki donem 0 ise nil ("—").
    static func percentChange(current: Double, previous: Double) -> Double? {
        guard previous != 0 else { return nil }
        return (current - previous) / abs(previous) * 100
    }
}
