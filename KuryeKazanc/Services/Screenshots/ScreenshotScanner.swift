import Foundation
import Observation
import Photos
import UIKit

struct LibraryScreenshot {
    var identifier: String
    var createdAt: Date?
    var data: () async -> Data?
}

protocol ScreenshotLibrary {
    var isAuthorized: Bool { get }
    func requestAccess() async -> Bool
    func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot]
}

/// PhotoKit: yalnizca ekran goruntusu alt turundeki fotograflar. Sinirli erisimde yalnizca secilenler gorunur.
struct PhotoKitScreenshotLibrary: ScreenshotLibrary {
    var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] {
        guard isAuthorized else { return [] }
        // Bit maskeli mediaSubtypes yuklemi yerine sistemin "Ekran Goruntuleri" akilli albumu (belgelenmis yol)
        guard let album = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil
        ).firstObject else { return [] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@", since as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let assets = PHAsset.fetchAssets(in: album, options: options)
        var result: [LibraryScreenshot] = []
        assets.enumerateObjects { asset, _, _ in
            result.append(LibraryScreenshot(identifier: asset.localIdentifier, createdAt: asset.creationDate) {
                await withCheckedContinuation { continuation in
                    let request = PHImageRequestOptions()
                    request.isNetworkAccessAllowed = true
                    request.deliveryMode = .highQualityFormat
                    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: request) { data, _, _, _ in
                        continuation.resume(returning: data)
                    }
                }
            })
        }
        return result
    }
}

/// Uygulama acilinca son 48 saatin islenmemis kazanc ekran goruntusunu bulup oneri olarak sunar.
@MainActor
@Observable
final class ScreenshotScanner {
    private(set) var suggestion: ImportedScreenshot?
    /// Kullanici otomatik taramayi acti mi? (Gozlenir: dugme acilinca gizlenir.)
    private(set) var isEnabled: Bool
    /// Tarama acik ama fotograf izni (Ayarlar'dan) geri alinmis: son taramada kutuphane erisilemedi.
    private(set) var isPermissionMissing = false

    /// Bu oturumda incelenip uygun bulunmayan goruntuler: her on plana geliste yeniden OCR'lanmasin.
    /// Bellekte tutulur; uygulama yeniden acilinca bosalir.
    @ObservationIgnored private(set) var rejectedIdentifiers: Set<String> = []

    @ObservationIgnored private let library: ScreenshotLibrary
    @ObservationIgnored private let importer: ScreenshotImporter
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isScanning = false

    init(library: ScreenshotLibrary = PhotoKitScreenshotLibrary(),
         importer: ScreenshotImporter = ScreenshotImporter(),
         defaults: UserDefaults = .standard) {
        self.library = library
        self.importer = importer
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: AppPreferences.screenshotScanEnabledKey)
    }

    /// Kullanici "otomatik bul"u actiginda: izin ister, verilirse tercihi kaydeder.
    func enable() async -> Bool {
        let granted = await library.requestAccess()
        defaults.set(granted, forKey: AppPreferences.screenshotScanEnabledKey)
        isEnabled = granted
        // Izin daha once reddedildiyse iOS tekrar sormaz: "Ayarlar'dan ac" satiri gosterilsin
        isPermissionMissing = !granted
        return granted
    }

    /// Kullanici taramayi kapatti (veya izin geri alindiktan sonra "Kapat" dedi).
    func disable() {
        defaults.set(false, forKey: AppPreferences.screenshotScanEnabledKey)
        isEnabled = false
        isPermissionMissing = false
        suggestion = nil
    }

    /// - Parameters:
    ///   - knownIdentifiers: Kaniti kayitli PhotoKit kimlikleri.
    ///   - knownTextHashes: Kayitli kanitlarin metin ozetleri; ayni ekranin baska kopyasi onerilmez.
    func scan(knownIdentifiers: Set<String>, knownTextHashes: Set<String> = [], now: Date = .now) async {
        guard isEnabled else {
            // Reddedilen etkinlestirmeden kalan uyari, izin Ayarlar'dan verilince kalkar
            if isPermissionMissing, library.isAuthorized {
                isPermissionMissing = false
            }
            suggestion = nil
            return
        }
        guard library.isAuthorized else {
            isPermissionMissing = true
            suggestion = nil
            return
        }
        isPermissionMissing = false
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let dismissedList: [String] = defaults.stringArray(forKey: AppPreferences.dismissedScreenshotIDsKey) ?? []
        let dismissed = Set<String>(dismissedList)
        let since = now.addingTimeInterval(-48 * 3600)
        let items: [LibraryScreenshot] = await library.recentScreenshots(since: since, limit: 5)
        for item in items {
            let identifier = item.identifier
            if knownIdentifiers.contains(identifier) || dismissed.contains(identifier)
                || rejectedIdentifiers.contains(identifier) {
                continue
            }
            // Veri alinamadiysa (iCloud indirmesi vb.) reddetme: sonraki taramada yeniden denenir
            guard let data = await item.data() else { continue }
            let result: ImportedScreenshot
            do {
                result = try await importer.importImage(data: data, assetIdentifier: identifier,
                                                        capturedAt: item.createdAt, referenceDate: now)
            } catch {
                rejectedIdentifiers.insert(identifier)
                continue
            }
            if knownTextHashes.contains(result.textHash) || !ScreenshotSuggestionRule.qualifies(result.parsed) {
                rejectedIdentifiers.insert(identifier)
                continue
            }
            suggestion = result
            return
        }
        suggestion = nil
    }

    func dismissSuggestion() {
        guard let id = suggestion?.assetIdentifier else { return }
        var dismissed = defaults.stringArray(forKey: AppPreferences.dismissedScreenshotIDsKey) ?? []
        dismissed.append(id)
        defaults.set(Array(dismissed.suffix(200)), forKey: AppPreferences.dismissedScreenshotIDsKey)
        suggestion = nil
    }

    /// Oneri forma aktarilinca listeden duser (kayit edilirse kanit kimligi zaten "bilinen" olur).
    func consumeSuggestion() -> ImportedScreenshot? {
        defer { suggestion = nil }
        return suggestion
    }
}
