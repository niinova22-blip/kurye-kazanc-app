import UIKit
import UniformTypeIdentifiers

/// Fotograflar > Paylas > Kurye Kazanc: gorselleri gelen kutusuna birakir ve kisa bir onay gosterir.
/// OCR burada yapilmaz (eklenti bellek siniri); uygulama acilinca islenir.
final class ShareViewController: UIViewController {
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.text = "Kurye Kazanç'a ekleniyor…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])
        Task { await handle() }
    }

    private func handle() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        var saved = 0
        for provider in providers.prefix(5) {
            if let data = await loadData(provider), (try? ScreenshotInbox.shared.add(data)) != nil {
                saved += 1
            }
        }
        label.text = saved > 0
            ? "Eklendi. Kurye Kazanç'ı açınca kayda dönüştürülecek."
            : "Görsel eklenemedi."
        try? await Task.sleep(for: .seconds(1.2))
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
