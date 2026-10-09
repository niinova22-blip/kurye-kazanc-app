import Foundation
import Observation

/// Taramadan cikan tek goruntu: kanit (kimlik dahil) + kalem olusturucunun girdisi.
struct PhotoScanResult {
    var imported: ImportedScreenshot
    var input: ScanInput
}

/// Fotograf kutuphanesini pencere icinde tarar: her goruntu sirayla (bellek) OCR'lanir, kazanc ekrani
/// olmayanlar elenir. Pencere suzmesi kutuphanenin isidir (`since`).
@MainActor
@Observable
final class PhotoScanService {
    static let maxImages = 60

    private(set) var progress: (done: Int, total: Int) = (0, 0)
    private(set) var isScanning = false

    @ObservationIgnored private let library: ScreenshotLibrary
    @ObservationIgnored private let importer: ScreenshotImporter

    init(library: ScreenshotLibrary = PhotoKitScreenshotLibrary(), importer: ScreenshotImporter = ScreenshotImporter()) {
        self.library = library
        self.importer = importer
    }

    func scan(since: Date, includeAllPhotos: Bool, knownIdentifiers: Set<String>, knownTextHashes: Set<String>,
              templates: [OCRTemplate]? = nil, now: Date = .now) async -> [PhotoScanResult] {
        guard !isScanning, library.isAuthorized else { return [] }
        isScanning = true
        defer { isScanning = false }

        var importer: ScreenshotImporter = self.importer
        if let templates { importer.parser.templates = templates }
        let items: [LibraryScreenshot] = includeAllPhotos
            ? await library.recentImages(since: since, limit: Self.maxImages)
            : await library.recentScreenshots(since: since, limit: Self.maxImages)
        let candidates = items.filter { !knownIdentifiers.contains($0.identifier) }
        progress = (0, candidates.count)

        var results: [PhotoScanResult] = []
        var seenHashes = knownTextHashes
        for item in candidates {
            defer { progress.done += 1 }
            guard let data = await item.data() else { continue }
            guard let imported = try? await importer.importImage(
                data: data, assetIdentifier: item.identifier, capturedAt: item.createdAt, referenceDate: now
            ) else { continue }
            guard imported.parsed.templateID != nil, imported.parsed.totalEarning > 0,
                  seenHashes.insert(imported.textHash).inserted else { continue }
            let captured: Date = imported.capturedAt ?? item.createdAt ?? now
            results.append(PhotoScanResult(
                imported: imported,
                input: ScanInput(parsed: imported.parsed, lines: imported.lines, capturedAt: captured)
            ))
        }
        return results
    }
}
