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
///
/// Emekli kimlikler: Apple girisi ya da cikisla birakilan oturumlar. "Verilerimi sil" bu kimliklerle
/// gonderilmis veriyi de silebilsin diye yenileme anahtarlariyla saklanir.
protocol SessionStore {
    func load() -> AuthSession?
    func save(_ s: AuthSession?)
    func loadRetired() -> [AuthSession]
    func saveRetired(_ list: [AuthSession])
}

/// Oturumu Keychain'de tutar. AfterFirstUnlockThisDeviceOnly: uygulama arka planda uyandiginda da
/// okunabilir; yedekle baska cihaza tasinmaz.
final class KeychainStore: SessionStore {
    static let defaultService: String = "com.kuryekazanc.app.session"
    private static let account: String = "session"
    private static let retiredAccount: String = "retired"

    private let service: String

    init(service: String = KeychainStore.defaultService) {
        self.service = service
    }

    func load() -> AuthSession? {
        guard let data = read(account: KeychainStore.account) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ s: AuthSession?) {
        guard let session = s else {
            write(nil, account: KeychainStore.account)
            return
        }
        guard let data = try? JSONEncoder().encode(session) else { return }
        write(data, account: KeychainStore.account)
    }

    func loadRetired() -> [AuthSession] {
        guard let data = read(account: KeychainStore.retiredAccount) else { return [] }
        return (try? JSONDecoder().decode([AuthSession].self, from: data)) ?? []
    }

    /// Bos liste kaydi siler.
    func saveRetired(_ list: [AuthSession]) {
        guard !list.isEmpty else {
            write(nil, account: KeychainStore.retiredAccount)
            return
        }
        guard let data = try? JSONEncoder().encode(list) else { return }
        write(data, account: KeychainStore.retiredAccount)
    }

    // MARK: - Keychain

    private func read(account: String) -> Data? {
        var query: [String: Any] = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    /// nil: kaydi siler. Aksi halde once gunceller; kayit yoksa ekler (silip eklemekten farkli olarak
    /// arada kayitsiz bir an olusmaz).
    private func write(_ data: Data?, account: String) {
        guard let data else {
            _ = SecItemDelete(baseQuery(account: account) as CFDictionary)
            return
        }
        let changes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus: OSStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, changes as CFDictionary)
        guard updateStatus == errSecItemNotFound else { return }
        var attributes: [String: Any] = baseQuery(account: account)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(attributes as CFDictionary, nil)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
