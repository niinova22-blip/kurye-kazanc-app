import Foundation
import Observation
import SwiftData

/// Kazanc taramasi sonuc ekrani: yayin eklentisinin biraktigi yakalamalari kalemlere cevirir,
/// secilenleri mevcut form yoluyla kaydeder ve yakalama dosyalarini siler.
@MainActor
@Observable
final class ScanResultsViewModel {
    struct Row: Identifiable {
        let item: ScanItem
        var isSelected: Bool
        let isAlreadySaved: Bool
        /// Ayni platform ve gun icin farkli tutarli bir kayit var: varsayilan secili degil.
        var hasSameDayRecord = false
        var id: String { item.id }
    }

    private(set) var rows: [Row] = []
    /// Gunlukte bitis yok: tarama yarida kesildi.
    var interrupted: Bool
    /// Son kaydetmede dogrulamadan gecemeyip atlanan kalem sayisi.
    private(set) var skippedCount = 0
    /// Kaydederken hata alan (veritabani) kalem sayisi.
    private(set) var failedCount = 0
    /// Atlanan kalemlerden ilkinin nedeni (dogrulama hatasi).
    private(set) var firstSkipReason: String?
    /// Son kaydetmede olusan kayitlardan topluluga gonderilebilecekler (ekranda calisma suresi olanlar).
    private(set) var sendableRecordIDs: Set<UUID> = []

    /// Var olan bir kaydin ozeti (tekrar tarama kontrolu icin).
    struct ExistingDaily: Equatable {
        var platformCode: String?
        var day: Date
        var gross: Double
    }

    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var itemFiles: [String: [URL]] = [:]
    @ObservationIgnored private var orphanFiles: [URL] = []
    /// Kalemlerin geldigi yer: yayin yakalamalari (dosyali) veya fotograf taramasi (dosyasiz).
    @ObservationIgnored private let store: BroadcastCaptureStore?
    @ObservationIgnored private let photoResults: [PhotoScanResult]?
    @ObservationIgnored private let region: PlaceRegion?
    @ObservationIgnored private var itemPhotos: [String: [PhotoScanResult]] = [:]
    @ObservationIgnored private let importer: ScreenshotImporter
    @ObservationIgnored private let knownTextHashes: Set<String>
    @ObservationIgnored private let existingDaily: [ExistingDaily]
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: Date

    init(store: BroadcastCaptureStore, templates: [OCRTemplate]?, knownTextHashes: Set<String>,
         existingDaily: [ExistingDaily] = [], interrupted: Bool, calendar: Calendar = .current, now: Date = .now) {
        self.store = store
        self.photoResults = nil
        self.region = nil
        self.importer = ScreenshotImporter(verifier: ScreenshotVerifier(calendar: calendar), templates: templates)
        self.knownTextHashes = knownTextHashes
        self.existingDaily = existingDaily
        self.interrupted = interrupted
        self.calendar = calendar
        self.now = now
    }

    /// Fotograf taramasi kaynagi: dosya yok; kanita PhotoKit kimligi yazilir, bolge bos formlara doldurulur.
    init(photoResults: [PhotoScanResult], templates: [OCRTemplate]? = nil, knownTextHashes: Set<String>,
         existingDaily: [ExistingDaily] = [], region: PlaceRegion? = nil, calendar: Calendar = .current,
         now: Date = .now) {
        self.store = nil
        self.photoResults = photoResults
        self.region = region
        self.importer = ScreenshotImporter(verifier: ScreenshotVerifier(calendar: calendar), templates: templates)
        self.knownTextHashes = knownTextHashes
        self.existingDaily = existingDaily
        self.interrupted = false
        self.calendar = calendar
        self.now = now
    }

    /// Yalnizca ekranda gunluk calisma suresi okunan kalemler topluluga gonderilir; digerlerinde saat tahminidir.
    static func isSendable(_ item: ScanItem) -> Bool {
        item.parsed.period == .day && item.parsed.workDuration != nil
    }

    /// Ayni platform + gun icin mevcut kayitlarin tutarlari.
    private func sameDayGross(for item: ScanItem) -> [Double] {
        guard item.kind == .daily else { return [] }
        let day = calendar.startOfDay(for: item.parsed.date)
        return existingDaily
            .filter { $0.platformCode == item.parsed.platformCode && calendar.startOfDay(for: $0.day) == day }
            .map(\.gross)
    }

    var selectedCount: Int { rows.filter { $0.isSelected && !$0.isAlreadySaved }.count }

    /// Ilk yuklemeden sonra tekrar cagrilarda secimler korunur.
    func loadIfNeeded() {
        guard !hasLoaded else { return }
        load()
    }

    func load() {
        hasLoaded = true
        if let photoResults {
            loadPhotos(photoResults)
            return
        }
        guard let store else { return }
        var inputs: [ScanInput] = []
        var inputURLs: [URL] = []
        var orphans: [URL] = []
        let builder = ScanResultBuilder(calendar: calendar)
        for url in store.pending() {
            // Bozuk dosya atlanir (kaydet / vazgecte silinir)
            guard let capture = store.load(url) else { orphans.append(url); continue }
            let imported = importer.importCapture(lines: capture.lines, capturedAt: capture.capturedAt, referenceDate: now)
            inputs.append(ScanInput(parsed: imported.parsed, lines: capture.lines, capturedAt: capture.capturedAt))
            inputURLs.append(url)
        }
        var files: [String: [URL]] = [:]
        for (input, url) in zip(inputs, inputURLs) {
            if let id = builder.itemID(for: input) {
                files[id, default: []].append(url)
            } else {
                orphans.append(url)
            }
        }
        itemFiles = files
        orphanFiles = orphans
        rows = makeRows(builder.build(inputs))
    }

