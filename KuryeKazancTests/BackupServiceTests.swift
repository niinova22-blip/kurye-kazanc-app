import XCTest
import SwiftData
@testable import KuryeKazanc

/// Hesap testleri icin sahte sunucu: oturum ayarlanabilir, yuklenen yedek geri indirilir.
@MainActor
final class FakeAccountClient: SupabaseServing {
    var session: AuthSession?
    /// Sunucuda duran yedek (uploadBackup yazar, downloadBackup okur).
    var storedBackup: Data?
    var deleteError: Error?
    /// Yukleme surerken calisir (yedek ortasinda baska islem denemek icin).
    var onUpload: (() async -> Void)?

    private(set) var uploadCount: Int = 0
    private(set) var deleteCount: Int = 0
    private(set) var signOutCount: Int = 0
    private(set) var appleNonces: [String] = []

    static func makeSession(anonymous: Bool) -> AuthSession {
        AuthSession(
            accessToken: "access", refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000), userID: "user-1", isAnonymous: anonymous
        )
    }

    func submitShift(_ p: ShiftPayload) async -> OutboxResult { .ok }

    func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult {
        .ok
    }

    func fetchTemplates() async -> [OCRTemplate]? { [] }

    func communityHeatmap(province: String, district: String) async -> [CommunityCell]? { nil }

    func communitySummary(province: String, district: String) async -> CommunitySummary? { nil }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        appleNonces.append(nonce)
        let fresh: AuthSession = FakeAccountClient.makeSession(anonymous: false)
        session = fresh
        return fresh
    }

    func uploadBackup(_ payload: Data) async throws {
        guard let session, !session.isAnonymous else { throw SupabaseError.notSignedIn }
        uploadCount += 1
        await onUpload?()
        // Sunucu jsonb'yi yeniden kodlar: bayt ayni kalmaz.
        let value = try JSONDecoder().decode(JSONValue.self, from: payload)
        storedBackup = try JSONEncoder().encode(value)
    }

    func downloadBackup() async throws -> Data? {
        guard let session, !session.isAnonymous else { throw SupabaseError.notSignedIn }
        return storedBackup
    }

    func deleteMyData() async throws {
        guard session != nil else { return }
        deleteCount += 1
        if let deleteError { throw deleteError }
    }

    func signOut() {
        signOutCount += 1
        session = nil
    }
}

