import Foundation

/// Iki kare kurali: bir ekran art arda iki karede ayni anahtarla okunursa kabul edilir (kaydirma
/// sirasindaki yarim kareler elenir). Kabul edilen anahtar tarama boyunca bir kez doner.
struct StableCaptureFilter {
    private(set) var accepted: Set<CaptureKey> = []
    private var previous: CaptureKey?
    private var seenOnce: Set<CaptureKey> = []
    /// Kabul edilmis ekranin yeniden okunma sayisi.
    private(set) var duplicateCount = 0

    /// Tek karede gorulup hic onaylanmayan farkli ekran sayisi (kacmis olabilir).
    var unconfirmedCount: Int { seenOnce.count }

    mutating func offer(_ key: CaptureKey?) -> CaptureKey? {
        defer { previous = key }
        guard let key else { return nil }
        if accepted.contains(key) {
            duplicateCount += 1
            return nil
        }
        if key == previous {
            accepted.insert(key)
            seenOnce.remove(key)
            return key
        }
        seenOnce.insert(key)
        return nil
    }
}
