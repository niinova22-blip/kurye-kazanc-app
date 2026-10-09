import AppIntents
import Foundation

/// Kisayollar otomasyonundan ekran goruntusunu paylasim sayfasi olmadan gelen kutusuna birakir.
struct SendScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Kurye Kazanç'a ekran görüntüsü gönder"
    static var description = IntentDescription("Ekran görüntüsünü Kurye Kazanç'a bırakır; uygulamayı açınca okunur.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Görüntü", supportedTypeIdentifiers: ["public.image"])
    var image: IntentFile

    /// Test icin gelen kutusu disaridan verilir.
    static func store(_ data: Data, in inbox: ScreenshotInbox) throws {
        try inbox.add(data)
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try Self.store(image.data, in: .shared)
        return .result(dialog: "Gönderildi; Kurye Kazanç'ı açınca okunur.")
    }
}

struct KuryeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendScreenshotIntent(),
            phrases: ["\(.applicationName) için ekran görüntüsü gönder"],
            shortTitle: "Ekran görüntüsü gönder",
            systemImageName: "camera.viewfinder"
        )
    }
}
