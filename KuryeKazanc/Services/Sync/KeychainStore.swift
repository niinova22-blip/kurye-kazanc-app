import Foundation
import Security

/// Supabase oturumu (GoTrue). Sure `expires_in` saniyesinden hesaplanir: clock() + expires_in.
struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: String
    var isAnonymous: Bool
}

/// Oturumun kalici saklandigi yer. `save(nil)` oturumu siler.
protocol SessionStore {
    func load() -> AuthSession?
    func save(_ s: AuthSession?)
}

/// Oturumu Keychain'de tutar. AfterFirstUnlock: uygulama arka planda uyandiginda da okunabilir.
final class KeychainStore: SessionStore {
    static let defaultService: String = "com.kuryekazanc.app.session"
    private static let account: String = "session"

    private let service: String

    init(service: String = KeychainStore.defaultService) {
        self.service = service
    }

    func load() -> AuthSession? {
        var query: [String: Any] = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ s: AuthSession?) {
        // Once eskiyi sil; sonra (varsa) yenisini ekle. Ekleme/guncelleme ayrimi gerekmez.
        _ = SecItemDelete(baseQuery() as CFDictionary)
        guard let session = s else { return }
        guard let data = try? JSONEncoder().encode(session) else { return }
        var attributes: [String: Any] = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        _ = SecItemAdd(attributes as CFDictionary, nil)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: KeychainStore.account,
        ]
    }
}
