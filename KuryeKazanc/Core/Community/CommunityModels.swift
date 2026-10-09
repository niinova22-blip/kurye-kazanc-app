import Foundation

/// Ilce isi haritasi hucresi (sunucu `community_heatmap`). weekday: 1 = Pazartesi ... 7 = Pazar.
struct CommunityCell: Codable, Equatable {
    var weekday: Int
    var hour: Int
    var perHour: Double
    var couriers: Int
    var shifts: Int

    enum CodingKeys: String, CodingKey {
        case weekday, hour, couriers, shifts
        case perHour = "per_hour"
    }
}

struct CommunityPlatformStat: Codable, Equatable {
    var code: String
    var perHour: Double?
    var perPackage: Double?
    var couriers: Int

    enum CodingKeys: String, CodingKey {
        case code, couriers
        case perHour = "per_hour"
        case perPackage = "per_package"
    }
}

/// Sunucu `community_summary`. `perHour`/`couriers` ilcede 5'ten az kurye varsa yoktur.
struct CommunitySummary: Codable, Equatable {
    var perHour: Double?
    var couriers: Int?
    var platforms: [CommunityPlatformStat]
    var best: [CommunityCell]

    enum CodingKeys: String, CodingKey {
        case couriers, platforms, best
        case perHour = "per_hour"
    }

    init(perHour: Double?, couriers: Int?, platforms: [CommunityPlatformStat], best: [CommunityCell]) {
        self.perHour = perHour
        self.couriers = couriers
        self.platforms = platforms
        self.best = best
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        perHour = try c.decodeIfPresent(Double.self, forKey: .perHour)
        couriers = try c.decodeIfPresent(Int.self, forKey: .couriers)
        platforms = try c.decodeIfPresent([CommunityPlatformStat].self, forKey: .platforms) ?? []
        best = try c.decodeIfPresent([CommunityCell].self, forKey: .best) ?? []
    }

    /// Ilcede gosterilecek ortalama yok (en az 5 kurye gerekir).
    var isInsufficient: Bool { perHour == nil }
}

/// Kendi ₺/saat'in ilce ortalamasiyla karsilastirmasi. Sunucu brut+bonus ile hesapladigi icin ayni olcu kullanilir.
enum CommunityComparison {
    /// (brut + bonus) / birlesik calisma saati; sure yoksa nil.
    static func ownPerHour(_ entries: [EarningEntry]) -> Double? {
        let intervals: [(start: Date, end: Date)] = entries.map { (start: $0.start, end: $0.end) }
        let hours: Double = EarningsCalculator.mergedDuration(of: intervals) / 3600
        guard hours > 0 else { return nil }
        let total: Double = entries.reduce(0) { $0 + $1.gross + $1.bonus }
        return total / hours
    }

    /// Yuzde fark (+ ustunde, - altinda); ilce degeri 0 ise nil.
    static func percentDifference(own: Double, community: Double) -> Double? {
        guard community > 0 else { return nil }
        return (own - community) / community * 100
    }
}
