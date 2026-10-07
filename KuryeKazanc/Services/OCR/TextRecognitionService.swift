import Foundation
import Vision
import UIKit

/// Goruntudeki metni satir satir dondurur (yukaridan asagi), normalize sinir kutulariyla.
protocol TextRecognizing {
    func recognize(in image: UIImage) async throws -> [RecognizedLine]
}

enum TextRecognitionError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Görsel okunamadı."
        case .noTextFound: "Görselde metin bulunamadı. Kazanç ekranının görüntüsünü seçtiğinden emin ol."
        }
    }
}

/// Apple Vision - VNRecognizeTextRequest ile cihaz uzerinde OCR (internet gerekmez, veri cihazdan cikmaz).
struct VisionTextRecognitionService: TextRecognizing {
    func recognize(in image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { throw TextRecognitionError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        let lines: [RecognizedLine] = try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Sayilar ve marka isimleri dil duzeltmesiyle bozulabiliyor
            request.usesLanguageCorrection = false
            let preferred = ["tr-TR", "en-US"]
            if let supported = try? request.supportedRecognitionLanguages() {
                let languages = preferred.filter(supported.contains)
                if !languages.isEmpty { request.recognitionLanguages = languages }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            return Self.orderedLines(from: request.results ?? [])
        }.value

        guard !lines.isEmpty else { throw TextRecognitionError.noTextFound }
        return lines
    }

    /// Gozlemleri okuma sirasina dizer: yukaridan asagi, ayni satirdakiler soldan saga birlestirilir;
    /// satirin kutusu parcalarin birlesimidir. (Vision koordinatlari: orijin sol alt, y yukari dogru artar.)
    static func orderedLines(from observations: [VNRecognizedTextObservation]) -> [RecognizedLine] {
        let items = observations.compactMap { obs -> (text: String, box: CGRect)? in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return (text, obs.boundingBox)
        }
        .sorted { $0.box.midY > $1.box.midY }

        var rows: [[(text: String, box: CGRect)]] = []
        for item in items {
            if var last = rows.last, let ref = last.first,
               abs(ref.box.midY - item.box.midY) < min(ref.box.height, item.box.height) * 0.5 {
                last.append(item)
                rows[rows.count - 1] = last
            } else {
                rows.append([item])
            }
        }
        return rows.map { row in
            let sorted = row.sorted { $0.box.minX < $1.box.minX }
            let box = sorted.dropFirst().reduce(sorted[0].box) { $0.union($1.box) }
            return RecognizedLine(
                text: sorted.map(\.text).joined(separator: " "),
                x: box.minX, y: box.minY, width: box.width, height: box.height
            )
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
