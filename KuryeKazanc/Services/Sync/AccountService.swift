import Foundation
import Observation
import SwiftData

/// Hesap islemleri hatalari.
enum AccountError: Error, Equatable {
    /// Sunucu ayari yok (`SupabaseConfig` eksik): hesap ozellikleri kapali.
    case serverUnavailable
    /// Hesapta yedek yok.
    case noBackup
    /// Yedekleme veya "Verilerimi sil" suruyor.
    case busy
}

extension AccountError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .serverUnavailable:
            return "Hesap özellikleri bu sürümde kullanılamıyor."
        case .noBackup:
            return "Bu hesapta yedek bulunamadı."
        case .busy:
            return "Yedekleme veya silme sürüyor, biraz sonra tekrar dene."
        }
    }
}

/// Apple ile Giris, yedekleme/geri yukleme ve "Verilerimi sil" (spec 4, 6).
///
/// Apple akisi: `makeNonce()` -> `hashed` Apple istegine (`ASAuthorizationAppleIDRequest.nonce`),
/// `raw` + Apple'in dondurdugu id_token `completeAppleSignIn` ile Supabase'e gider.
///
/// Riza kuyrugu: `syncCoordinator` istege bagli bagimlilik (Gorev 8 baglar). Verilirse
/// "Verilerimi sil" rizalari kapattiktan sonra onun `...ConsentChanged(enabled: false)` metotlarini
/// cagirir ve bekleyen gonderimler silinir. Testlerde gercek `SyncCoordinator` + sahte istemci verilir.
@MainActor
@Observable
final class AccountService {
    /// Otomatik yedek en fazla bu siklikta.
    static let autoBackupInterval: TimeInterval = 24 * 60 * 60

    private(set) var isSignedInWithApple: Bool
    private(set) var lastBackupDate: Date?
    /// Yedekleme / geri yukleme suruyor (arayuz dugmeleri kilitlenir).
    private(set) var isBusy: Bool = false

    private let client: (any SupabaseServing)?
    private let defaults: UserDefaults
    private let syncCoordinator: SyncCoordinator?
    private let clock: () -> Date
    @ObservationIgnored private var isBackingUp: Bool = false
    /// "Verilerimi sil" basladi ve henuz basariyla bitmedi (yalnizca bellekte). Bu surede yedek
    /// alinmaz: silinmesi istenen veri sunucuya yeniden yazilmasin. Yalnizca basarida temizlenir.
    @ObservationIgnored private var isDeletePending: Bool = false

    init(
        client: (any SupabaseServing)?,
        defaults: UserDefaults = .standard,
        syncCoordinator: SyncCoordinator? = nil,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.client = client
        self.defaults = defaults
        self.syncCoordinator = syncCoordinator
        self.clock = clock
        self.isSignedInWithApple = AccountService.isApple(client?.session)
        if let seconds = defaults.object(forKey: AppPreferences.lastBackupDateKey) as? Double {
            self.lastBackupDate = Date(timeIntervalSince1970: seconds)
        } else {
            self.lastBackupDate = nil
        }
    }

    // MARK: - Apple ile Giris

