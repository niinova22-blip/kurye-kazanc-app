import Foundation
import Observation

/// Riza + kayit degisince gonderim kuyrugunu yonetir, kuyrugu bosaltir, uzak sablonlari ceker,
/// kalibrasyon ornegi gonderir (spec 4).
///
/// Ag kurali: `client` nil ise (sunucu ayari yok) her sey no-op. Paylasim VE kalibrasyon rizasi
/// kapaliyken istemciye hicbir cagri yapilmaz (flush ve sablon cekimi dahil).
@MainActor
@Observable
final class SyncCoordinator {
    /// Uzak sablonlar en fazla bu siklikta cekilir.
    static let templateRefreshInterval: TimeInterval = 12 * 60 * 60

    private(set) var lastSyncDate: Date?
    private(set) var remoteTemplates: [OCRTemplate]

    private let client: (any SupabaseServing)?
    private let queue: OutboxQueue
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let clock: () -> Date
    private let templatesFileURL: URL

    @ObservationIgnored private var isFlushing: Bool = false
    @ObservationIgnored private var isRefreshingTemplates: Bool = false
    /// Suren gonderim (flush / sendCalibration) sayisi; `waitUntilIdle` bunlarin bitmesini bekler.
    @ObservationIgnored private var activeSends: Int = 0
    @ObservationIgnored private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    /// - Parameter templatesFileURL: Testler icin; nil ise Application Support/remote_templates.json.
    init(
        client: (any SupabaseServing)?,
        queue: OutboxQueue,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        clock: @escaping () -> Date = { Date() },
        templatesFileURL: URL? = nil
    ) {
        self.client = client
        self.queue = queue
        self.defaults = defaults
        self.calendar = calendar
        self.clock = clock
        let fileURL: URL = templatesFileURL ?? SyncCoordinator.defaultTemplatesFileURL()
        self.templatesFileURL = fileURL
        self.remoteTemplates = SyncCoordinator.loadTemplates(from: fileURL)
        self.lastSyncDate = SyncCoordinator.date(forKey: AppPreferences.lastSyncDateKey, in: defaults)
    }

    /// Sunucu ayari var mi (istemci olusturuldu mu).
    var isServerAvailable: Bool { client != nil }

    // MARK: - Riza

    var isSharingEnabled: Bool {
        defaults.bool(forKey: AppPreferences.dataSharingOptInKey)
    }

    var isCalibrationEnabled: Bool {
        defaults.bool(forKey: AppPreferences.calibrationOptInKey)
    }

    /// Paylasim veya kalibrasyon rizasi yoksa ag kullanilmaz.
    private var isNetworkAllowed: Bool {
        isSharingEnabled || isCalibrationEnabled
    }

    /// Kapatilinca bekleyen vardiyalar gonderilmeden silinir. Acilinca gecmis kayitlar eklenmez.
    func sharingConsentChanged(enabled: Bool) {
        guard !enabled else { return }
        queue.removeAll(kind: .shift)
    }

    /// Kapatilinca bekleyen kalibrasyon ornekleri gonderilmeden silinir.
    func calibrationConsentChanged(enabled: Bool) {
        guard !enabled else { return }
        queue.removeAll(kind: .calibration)
    }

    // MARK: - Kayit

    /// Kayit kaydedildi/duzenlendi. Uygunsa kuyruga eklenir (ayni kayit icin eski oge degisir);
    /// artik uygun degilse (or. sonradan `ocrEdited`) bekleyen ogesi silinir.
    func recordSaved(_ record: EarningRecord, vehicle: String) {
        guard client != nil, isSharingEnabled else { return }
        guard !sentRecordIDs.contains(record.id.uuidString) else { return }
        guard let data = shiftPayloadData(for: record, vehicle: vehicle) else {
            queue.remove(id: record.id)
            return
        }
        let item = OutboxItem(id: record.id, kind: .shift, payload: data, failures: 0, notBefore: clock())
        queue.enqueue(item)
    }

    private func shiftPayloadData(for record: EarningRecord, vehicle: String) -> Data? {
        // Haftalik ozet ve tek siparis karti vardiya degildir: gonderilmez (yalnizca gunluk / belirsiz donem).
        guard let evidence = record.evidence, evidence.period != .week, evidence.period != .order else { return nil }
        let hash: String = TextHash.sha256(evidence.lines.map(\.text))
        let payload: ShiftPayload? = ShiftPayloadBuilder.make(
            recordID: record.id, platformCode: record.platform?.code,
            province: record.province, district: record.district, vehicle: vehicle,
            start: record.startTime, end: record.endTime,
            gross: record.grossEarning, bonus: record.bonus, packages: record.packageCount,
            distanceKm: record.distanceKm, level: record.verification.rawValue,
            templateID: evidence.templateID, templateVersion: evidence.templateVersion,
            textHash: hash, calendar: calendar
        )
        guard let payload else { return nil }
        return try? JSONEncoder().encode(payload)
    }

