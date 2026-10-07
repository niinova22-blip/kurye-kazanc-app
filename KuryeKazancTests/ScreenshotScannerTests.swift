import XCTest
import UIKit
@testable import KuryeKazanc

@MainActor
final class ScreenshotScannerTests: XCTestCase {
    struct FakeLibrary: ScreenshotLibrary {
        var isAuthorized: Bool
        var items: [LibraryScreenshot]
        func requestAccess() async -> Bool { isAuthorized }
        func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] { Array(items.prefix(limit)) }
    }

    struct LinesByData: TextRecognizing {
        func recognize(in image: UIImage) async throws -> [RecognizedLine] {
            // Gorsel genisligi hangi metnin donecegini secer (test kolayligi)
            let lines = image.size.width > 100
                ? ["Getir", "Toplam Kazanç", "₺700"]
                : ["Hava durumu", "18°"]
            return lines.map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.1) }
        }
    }

    private func png(width: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 10), format: format).image { _ in }.pngData()!
    }

    private func makeScanner(authorized: Bool, items: [LibraryScreenshot]) -> ScreenshotScanner {
        let defaults = UserDefaults(suiteName: "scanner-\(UUID())")!
        defaults.set(true, forKey: AppPreferences.screenshotScanEnabledKey)
        return ScreenshotScanner(
            library: FakeLibrary(isAuthorized: authorized, items: items),
            importer: ScreenshotImporter(recognizer: LinesByData(), assetIsScreenshot: { _ in true }),
            defaults: defaults
        )
    }

    func testSuggestsFirstRecognizedPlatformScreenshot() async {
        let other = png(width: 50), getir = png(width: 200)
        let scanner = makeScanner(authorized: true, items: [
            LibraryScreenshot(identifier: "weather", createdAt: .now, data: { other }),
            LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir }),
        ])
        await scanner.scan(knownIdentifiers: [])
        XCTAssertEqual(scanner.suggestion?.assetIdentifier, "getir")
        XCTAssertEqual(scanner.suggestion?.parsed.platformCode, "getir")
    }

    func testSkipsKnownAndDismissed() async {
        let getir = png(width: 200)
        let scanner = makeScanner(authorized: true, items: [LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir })])
        await scanner.scan(knownIdentifiers: ["getir"])
        XCTAssertNil(scanner.suggestion)

        let scanner2 = makeScanner(authorized: true, items: [LibraryScreenshot(identifier: "g2", createdAt: .now, data: { getir })])
        await scanner2.scan(knownIdentifiers: [])
        scanner2.dismissSuggestion()
        await scanner2.scan(knownIdentifiers: [])
        XCTAssertNil(scanner2.suggestion)
    }

    func testNoPermissionMeansNoSuggestionAndNoCrash() async {
        let getir = png(width: 200)
        let scanner = makeScanner(authorized: false, items: [LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir })])
        await scanner.scan(knownIdentifiers: [])
        XCTAssertNil(scanner.suggestion)
    }
}