    /// 32 rastgele bayt -> base64url (`raw`); Apple'a `hashed` (SHA-256 hex) verilir.
    func makeNonce() -> (raw: String, hashed: String) {
        var generator = SystemRandomNumberGenerator()
        let bytes: [UInt8] = (0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
        let raw: String = AccountService.base64URL(bytes)
        return (raw, SHA256.hex(raw))
    }

    /// Supabase'e ham nonce gider (sunucu hash'leyip id_token'daki ile karsilastirir).
    func completeAppleSignIn(idToken: String, rawNonce: String) async throws {
        guard let client else { throw AccountError.serverUnavailable }
        defer { refreshSessionState() }
        _ = try await client.signInWithApple(idToken: idToken, nonce: rawNonce)
    }

    /// Yalnizca yerel oturum silinir; sonraki gonderimde yeni anonim oturum acilir.
    func signOut() {
        client?.signOut()
        clearBackupDate()
        refreshSessionState()
    }

    // MARK: - Yedek

    /// Tum kazanc/gider + tercihler sunucuya. Apple ile girisli degilse `.notSignedIn`.
    func backupNow(context: ModelContext) async throws {
        guard let client else { throw AccountError.serverUnavailable }
        guard !isDeletePending else { throw AccountError.busy }
        refreshSessionState()
        guard isSignedInWithApple else { throw SupabaseError.notSignedIn }
        // Otomatik ve elle yedek ust uste binmesin; ikincisi sessizce biter.
        guard !isBackingUp else { return }
        isBackingUp = true
        isBusy = true
        defer {
            isBackingUp = false
            isBusy = false
            refreshSessionState()
        }
        let now: Date = clock()
        let payload: BackupPayload = try BackupService.makePayload(context: context, defaults: defaults, now: now)
        let data: Data = try BackupService.encode(payload)
        try await client.uploadBackup(data)
        setBackupDate(now)
    }

    /// Kayit kaydedildikten sonra (Gorev 8): Apple ile girisliyse ve son yedekten 24 saat
    /// gectiyse yedekler. Hata sessizce yutulur (bir sonraki kayitta tekrar denenir).
    /// Yedek tabani (`lastBackupDate`) yoksa otomatik yedek ALINMAZ: sunucuda tek satir yedek var ve
    /// yukleme onu degistirir. Yeni telefonda geri yuklemeden once kaydedilen tek vardiya ya da
    /// "Tum kayitlari sil" sonrasi bos veri tam yedegi ezmesin. Taban: elle yedek veya geri yukleme.
    func backupIfDue(context: ModelContext) async {
        guard client != nil, !isDeletePending, lastBackupDate != nil else { return }
        refreshSessionState()
        guard isSignedInWithApple, isBackupDue else { return }
        try? await backupNow(context: context)
    }

    /// Taban yoksa false (otomatik yedek elle ilk yedekten / geri yuklemeden sonra baslar).
    var isBackupDue: Bool {
        guard let lastBackupDate else { return false }
        let elapsed: TimeInterval = clock().timeIntervalSince(lastBackupDate)
        // Saat geri alinmissa (elapsed < 0) beklemeden yedeklenir.
        return elapsed < 0 || elapsed >= AccountService.autoBackupInterval
    }

    /// Sunucudaki yedegi indirip birlestirir (id'si mevcut kayit atlanir).
    func restore(context: ModelContext, platforms: [Platform]) async throws -> (added: Int, skipped: Int) {
        guard let client else { throw AccountError.serverUnavailable }
        refreshSessionState()
        guard isSignedInWithApple else { throw SupabaseError.notSignedIn }
        isBusy = true
        defer {
            isBusy = false
            refreshSessionState()
        }
        guard let data = try await client.downloadBackup() else { throw AccountError.noBackup }
        // Sunucu jsonb'yi yeniden kodlar: bayt karsilastirma yok, cozulur.
        let payload: BackupPayload = try BackupService.decode(data)
        let result: (added: Int, skipped: Int) = try BackupService.restore(
            payload, into: context, platforms: platforms, defaults: defaults
        )
        // Yerel veri artik yedegi kapsiyor: otomatik yedek bu andan itibaren guvenli.
        setBackupDate(clock())
        return result
    }

    /// Profil > "Tum kayitlari sil" sonrasi: taban silinir; bos veri otomatik yedekle sunucudaki
    /// yedegi ezmesin. Kullanici isterse "Simdi yedekle" ile bilerek yedekler.
    func localRecordsCleared() {
        clearBackupDate()
    }

    // MARK: - Verilerimi sil

    /// Sirasi: (0) yedek suruyorsa `.busy`, (1) paylasim/konum/kalibrasyon rizalari kapatilir ve kuyruk bosaltilir (yerel, her zaman),
    /// (2) sunucuda `delete_my_data` (oturum varsa), (3) cikis.
    /// Sunucu cagrisi basarisizsa hata firlatilir ve oturum KORUNUR: kullanici tekrar deneyebilsin
    /// (cikis yapilsaydi o kimligin verisine bir daha ulasilamazdi).
    /// `context`: yerel kayitlar bilerek SILINMEZ (Profil'deki "Tum kayitlari sil" ayri); imza
    /// arayuzle uyumlu kalsin diye alinir.
    /// Yedek yukleniyorsa `.busy` (yukleme silmeden sonra bitip veriyi geri yazmasin).
    func deleteMyData(context: ModelContext) async throws {
        guard !isBackingUp else { throw AccountError.busy }
        isDeletePending = true
        revokeConsents()
        if let client {
            try await client.deleteMyData()
        }
        signOut()
        isDeletePending = false
    }

    /// Riza anahtarlari ONCE yazilir; koordinator kuyrugu bu degerlere gore bosaltir.
    private func revokeConsents() {
        defaults.set(false, forKey: AppPreferences.dataSharingOptInKey)
        defaults.set(0.0, forKey: AppPreferences.dataSharingConsentDateKey)
        defaults.set(false, forKey: AppPreferences.locationSharingOptInKey)
        defaults.set(0.0, forKey: AppPreferences.locationSharingConsentDateKey)
        defaults.set(false, forKey: AppPreferences.calibrationOptInKey)
        syncCoordinator?.sharingConsentChanged(enabled: false)
        syncCoordinator?.calibrationConsentChanged(enabled: false)
    }

    // MARK: - Yardimcilar

    /// `client.session` gozlenebilir degil: her cagridan sonra yeniden okunur.
    private func refreshSessionState() {
        let signedIn: Bool = AccountService.isApple(client?.session)
        if signedIn != isSignedInWithApple {
            isSignedInWithApple = signedIn
        }
    }

    private func setBackupDate(_ date: Date) {
        lastBackupDate = date
        defaults.set(date.timeIntervalSince1970, forKey: AppPreferences.lastBackupDateKey)
    }

    private func clearBackupDate() {
        lastBackupDate = nil
        defaults.removeObject(forKey: AppPreferences.lastBackupDateKey)
    }

    private static func isApple(_ session: AuthSession?) -> Bool {
        guard let session else { return false }
        return !session.isAnonymous
    }

    static func base64URL(_ bytes: [UInt8]) -> String {
        Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
