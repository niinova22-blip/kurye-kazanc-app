import XCTest
import UIKit
@testable import KuryeKazanc

final class ScreenshotImporterTests: XCTestCase {
    struct FakeRecognizer: TextRecognizing {
        var lines: [String]
        func recognize(in image: UIImage) async throws -> [RecognizedLine] {
            lines.enumerated().map { RecognizedLine(text: $1, x: 0, y: 1 - Double($0) * 0.05, width: 0.5, height: 0.04) }
        }
    }

    /// Bilinen iPhone ekran boyutunda (1179x2556) EXIF'siz PNG.
    private func screenshotPNG() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1179, height: 2556), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1179, height: 2556))
        }
        return image.pngData()!
    }

    func testImportParsesAndAssesses() async throws {
        let importer = ScreenshotImporter(
            recognizer: FakeRecognizer(lines: ["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"]),
            assetIsScreenshot: { _ in nil }
        )
        let result = try await importer.importImage(data: screenshotPNG(), assetIdentifier: nil)
        XCTAssertEqual(result.parsed.platformCode, "getir")
        XCTAssertEqual(result.parsed.totalEarning, 980, accuracy: 0.001)
        XCTAssertTrue(result.isGenuine)
        // Sablon kalibrasyonda -> dogrulanmamis
        XCTAssertEqual(result.assessment.candidate, .ocrUnverified)
        XCTAssertEqual(result.lines.count, 7)
    }

    func testPhotoKitSaysNotScreenshot() async throws {
        let importer = ScreenshotImporter(
            recognizer: FakeRecognizer(lines: ["Getir", "Toplam Kazanç", "₺500"]),
            assetIsScreenshot: { _ in false }
        )
        let result = try await importer.importImage(data: screenshotPNG(), assetIdentifier: "X")
        XCTAssertFalse(result.isGenuine)
    }

    func testRelativeDayIsResolvedAgainstCaptureTime() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let captured = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 23, minute: 30))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 9))!
        let importer = ScreenshotImporter(
            recognizer: FakeRecognizer(lines: ["Getir", "Bugün", "Toplam Kazanç", "₺500"]),
            parser: EarningsScreenshotParser(calendar: calendar),
            verifier: ScreenshotVerifier(calendar: calendar),
            assetIsScreenshot: { _ in nil }
        )
        let result = try await importer.importImage(data: screenshotPNG(), assetIdentifier: nil,
                                                    capturedAt: captured, referenceDate: now)
        XCTAssertEqual(result.parsed.date, calendar.startOfDay(for: captured))
        XCTAssertEqual(result.capturedAt, captured)
    }
}
