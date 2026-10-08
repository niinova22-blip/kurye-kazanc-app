import XCTest
@testable import KuryeKazanc

/// Sahte ag: yol -> yanit kuyrugu. Kuyrukta tek yanit kalinca o yanit tekrar tekrar doner.
final class StubProtocol: URLProtocol {
    struct Stub {
        let status: Int
        let body: String
    }

    struct Recorded {
        let method: String
        let path: String
        let query: String
        let headers: [String: String]
        let body: String
    }

    private static let lock = NSLock()
    private static var routes: [String: [Stub]] = [:]
    private static var recorded: [Recorded] = []

    static func reset(_ newRoutes: [String: [Stub]]) {
        lock.lock()
        routes = newRoutes
        recorded = []
        lock.unlock()
    }

    static var requests: [Recorded] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private static func record(_ item: Recorded) {
        lock.lock()
        recorded.append(item)
        lock.unlock()
    }

    private static func next(for path: String) -> Stub {
        lock.lock()
        defer { lock.unlock() }
        guard var queue = routes[path], let first = queue.first else {
            return Stub(status: 404, body: "{}")
        }
        if queue.count > 1 {
            queue.removeFirst()
            routes[path] = queue
        }
        return first
    }

    /// URLProtocol icinde httpBody nil gelir; govde akistan okunur.
    static func bodyData(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count: Int = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    /// Baslik adlari Foundation surumune gore farkli harf buyuklugunde gelebilir; kucuk harfe indirilir.
    static func lowercasedHeaders(_ request: URLRequest) -> [String: String] {
        var result: [String: String] = [:]
        for (name, value) in request.allHTTPHeaderFields ?? [:] {
            result[name.lowercased()] = value
        }
        return result
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let bodyText = String(decoding: StubProtocol.bodyData(of: request), as: UTF8.self)
        let item = Recorded(
            method: request.httpMethod ?? "GET", path: url.path, query: url.query ?? "",
            headers: StubProtocol.lowercasedHeaders(request), body: bodyText
        )
        StubProtocol.record(item)
        let stub: Stub = StubProtocol.next(for: url.path)
        let headerFields: [String: String] = ["Content-Type": "application/json"]
        guard let response = HTTPURLResponse(
            url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: headerFields
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class MemorySessionStore: SessionStore {
    var stored: AuthSession?
    var saveCount: Int = 0

    init(_ initial: AuthSession? = nil) {
        stored = initial
    }

    func load() -> AuthSession? { stored }

    func save(_ s: AuthSession?) {
        stored = s
        saveCount += 1
    }
}

final class SupabaseClientTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let signupPath = "/auth/v1/signup"
    private static let tokenPath = "/auth/v1/token"
    private static let shiftPath = "/rest/v1/rpc/submit_shift"
    private static let templatesPath = "/rest/v1/ocr_templates"
    private static let backupsPath = "/rest/v1/backups"

    private static let anonSessionJSON =
        #"{"access_token":"acc-anon","refresh_token":"ref-anon","expires_in":3600,"user":{"id":"user-anon","is_anonymous":true}}"#
    private static let refreshedJSON =
        #"{"access_token":"acc-new","refresh_token":"ref-new","expires_in":3600,"user":{"id":"user-1","is_anonymous":false}}"#

    @MainActor
    private func makeClient(store: MemorySessionStore) -> SupabaseClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let transport = URLSession(configuration: configuration)
        let config = SupabaseConfig(url: URL(string: "https://test.supabase.co")!, anonKey: "anon-key")
        let fixedNow: Date = SupabaseClientTests.now
        return SupabaseClient(config: config, store: store, transport: transport, clock: { fixedNow })
    }

    private func samplePayload() -> ShiftPayload {
        ShiftPayload(
            clientRecordID: "6f1c2a52-6a4e-4d43-9a43-0d3f8e0c0a11", platformCode: "getir",
            province: "İstanbul", district: "Kadıköy", vehicle: "motorcycle", weekday: 1, startSlot: 74,
            durationMin: 153, gross: 900, bonus: 100, packages: 12, distanceKm: 41.5, level: "ocrUnverified",
            templateID: "getir.earnings", templateVersion: 1, textHash: String(repeating: "a", count: 64)
        )
    }

    private func session(expiresIn seconds: TimeInterval, anonymous: Bool = false) -> AuthSession {
        AuthSession(
            accessToken: "acc-old", refreshToken: "ref-old",
            expiresAt: SupabaseClientTests.now.addingTimeInterval(seconds),
            userID: "user-1", isAnonymous: anonymous
        )
    }

    // (a) Oturum yokken once anonim kayit, sonra RPC.
    @MainActor
    func testSubmitShiftWithoutSessionSignsUpAnonymouslyFirst() async throws {
        StubProtocol.reset([
            SupabaseClientTests.signupPath: [.init(status: 200, body: SupabaseClientTests.anonSessionJSON)],
            SupabaseClientTests.shiftPath: [.init(status: 200, body: #""ok""#)],
        ])
        let store = MemorySessionStore()
        let client = makeClient(store: store)

        let result: OutboxResult = await client.submitShift(samplePayload())

        XCTAssertEqual(result, .ok)
        let requests = StubProtocol.requests
        XCTAssertEqual(requests.map { $0.path }, [SupabaseClientTests.signupPath, SupabaseClientTests.shiftPath])
        XCTAssertEqual(requests[0].method, "POST")
        XCTAssertEqual(requests[0].body, "{}")
        XCTAssertEqual(requests[0].headers["apikey"], "anon-key")
        XCTAssertNil(requests[0].headers["authorization"])
        let rpc = requests[1]
        XCTAssertEqual(rpc.method, "POST")
        XCTAssertTrue(rpc.body.contains(#""payload""#))
        XCTAssertTrue(rpc.body.contains(#""text_hash""#))
        XCTAssertEqual(rpc.headers["authorization"], "Bearer acc-anon")
        XCTAssertEqual(rpc.headers["apikey"], "anon-key")
        XCTAssertEqual(store.stored?.userID, "user-anon")
        XCTAssertEqual(store.stored?.isAnonymous, true)
        XCTAssertEqual(store.stored?.expiresAt, SupabaseClientTests.now.addingTimeInterval(3600))
        XCTAssertEqual(client.session, store.stored)
    }

    // (b)
    @MainActor
    func testDuplicateResult() async {
        StubProtocol.reset([
            SupabaseClientTests.shiftPath: [.init(status: 200, body: #""duplicate""#)],
        ])
        let client = makeClient(store: MemorySessionStore(session(expiresIn: 3600)))

        let result: OutboxResult = await client.submitShift(samplePayload())

        XCTAssertEqual(result, .duplicate)
        XCTAssertEqual(StubProtocol.requests.map { $0.path }, [SupabaseClientTests.shiftPath])
    }

    // (c)
    @MainActor
    func testServerErrorIsTransient() async {
        StubProtocol.reset([
            SupabaseClientTests.shiftPath: [.init(status: 503, body: "{}")],
        ])
        let client = makeClient(store: MemorySessionStore(session(expiresIn: 3600)))

        let result: OutboxResult = await client.submitShift(samplePayload())

        XCTAssertEqual(result, .transient)
    }

    // (d) Suresi dolmus oturum: once refresh_token, kayit yok.
    @MainActor
    func testExpiredSessionRefreshesFirst() async {
        StubProtocol.reset([
            SupabaseClientTests.tokenPath: [.init(status: 200, body: SupabaseClientTests.refreshedJSON)],
            SupabaseClientTests.shiftPath: [.init(status: 200, body: #""ok""#)],
        ])
        let store = MemorySessionStore(session(expiresIn: 30))
        let client = makeClient(store: store)

        let result: OutboxResult = await client.submitShift(samplePayload())

        XCTAssertEqual(result, .ok)
        let requests = StubProtocol.requests
        XCTAssertEqual(requests.map { $0.path }, [SupabaseClientTests.tokenPath, SupabaseClientTests.shiftPath])
        XCTAssertEqual(requests[0].query, "grant_type=refresh_token")
        XCTAssertTrue(requests[0].body.contains(#""refresh_token":"ref-old""#))
        XCTAssertEqual(requests[1].headers["authorization"], "Bearer acc-new")
        XCTAssertEqual(store.stored?.accessToken, "acc-new")
    }

    // Yenileme reddedilirse yeni anonim kayit.
    @MainActor
    func testRejectedRefreshFallsBackToAnonymousSignup() async {
        StubProtocol.reset([
            SupabaseClientTests.tokenPath: [.init(status: 400, body: #"{"error":"invalid_grant"}"#)],
            SupabaseClientTests.signupPath: [.init(status: 200, body: SupabaseClientTests.anonSessionJSON)],
            SupabaseClientTests.shiftPath: [.init(status: 200, body: #""ok""#)],
        ])
        let store = MemorySessionStore(session(expiresIn: -10))
        let client = makeClient(store: store)

        let result: OutboxResult = await client.submitShift(samplePayload())

        XCTAssertEqual(result, .ok)
        let paths: [String] = StubProtocol.requests.map { $0.path }
        XCTAssertEqual(paths, [SupabaseClientTests.tokenPath, SupabaseClientTests.signupPath, SupabaseClientTests.shiftPath])
        XCTAssertEqual(store.stored?.userID, "user-anon")
    }

    // 401: bir kez yenileyip tekrar dener.
    @MainActor
    func testUnauthorizedRetriesOnceAfterRefresh() async {
        StubProtocol.reset([
            SupabaseClientTests.shiftPath: [
                .init(status: 401, body: "{}"),
                .init(status: 200, body: #""ok""#),
            ],
            SupabaseClientTests.tokenPath: [.init(status: 200, body: SupabaseClientTests.refreshedJSON)],
        ])
        let client = makeClient(store: MemorySessionStore(session(expiresIn: 3600)))

        let result: OutboxResult = await client.submitShift(samplePayload())

        XCTAssertEqual(result, .ok)
        let requests = StubProtocol.requests
        let paths: [String] = requests.map { $0.path }
        XCTAssertEqual(paths, [SupabaseClientTests.shiftPath, SupabaseClientTests.tokenPath, SupabaseClientTests.shiftPath])
        XCTAssertEqual(requests[0].headers["authorization"], "Bearer acc-old")
        XCTAssertEqual(requests[2].headers["authorization"], "Bearer acc-new")
    }

    // Taninmayan metin ve kalici 4xx -> .invalid
    @MainActor
    func testOutboxResultMapping() {
        XCTAssertEqual(SupabaseClient.outboxResult(status: 200, body: Data(#""rate_limited""#.utf8)), .rateLimited)
        XCTAssertEqual(SupabaseClient.outboxResult(status: 200, body: Data(#""bilinmeyen""#.utf8)), .invalid)
        XCTAssertEqual(SupabaseClient.outboxResult(status: 400, body: Data()), .invalid)
        XCTAssertEqual(SupabaseClient.outboxResult(status: 429, body: Data()), .transient)
        XCTAssertEqual(SupabaseClient.outboxResult(status: 500, body: Data()), .transient)
    }

    // (e)
    @MainActor
    func testFetchTemplatesDecodesBodies() async throws {
        let encoded: Data = try JSONEncoder().encode(BundledTemplates.generic)
        let templateJSON = String(decoding: encoded, as: UTF8.self)
        let responseBody = #"[{"body":"# + templateJSON + #"},{"body":{"bozuk":true}}]"#
        StubProtocol.reset([
            SupabaseClientTests.templatesPath: [.init(status: 200, body: responseBody)],
        ])
        let client = makeClient(store: MemorySessionStore())

        let templates: [OCRTemplate]? = await client.fetchTemplates()

        XCTAssertEqual(templates, [BundledTemplates.generic])
        let requests = StubProtocol.requests
        XCTAssertEqual(requests.count, 1, "Sablon okumak icin oturum acilmaz")
        XCTAssertEqual(requests.first?.method, "GET")
        XCTAssertEqual(requests.first?.query, "select=body")
        XCTAssertNil(requests.first?.headers["authorization"])
    }

    @MainActor
    func testFetchTemplatesReturnsNilOnServerError() async {
        StubProtocol.reset([
            SupabaseClientTests.templatesPath: [.init(status: 500, body: "{}")],
        ])
        let client = makeClient(store: MemorySessionStore())

        let templates: [OCRTemplate]? = await client.fetchTemplates()

        XCTAssertNil(templates)
    }

    // Yedek: yalnizca anonim olmayan oturumda; upsert basligi ve user_id filtresi.
    @MainActor
    func testBackupRoundTripForSignedInUser() async throws {
        StubProtocol.reset([
            SupabaseClientTests.backupsPath: [
                .init(status: 201, body: ""),
                .init(status: 200, body: #"[{"payload":{"shifts":[1,2],"name":"Ali"}}]"#),
            ],
        ])
        let client = makeClient(store: MemorySessionStore(session(expiresIn: 3600)))

        try await client.uploadBackup(Data(#"{"shifts":[1,2],"name":"Ali"}"#.utf8))
        let downloaded: Data? = try await client.downloadBackup()

        let requests = StubProtocol.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].method, "POST")
        XCTAssertEqual(requests[0].headers["prefer"], "resolution=merge-duplicates")
        XCTAssertTrue(requests[0].body.contains(#""user_id":"user-1""#))
        XCTAssertTrue(requests[0].body.contains(#""payload""#))
        XCTAssertEqual(requests[1].method, "GET")
        XCTAssertEqual(requests[1].query, "select=payload&user_id=eq.user-1")
        let data = try XCTUnwrap(downloaded)
        let value: JSONValue = try JSONDecoder().decode(JSONValue.self, from: data)
        let expected: JSONValue = .object(["shifts": .array([.int(1), .int(2)]), "name": .string("Ali")])
        XCTAssertEqual(value, expected)
    }

    @MainActor
    func testBackupRefusedForAnonymousSession() async {
        StubProtocol.reset([:])
        let client = makeClient(store: MemorySessionStore(session(expiresIn: 3600, anonymous: true)))

        do {
            try await client.uploadBackup(Data("{}".utf8))
            XCTFail("Anonim kullanici yedekleyemez")
        } catch {
            XCTAssertEqual(error as? SupabaseError, .notSignedIn)
        }
        XCTAssertTrue(StubProtocol.requests.isEmpty)
    }

    @MainActor
    func testSignOutClearsStoredSession() {
        let store = MemorySessionStore(session(expiresIn: 3600))
        let client = makeClient(store: store)

        client.signOut()

        XCTAssertNil(client.session)
        XCTAssertNil(store.stored)
    }

    // (f) fromBundle bos degerde nil; ayni kural yardimci init ile sinanir.
    func testConfigRequiresBothValues() {
        XCTAssertNil(SupabaseConfig(urlString: "", anonKey: "anahtar"))
        XCTAssertNil(SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: ""))
        XCTAssertNil(SupabaseConfig(urlString: "   ", anonKey: "  "))
        XCTAssertNil(SupabaseConfig(urlString: "abc", anonKey: "anahtar"))
        let config = SupabaseConfig(urlString: "https://abc.supabase.co", anonKey: "anahtar")
        XCTAssertEqual(config?.url.host, "abc.supabase.co")
        XCTAssertEqual(config?.anonKey, "anahtar")
    }
}
