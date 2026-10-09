import XCTest
import SwiftData
@testable import KuryeKazanc

/// Sahte sunucu: her cagriyi sayar. Ag kurali testleri `callCount == 0` bekler.
@MainActor
final class FakeSupabase: SupabaseServing {
    /// Sirayla dondurulur; tek sonuc kalinca o tekrarlanir.
    var shiftResults: [OutboxResult] = [.ok]
    var calibrationResults: [OutboxResult] = [.ok]
    var templates: [OCRTemplate]? = []
    /// Vardiya gonderimi surerken calisir (suren gonderimi taklit etmek icin).
    var onSubmitShift: (() async -> Void)?

    private(set) var submittedShifts: [ShiftPayload] = []
    private(set) var submittedCalibrations: [[RecognizedLine]] = []
    private(set) var fetchCount: Int = 0
    private(set) var otherCalls: Int = 0

    var callCount: Int {
        submittedShifts.count + submittedCalibrations.count + fetchCount + otherCalls
    }

    var session: AuthSession? { nil }

    func submitShift(_ p: ShiftPayload) async -> OutboxResult {
        submittedShifts.append(p)
        await onSubmitShift?()
        return Self.next(&shiftResults)
    }

    func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult {
        submittedCalibrations.append(lines)
        return Self.next(&calibrationResults)
    }

    func fetchTemplates() async -> [OCRTemplate]? {
        fetchCount += 1
        return templates
    }

    var rules: [PlatformRule]? = []
    private(set) var ruleFetchCount: Int = 0

    func fetchPlatformRules() async -> [PlatformRule]? {
        ruleFetchCount += 1
        return rules
    }

    func communityHeatmap(province: String, district: String) async -> [CommunityCell]? {
        otherCalls += 1
        return nil
    }

    func communitySummary(province: String, district: String) async -> CommunitySummary? {
        otherCalls += 1
        return nil
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession {
        otherCalls += 1
        throw SupabaseError.notSignedIn
    }

    func uploadBackup(_ payload: Data) async throws {
        otherCalls += 1
    }

    func downloadBackup() async throws -> Data? {
        otherCalls += 1
        return nil
    }

    func deleteMyData() async throws {
        otherCalls += 1
    }

    func signOut() {
        otherCalls += 1
    }

    private static func next(_ results: inout [OutboxResult]) -> OutboxResult {
        guard let first = results.first else { return .ok }
        if results.count > 1 {
            results.removeFirst()
        }
        return first
    }
}

@MainActor
final class SyncCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var defaults: UserDefaults!
    private var suiteName: String = ""
    private var directory: URL!
    private var fake: FakeSupabase!
    private var queue: OutboxQueue!
    private var now: Date = Date(timeIntervalSince1970: 0)

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    private let ocrLines: [String] = ["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"]

    override func setUp() async throws {
        container = ModelContainerFactory.make(inMemory: true)
        DataSeeder.seedPlatformsIfNeeded(in: context)
        suiteName = "SyncCoordinatorTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fake = FakeSupabase()
        queue = OutboxQueue(fileURL: directory.appendingPathComponent("outbox.json"))
        now = at(6, 18)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
        container = nil
        fake = nil
        queue = nil
    }

    // MARK: - Yardimcilar

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func makeCoordinator(client: (any SupabaseServing)?) -> SyncCoordinator {
        SyncCoordinator(
            client: client, queue: queue, defaults: defaults, calendar: calendar,
            clock: { [unowned self] in self.now },
            templatesFileURL: directory.appendingPathComponent("remote_templates.json"),
            rulesFileURL: directory.appendingPathComponent("platform_rules.json")
        )
    }

    private func setConsents(sharing: Bool, calibration: Bool) {
        defaults.set(sharing, forKey: AppPreferences.dataSharingOptInKey)
        defaults.set(calibration, forKey: AppPreferences.calibrationOptInKey)
    }

    private var getir: Platform {
        let all = (try? context.fetch(FetchDescriptor<Platform>())) ?? []
        return all.first { $0.code == "getir" }!
    }