    private func loadPhotos(_ results: [PhotoScanResult]) {
        let builder = ScanResultBuilder(calendar: calendar)
        var grouped: [String: [PhotoScanResult]] = [:]
        for result in results {
            if let id = builder.itemID(for: result.input) { grouped[id, default: []].append(result) }
        }
        itemPhotos = grouped
        rows = makeRows(builder.build(results.map(\.input)))
    }

    private func makeRows(_ items: [ScanItem]) -> [Row] {
        items.map { item in
            let sameDay = sameDayGross(for: item)
            let sameTotal = sameDay.contains { abs($0 - item.parsed.totalEarning) < 0.01 }
            let saved = knownTextHashes.contains(item.textHash) || sameTotal
            let hasSameDay = !saved && !sameDay.isEmpty
            let defaultOn: Bool
            switch item.kind {
            case .daily, .orderGroup: defaultOn = true
            case .weekly, .unknown: defaultOn = false
            }
            // Haftalik ozet vardiya degildir: asla secilemez, kaydedilmez
            return Row(item: item, isSelected: defaultOn && !saved && !hasSameDay && item.kind != .weekly,
                       isAlreadySaved: saved,
                       hasSameDayRecord: hasSameDay)
        }
    }

    func setSelected(_ selected: Bool, for id: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }), !rows[index].isAlreadySaved,
              rows[index].item.kind != .weekly else { return }
        rows[index].isSelected = selected
    }

    /// Secili kalemleri form yoluyla kaydeder. Kaydetme bu ekrandaki acik onaydir; "kontrol et" vurgulari
    /// kaydi engellemez, yalnizca dogrulama hatasi (or. platform bulunamadi) kalemi atlatir.
    @discardableResult
    func save(in context: ModelContext, platforms: [Platform]) throws -> [EarningRecord] {
        skippedCount = 0
        failedCount = 0
        firstSkipReason = nil
        sendableRecordIDs = []
        var saved: [EarningRecord] = []
        for row in rows where row.isSelected && !row.isAlreadySaved {
            let item = row.item
            let imported = importedEvidence(for: item)
            let form = EarningFormViewModel(defaultPlatform: nil, now: item.capturedAt, calendar: calendar)
            form.apply(imported, platforms: platforms, knownTextHashes: knownTextHashes)
            if photoResults != nil, let region {
                if form.province.isEmpty { form.province = region.province ?? "" }
                if form.district.isEmpty { form.district = region.district ?? "" }
                if form.neighborhood.isEmpty { form.neighborhood = region.neighborhood ?? "" }
            }
            guard form.canSave else {
                // Secili ama kaydedilemeyen kalemin dosyalari silinmez
                skippedCount += 1
                if firstSkipReason == nil { firstSkipReason = form.validationErrors.first }
                continue
            }
            // Tek kalemin kayit hatasi oncekilerin kuyruga alinmasini engellemez
            do {
                let record = try form.save(in: context)
                saved.append(record)
                if Self.isSendable(item) { sendableRecordIDs.insert(record.id) }
                removeFiles(for: item.id)
            } catch {
                failedCount += 1
            }
        }
        // Secilmeyen kalemler ve kalem uretmeyen dosyalar silinir; atlananlar kalir
        let skippedIDs = rows.filter { row in
            row.isSelected && !row.isAlreadySaved && itemFiles[row.id] != nil
        }.map(\.id)
        let kept = Set(skippedIDs)
        for id in Array(itemFiles.keys) where !kept.contains(id) { removeFiles(for: id) }
        if let store { orphanFiles.forEach(store.remove) }
        orphanFiles = []
        if skippedCount > 0 || failedCount > 0 {
            load()
        } else {
            rows = []
        }
        return saved
    }

    /// Fotograf kaynaginda tek kalem orijinal kanitini (kimlik, gercek ekran) korur; siparis grubu birlestirilir.
    private func importedEvidence(for item: ScanItem) -> ImportedScreenshot {
        if let photos = itemPhotos[item.id], !photos.isEmpty {
            if case .orderGroup = item.kind {
                var merged = importer.makeImported(parsed: item.parsed, lines: item.lines,
                                                   capturedAt: item.capturedAt, referenceDate: now)
                merged.assetIdentifier = photos.first?.imported.assetIdentifier
                merged.isGenuine = photos.allSatisfy(\.imported.isGenuine)
                return merged
            }
            return photos[0].imported
        }
        return importer.makeImported(parsed: item.parsed, lines: item.lines,
                                     capturedAt: item.capturedAt, referenceDate: now)
    }

    private func removeFiles(for id: String) {
        guard let store else { return }
        itemFiles[id]?.forEach(store.remove)
        itemFiles[id] = nil
    }

    func discard() {
        store?.removeAll()
        rows = []
    }
}
