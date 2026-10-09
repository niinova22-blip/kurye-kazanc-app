import Foundation

/// Tahminin dayandigi veri. Ustteki daha ozeldir.
enum ForecastBasis: String, Equatable {
    /// Ayni hafta gunu ve saat.
    case weekdayHour
    /// Ayni saat, tum gunler.
    case hour
    /// Platformdaki tum kayitlar.
    case platform
    /// Kayit yok; kullanicinin girdigi platform ucreti.
    case offeredRate

    var displayName: String {
        switch self {
        case .weekdayHour: "aynı gün ve saatteki kayıtların"
        case .hour: "aynı saatteki kayıtların"
        case .platform: "platformdaki tüm kayıtların"
        case .offeredRate: "girdiğin platform ücretinin"
        }
    }
}

/// Bir platformda bir saatlik calismanin tahmini (brut + bonus, TL/saat).
struct HourForecast: Equatable {
    var low: Double
    var mid: Double
    var high: Double
    var kmPerHour: Double
    var packagesPerHour: Double?
    var samples: Int
    var basis: ForecastBasis
}

/// Kullanicinin kendi kayitlarindan tahmin. Tarife uydurmaz: kayit ya da kullanici ucreti yoksa nil.
struct EarningsForecaster {
    var calendar: Calendar
    var lookbackWeeks: Int = 8
    var minSamples: Int = 3
    /// Bir kaydin bir saate sayilmasi icin o saatle en az bu kadar dakika ortusmesi gerekir.
    var minOverlapMinutes: Double = 15

    private struct Sample {
        var rate: Double
        var kmPerHour: Double
        var packagesPerHour: Double?
        var slots: Set<HourSlot>
    }

    /// Pazartesi = 1 ... Pazar = 7.
    func weekday(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    func forecast(entries: [EarningEntry], platform: String, day: Date, hour: Int, offeredRate: Double? = nil) -> HourForecast? {
        let samples = self.samples(entries: entries, platform: platform, day: day)
        let targetWeekday = weekday(of: day)
        let levels: [(ForecastBasis, (Sample) -> Bool)] = [
            (.weekdayHour, { $0.slots.contains(HourSlot(weekday: targetWeekday, hour: hour)) }),
            (.hour, { $0.slots.contains { $0.hour == hour } }),
            (.platform, { _ in true }),
        ]
        for (basis, filter) in levels {
            let chosen = samples.filter(filter)
            if chosen.count >= minSamples { return make(chosen, basis: basis) }
        }
        if let offeredRate, offeredRate > 0 {
            return HourForecast(low: offeredRate, mid: offeredRate, high: offeredRate, kmPerHour: 0,
                                packagesPerHour: nil, samples: 0, basis: .offeredRate)
        }
        return nil
    }

    /// Platformdaki son `lookbackWeeks` haftanin (plan gunu haric) kayit sayisi.
    func sampleCount(entries: [EarningEntry], platform: String, day: Date) -> Int {
        samples(entries: entries, platform: platform, day: day).count
    }

    private func samples(entries: [EarningEntry], platform: String, day: Date) -> [Sample] {
        let dayStart = calendar.startOfDay(for: day)
        guard let windowStart = calendar.date(byAdding: .day, value: -7 * lookbackWeeks, to: dayStart) else { return [] }
        return entries.compactMap { entry -> Sample? in
            guard (entry.platformCode ?? "other") == platform,
                  entry.start >= windowStart, entry.start < dayStart else { return nil }
            let hours = entry.end.timeIntervalSince(entry.start) / 3600
            guard hours >= minOverlapMinutes / 60 else { return nil }
            let packages = entry.packageCount.map { Double($0) / hours }
            return Sample(
                rate: (entry.gross + entry.bonus) / hours,
                kmPerHour: max(0, entry.distanceKm) / hours,
                packagesPerHour: packages,
                slots: slots(of: entry)
            )
        }
    }

    private func slots(of entry: EarningEntry) -> Set<HourSlot> {
        var result: Set<HourSlot> = []
        var cursor = entry.start
        while cursor < entry.end {
            let hourStart = calendar.dateInterval(of: .hour, for: cursor)?.start ?? cursor
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? entry.end
            let segmentEnd = min(hourEnd, entry.end)
            if segmentEnd.timeIntervalSince(cursor) / 60 >= minOverlapMinutes {
                result.insert(HourSlot(weekday: weekday(of: cursor), hour: calendar.component(.hour, from: cursor)))
            }
            cursor = segmentEnd
        }
        return result
    }

    private func make(_ samples: [Sample], basis: ForecastBasis) -> HourForecast {
        let rates = samples.map(\.rate).sorted()
        let packages = samples.compactMap(\.packagesPerHour)
        return HourForecast(
            low: Self.percentile(rates, 0.25),
            mid: Self.percentile(rates, 0.5),
            high: Self.percentile(rates, 0.75),
            kmPerHour: samples.map(\.kmPerHour).reduce(0, +) / Double(samples.count),
            packagesPerHour: packages.isEmpty ? nil : packages.reduce(0, +) / Double(packages.count),
            samples: samples.count,
            basis: basis
        )
    }

    /// Dogrusal aradegerli yuzdelik; `sorted` sirali ve bos degil.
    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard sorted.count > 1 else { return sorted.first ?? 0 }
        let position = p * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }
}