    private func makeEvidence(lines: [String]) -> ScreenshotEvidence {
        let parsed = ParsedEarning(
            platformCode: "getir", date: at(6, 0), packageCount: 11, totalEarning: 980,
            bonus: 0, totalIncludesBonus: true, fieldsToReview: [],
            templateID: "getir.earnings", templateVersion: 1
        )
        let recognized: [RecognizedLine] = lines.enumerated().map { index, text in
            RecognizedLine(text: text, x: 0, y: 1 - Double(index) * 0.05, width: 0.5, height: 0.04)
        }
        let evidence = ScreenshotEvidence(
            capturedAt: at(6, 17, 45), assetIdentifier: nil, parsed: parsed,
            lines: recognized, isGenuineScreenshot: true
        )
        context.insert(evidence)
        return evidence
    }

    private func makeRecord(level: VerificationLevel, withEvidence: Bool = true) -> EarningRecord {
        let record = EarningRecord(
            startTime: at(6, 9), endTime: at(6, 17, 30), platform: getir,
            province: "İstanbul", district: "Kadıköy", grossEarning: 980, packageCount: 11,
            source: withEvidence ? .ocr : .manual, verification: level, calendar: calendar
        )
        context.insert(record)
        if withEvidence {
            record.evidence = makeEvidence(lines: ocrLines)
        }
        return record
    }

    // MARK: - Ag kurali (Review Focus 1)

    func testSharingOff_noClientCalls() async {
        setConsents(sharing: false, calibration: false)
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)

        sync.recordSaved(record, vehicle: "motorcycle")
        await sync.flush()
        await sync.refreshTemplatesIfNeeded()
        let calibration = await sync.sendCalibration(record.evidence!)

