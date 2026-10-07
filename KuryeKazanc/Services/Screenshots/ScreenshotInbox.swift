import Foundation

/// Paylas eklentisi ile uygulama arasindaki gelen kutusu (App Group klasoru).
/// Eklenti gorseli buraya birakir; uygulama acilinca isler ve siler. SwiftData deposu paylasilmaz.
struct ScreenshotInbox {
    static let appGroupID = "group.com.kuryekazanc.app"

    enum InboxError: Error { case unavailable }

    let directory: URL?

    init(directory: URL?) {
        self.directory = directory
    }

    static var shared: ScreenshotInbox {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        return ScreenshotInbox(directory: base?.appendingPathComponent("Inbox", isDirectory: true))
    }

    func add(_ data: Data) throws {
        guard let directory else { throw InboxError.unavailable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString).img"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    /// Eskiden yeniye.
    func pending() -> [URL] {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "img" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Dosyayi isleme icin "sahiplenir": adini degistirir ki ikinci bir tarama ayni gorseli gormesin.
    /// Baska bir tarama once aldiysa nil.
    func claim(_ url: URL) -> URL? {
        let claimed = url.deletingPathExtension().appendingPathExtension("processing")
        do {
            try FileManager.default.moveItem(at: url, to: claimed)
            return claimed
        } catch {
            return nil
        }
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
