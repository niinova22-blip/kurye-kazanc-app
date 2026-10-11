import Foundation

/// Sunucu islemleri. Ana aktorde calisir: oturum durumu tek yerden, sirali degisir.
@MainActor
protocol SupabaseServing {
    func submitShift(_ p: ShiftPayload) async -> OutboxResult
    func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult
    func fetchTemplates() async -> [OCRTemplate]?
    func fetchPlatformRules() async -> [PlatformRule]?
    func fetchTariffVersions() async -> [TariffVersion]?
    func fetchTariffEvents(platform: String) async -> [TariffChangeEvent]?
    func communityHeatmap(province: String, district: String) async -> [CommunityCell]?
    func communitySummary(province: String, district: String) async -> CommunitySummary?
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
    func uploadBackup(_ payload: Data) async throws
    func downloadBackup() async throws -> Data?
    func deleteMyData() async throws
    func signOut()
    var session: AuthSession? { get }
}

extension SupabaseServing {
    /// Varsayilan: kural yok (test istemcileri icin). Gercek istemci sunucudan ceker.
    func fetchPlatformRules() async -> [PlatformRule]? { nil }
    /// Varsayilan: tarife yok (test istemcileri). Uygulama gomulu ornek tarifeyle calisir.
    func fetchTariffVersions() async -> [TariffVersion]? { nil }
    func fetchTariffEvents(platform: String) async -> [TariffChangeEvent]? { nil }
}

/// Elle yazilmis kucuk Supabase REST istemcisi (GoTrue + PostgREST). Ucuncu taraf bagimlilik yok.
@MainActor
final class SupabaseClient: SupabaseServing {
    /// Sure bu kadar saniye icinde dolacaksa istekten once yenilenir.
    static let refreshMargin: TimeInterval = 60
    /// Bu durumlarda RPC sonucu gecici sayilir (tekrar denenir); diger 4xx kalici `.invalid`.
    static let transientStatuses: Set<Int> = [401, 403, 404, 408, 425, 429]
    /// Yalnizca bu yanitlar "yenileme anahtari olu" demektir; digerlerinde (429, 5xx, ag) oturum korunur.
    static let refreshRejectedStatuses: Set<Int> = [400, 401, 403]

    private struct HTTPResult {
        let status: Int
        let body: Data

        var isSuccess: Bool { (200..<300).contains(status) }
    }

    private let config: SupabaseConfig
    private let store: SessionStore
    private let transport: URLSession
    private let clock: () -> Date
    private let encoder: JSONEncoder = JSONEncoder()
    private let decoder: JSONDecoder = JSONDecoder()

    private(set) var session: AuthSession?
    /// Ayni anda gelen cagrilar tek bir yenileme/kayit islemini paylasir.
    private var pendingAuth: Task<AuthSession, Error>?
    /// Cikis ve Apple girisinde artar; eski donemde baslamis yenileme sonucunu yazamaz.
    private var authEpoch: Int = 0

    init(
        config: SupabaseConfig,
        store: SessionStore,
        transport: URLSession = .shared,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.config = config
        self.store = store
        self.transport = transport
        self.clock = clock
        self.session = store.load()
    }

    // MARK: - Gonderim

    func submitShift(_ p: ShiftPayload) async -> OutboxResult {
        let body: Data
        do {
            body = try encoder.encode(RPCBody(payload: p))
        } catch {
            return .invalid
        }
        return await callOutboxRPC("submit_shift", body: body)
    }

    func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult {
        let payload = CalibrationBody(platformCode: platformCode, templateID: templateID, lines: lines)
        let body: Data
        do {
            body = try encoder.encode(RPCBody(payload: payload))
        } catch {
            return .invalid
        }
        return await callOutboxRPC("submit_calibration", body: body)
    }

