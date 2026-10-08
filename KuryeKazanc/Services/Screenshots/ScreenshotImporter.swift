import Foundation
import ImageIO
import Photos
import UIKit

/// Ekran goruntusu -> OCR -> ayristirma -> dogrulama degerlendirmesi. Form, paylas eklentisi gelen kutusu
/// ve otomatik tarama ayni yolu kullanir.
struct ImportedScreenshot {
    var lines: [RecognizedLine]
    var parsed: ParsedEarning
    var assessment: ScreenshotAssessment
    var capturedAt: Date?
    var assetIdentifier: String?
    var isGenuine: Bool
    /// Normalize OCR metninin ozeti (bkz. `TextHash`); ayni ekran ikinci kez kaydedilmesin.
    var textHash: String = ""
}

struct ScreenshotImporter {
    var recognizer: TextRecognizing = VisionTextRecognitionService()
    var parser = EarningsScreenshotParser()
    var verifier = ScreenshotVerifier(calendar: .current)
    /// Test icin: PhotoKit sorgusu yerine sabit deger.
    var assetIsScreenshot: (String) -> Bool? = ScreenshotImporter.photoKitIsScreenshot

    /// - Parameter templates: Sunucuyla birlestirilmis sablonlar (`SyncCoordinator.mergedTemplates()`).
    ///   nil ise ayristiricinin kendi sablonlari (gomulu) kullanilir.
    init(
        recognizer: TextRecognizing = VisionTextRecognitionService(),
        parser: EarningsScreenshotParser = EarningsScreenshotParser(),
        verifier: ScreenshotVerifier = ScreenshotVerifier(calendar: .current),
        assetIsScreenshot: @escaping (String) -> Bool? = ScreenshotImporter.photoKitIsScreenshot,
        templates: [OCRTemplate]? = nil
    ) {
        self.recognizer = recognizer
        var configured: EarningsScreenshotParser = parser
        if let templates {
            configured.templates = templates
        }
        self.parser = configured
        self.verifier = verifier
        self.assetIsScreenshot = assetIsScreenshot
    }

    /// - Parameters:
    ///   - capturedAt: Gorselin cekildigi an (PhotoKit); EXIF yoksa kullanilir.
    ///   - referenceDate: Simdi. Tarih yakinligi kontrolu buna gore yapilir.
    func importImage(data: Data, assetIdentifier: String?, capturedAt: Date? = nil,
                     referenceDate: Date = .now) async throws -> ImportedScreenshot {
        guard let image = UIImage(data: data) else { throw TextRecognitionError.invalidImage }
        let lines = try await recognizer.recognize(in: image)
        let texts: [String] = lines.map(\.text)
        let metadata = Self.metadata(of: data)
        let captured = metadata.capturedAt ?? capturedAt
        // "Bugun"/"Dun" ekranin cekildigi gune gore cozulur (ertesi gun paylasilan goruntu kaymasin)
        let parsed = parser.parse(lines: texts, referenceDate: captured ?? referenceDate)

        let isGenuine = ScreenshotAuthenticity.isGenuine(
            assetIsScreenshot: assetIdentifier.flatMap(assetIsScreenshot),
            pixelWidth: metadata.pixelWidth, pixelHeight: metadata.pixelHeight,
            hasCameraMetadata: metadata.hasCameraMetadata
        )
        let template = parsed.templateID.flatMap { id in parser.templates.first { $0.id == id } }
        let assessment = verifier.assess(parsed, template: template, isGenuine: isGenuine, referenceDate: referenceDate)

        return ImportedScreenshot(
            lines: lines, parsed: parsed, assessment: assessment,
            capturedAt: captured, assetIdentifier: assetIdentifier, isGenuine: isGenuine,
            textHash: TextHash.of(texts)
        )
    }

    struct ImageMetadata {
        var pixelWidth: Int
        var pixelHeight: Int
        var hasCameraMetadata: Bool
        var capturedAt: Date?
    }

    /// Piksel boyutu, kamera EXIF'i (Make/LensMake) ve cekim tarihi.
    static func metadata(of data: Data) -> ImageMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return ImageMetadata(pixelWidth: 0, pixelHeight: 0, hasCameraMetadata: false, capturedAt: nil)
        }
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let hasCamera = tiff?[kCGImagePropertyTIFFMake] != nil || exif?[kCGImagePropertyExifLensMake] != nil
        var captured: Date?
        if let text = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            captured = formatter.date(from: text)
        }
        return ImageMetadata(
            pixelWidth: props[kCGImagePropertyPixelWidth] as? Int ?? 0,
            pixelHeight: props[kCGImagePropertyPixelHeight] as? Int ?? 0,
            hasCameraMetadata: hasCamera,
            capturedAt: captured
        )
    }

    /// Fotograf erisimi yoksa nil (boyut/EXIF kontrolune duser).
    static func photoKitIsScreenshot(_ identifier: String) -> Bool? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return nil }
        return asset.mediaSubtypes.contains(.photoScreenshot)
    }
}
