import Foundation

/// 1.12.2: gunluk / haftalik / aylik toplam paket ve o toplama bagli prim / bonus durumu.
///
/// Firmaya gore:
/// - Paket Taxi (Restoran / Migros / Migros Hemen): gunluk prim GUNUN toplam paketine gore tek kademe (Restoran'da
///   "21. paketten itibaren" paket primi), aylik bonus AYIN toplamina gore tek kademe; haftalik bonus yok (sayac bilgi icin).
/// - Yemeksepeti: gunluk bonus gunun toplamina, haftalik bonus haftanin (Pzt–Paz) toplamina gore; aylik bonus yok.
/// Tutarlar motorun kendisinden (ayni tarife, ayni uygunluk kurallari) okunur; burada kural tekrar yazilmaz.
struct BonusTrack: Equatable, Identifiable {
    enum Scope: String, CaseIterable {
        case day, week, month

        var unit: TariffUnit {
            switch self {
            case .day: .day
            case .week: .week
            case .month: .month
            }
        }

        var title: String {
            switch self {
            case .day: "Bugün"
            case .week: "Bu hafta"
            case .month: "Bu ay"
            }
        }
    }

    var scope: Scope
    var packages: Int
    /// Bu toplamla su an hak edilen prim / bonus (yoksa sifir).
    var reached: Money
    /// Ulasilan kademenin adi ("Günlük 24–27 paket primi").
    var reachedLabel: String?
    /// Siradaki kademe.
    var next: BonusProgress?
    /// Bu donemde firmanin bu sayaca bagli primi var mi (yoksa yalnizca sayac gosterilir).
    var hasBonus: Bool

    var id: String { scope.rawValue }
}

enum BonusTracker {
    /// Firmanin hangi donemlerde sayac tutmasi gerektigi: Yemeksepeti'nde aylik yok.
    static func scopes(platform: String) -> [BonusTrack.Scope] {
        platform == "yemeksepeti" ? [.day, .week] : [.day, .week, .month]
    }

    /// - Parameters:
    ///   - base: Kayitli tercihlerle doldurulmus girdi (bolge, kidem, calisma saati, isaretler).
    ///   - counts: Donem toplam paketleri (suren vardiya dahil).
    static func tracks(engine: PayEngine, version: TariffVersion, base: PayInput, day: String,
                       counts: [BonusTrack.Scope: Int]) -> [BonusTrack] {
        scopes(platform: base.platformCode).map { scope in
            let packages: Int = counts[scope] ?? 0
            let hasBonus: Bool = version.activeItems(on: day).contains { isTracked(scope: scope, item: $0) }
            guard hasBonus else {
                return BonusTrack(scope: scope, packages: packages, reached: .zero, reachedLabel: nil, next: nil, hasBonus: false)
            }
            var input = base
            input.span = scope == .day ? .day : (scope == .week ? .week : .month)
            input.startDay = day
            input.endDay = day
            input.dayPackages = packages
            input.nightPackages = 0
            input.combinedPackages = 0
            input.periodPackages = scope == .day ? nil : packages
            input.deliveryDistancesKm = []
            input.deliverySlots = []
            input.totalKm = nil
            input.workDays = scope == .day ? nil : 1
            guard case let .success(result) = engine.calculate(input, version: version) else {
                return BonusTrack(scope: scope, packages: packages, reached: .zero, reachedLabel: nil, next: nil, hasBonus: true)
            }
            let itemsByID: [String: TariffItem] = Dictionary(version.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let lines: [PayLine] = result.lines.filter { line in
                guard line.included, line.isCash, let id = line.itemID, let item = itemsByID[id] else { return false }
                return isTracked(scope: scope, item: item)
            }
            let reached: Money = lines.map(\.low).sum()
            let label: String? = lines.count == 1 ? lines[0].label : (lines.isEmpty ? nil : lines.map(\.label).joined(separator: " + "))
            let next: BonusProgress? = result.progress.first { $0.unit == scope.unit && $0.target > packages }
            return BonusTrack(scope: scope, packages: packages, reached: reached, reachedLabel: label, next: next, hasBonus: true)
        }
    }

    /// Kalem bu sayaca bagli bir prim / bonus mu: gunluk / haftalik / aylik kademe ya da gunluk esikli paket primi.
    static func isTracked(scope: BonusTrack.Scope, item: TariffItem) -> Bool {
        switch scope {
        case .day:
            return (item.method == .tier && item.unit == .day) || item.method == .dailyPackageRate
        case .week:
            return item.method == .tier && item.unit == .week && item.conditions.weekdays == nil
        case .month:
            return (item.method == .tier && item.unit == .month) || (item.type.isBonus && item.unit == .month)
        }
    }
}