    /// Kayit silindi: bekleyen vardiyasi gonderilmeden cikarilir (yerel islem, ag yok).
    /// Kalibrasyon ogeleri kanit id'si tasir; onlara dokunulmaz.
    func recordDeleted(id: UUID) {
        guard queue.items.contains(where: { $0.id == id && $0.kind == .shift }) else { return }
        queue.remove(id: id)
    }

    /// "Tum kayitlari sil": bekleyen tum vardiyalar gonderilmeden silinir (yerel islem, ag yok).
    func allRecordsDeleted() {
        queue.removeAll(kind: .shift)
    }

    // MARK: - Gonderim

    /// Zamani gelmis ogeleri sirayla gonderir. Gecici hatada durur (ag yok varsayilir);
    /// gunluk sinirda o turdeki diger ogeler bu turda denenmez.
    func flush() async {
        guard let client, !isFlushing else { return }
        dropItemsWithoutConsent()
        guard isNetworkAllowed else { return }
        isFlushing = true
        beginSend()
        defer {
            isFlushing = false
            endSend()
        }

        let now: Date = clock()
        var limitedKinds: Set<OutboxItem.Kind> = []
        var anyOK: Bool = false
        for item in queue.items where item.notBefore <= now {
            guard queue.contains(id: item.id), hasConsent(for: item.kind) else { continue }
            guard !limitedKinds.contains(item.kind) else { continue }
            let result: OutboxResult = await send(item, using: client)
            if result == .ok {
                anyOK = true
            }
            apply(result, to: item)
            if result == .transient {
                break
            }
            if result == .rateLimited {
                limitedKinds.insert(item.kind)
            }
        }
        if anyOK {
            markSynced(now)
        }
    }

    private func send(_ item: OutboxItem, using client: any SupabaseServing) async -> OutboxResult {
        let decoder = JSONDecoder()
        switch item.kind {
        case .shift:
            guard let payload = try? decoder.decode(ShiftPayload.self, from: item.payload) else { return .invalid }
            return await client.submitShift(payload)
        case .calibration:
            guard let sample = try? decoder.decode(CalibrationOutboxPayload.self, from: item.payload) else {
                return .invalid
            }
            return await client.submitCalibration(
                platformCode: sample.platformCode, templateID: sample.templateID, lines: sample.lines
            )
        }
    }

    /// Sonucu kuyruga yansitir. Gonderim surerken oge degistiyse (kayit yeniden kaydedildi) ya da
    /// silindiyse (riza kapandi) yeni hal korunur.
    private func apply(_ result: OutboxResult, to item: OutboxItem) {
        let isUnchanged: Bool = queue.items.first(where: { $0.id == item.id }) == item
        if OutboxPolicy.isFinal(result) {
            if item.kind == .shift, result != .invalid {
                markSent(item.id)
            }
            if isUnchanged {
                queue.remove(id: item.id)
            }
            return
        }
        if result == .rateLimited {
            deferAll(of: item.kind)
        }
        guard isUnchanged else { return }
        queue.replace(rescheduled(item, after: result))
    }

    /// Gunluk sinir kullaniciya ozgu: o turdeki tum bekleyen ogeler ertesi gune kalir.
    private func deferAll(of kind: OutboxItem.Kind) {
        let nextDay: Date = OutboxPolicy.nextDay(after: clock())
        for queued in queue.items where queued.kind == kind && queued.notBefore < nextDay {
            var updated: OutboxItem = queued
            updated.notBefore = nextDay
            queue.replace(updated)
        }
    }

    private func rescheduled(_ item: OutboxItem, after result: OutboxResult) -> OutboxItem {
        var updated: OutboxItem = item
        let now: Date = clock()
        if result == .rateLimited {
            updated.notBefore = OutboxPolicy.nextDay(after: now)
        } else {
            updated.failures += 1
            updated.notBefore = OutboxPolicy.nextAttempt(after: updated.failures, now: now)
        }
        return updated
    }

    private func hasConsent(for kind: OutboxItem.Kind) -> Bool {
        switch kind {
        case .shift: return isSharingEnabled
        case .calibration: return isCalibrationEnabled
        }
    }

    /// Rizasi geri alinmis turdeki ogeler gonderilmeden silinir (yerel islem, ag yok).
    private func dropItemsWithoutConsent() {
        if !isSharingEnabled {
            queue.removeAll(kind: .shift)
        }
        if !isCalibrationEnabled {
            queue.removeAll(kind: .calibration)
        }
    }

    // MARK: - Kalibrasyon

