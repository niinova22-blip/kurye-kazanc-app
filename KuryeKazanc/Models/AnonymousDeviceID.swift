import Foundation

/// Cihazda bir kez uretilen rastgele UUID.
///
/// - Kullanici kimligiyle, Apple ID ile, IDFA/IDFV ile hicbir baglantisi yoktur.
/// - Bilerek Keychain yerine UserDefaults'ta tutulur: uygulama silinip yuklenince yeni UUID uretilir,
///   boylece uzun vadeli izlenebilirlik olusmaz.
/// - V1'de bu deger hicbir sunucuya gonderilmez; yalnizca kayitlara eklenir ki ileride
///   (kullanici acik onay verirse) anonim istatistik havuzuna kolayca aktarilabilsin.
enum AnonymousDeviceID {
    static let storageKey = "anonymousDeviceID"

    static var current: UUID { current(in: .standard) }

    static func current(in defaults: UserDefaults) -> UUID {
        if let stored = defaults.string(forKey: storageKey), let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let new = UUID()
        defaults.set(new.uuidString, forKey: storageKey)
        return new
    }
}
