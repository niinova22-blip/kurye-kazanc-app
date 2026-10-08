import Foundation

/// Sunucu islemleri. Ana aktorde calisir: oturum durumu tek yerden, sirali degisir.
@MainActor
protocol SupabaseServing {
    func submitShift(_ p: ShiftPayload) async -> OutboxResult
    func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult
    func fetchTemplates() async -> [OCRTemplate]?
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession
    func uploadBackup(_ payload: Data) async throws
    func downloadBackup() async throws -> Data?
    func deleteMyData() async throws
    func signOut()
    var session: AuthSession? { get }
}

/// Elle yazilmis kucuk Supabase REST istemcisi (GoTrue + PostgREST). Ucuncu taraf bagimlilik yok.
@MainActor
final class SupabaseClient: SupabaseServing {
    /// Sure bu kadar saniye icinde dolacaksa istekten once yenilenir.
    static let refreshMargin: TimeInterval = 60
    /// Bu durumlarda RPC sonucu gecici sayilir (tekrar denenir); diger 4xx kalici `.invalid`.
    static let transientStatuses: Set<Int> = [401, 403, 404, 408, 425, 429]

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

    // MARK: - Oturum

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        let body: Data = try encoder.encode(IDTokenBody(provider: "apple", idToken: idToken, nonce: nonce))
        let query: [URLQueryItem] = [URLQueryItem(name: "grant_type", value: "id_token")]
        let fresh: AuthSession = try await requestSession(path: "auth/v1/token", query: query, body: body)
        apply(fresh)
        return fresh
    }

    /// Yalnizca yerel oturumu siler; sunucu cagrisi yok.
    func signOut() {
        pendingAuth = nil
        apply(nil)
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

    /// Sunucudaki tum verilerimi siler. Oturum yoksa sunucuda veri de yoktur.
    func deleteMyData() async throws {
        guard session != nil else { return }
        let body: Data = try encoder.encode(EmptyBody())
        let result: HTTPResult = try await sendAuthorized(allowSignup: false) { current in
            self.makeRequest(
                method: "POST", path: "rest/v1/rpc/delete_my_data", body: body, accessToken: current.accessToken
            )
        }
        guard result.isSuccess else { throw SupabaseError.http(result.status) }
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
        if !forceRenew, let current = session, isFresh(current) {
            return current
        }
        if let pending = pendingAuth {
            return try await pending.value
        }
        let task = Task<AuthSession, Error> {
            try await self.renewSession(allowSignup: allowSignup)
        }
        pendingAuth = task
        defer { pendingAuth = nil }
        return try await task.value
    }

    private func isFresh(_ candidate: AuthSession) -> Bool {
        let remaining: TimeInterval = candidate.expiresAt.timeIntervalSince(clock())
        return remaining > SupabaseClient.refreshMargin
    }

    /// Once refresh_token ile yenile; sunucu reddederse (4xx) yeni anonim kayit (izinliyse).
    /// Ag/5xx hatasinda oturum degismez, hata yukari tasinir.
    private func renewSession(allowSignup: Bool) async throws -> AuthSession {
        if let current = session {
            do {
                let refreshed: AuthSession = try await refresh(using: current.refreshToken)
                apply(refreshed)
                return refreshed
            } catch SupabaseError.http(let status) where (400..<500).contains(status) {
                // Yenileme anahtari gecersiz: eski oturum kullanilamaz.
                apply(nil)
            }
        }
        guard allowSignup else { throw SupabaseError.notSignedIn }
        let fresh: AuthSession = try await signUpAnonymously()
        apply(fresh)
        return fresh
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