    /// Kalibrasyon rizasi yoksa istek atilmadan `.invalid`. Satirlar maskelenerek gonderilir.
    /// Gecici hata / gunluk sinirda ornek kuyruga alinir ve sonra tekrar denenir.
    func sendCalibration(_ evidence: ScreenshotEvidence) async -> OutboxResult {
        guard let client, isCalibrationEnabled else { return .invalid }
        let sample = CalibrationOutboxPayload(
            platformCode: evidence.platformCode,
            templateID: evidence.templateID,
            lines: SyncCoordinator.maskedLines(evidence.lines)
        )
        guard !sample.lines.isEmpty else { return .invalid }
        // Ayni ornegin kuyruktaki kopyasi da gonderilmesin (sunucu kalibrasyonda tekrar ayiklamaz);
        // basarisizlikta asagida yeniden kuyruga alinir.
        queue.remove(id: evidence.id)
        let sampleID: UUID = evidence.id
        beginSend()
        let result: OutboxResult = await client.submitCalibration(
            platformCode: sample.platformCode, templateID: sample.templateID, lines: sample.lines
        )
        endSend()
        if result == .ok {
            markSynced(clock())
        }
        if !OutboxPolicy.isFinal(result), isCalibrationEnabled {
            enqueueCalibrationRetry(id: sampleID, sample: sample, after: result)
        }
        return result
    }

    private func enqueueCalibrationRetry(id: UUID, sample: CalibrationOutboxPayload, after result: OutboxResult) {
        guard let data = try? JSONEncoder().encode(sample) else { return }
        let fresh = OutboxItem(id: id, kind: .calibration, payload: data, failures: 0, notBefore: clock())
        queue.enqueue(rescheduled(fresh, after: result))
        if result == .rateLimited {
            deferAll(of: .calibration)
        }
    }

    static func maskedLines(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        lines.map { line in
            var masked: RecognizedLine = line
            masked.text = CalibrationMasker.mask(line.text)
            return masked
        }
    }

    // MARK: - Bekleme

    /// Suren gonderim yoksa hemen doner; varsa hepsi bitince doner ("Verilerimi sil" oncesi).
    func waitUntilIdle() async {
        guard activeSends > 0 else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            idleWaiters.append(continuation)
        }
    }

    private func beginSend() {
        activeSends += 1
    }

    private func endSend() {
        activeSends = max(0, activeSends - 1)
        guard activeSends == 0 else { return }
        let waiters: [CheckedContinuation<Void, Never>] = idleWaiters
        idleWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }

    // MARK: - Sablonlar

    /// Uygulama acilisinda cagrilir: riza yoksa ya da son cekimden 12 saat gecmediyse istek yok.
    func refreshTemplatesIfNeeded() async {
        guard let client, isNetworkAllowed, !isRefreshingTemplates else { return }
        let now: Date = clock()
        if let last = SyncCoordinator.date(forKey: AppPreferences.templatesFetchedAtKey, in: defaults) {
            let elapsed: TimeInterval = now.timeIntervalSince(last)
            // Saat geri alinmissa (elapsed < 0) beklemeden tekrar cekilir.
            if elapsed >= 0, elapsed < SyncCoordinator.templateRefreshInterval { return }
        }
        isRefreshingTemplates = true
        defer { isRefreshingTemplates = false }

        guard let fetched = await client.fetchTemplates() else { return }
        let latest: [OCRTemplate] = SyncCoordinator.latestVersions(fetched)
        remoteTemplates = latest
        saveTemplates(latest)
        defaults.set(now.timeIntervalSince1970, forKey: AppPreferences.templatesFetchedAtKey)
    }

    /// Gomulu + uzak sablonlar (ayni id icin yuksek surum).
    func mergedTemplates() -> [OCRTemplate] {
        TemplateMerger.merge(bundled: BundledTemplates.all, remote: remoteTemplates)
    }

    /// Sunucu her sablonun tum surumlerini dondurur: id basina en yuksek surum, id'ye gore sirali.
    static func latestVersions(_ templates: [OCRTemplate]) -> [OCRTemplate] {
        var best: [String: OCRTemplate] = [:]
        for template in templates {
            if let existing = best[template.id], existing.version >= template.version { continue }
            best[template.id] = template
        }
        return best.values.sorted { $0.id < $1.id }
    }

    private static func defaultTemplatesFileURL() -> URL {
        let base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("remote_templates.json")
    }

    private static func loadTemplates(from url: URL) -> [OCRTemplate] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([OCRTemplate].self, from: data)) ?? []
    }

    private func saveTemplates(_ templates: [OCRTemplate]) {
        let directory: URL = templatesFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(templates) else { return }
        try? data.write(to: templatesFileURL, options: OutboxQueue.writeOptions)
    }

    // MARK: - Kalici durum

    var sentRecordIDs: Set<String> {
        Set(defaults.stringArray(forKey: AppPreferences.sentRecordIDsKey) ?? [])
    }

    private func markSent(_ id: UUID) {
        var ids: [String] = defaults.stringArray(forKey: AppPreferences.sentRecordIDsKey) ?? []
        let key: String = id.uuidString
        guard !ids.contains(key) else { return }
        ids.append(key)
        defaults.set(ids, forKey: AppPreferences.sentRecordIDsKey)
    }

    private func markSynced(_ date: Date) {
        lastSyncDate = date
        defaults.set(date.timeIntervalSince1970, forKey: AppPreferences.lastSyncDateKey)
    }

    private static func date(forKey key: String, in defaults: UserDefaults) -> Date? {
        guard let seconds = defaults.object(forKey: key) as? Double else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
