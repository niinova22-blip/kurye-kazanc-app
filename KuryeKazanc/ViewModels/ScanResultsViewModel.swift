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
        var id: String { item.id }
    }

    private(set) var rows: [Row] = []
    /// Gunlukte bitis yok: tarama yarida kesildi.
    var interrupted: Bool
    /// Son kaydetmede dogrulamadan gecemeyip atlanan kalem sayisi.
    private(set) var skippedCount = 0

    @ObservationIgnored private let store: BroadcastCaptureStore
    @ObservationIgnored private let importer: ScreenshotImporter
    @ObservationIgnored private let knownTextHashes: Set<String>
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: Date

    init(store: BroadcastCaptureStore, templates: [OCRTemplate]?, knownTextHashes: Set<String>,
         interrupted: Bool, calendar: Calendar = .current, now: Date = .now) {
        self.store = store
        self.importer = ScreenshotImporter(verifier: ScreenshotVerifier(calendar: calendar), templates: templates)
        self.knownTextHashes = knownTextHashes
        self.interrupted = interrupted
        self.calendar = calendar
        self.now = now
    }

    var selectedCount: Int { rows.filter { $0.isSelected && !$0.isAlreadySaved }.count }

    func load() {
        var inputs: [ScanInput] = []
        for url in store.pending() {
            // Bozuk dosya atlanir
            guard let capture = store.load(url) else { continue }
            let imported = importer.importCapture(lines: capture.lines, capturedAt: capture.capturedAt, referenceDate: now)
            inputs.append(ScanInput(parsed: imported.parsed, lines: capture.lines, capturedAt: capture.capturedAt))
        }
        rows = ScanResultBuilder(calendar: calendar).build(inputs).map { item in
            let saved = knownTextHashes.contains(item.textHash)
            let defaultOn: Bool
            switch item.kind {
            case .daily, .orderGroup: defaultOn = true
            case .weekly, .unknown: defaultOn = false
            }
            return Row(item: item, isSelected: defaultOn && !saved, isAlreadySaved: saved)
        }
    }

    func setSelected(_ selected: Bool, for id: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }), !rows[index].isAlreadySaved else { return }
        rows[index].isSelected = selected
    }

    /// Secili kalemleri form yoluyla kaydeder. Kaydetme bu ekrandaki acik onaydir; "kontrol et" vurgulari
    /// kaydi engellemez, yalnizca dogrulama hatasi (or. platform bulunamadi) kalemi atlatir.
    @discardableResult
    func save(in context: ModelContext, platforms: [Platform]) throws -> [EarningRecord] {
        skippedCount = 0
        var saved: [EarningRecord] = []
        for row in rows where row.isSelected && !row.isAlreadySaved {
            let item = row.item
            let imported = importer.makeImported(parsed: item.parsed, lines: item.lines,
                                                 capturedAt: item.capturedAt, referenceDate: now)
            let form = EarningFormViewModel(defaultPlatform: nil, now: item.capturedAt, calendar: calendar)
            form.apply(imported, platforms: platforms, knownTextHashes: knownTextHashes)
            guard form.canSave else {
                skippedCount += 1
                continue
            }
            saved.append(try form.save(in: context))
        }
        store.removeAll()
        rows = []
        return saved
    }

    func discard() {
        store.removeAll()
        rows = []
    }
}