    /// Sablonlar herkese acik: oturum gerekmez (yalnizca apikey). Hata durumunda nil.
    func fetchTemplates() async -> [OCRTemplate]? {
        let query: [URLQueryItem] = [URLQueryItem(name: "select", value: "body")]
        let request: URLRequest = makeRequest(method: "GET", path: "rest/v1/ocr_templates", query: query)
        guard let result = try? await perform(request), result.isSuccess else { return nil }
        guard let rows = try? decoder.decode([TemplateRow].self, from: result.body) else { return nil }
        return rows.compactMap { $0.body }
    }

    /// Planlama kurallari herkese acik: oturum gerekmez. Bozuk satir atlanir; istek basarisizsa nil.
    func fetchPlatformRules() async -> [PlatformRule]? {
        let query: [URLQueryItem] = [URLQueryItem(name: "select", value: "*")]
        let request: URLRequest = makeRequest(method: "GET", path: "rest/v1/platform_rules", query: query)
        guard let result = try? await perform(request), result.isSuccess else { return nil }
        guard let rows = try? decoder.decode([LossyRule].self, from: result.body) else { return nil }
        return rows.compactMap(\.rule)
    }

    // MARK: - Hakedis tarifeleri

    /// Yayindaki tarife surumleri ve kalemleri (herkese acik; RLS yalnizca yayimlanmis / suresi dolmus surumleri dondurur).
    /// Bozuk satir atlanir; istek basarisizsa nil (uygulama son bilinen / gomulu tarifeyle devam eder).
    func fetchTariffVersions() async -> [TariffVersion]? {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "*,items:tariff_items(*)"),
            URLQueryItem(name: "approval_status", value: "in.(published,expired)"),
        ]
        let request: URLRequest = makeRequest(method: "GET", path: "rest/v1/tariff_versions", query: query)
        guard let result = try? await perform(request), result.isSuccess else { return nil }
        guard let rows = try? decoder.decode([LossyTariffVersion].self, from: result.body) else { return nil }
        return rows.compactMap(\.version)
    }

    /// Bir platformun son tarife olaylari (yayim / geri cekme). Yalnizca istenen platform sorgulanir.
    func fetchTariffEvents(platform: String) async -> [TariffChangeEvent]? {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "platform_id", value: "eq.\(platform)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "30"),
        ]
        let request: URLRequest = makeRequest(method: "GET", path: "rest/v1/tariff_change_events", query: query)
        guard let result = try? await perform(request), result.isSuccess else { return nil }
        guard let rows = try? decoder.decode([LossyTariffEvent].self, from: result.body) else { return nil }
        return rows.compactMap(\.event)
    }

    // MARK: - Topluluk

    /// Ilce isi haritasi (oturum gerekir; anonim oturum olur). Hata durumunda nil.
    func communityHeatmap(province: String, district: String) async -> [CommunityCell]? {
        await communityRPC("community_heatmap", province: province, district: district, as: [CommunityCell].self)
    }

    /// Ilce ozeti (oturum gerekir). Hata durumunda nil.
    func communitySummary(province: String, district: String) async -> CommunitySummary? {
        await communityRPC("community_summary", province: province, district: district, as: CommunitySummary.self)
    }

    private func communityRPC<T: Decodable>(_ name: String, province: String, district: String, as type: T.Type) async -> T? {
        guard let body = try? encoder.encode(CommunityBody(province: province, district: district)) else { return nil }
        let path: String = "rest/v1/rpc/\(name)"
        let result: HTTPResult
        do {
            result = try await sendAuthorized(allowSignup: true) { current in
                self.makeRequest(method: "POST", path: path, body: body, accessToken: current.accessToken)
            }
        } catch {
            return nil
        }
        guard result.isSuccess else { return nil }
        return try? decoder.decode(T.self, from: result.body)
    }

    // MARK: - Oturum

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let body: Data = try encoder.encode(IDTokenBody(provider: "apple", idToken: idToken, nonce: nonce))
        let query: [URLQueryItem] = [URLQueryItem(name: "grant_type", value: "id_token")]
        let fresh: AuthSession = try await requestSession(path: "auth/v1/token", query: query, body: body)
        invalidatePendingAuth()
        // Onceki (anonim ya da baska Apple) kimlik ayri bir kullanicidir: "Verilerimi sil" icin saklanir.
        retire(session ?? store.load(), unlessUserID: fresh.userID)
        // Ayni hesaba tekrar giris: o kimlik artik gecerli oturum, emekli listesinde tutulmaz.
        removeRetired(userID: fresh.userID)
        apply(fresh)
        return fresh
    }

    /// Yalnizca yerel oturumu siler; sunucu cagrisi yok. Kimlik "Verilerimi sil" icin emekliye ayrilir.
    func signOut() {
        invalidatePendingAuth()
        retire(session ?? store.load(), unlessUserID: nil)
        apply(nil)
    }

    /// Suren yenileme/kayit islemini iptal eder; sonucu artik oturuma yazilamaz.
    private func invalidatePendingAuth() {
        authEpoch += 1
        pendingAuth?.cancel()
        pendingAuth = nil
    }

    // MARK: - Yedek ve silme

    /// Yedek yalnizca Apple ile girisli (anonim olmayan) kullanicida. `payload` gecerli JSON olmali.
    func uploadBackup(_ payload: Data) async throws {
        let value: JSONValue
        do {
            value = try decoder.decode(JSONValue.self, from: payload)
        } catch {
            throw SupabaseError.invalidPayload
        }
        let result: HTTPResult = try await sendAuthorized(allowSignup: false) { current in
            guard !current.isAnonymous else { throw SupabaseError.notSignedIn }
            let row = BackupUploadRow(userID: current.userID, payload: value)
            let body: Data = try self.encoder.encode(row)
            return self.makeRequest(
                method: "POST", path: "rest/v1/backups", body: body,
                accessToken: current.accessToken, prefer: "resolution=merge-duplicates"
            )
        }
        guard result.isSuccess else { throw SupabaseError.http(result.status) }
    }

    /// Yedek yoksa nil.
    func downloadBackup() async throws -> Data? {
        let result: HTTPResult = try await sendAuthorized(allowSignup: false) { current in
            guard !current.isAnonymous else { throw SupabaseError.notSignedIn }
            let query: [URLQueryItem] = [
                URLQueryItem(name: "select", value: "payload"),
                URLQueryItem(name: "user_id", value: "eq.\(current.userID)"),
            ]
            return self.makeRequest(
                method: "GET", path: "rest/v1/backups", query: query, accessToken: current.accessToken
            )
        }
        guard result.isSuccess else { throw SupabaseError.http(result.status) }
        let rows: [BackupDownloadRow]
        do {
            rows = try decoder.decode([BackupDownloadRow].self, from: result.body)
        } catch {
            throw SupabaseError.invalidResponse
        }
        guard let first = rows.first else { return nil }
        return try encoder.encode(first.payload)
    }

    /// Bu cihazin tum kimlikleriyle gonderilmis verileri siler: once gecerli oturum, sonra emekli
    /// kimlikler. Gecerli oturumun verisi silinince oturum (emekliye ayrilmadan) birakilir.
    /// Emekli kimlikte gecici hata: kimlik listede kalir, sonunda hata firlatilir (tekrar denenebilir).
    func deleteMyData() async throws {
        let body: Data = try encoder.encode(EmptyBody())
        if session != nil {
            do {
                let result: HTTPResult = try await sendAuthorized(allowSignup: false) { current in
                    self.makeRequest(
                        method: "POST", path: "rest/v1/rpc/delete_my_data", body: body, accessToken: current.accessToken
                    )
                }
                guard result.isSuccess else { throw SupabaseError.http(result.status) }
                invalidatePendingAuth()
                apply(nil)
            } catch SupabaseError.notSignedIn where session == nil {
                // Oturum anahtari reddedildi ve oturum dustu: bu kimlige artik ulasilamaz.
            }
        }
        try await deleteRetiredIdentities(body: body)
    }

    /// Her emekli kimlik gecerli oturum yapilmadan yenilenir ve onun anahtariyla silinir.
    private func deleteRetiredIdentities(body: Data) async throws {
        var failure: Error?
        for identity in store.loadRetired() {
            let renewed: AuthSession
            do {
                renewed = try await refresh(using: identity.refreshToken)
            } catch SupabaseError.http(let status) where SupabaseClient.refreshRejectedStatuses.contains(status) {
                // Anahtar olu: bu kimlige artik ulasilamaz, listeden cikar.
                removeRetired(userID: identity.userID)
                continue
            } catch {
                failure = error
                continue
            }
            // Yenileme anahtari donusumlu: yeni anahtar saklanir (silme basarisiz olursa tekrar icin).
            updateRetired(userID: identity.userID, with: renewed)
            do {
                let request: URLRequest = makeRequest(
                    method: "POST", path: "rest/v1/rpc/delete_my_data", body: body, accessToken: renewed.accessToken
                )
                let result: HTTPResult = try await perform(request)
                guard result.isSuccess else { throw SupabaseError.http(result.status) }
                removeRetired(userID: identity.userID)
            } catch {
                failure = error
            }
        }
        if let failure { throw failure }
    }

    // MARK: - Emekli kimlikler

    /// Birakilan kimligi listeye ekler (ayni kullanici varsa yenisiyle degisir).
    /// `unlessUserID` ile ayni kullaniciysa (ayni Apple hesabiyla tekrar giris) eklenmez.
    private func retire(_ old: AuthSession?, unlessUserID: String?) {
        guard let old, old.userID != unlessUserID else { return }
        var list: [AuthSession] = store.loadRetired().filter { $0.userID != old.userID }
        list.append(old)
        store.saveRetired(list)
    }

    private func updateRetired(userID: String, with renewed: AuthSession) {
        var list: [AuthSession] = store.loadRetired()
        guard let index = list.firstIndex(where: { $0.userID == userID }) else { return }
        var updated: AuthSession = renewed
        updated.userID = userID
        list[index] = updated
        store.saveRetired(list)
    }

    private func removeRetired(userID: String) {
        let list: [AuthSession] = store.loadRetired()
        let remaining: [AuthSession] = list.filter { $0.userID != userID }
        guard remaining.count != list.count else { return }
        store.saveRetired(remaining)
    }

    // MARK: - RPC sonucu

    private func callOutboxRPC(_ name: String, body: Data) async -> OutboxResult {
        let path: String = "rest/v1/rpc/\(name)"
        let result: HTTPResult
        do {
            result = try await sendAuthorized(allowSignup: true) { current in
                self.makeRequest(method: "POST", path: path, body: body, accessToken: current.accessToken)
            }
        } catch {
            return .transient
        }
        return SupabaseClient.outboxResult(status: result.status, body: result.body)
    }

    /// 2xx: JSON metin ("ok" vb.) -> OutboxResult, taninmazsa .invalid. 5xx ve gecici durumlar -> .transient.
    static func outboxResult(status: Int, body: Data) -> OutboxResult {
        if (200..<300).contains(status) {
            let text: String? = try? JSONDecoder().decode(String.self, from: body)
            guard let raw = text, let parsed = OutboxResult(rawValue: raw) else { return .invalid }
            return parsed
        }
        if status >= 500 || transientStatuses.contains(status) {
            return .transient
        }
        return .invalid
    }

    // MARK: - Yetkili istek

    /// Gecerli oturumla istegi gonderir; 401 gelirse oturumu bir kez yenileyip tekrar dener.
    private func sendAuthorized(
        allowSignup: Bool,
        build: (AuthSession) throws -> URLRequest
    ) async throws -> HTTPResult {
        let first: AuthSession = try await validSession(allowSignup: allowSignup, forceRenew: false)
        let firstResult: HTTPResult = try await perform(try build(first))
        guard firstResult.status == 401 else { return firstResult }
        let second: AuthSession = try await validSession(allowSignup: allowSignup, forceRenew: true)
        return try await perform(try build(second))
    }

    private func validSession(allowSignup: Bool, forceRenew: Bool) async throws -> AuthSession {
        if session == nil, let reloaded = store.load() {
            // Baska bir yerde (or. arka plan) kaydedilmis oturum: anonim kayittan once bir kez bak.
            session = reloaded
        }
        if !forceRenew, let current = session, isFresh(current) {
            return current
        }
        if let pending = pendingAuth {
            return try await pending.value
        }
        let epoch: Int = authEpoch
        let task = Task<AuthSession, Error> {
            try await self.renewSession(allowSignup: allowSignup, epoch: epoch)
        }
        pendingAuth = task
        defer {
            if pendingAuth == task { pendingAuth = nil }
        }
        return try await task.value
    }

    private func isFresh(_ candidate: AuthSession) -> Bool {
        let remaining: TimeInterval = candidate.expiresAt.timeIntervalSince(clock())
        return remaining > SupabaseClient.refreshMargin
    }

    /// Once refresh_token ile yenile; sunucu reddederse (400/401/403) yeni anonim kayit (izinliyse).
    /// Ag, 429, 5xx gibi hatalarda oturum degismez, hata yukari tasinir.
    /// `epoch` degistiyse (cikis / Apple girisi) sonuc yazilmaz: CancellationError.
    private func renewSession(allowSignup: Bool, epoch: Int) async throws -> AuthSession {
        if let current = session {
            do {
                let refreshed: AuthSession = try await refresh(using: current.refreshToken)
                guard epoch == authEpoch else {
                    // Bu sirada kimlik emekliye ayrildi: eski anahtar artik gecersiz, yenisi saklanir.
                    updateRetired(userID: current.userID, with: refreshed)
                    throw CancellationError()
                }
                apply(refreshed)
                return refreshed
            } catch SupabaseError.http(let status) where SupabaseClient.refreshRejectedStatuses.contains(status) {
                // Yenileme anahtari gecersiz: eski oturum kullanilamaz.
                try ensureEpoch(epoch)
                apply(nil)
            }
        }
        guard allowSignup else { throw SupabaseError.notSignedIn }
        try ensureEpoch(epoch)
        let fresh: AuthSession = try await signUpAnonymously()
        try ensureEpoch(epoch)
        apply(fresh)
        return fresh
    }

    private func ensureEpoch(_ epoch: Int) throws {
        guard epoch == authEpoch else { throw CancellationError() }
    }

    private func refresh(using refreshToken: String) async throws -> AuthSession {
        let body: Data = try encoder.encode(RefreshBody(refreshToken: refreshToken))
        let query: [URLQueryItem] = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        return try await requestSession(path: "auth/v1/token", query: query, body: body)
    }

    private func signUpAnonymously() async throws -> AuthSession {
        let body: Data = try encoder.encode(EmptyBody())
        return try await requestSession(path: "auth/v1/signup", query: [], body: body)
    }

    private func requestSession(path: String, query: [URLQueryItem], body: Data) async throws -> AuthSession {
        let request: URLRequest = makeRequest(method: "POST", path: path, query: query, body: body)
        let result: HTTPResult = try await perform(request)
        guard result.isSuccess else { throw SupabaseError.http(result.status) }
        let token: TokenResponse
        do {
            token = try decoder.decode(TokenResponse.self, from: result.body)
        } catch {
            throw SupabaseError.invalidResponse
        }
        return token.session(now: clock())
    }

    private func apply(_ newSession: AuthSession?) {
        session = newSession
        store.save(newSession)
    }

    // MARK: - HTTP

    private func makeRequest(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        accessToken: String? = nil,
        prefer: String? = nil
    ) -> URLRequest {
        let base: URL = config.url.appendingPathComponent(path)
        var components: URLComponents? = URLComponents(url: base, resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }
        let url: URL = components?.url ?? base
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        return request
    }

    /// Ag hatasi -> SupabaseError.network; HTTP durum kodu cagirana birakilir.
    private func perform(_ request: URLRequest) async throws -> HTTPResult {
        let pair: (Data, URLResponse)
        do {
            pair = try await transport.data(for: request)
        } catch {
            throw SupabaseError.network
        }
        guard let http = pair.1 as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        return HTTPResult(status: http.statusCode, body: pair.0)
    }
}