        XCTAssertEqual(calibration, .invalid)
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(fake.callCount, 0)
        XCTAssertNil(sync.lastSyncDate)
    }

    func testNoClient_everythingNoop() async {
        setConsents(sharing: true, calibration: true)
        let sync = makeCoordinator(client: nil)
        let record = makeRecord(level: .ocrUnverified)

        sync.recordSaved(record, vehicle: "motorcycle")
        await sync.flush()
        let calibration = await sync.sendCalibration(record.evidence!)

        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(calibration, .invalid)
    }

    // MARK: - Kuyruk

    func testEligibleRecord_sentOnceAndRemembered() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)

        sync.recordSaved(record, vehicle: "motorcycle")
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.items.first?.kind, .shift)
        XCTAssertEqual(queue.items.first?.id, record.id)

        await sync.flush()
        XCTAssertEqual(fake.submittedShifts.count, 1)
        let sent = fake.submittedShifts.first
        XCTAssertEqual(sent?.level, "ocrUnverified")
        XCTAssertEqual(sent?.platformCode, "getir")
        XCTAssertEqual(sent?.vehicle, "motorcycle")
        XCTAssertEqual(sent?.textHash, TextHash.sha256(ocrLines))
        XCTAssertEqual(sent?.clientRecordID, record.id.uuidString.lowercased())
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertTrue(sync.sentRecordIDs.contains(record.id.uuidString))
        XCTAssertEqual(sync.lastSyncDate, now)

        // Ayni kayit tekrar kaydedilince kuyruga girmez
        sync.recordSaved(record, vehicle: "motorcycle")
        XCTAssertTrue(queue.items.isEmpty)
        await sync.flush()
        XCTAssertEqual(fake.submittedShifts.count, 1)
    }

    /// Haftalik ozet ekrani tek vardiya gibi gonderilmez.
    func testWeeklyEvidence_notQueued() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)
        record.evidence?.periodRaw = OCRTemplate.Period.week.rawValue

        sync.recordSaved(record, vehicle: "motorcycle")
        await sync.flush()

        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertTrue(fake.submittedShifts.isEmpty)

        // Gunluk ekran gonderilir
        let daily = makeRecord(level: .ocrUnverified)
        daily.evidence?.periodRaw = OCRTemplate.Period.day.rawValue
        sync.recordSaved(daily, vehicle: "motorcycle")
        XCTAssertEqual(queue.items.map(\.id), [daily.id])
    }

    func testOrderEvidence_notQueued() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)
        record.evidence?.periodRaw = OCRTemplate.Period.order.rawValue

        sync.recordSaved(record, vehicle: "motorcycle")
        await sync.flush()

        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertTrue(fake.submittedShifts.isEmpty)
    }

    /// `waitUntilIdle` suren gonderim bitene kadar doner.
    func testWaitUntilIdle_waitsForInFlightFlush() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        sync.recordSaved(makeRecord(level: .ocrUnverified), vehicle: "motorcycle")
        var events: [String] = []
        fake.onSubmitShift = {
            events.append("send-start")
            try? await Task.sleep(nanoseconds: 100_000_000)
            events.append("send-end")
        }

        let flushTask = Task { await sync.flush() }
        for _ in 0..<500 where fake.submittedShifts.isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(fake.submittedShifts.count, 1, "Gonderim baslamali")
        await sync.waitUntilIdle()
        events.append("idle")
        await flushTask.value

        XCTAssertEqual(events, ["send-start", "send-end", "idle"])
        // Bos durumda hemen doner
        await sync.waitUntilIdle()
    }

    func testResave_replacesQueuedItem() {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)

        sync.recordSaved(record, vehicle: "motorcycle")
        record.grossEarning = 900
        sync.recordSaved(record, vehicle: "motorcycle")

        XCTAssertEqual(queue.items.count, 1)
        let payload = try? JSONDecoder().decode(ShiftPayload.self, from: queue.items[0].payload)
        XCTAssertEqual(payload?.gross, 900)
    }

    func testManualRecord_notQueued() {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)

        sync.recordSaved(makeRecord(level: .manual, withEvidence: false), vehicle: "motorcycle")
        sync.recordSaved(makeRecord(level: .manual), vehicle: "motorcycle")

        XCTAssertTrue(queue.items.isEmpty)
    }

    func testRecordEditedLater_queuedItemRemoved() {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)
        sync.recordSaved(record, vehicle: "motorcycle")
        XCTAssertEqual(queue.items.count, 1)

        record.verification = .ocrEdited
        sync.recordSaved(record, vehicle: "motorcycle")

        XCTAssertTrue(queue.items.isEmpty)
    }

    func testRecordDeleted_removesOnlyItsShift() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let deleted = makeRecord(level: .ocrUnverified)
        let kept = makeRecord(level: .verified)
        sync.recordSaved(deleted, vehicle: "motorcycle")
        sync.recordSaved(kept, vehicle: "motorcycle")
        let calibrationID = UUID()
        queue.enqueue(OutboxItem(id: calibrationID, kind: .calibration, payload: Data("c".utf8), failures: 0, notBefore: now))

        sync.recordDeleted(id: deleted.id)
        sync.recordDeleted(id: calibrationID) // vardiya degil: dokunulmaz

        XCTAssertEqual(queue.items.map(\.id), [kept.id, calibrationID])
        await sync.flush()
        XCTAssertEqual(fake.submittedShifts.map(\.clientRecordID), [kept.id.uuidString.lowercased()])
    }

    func testAllRecordsDeleted_dropsPendingShiftsOnly() {
        setConsents(sharing: true, calibration: true)
        let sync = makeCoordinator(client: fake)
        sync.recordSaved(makeRecord(level: .ocrUnverified), vehicle: "motorcycle")
        let calibrationID = UUID()
        queue.enqueue(OutboxItem(id: calibrationID, kind: .calibration, payload: Data("c".utf8), failures: 0, notBefore: now))

        sync.allRecordsDeleted()

        XCTAssertEqual(queue.items.map(\.id), [calibrationID])
        XCTAssertEqual(fake.callCount, 0)
    }

    // MARK: - Sonuclar (Review Focus 3)

    func testDuplicate_removedAndRemembered() async {
        setConsents(sharing: true, calibration: false)
        fake.shiftResults = [.duplicate]
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)

        sync.recordSaved(record, vehicle: "motorcycle")
        await sync.flush()

        XCTAssertEqual(fake.submittedShifts.count, 1)
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertTrue(sync.sentRecordIDs.contains(record.id.uuidString))
        XCTAssertNil(sync.lastSyncDate)
    }

    func testTransient_staysWithBackoff() async {
        setConsents(sharing: true, calibration: false)
        fake.shiftResults = [.transient, .ok]
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)

        sync.recordSaved(record, vehicle: "motorcycle")
        await sync.flush()

        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.items.first?.failures, 1)
        XCTAssertEqual(queue.items.first?.notBefore, now.addingTimeInterval(60))
        XCTAssertNil(sync.lastSyncDate)

        // Hemen tekrar: zamani gelmedi, istek yok
        await sync.flush()
        XCTAssertEqual(fake.submittedShifts.count, 1)

        // Bekleme dolunca gonderilir
        now = now.addingTimeInterval(61)
        await sync.flush()
        XCTAssertEqual(fake.submittedShifts.count, 2)
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(sync.lastSyncDate, now)
    }

    func testRateLimited_defersAllShiftsUntilNextDay() async {
        setConsents(sharing: true, calibration: false)
        fake.shiftResults = [.rateLimited, .ok]
        let sync = makeCoordinator(client: fake)
        sync.recordSaved(makeRecord(level: .ocrUnverified), vehicle: "motorcycle")
        sync.recordSaved(makeRecord(level: .ocrUnverified), vehicle: "motorcycle")

        await sync.flush()

        // Ikinci oge bu turda denenmez; ikisi de ertesi gune kalir
        let nextDay: Date = OutboxPolicy.nextDay(after: now)
        XCTAssertEqual(fake.submittedShifts.count, 1)
        XCTAssertEqual(queue.items.count, 2)
        XCTAssertEqual(queue.items.map(\.notBefore), [nextDay, nextDay])
        XCTAssertEqual(queue.items.map(\.failures), [0, 0])
    }

    func testTransient_stopsFlushBeforeNextItem() async {
        setConsents(sharing: true, calibration: false)
        fake.shiftResults = [.transient, .ok]
        let sync = makeCoordinator(client: fake)
        let first = makeRecord(level: .ocrUnverified)
        let second = makeRecord(level: .ocrUnverified)
        sync.recordSaved(first, vehicle: "motorcycle")
        sync.recordSaved(second, vehicle: "motorcycle")

        await sync.flush()

        XCTAssertEqual(fake.submittedShifts.count, 1)
        XCTAssertEqual(fake.submittedShifts.first?.clientRecordID, first.id.uuidString.lowercased())
        XCTAssertEqual(queue.items.count, 2)
        XCTAssertEqual(queue.items.first { $0.id == first.id }?.failures, 1)
        XCTAssertEqual(queue.items.first { $0.id == second.id }?.failures, 0)
        XCTAssertEqual(queue.items.first { $0.id == second.id }?.notBefore, now)
    }

    // MARK: - Riza geri alma (Review Focus 5)

    func testSharingRevoked_clearsQueueAndSendsNothing() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        sync.recordSaved(makeRecord(level: .ocrUnverified), vehicle: "motorcycle")
        XCTAssertEqual(queue.items.count, 1)

        defaults.set(false, forKey: AppPreferences.dataSharingOptInKey)
        sync.sharingConsentChanged(enabled: false)
        XCTAssertTrue(queue.items.isEmpty)

        await sync.flush()
        XCTAssertEqual(fake.callCount, 0)
    }

    func testSharingRevokedWithoutNotification_flushDropsShifts() async {
        setConsents(sharing: true, calibration: true)
        let sync = makeCoordinator(client: fake)
        sync.recordSaved(makeRecord(level: .ocrUnverified), vehicle: "motorcycle")

        // Riza baska yerden kapandi; kalibrasyon acik oldugu icin flush calisir ama vardiya gonderilmez
        defaults.set(false, forKey: AppPreferences.dataSharingOptInKey)
        await sync.flush()

        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(fake.callCount, 0)
    }

    // MARK: - Kalibrasyon

    func testCalibration_withoutConsent_invalidAndNoCall() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let evidence = makeEvidence(lines: ocrLines)

        let result = await sync.sendCalibration(evidence)

        XCTAssertEqual(result, .invalid)
        XCTAssertEqual(fake.callCount, 0)
    }

    func testCalibration_withConsent_sendsMaskedLines() async {
        setConsents(sharing: false, calibration: true)
        let sync = makeCoordinator(client: fake)
        let evidence = makeEvidence(lines: ["Getir", "IBAN TR33 0006 1005 1978 6457 8413 26", "Toplam Kazanç", "₺980,00"])

        let result = await sync.sendCalibration(evidence)

        XCTAssertEqual(result, .ok)
        XCTAssertEqual(fake.submittedCalibrations.count, 1)
        let texts: [String] = fake.submittedCalibrations.first?.map(\.text) ?? []
        XCTAssertEqual(texts, ["Getir", "IBAN ***", "Toplam Kazanç", "₺980,00"])
        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(sync.lastSyncDate, now)
    }

    func testCalibration_transientQueuedAndRetried() async {
        setConsents(sharing: false, calibration: true)
        fake.calibrationResults = [.transient, .ok]
        let sync = makeCoordinator(client: fake)
        let evidence = makeEvidence(lines: ["Getir", "IBAN TR33 0006 1005 1978 6457 8413 26"])

        let result = await sync.sendCalibration(evidence)
        XCTAssertEqual(result, .transient)
        XCTAssertEqual(queue.items.count, 1)
        XCTAssertEqual(queue.items.first?.kind, .calibration)
        XCTAssertEqual(queue.items.first?.failures, 1)

        now = now.addingTimeInterval(61)
        await sync.flush()
        XCTAssertEqual(fake.submittedCalibrations.count, 2)
        XCTAssertEqual(fake.submittedCalibrations.last?.map(\.text), ["Getir", "IBAN ***"])
        XCTAssertTrue(queue.items.isEmpty)
    }

    func testCalibration_resendRemovesQueuedCopy() async {
        setConsents(sharing: false, calibration: true)
        fake.calibrationResults = [.transient, .ok]
        let sync = makeCoordinator(client: fake)
        let evidence = makeEvidence(lines: ["Getir", "Toplam Kazanç", "₺980,00"])

        let first = await sync.sendCalibration(evidence)
        XCTAssertEqual(first, .transient)
        XCTAssertEqual(queue.items.count, 1)

        // Elle tekrar gonderim basarili: kuyruktaki kopya da silinir
        let second = await sync.sendCalibration(evidence)
        XCTAssertEqual(second, .ok)
        XCTAssertTrue(queue.items.isEmpty)

        now = now.addingTimeInterval(61)
        await sync.flush()
        XCTAssertEqual(fake.submittedCalibrations.count, 2)
        XCTAssertTrue(queue.items.isEmpty)
    }

    // MARK: - Sablonlar

    func testRefreshTemplates_picksLatestAndThrottles() async {
        setConsents(sharing: true, calibration: false)
        let base: OCRTemplate = BundledTemplates.template(id: "getir.earnings")!
        var v2 = base
        v2.version = 2
        var v3 = base
        v3.version = 3
        fake.templates = [v2, v3, base]
        let sync = makeCoordinator(client: fake)

        await sync.refreshTemplatesIfNeeded()
        XCTAssertEqual(fake.fetchCount, 1)
        XCTAssertEqual(sync.remoteTemplates.map(\.version), [3])
        let merged = sync.mergedTemplates()
        XCTAssertEqual(merged.first { $0.id == "getir.earnings" }?.version, 3)
        XCTAssertEqual(merged.count, BundledTemplates.all.count)

        // 12 saat dolmadan tekrar cekilmez
        now = now.addingTimeInterval(11 * 3600)
        await sync.refreshTemplatesIfNeeded()
        XCTAssertEqual(fake.fetchCount, 1)

        now = now.addingTimeInterval(2 * 3600)
        await sync.refreshTemplatesIfNeeded()
        XCTAssertEqual(fake.fetchCount, 2)

        // Dosyaya yazildi: yeni koordinator diskten okur
        let reloaded = makeCoordinator(client: nil)
        XCTAssertEqual(reloaded.remoteTemplates.map(\.version), [3])
    }

    func testRefreshTemplates_failureKeepsPreviousAndRetries() async {
        setConsents(sharing: false, calibration: true)
        fake.templates = nil
        let sync = makeCoordinator(client: fake)

        await sync.refreshTemplatesIfNeeded()
        await sync.refreshTemplatesIfNeeded()

        XCTAssertEqual(fake.fetchCount, 2)
        XCTAssertTrue(sync.remoteTemplates.isEmpty)
        XCTAssertEqual(sync.mergedTemplates(), BundledTemplates.all)
    }

    // MARK: - Planlama kurallari

    func testRefreshRules_newVersionOverridesBundledAndPersists() async {
        setConsents(sharing: true, calibration: false)
        var updated: PlatformRule = BundledRules.all.first { $0.id == "tgo-peak" }!
        updated.version = 2
        updated.status = .verified
        updated.params.hours = 18
        fake.rules = [updated]
        let sync = makeCoordinator(client: fake)

        await sync.refreshRulesIfNeeded()
        XCTAssertEqual(fake.ruleFetchCount, 1)
        let rule: PlatformRule? = sync.ruleSet().latest.first { $0.id == "tgo-peak" }
        XCTAssertEqual(rule?.version, 2)
        XCTAssertEqual(rule?.params.hours, 18)
        XCTAssertEqual(sync.ruleSet().latest.count, BundledRules.all.count)

        now = now.addingTimeInterval(3600)
        await sync.refreshRulesIfNeeded()
        XCTAssertEqual(fake.ruleFetchCount, 1)

        let reloaded = makeCoordinator(client: nil)
        XCTAssertEqual(reloaded.ruleSet().latest.first { $0.id == "tgo-peak" }?.version, 2)
        XCTAssertNotNil(reloaded.rulesFetchedAt)
    }

    func testRefreshRules_noConsentOrFailureKeepsBundled() async {
        setConsents(sharing: false, calibration: false)
        let sync = makeCoordinator(client: fake)
        await sync.refreshRulesIfNeeded()
        XCTAssertEqual(fake.ruleFetchCount, 0)

        setConsents(sharing: true, calibration: false)
        fake.rules = nil
        await sync.refreshRulesIfNeeded()
        XCTAssertEqual(fake.ruleFetchCount, 1)
        XCTAssertNil(sync.rulesFetchedAt)
        XCTAssertEqual(sync.ruleSet().latest.count, BundledRules.all.count)
    }

    // MARK: - OutboxQueue

    func testQueue_persistsAndReplacesSameID() {
        let url = directory.appendingPathComponent("q.json")
        let first = OutboxQueue(fileURL: url)
        let id = UUID()
        first.enqueue(OutboxItem(id: id, kind: .shift, payload: Data("a".utf8), failures: 0, notBefore: now))
        first.enqueue(OutboxItem(id: id, kind: .shift, payload: Data("b".utf8), failures: 0, notBefore: now))
        first.enqueue(OutboxItem(id: UUID(), kind: .calibration, payload: Data("c".utf8), failures: 0, notBefore: now))

        let second = OutboxQueue(fileURL: url)
        XCTAssertEqual(second.items, first.items)
        XCTAssertEqual(second.items.count, 2)
        XCTAssertEqual(second.items.last?.kind, .calibration)

        second.removeAll(kind: .calibration)
        XCTAssertEqual(OutboxQueue(fileURL: url).items.map(\.payload), [Data("b".utf8)])

        // Silinmis ogeyi replace geri getirmez
        second.remove(id: id)
        second.replace(OutboxItem(id: id, kind: .shift, payload: Data("x".utf8), failures: 1, notBefore: now))
        XCTAssertTrue(second.items.isEmpty)
    }
}
