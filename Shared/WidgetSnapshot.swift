import Foundation

/// 1.12: widget'in gosterdigi bugunku ozet. Uygulama App Group'a yazar, KuryeLiveActivity eklentisi okur.
/// Iki kaynak ayri alanlari gunceller: Bugun ekrani kayitli paketleri / neti / hedefi / bolgeyi,
/// canli vardiya ise suren vardiyanin paketlerini (kilit ekranindan +1 uygulama acilmadan da yazilir).
struct WidgetSnapshot: Codable, Equatable {
    /// "yyyy-MM-dd" (yerel). Baska gunse kayitli degerler sifir sayilir.
    var day: String = ""
    /// Bugun kaydedilmis paketler (suren vardiya haric).
    var savedPackages: Int = 0
    var todayNet: Double = 0
    /// Bugunku paket hedefi (plan yoksa 0).
    var targetPackages: Int = 0
    /// "İstanbul · 1. bölge" gibi.
    var region: String = ""
    var firm: String = ""
    var isShiftActive: Bool = false
    var shiftPackages: Int = 0
    var shiftStart: Date?
    /// 1.14: canli vardiya Pro'da; true ise widget +1 yerine uygulamayi acar (satin alma ekrani). Eski kayitlarda nil.
    var shiftLocked: Bool?

    static let suiteName = "group.com.kuryekazanc.app"
    static let key = "widget.snapshot.v1"

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Bugunku toplam paket (kayitli + suren vardiya).
    func packages(now: Date = Date()) -> Int {
        let saved: Int = day == Self.dayKey(now) ? savedPackages : 0
        return saved + (isShiftActive ? shiftPackages : 0)
    }

    func fraction(now: Date = Date()) -> Double {
        guard targetPackages > 0, day == Self.dayKey(now) else { return 0 }
        return min(1, Double(packages(now: now)) / Double(targetPackages))
    }

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snapshot
    }

    /// Yukle -> degistir -> yaz. Degisiklik yoksa false (widget yeniden cizilmez).
    @discardableResult
    static func update(_ change: (inout WidgetSnapshot) -> Void) -> Bool {
        let old: WidgetSnapshot = load()
        var new: WidgetSnapshot = old
        change(&new)
        guard new != old, let data = try? JSONEncoder().encode(new) else { return false }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: key)
        return true
    }
}
