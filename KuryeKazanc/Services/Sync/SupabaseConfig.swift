import Foundation

/// Supabase proje adresi ve anon anahtari (Info.plist). Anon anahtar gizli degildir; yetki RLS ile korunur.
struct SupabaseConfig: Equatable {
    let url: URL
    let anonKey: String

    static let urlKey: String = "SupabaseURL"
    static let anonKeyKey: String = "SupabaseAnonKey"

    /// Info.plist degerleri bos ya da gecersizse nil: sunucu kapali sayilir.
    static var fromBundle: SupabaseConfig? {
        let urlString: String = (Bundle.main.object(forInfoDictionaryKey: urlKey) as? String) ?? ""
        let key: String = (Bundle.main.object(forInfoDictionaryKey: anonKeyKey) as? String) ?? ""
        return SupabaseConfig(urlString: urlString, anonKey: key)
    }
}

extension SupabaseConfig {
    /// Uyeye ozel init uzantida: yapinin otomatik `init(url:anonKey:)` hali korunur.
    init?(urlString: String, anonKey: String) {
        let trimmedURL: String = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey: String = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedKey.isEmpty else { return nil }
        guard let parsed = URL(string: trimmedURL) else { return nil }
        // Yalnizca HTTPS: oturum anahtarlari duz metin baglantida gitmez.
        guard parsed.scheme?.lowercased() == "https" else { return nil }
        guard let host = parsed.host, !host.isEmpty else { return nil }
        self.init(url: parsed, anonKey: trimmedKey)
    }
}