@MainActor
final class BackupServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var defaults: UserDefaults!
    private var suiteName: String = ""
    private var directory: URL!
    private var now: Date = Date(timeIntervalSince1970: 1_791_000_000)

    override func setUp() async throws {
        container = ModelContainerFactory.make(inMemory: true)
        DataSeeder.seedPlatformsIfNeeded(in: context)
        suiteName = "BackupServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
        container = nil
    }

    // MARK: - Yardimcilar

    private func platforms(in context: ModelContext) -> [Platform] {
        (try? context.fetch(FetchDescriptor<Platform>())) ?? []
    }

    private func makeEvidence(in context: ModelContext) -> ScreenshotEvidence {
        let parsed = ParsedEarning(
            platformCode: "getir", date: now, packageCount: 11, totalEarning: 980,
            bonus: 0, totalIncludesBonus: true, fieldsToReview: [],
            templateID: "getir.earnings", templateVersion: 1
        )
        let lines: [RecognizedLine] = ["Getir", "IBAN TR33 0006 1005 1978 6457 8413 26", "Toplam Kazanç", "₺980,00"]
            .enumerated()
            .map { index, text in
                RecognizedLine(text: text, x: 0, y: 1 - Double(index) * 0.05, width: 0.5, height: 0.04)
            }
        let evidence = ScreenshotEvidence(
            capturedAt: now, assetIdentifier: nil, parsed: parsed, lines: lines, isGenuineScreenshot: true
        )
        context.insert(evidence)
        return evidence
    }

    /// 2 kazanc (biri kanitli) + 1 gider.
    @discardableResult
    private func seedRecords(in context: ModelContext) throws -> (EarningRecord, EarningRecord, ExpenseRecord) {
        let getir: Platform = platforms(in: context).first { $0.code == "yemeksepeti" }!
        let first = EarningRecord(
            startTime: now, endTime: now.addingTimeInterval(3600), platform: getir,
            province: "İstanbul", district: "Kadıköy", grossEarning: 980, bonus: 20.5,
            distanceKm: 42.25, packageCount: 11, source: .ocr, verification: .verified,
            createdAt: now
        )
        first.evidence = makeEvidence(in: context)
        let second = EarningRecord(
            startTime: now.addingTimeInterval(86_400), endTime: now.addingTimeInterval(90_000),
            grossEarning: 500.75, createdAt: now
        )
        let expense = ExpenseRecord(date: now, type: .fuel, amount: 250, note: "Benzin", createdAt: now)
        context.insert(first)
        context.insert(second)
        context.insert(expense)
        try context.save()
        return (first, second, expense)
    }

    // MARK: - BackupService

    func testRoundTrip_restoresAllRecordsIntoEmptyStore() throws {
        try seedRecords(in: context)
        defaults.set(3.5, forKey: AppPreferences.costPerKmKey)
        defaults.set(7000.0, forKey: AppPreferences.weeklyGoalKey)

        let payload = try BackupService.makePayload(context: context, defaults: defaults, now: now)
        XCTAssertEqual(payload.version, BackupService.currentVersion)
        XCTAssertEqual(payload.earnings.count, 2)
        XCTAssertEqual(payload.expenses.count, 1)
        XCTAssertEqual(payload.preferences, [AppPreferences.costPerKmKey: 3.5, AppPreferences.weeklyGoalKey: 7000])

        // JSON uzerinden (sunucuya gidip gelen hal)
        let decoded = try BackupService.decode(BackupService.encode(payload))
        XCTAssertEqual(decoded, payload)

        let target = ModelContainerFactory.make(inMemory: true)
        let targetContext = target.mainContext
        DataSeeder.seedPlatformsIfNeeded(in: targetContext)
        let targetDefaults = UserDefaults(suiteName: suiteName + "-target")!
        defer { targetDefaults.removePersistentDomain(forName: suiteName + "-target") }

        let result = try BackupService.restore(
            decoded, into: targetContext, platforms: platforms(in: targetContext), defaults: targetDefaults
        )
        XCTAssertEqual(result.added, 3)
        XCTAssertEqual(result.skipped, 0)

        let earnings = try targetContext.fetch(FetchDescriptor<EarningRecord>(sortBy: [SortDescriptor(\.startTime)]))
        let expenses = try targetContext.fetch(FetchDescriptor<ExpenseRecord>())
        XCTAssertEqual(earnings.count, 2)
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(earnings[0].platform?.code, "yemeksepeti")
        XCTAssertEqual(earnings[0].grossEarning, 980)
        XCTAssertEqual(earnings[0].bonus, 20.5)
        XCTAssertEqual(earnings[0].distanceKm, 42.25)
        XCTAssertEqual(earnings[0].packageCount, 11)
        XCTAssertEqual(earnings[0].district, "Kadıköy")
        XCTAssertEqual(earnings[0].verification, .verified)
        XCTAssertEqual(earnings[0].source, .ocr)
        XCTAssertNil(earnings[0].evidence)
        XCTAssertNil(earnings[1].platform)
        XCTAssertEqual(expenses[0].type, .fuel)
        XCTAssertEqual(expenses[0].note, "Benzin")
        XCTAssertEqual(targetDefaults.double(forKey: AppPreferences.costPerKmKey), 3.5)
        XCTAssertEqual(targetDefaults.double(forKey: AppPreferences.weeklyGoalKey), 7000)
        XCTAssertNil(targetDefaults.object(forKey: AppPreferences.dailyGoalKey))
    }

    func testRestoreTwice_skipsExistingIDs() throws {
        try seedRecords(in: context)
        let payload = try BackupService.makePayload(context: context, defaults: defaults, now: now)

        let target = ModelContainerFactory.make(inMemory: true)
        let targetContext = target.mainContext
        DataSeeder.seedPlatformsIfNeeded(in: targetContext)
        let list = platforms(in: targetContext)

        let first = try BackupService.restore(payload, into: targetContext, platforms: list, defaults: defaults)
        XCTAssertEqual(first.added, 3)
        let second = try BackupService.restore(payload, into: targetContext, platforms: list, defaults: defaults)
        XCTAssertEqual(second.added, 0)
        XCTAssertEqual(second.skipped, 3)
        XCTAssertEqual(try targetContext.fetchCount(FetchDescriptor<EarningRecord>()), 2)
        XCTAssertEqual(try targetContext.fetchCount(FetchDescriptor<ExpenseRecord>()), 1)
    }

    func testRestoreIntoSameStore_keepsLocalValues() throws {
        let (first, _, _) = try seedRecords(in: context)
        let payload = try BackupService.makePayload(context: context, defaults: defaults, now: now)
        first.grossEarning = 1234
        try context.save()

        let result = try BackupService.restore(payload, into: context, platforms: platforms(in: context), defaults: defaults)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.skipped, 3)
        XCTAssertEqual(first.grossEarning, 1234)
    }

    /// Geri yukleme acik kullanici istegi: yedekteki tercih cihazdakini ezer (onboarding costPerKm'i
    /// her zaman yazar; yeni telefonda "yalnizca bossa" kurali hic islemezdi).
    func testRestore_overwritesLocalPreferenceWithBackup() throws {
        defaults.set(2.0, forKey: AppPreferences.costPerKmKey)
        defaults.set(5000.0, forKey: AppPreferences.weeklyGoalKey)
        let payload = BackupPayload(
            version: 1, earnings: [], expenses: [],
            preferences: [
                AppPreferences.costPerKmKey: 3.5, AppPreferences.dailyGoalKey: 900,
                AppPreferences.weeklyGoalKey: .nan, "isWorking": 1
            ],
            createdAt: now
        )
        _ = try BackupService.restore(payload, into: context, platforms: [], defaults: defaults)
        XCTAssertEqual(defaults.double(forKey: AppPreferences.costPerKmKey), 3.5)
        XCTAssertEqual(defaults.double(forKey: AppPreferences.dailyGoalKey), 900)
        // Sonlu olmayan deger yazilmaz, yerel kalir.
        XCTAssertEqual(defaults.double(forKey: AppPreferences.weeklyGoalKey), 5000)
        XCTAssertNil(defaults.object(forKey: "isWorking"))
    }

    func testRestore_rejectsNewerVersion() throws {
        let payload = BackupPayload(version: 99, earnings: [], expenses: [], preferences: [:], createdAt: now)
        XCTAssertThrowsError(try BackupService.restore(payload, into: context, platforms: [], defaults: defaults)) { error in
            XCTAssertEqual(error as? BackupError, .unsupportedVersion(99))
        }
    }

    func testPayload_carriesNoEvidence() throws {
        try seedRecords(in: context)
        let payload = try BackupService.makePayload(context: context, defaults: defaults, now: now)
        let data = try BackupService.encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("IBAN"))
        XCTAssertFalse(json.contains("Toplam"))
        XCTAssertFalse(json.contains("evidence"))
        XCTAssertFalse(json.contains("lines"))
        XCTAssertFalse(json.contains("anonymousDeviceID"))
    }

    // MARK: - AccountService

    private func makeAccount(client: FakeAccountClient?, sync: SyncCoordinator? = nil) -> AccountService {
        AccountService(client: client, defaults: defaults, syncCoordinator: sync, clock: { [unowned self] in self.now })
    }

    func testNonce_isBase64URLAndHashedIs64Hex() {
        let account = makeAccount(client: nil)
        let nonce = account.makeNonce()
        XCTAssertEqual(nonce.raw.count, 43)
        XCTAssertNil(nonce.raw.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
        XCTAssertEqual(nonce.hashed.count, 64)
        XCTAssertNil(nonce.hashed.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdef").inverted))
        XCTAssertEqual(nonce.hashed, SHA256.hex(nonce.raw))
        XCTAssertNotEqual(account.makeNonce().raw, nonce.raw)
    }

    func testAppleSignIn_sendsRawNonceAndUpdatesState() async throws {
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: true)
        let account = makeAccount(client: fake)
        XCTAssertFalse(account.isSignedInWithApple)

        let nonce = account.makeNonce()
        try await account.completeAppleSignIn(idToken: "token", rawNonce: nonce.raw)
        XCTAssertEqual(fake.appleNonces, [nonce.raw])
        XCTAssertTrue(account.isSignedInWithApple)

        account.signOut()
        XCTAssertFalse(account.isSignedInWithApple)
        XCTAssertEqual(fake.signOutCount, 1)
    }

    func testBackupNow_anonymousThrowsWithoutUpload() async throws {
        try seedRecords(in: context)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: true)
        let account = makeAccount(client: fake)
        do {
            try await account.backupNow(context: context)
            XCTFail("Anonim oturumda yedek alinmamali")
        } catch {
            XCTAssertEqual(error as? SupabaseError, .notSignedIn)
        }
        XCTAssertEqual(fake.uploadCount, 0)
        XCTAssertNil(account.lastBackupDate)
    }

    func testBackupThenRestoreOnNewDevice() async throws {
        try seedRecords(in: context)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        let account = makeAccount(client: fake)

        try await account.backupNow(context: context)
        XCTAssertEqual(fake.uploadCount, 1)
        XCTAssertEqual(account.lastBackupDate, now)
        XCTAssertEqual(defaults.double(forKey: AppPreferences.lastBackupDateKey), now.timeIntervalSince1970)
        XCTAssertFalse(account.isBackupDue)

        let target = ModelContainerFactory.make(inMemory: true)
        let targetContext = target.mainContext
        DataSeeder.seedPlatformsIfNeeded(in: targetContext)
        let result = try await account.restore(context: targetContext, platforms: platforms(in: targetContext))
        XCTAssertEqual(result.added, 3)
        XCTAssertEqual(result.skipped, 0)
    }

    func testRestore_withoutBackupThrowsNoBackup() async throws {
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        let account = makeAccount(client: fake)
        do {
            _ = try await account.restore(context: context, platforms: [])
            XCTFail("Yedek yokken hata beklenir")
        } catch {
            XCTAssertEqual(error as? AccountError, .noBackup)
        }
    }

    func testBackupIfDue_respects24Hours() async throws {
        try seedRecords(in: context)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        let account = makeAccount(client: fake)

        // Taban: elle ilk yedek
        try await account.backupNow(context: context)
        XCTAssertEqual(fake.uploadCount, 1)
        now = now.addingTimeInterval(23 * 3600)
        await account.backupIfDue(context: context)
        XCTAssertEqual(fake.uploadCount, 1)
        now = now.addingTimeInterval(3600)
        await account.backupIfDue(context: context)
        XCTAssertEqual(fake.uploadCount, 2)
    }

    /// Yeni telefonda giris + geri yuklemeden once kayit: tam yedek tek kayitla ezilmesin.
    func testBackupIfDue_withoutBaselineDoesNotUpload() async throws {
        try seedRecords(in: context)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        fake.storedBackup = Data("tam-yedek".utf8)
        let account = makeAccount(client: fake)
        XCTAssertNil(account.lastBackupDate)
        XCTAssertFalse(account.isBackupDue)

        await account.backupIfDue(context: context)

        XCTAssertEqual(fake.uploadCount, 0)
        XCTAssertEqual(fake.storedBackup, Data("tam-yedek".utf8))
        XCTAssertNil(account.lastBackupDate)
    }

    func testRestore_setsBaselineForAutomaticBackup() async throws {
        try seedRecords(in: context)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        let account = makeAccount(client: fake)
        try await account.backupNow(context: context)
        XCTAssertEqual(fake.uploadCount, 1)

        // Yeni cihaz: ayni sunucu, taban yok
        let fresh = UserDefaults(suiteName: suiteName + "-yeni")!
        defer { fresh.removePersistentDomain(forName: suiteName + "-yeni") }
        let newDevice = AccountService(client: fake, defaults: fresh, clock: { [unowned self] in self.now })
        let target = ModelContainerFactory.make(inMemory: true)
        let targetContext = target.mainContext
        DataSeeder.seedPlatformsIfNeeded(in: targetContext)
        now = now.addingTimeInterval(3600)

        _ = try await newDevice.restore(context: targetContext, platforms: platforms(in: targetContext))

        XCTAssertEqual(newDevice.lastBackupDate, now)
        XCTAssertEqual(fresh.double(forKey: AppPreferences.lastBackupDateKey), now.timeIntervalSince1970)
        XCTAssertFalse(newDevice.isBackupDue)
        now = now.addingTimeInterval(24 * 3600)
        await newDevice.backupIfDue(context: targetContext)
        XCTAssertEqual(fake.uploadCount, 2)
    }

    /// "Tum kayitlari sil" sonrasi bos veri otomatik yedekle sunucuya yazilmaz.
    func testLocalRecordsCleared_clearsBaselineAndStopsAutomaticBackup() async throws {
        try seedRecords(in: context)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        let account = makeAccount(client: fake)
        try await account.backupNow(context: context)
        XCTAssertEqual(fake.uploadCount, 1)

        account.localRecordsCleared()

        XCTAssertNil(account.lastBackupDate)
        XCTAssertNil(defaults.object(forKey: AppPreferences.lastBackupDateKey))
        now = now.addingTimeInterval(25 * 3600)
        await account.backupIfDue(context: context)
        XCTAssertEqual(fake.uploadCount, 1)
    }

    func testDeleteMyData_revokesConsentsClearsQueueAndKeepsLocalRecords() async throws {
        try seedRecords(in: context)
        defaults.set(true, forKey: AppPreferences.dataSharingOptInKey)
        defaults.set(now.timeIntervalSince1970, forKey: AppPreferences.dataSharingConsentDateKey)
        defaults.set(true, forKey: AppPreferences.locationSharingOptInKey)
        defaults.set(now.timeIntervalSince1970, forKey: AppPreferences.locationSharingConsentDateKey)
        defaults.set(true, forKey: AppPreferences.calibrationOptInKey)
        defaults.set(now.timeIntervalSince1970, forKey: AppPreferences.lastBackupDateKey)

        let queue = OutboxQueue(fileURL: directory.appendingPathComponent("outbox.json"))
        queue.enqueue(OutboxItem(id: UUID(), kind: .shift, payload: Data("{}".utf8), failures: 0, notBefore: now))
        queue.enqueue(OutboxItem(id: UUID(), kind: .calibration, payload: Data("{}".utf8), failures: 0, notBefore: now))
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        let sync = SyncCoordinator(
            client: fake, queue: queue, defaults: defaults,
            templatesFileURL: directory.appendingPathComponent("remote_templates.json")
        )
        let account = makeAccount(client: fake, sync: sync)

        try await account.deleteMyData(context: context)

        XCTAssertEqual(fake.deleteCount, 1)
        XCTAssertEqual(fake.signOutCount, 1)
        XCTAssertFalse(account.isSignedInWithApple)
        XCTAssertNil(account.lastBackupDate)
        XCTAssertFalse(defaults.bool(forKey: AppPreferences.dataSharingOptInKey))
        XCTAssertEqual(defaults.double(forKey: AppPreferences.dataSharingConsentDateKey), 0)
        XCTAssertFalse(defaults.bool(forKey: AppPreferences.locationSharingOptInKey))
        XCTAssertEqual(defaults.double(forKey: AppPreferences.locationSharingConsentDateKey), 0)
        XCTAssertFalse(defaults.bool(forKey: AppPreferences.calibrationOptInKey))
        XCTAssertTrue(queue.items.isEmpty)
        // Yerel veri kullaniciya ait: silinmez.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EarningRecord>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseRecord>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScreenshotEvidence>()), 1)
    }

    func testDeleteMyData_serverFailureKeepsSession() async throws {
        defaults.set(true, forKey: AppPreferences.dataSharingOptInKey)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        fake.deleteError = SupabaseError.network
        let account = makeAccount(client: fake)

        do {
            try await account.deleteMyData(context: context)
            XCTFail("Sunucu hatasi iletilmeli")
        } catch {
            XCTAssertEqual(error as? SupabaseError, .network)
        }
        XCTAssertEqual(fake.signOutCount, 0)
        XCTAssertTrue(account.isSignedInWithApple)
        // Riza yine de kapandi (yerel, ag gerektirmez).
        XCTAssertFalse(defaults.bool(forKey: AppPreferences.dataSharingOptInKey))
    }

    /// Silme sunucuda basarisiz olduysa (oturum korunur) yedek alinmaz: silinmesi istenen veri
    /// sunucuya yeniden yazilmasin.
    func testDeleteMyData_failedDeleteBlocksBackups() async throws {
        try seedRecords(in: context)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        fake.deleteError = SupabaseError.network
        let account = makeAccount(client: fake)

        do {
            try await account.deleteMyData(context: context)
            XCTFail("Sunucu hatasi iletilmeli")
        } catch {}
        XCTAssertTrue(account.isSignedInWithApple)

        await account.backupIfDue(context: context)
        XCTAssertEqual(fake.uploadCount, 0)
        do {
            try await account.backupNow(context: context)
            XCTFail("Silme bitmeden yedek alinmamali")
        } catch {
            XCTAssertEqual(error as? AccountError, .deletePending)
        }
        XCTAssertEqual(fake.uploadCount, 0)

        // Tekrar deneme basarili: veri silinir, cikis yapilir.
        fake.deleteError = nil
        try await account.deleteMyData(context: context)
        XCTAssertEqual(fake.deleteCount, 2)
        XCTAssertFalse(account.isSignedInWithApple)
    }

    /// Yedek yuklenirken "Verilerimi sil" reddedilir: yukleme silmeden sonra bitip veriyi geri yazmasin.
    func testDeleteMyData_duringBackupThrowsBusy() async throws {
        try seedRecords(in: context)
        defaults.set(true, forKey: AppPreferences.dataSharingOptInKey)
        let fake = FakeAccountClient()
        fake.session = FakeAccountClient.makeSession(anonymous: false)
        let account = makeAccount(client: fake)
        var deleteError: Error?
        fake.onUpload = { [unowned self] in
            do {
                try await account.deleteMyData(context: self.context)
            } catch {
                deleteError = error
            }
        }

        try await account.backupNow(context: context)
        fake.onUpload = nil

        XCTAssertEqual(deleteError as? AccountError, .busy)
        XCTAssertEqual(fake.uploadCount, 1)
        XCTAssertEqual(fake.deleteCount, 0)
        XCTAssertEqual(fake.signOutCount, 0)
        // Reddedilen silme rizalara dokunmaz.
        XCTAssertTrue(defaults.bool(forKey: AppPreferences.dataSharingOptInKey))
        XCTAssertTrue(account.isSignedInWithApple)
    }
}
