import Foundation

/// Yayin eklentisinin kabul ettigi ekranlarin App Group deposu. Eklenti yazar, uygulama okuyup siler.
struct BroadcastCaptureStore {
    private let directory: URL?

    static var shared: BroadcastCaptureStore {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ScreenshotInbox.appGroupID)
        return BroadcastCaptureStore(directory: base?.appendingPathComponent("BroadcastCaptures", isDirectory: true))
    }

    init(directory: URL?) {
        self.directory = directory
    }

    func save(_ capture: BroadcastCapture) throws {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ms = Int(Date().timeIntervalSince1970 * 1000)
        let url = directory.appendingPathComponent("\(ms)-\(UUID().uuidString).json")
        try JSONEncoder().encode(capture).write(to: url, options: .atomic)
    }

    /// Eskiden yeniye (dosya adi milisaniye ile baslar).
    func pending() -> [URL] {
        guard let directory,
              let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        return urls.filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Bozuk dosyada nil.
    func load(_ url: URL) -> BroadcastCapture? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BroadcastCapture.self, from: data)
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func removeAll() {
        pending().forEach(remove)
    }
}
