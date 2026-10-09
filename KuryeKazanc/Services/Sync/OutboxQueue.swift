import Foundation

/// Bekleyen bir gonderim. Vardiya icin `id` kaydin id'sidir; kalibrasyon icin kanitin id'si.
struct OutboxItem: Codable, Equatable {
    enum Kind: String, Codable {
        case shift
        case calibration
    }

    var id: UUID
    var kind: Kind
    /// JSON yuk (vardiya: `ShiftPayload`, kalibrasyon: `CalibrationOutboxPayload`).
    var payload: Data
    var failures: Int
    /// Bu andan once tekrar denenmez.
    var notBefore: Date
}

/// Kuyruktaki kalibrasyon ornegi (satirlar zaten maskelenmis).
struct CalibrationOutboxPayload: Codable, Equatable {
    var platformCode: String?
    var templateID: String?
    var lines: [RecognizedLine]
}

/// Bekleyen gonderimler. Her degisiklikte dosyaya JSON olarak atomik yazilir; acilista okunur.
/// Ag yok: yalnizca yerel dosya.
final class OutboxQueue {
    private let fileURL: URL
    private(set) var items: [OutboxItem]

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.items = OutboxQueue.load(from: fileURL)
    }

    /// Varsayilan konum: Application Support/outbox.json
    static func defaultFileURL() -> URL {
        let base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("outbox.json")
    }

    /// Ayni id varsa eski oge cikarilir, yenisi sona eklenir.
    func enqueue(_ item: OutboxItem) {
        items.removeAll { $0.id == item.id }
        items.append(item)
        save()
    }

    func remove(id: UUID) {
        let before: Int = items.count
        items.removeAll { $0.id == id }
        if items.count != before {
            save()
        }
    }

    /// Ayni id'li ogeyi yerinde gunceller; oge yoksa (bu arada silinmisse) hicbir sey yapmaz.
    func replace(_ item: OutboxItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func contains(id: UUID) -> Bool {
        items.contains { $0.id == id }
    }

    func removeAll() {
        items = []
        save()
    }

    func removeAll(kind: OutboxItem.Kind) {
        let before: Int = items.count
        items.removeAll { $0.kind == kind }
        if items.count != before {
            save()
        }
    }

    // MARK: - Dosya

    private static func load(from url: URL) -> [OutboxItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([OutboxItem].self, from: data)) ?? []
    }

    /// Atomik yazim; iOS'ta cihazin ilk kilit acilisina kadar dosya korumali.
    static var writeOptions: Data.WritingOptions {
        #if os(iOS)
        return [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        return [.atomic]
        #endif
    }

    private func save() {
        let directory: URL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: OutboxQueue.writeOptions)
    }
}
