import Foundation

/// 1.12.3: vardiya surerken bolge ne zaman yeniden cozulur (ters geocoding). Kurye 1. bolgede baslayip 2. bolgeye
/// gecerse tarife bolgesi, vardiya ekrani, widget ve kilit ekrani guncellensin; ama geocoder'a her 25 m'de sorulmasin.
/// - Ilk konum: hemen.
/// - 500 m+ yer degistirme: en az 60 sn arayla (Apple geocoder dakikada ~1 istegi rahat karsilar).
/// - Bolge sinirinda yavas ilerleme: 10 dk gectiyse 100 m+ hareket yeter.
/// - Yer henuz cozulemedi (internet yok, geocoder hatasi): dakikada bir yeniden denenir.
struct RegionRefreshPolicy {
    var moveMeters: Double = 500
    var minimumGap: TimeInterval = 60
    var slowInterval: TimeInterval = 600
    var slowMoveMeters: Double = 100

    func shouldResolve(lastPoint: GeoPoint?, lastAt: Date?, point: GeoPoint, now: Date, hasPlace: Bool = true) -> Bool {
        guard let lastPoint, let lastAt else { return true }
        let elapsed: TimeInterval = now.timeIntervalSince(lastAt)
        let meters: Double = lastPoint.distanceKm(to: point) * 1000
        // Saat geri alindi: beklersek bolge uzun sure eski kalir
        if elapsed < 0 { return meters >= slowMoveMeters }
        guard elapsed >= minimumGap else { return false }
        if !hasPlace { return true }
        if meters >= moveMeters { return true }
        return elapsed >= slowInterval && meters >= slowMoveMeters
    }
}
