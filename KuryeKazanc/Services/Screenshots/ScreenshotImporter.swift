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
}

struct ScreenshotImporter {
    var recognizer: TextRecognizing = VisionTextRecognitionService()
    var parser = EarningsScreenshotParser()
    var verifier = ScreenshotVerifier(calendar: .current)
    /// Test icin: PhotoKit sorgusu yerine sabit deger.
    var assetIsScreenshot: (String) -> Bool? = ScreenshotImporter.photoKitIsScreenshot

    func importImage(data: Data, assetIdentifier: String?, referenceDate: Date = .now) async throws -> ImportedScreenshot {
        guard let image = UIImage(data: data) else { throw TextRecognitionError.invalidImage }
        let lines = try await recognizer.recognize(in: image)
        let parsed = parser.parse(lines: lines.map(\.text), referenceDate: referenceDate)

        let metadata = Self.metadata(of: data)
        let isGenuine = ScreenshotAuthenticity.isGenuine(
            assetIsScreenshot: assetIdentifier.flatMap(assetIsScreenshot),
            pixelWidth: metadata.pixelWidth, pixelHeight: metadata.pixelHeight,
            hasCameraMetadata: metadata.hasCameraMetadata
        )
        let template = parsed.templateID.flatMap { id in parser.templates.first { $0.id == id } }
        let assessment = verifier.assess(parsed, template: template, isGenuine: isGenuine, referenceDate: referenceDate)

        return ImportedScreenshot(
            lines: lines, parsed: parsed, assessment: assessment,
            capturedAt: metadata.capturedAt, assetIdentifier: assetIdentifier, isGenuine: isGenuine
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
