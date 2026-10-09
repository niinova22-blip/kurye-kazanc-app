import XCTest
import UIKit
@testable import KuryeKazanc

/// Getir kazanc ekrani: platform + 2 parmak izi ("kazanclarim", "toplam kazanc") + pozitif toplam.
private let getirLines = ["Getir", "Kazançlarım", "Toplam Kazanç", "₺700"]
/// Platform taninir ama parmak izi tek (kazanc ekrani oldugu kesin degil).
private let weakLines = ["Getir", "Toplam Kazanç", "₺700"]
/// Parmak izi tamam ama tutar yok.
private let zeroLines = ["Getir", "Kazançlarım", "Toplam Kazanç"]
private let weatherLines = ["Hava durumu", "18°"]

@MainActor
final class ScreenshotScannerTests: XCTestCase {
    struct FakeLibrary: ScreenshotLibrary {
        var isAuthorized: Bool
        var items: [LibraryScreenshot]
        func requestAccess() async -> Bool { isAuthorized }
        func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] { Array(items.prefix(limit)) }
        func recentImages(since: Date, limit: Int) async -> [LibraryScreenshot] { Array(items.prefix(limit)) }
    }

    /// Kac kez OCR yapildigini sayar (reddedilen goruntu tekrar okunmasin testi).
    final class Counter {
        var count = 0
    }

    struct LinesByData: TextRecognizing {
        var counter = Counter()
        func recognize(in image: UIImage) async throws -> [RecognizedLine] {
            counter.count += 1
            // Gorsel genisligi hangi metnin donecegini secer (test kolayligi)
            let lines: [String]
            switch Int(image.size.width) {
            case 200: lines = getirLines
            case 150: lines = weakLines
            case 120: lines = zeroLines
            default: lines = weatherLines
            }
            return lines.map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.1) }
        }
    }

    private func png(width: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 10), format: format).image { _ in }.pngData()!
    }

    private func makeScanner(authorized: Bool, items: [LibraryScreenshot], counter: Counter = Counter(),
                             defaults: UserDefaults = UserDefaults(suiteName: "scanner-\(UUID())")!) -> ScreenshotScanner {
        defaults.set(true, forKey: AppPreferences.screenshotScanEnabledKey)
        return ScreenshotScanner(
            library: FakeLibrary(isAuthorized: authorized, items: items),
            importer: ScreenshotImporter(recognizer: LinesByData(counter: counter), assetIsScreenshot: { _ in true }),
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
        XCTAssertEqual(scanner.suggestion?.textHash, TextHash.of(getirLines))
    }

    func testRequiresFingerprintAndPositiveTotal() async {
        let weak = png(width: 150), zero = png(width: 120)
        let scanner = makeScanner(authorized: true, items: [
            LibraryScreenshot(identifier: "weak", createdAt: .now, data: { weak }),
            LibraryScreenshot(identifier: "zero", createdAt: .now, data: { zero }),
        ])
        await scanner.scan(knownIdentifiers: [])
        XCTAssertNil(scanner.suggestion, "Parmak izi yetersiz veya tutari olmayan ekran onerilmemeli")
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

    func testSkipsScreenshotWhoseTextWasAlreadySaved() async {
        let getir = png(width: 200)
        let items = [LibraryScreenshot(identifier: "copy", createdAt: .now, data: { getir })]
        let scanner = makeScanner(authorized: true, items: items)
        await scanner.scan(knownIdentifiers: [], knownTextHashes: [TextHash.of(getirLines)])
        XCTAssertNil(scanner.suggestion, "Ayni metinli ekran (baska kopya) tekrar onerilmemeli")

        let fresh = makeScanner(authorized: true, items: items)
        await fresh.scan(knownIdentifiers: [], knownTextHashes: ["0000000000000000"])
        XCTAssertEqual(fresh.suggestion?.assetIdentifier, "copy")
    }

    func testRejectedScreenshotsAreNotRecognizedAgainInSameSession() async {
        let weather = png(width: 50), weak = png(width: 150)
        let counter = Counter()
        let scanner = makeScanner(authorized: true, items: [
            LibraryScreenshot(identifier: "weather", createdAt: .now, data: { weather }),
            LibraryScreenshot(identifier: "weak", createdAt: .now, data: { weak }),
        ], counter: counter)
        await scanner.scan(knownIdentifiers: [])
        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(scanner.rejectedIdentifiers, ["weather", "weak"])

        await scanner.scan(knownIdentifiers: [])
        XCTAssertEqual(counter.count, 2, "Uygun olmayan ekranlar her on plana geliste yeniden OCR'lanmamali")
        XCTAssertNil(scanner.suggestion)
    }

    func testNoPermissionMeansNoSuggestionAndNoCrash() async {
        let getir = png(width: 200)
        let scanner = makeScanner(authorized: false, items: [LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir })])
        await scanner.scan(knownIdentifiers: [])
        XCTAssertNil(scanner.suggestion)
    }

    func testRevokedPermissionIsReported() async {
        let getir = png(width: 200)
        let item = LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir })
        let revoked = makeScanner(authorized: false, items: [item])
        XCTAssertFalse(revoked.isPermissionMissing, "Taramadan once bilinmez")
        await revoked.scan(knownIdentifiers: [])
        XCTAssertTrue(revoked.isEnabled)
        XCTAssertTrue(revoked.isPermissionMissing)

        let granted = makeScanner(authorized: true, items: [item])
        await granted.scan(knownIdentifiers: [])
        XCTAssertFalse(granted.isPermissionMissing)
    }

    func testEnableWithDeniedPermissionShowsSettingsHint() async {
        let defaults = UserDefaults(suiteName: "scanner-\(UUID())")!
        let scanner = makeScanner(authorized: false, items: [], defaults: defaults)
        scanner.disable()
        let granted = await scanner.enable()
        XCTAssertFalse(granted)
        XCTAssertFalse(scanner.isEnabled)
        XCTAssertTrue(scanner.isPermissionMissing, "Reddedilmis izinde Ayarlar yonlendirmesi gorunmeli")
        await scanner.scan(knownIdentifiers: [])
        XCTAssertTrue(scanner.isPermissionMissing, "Izin hala yokken uyari kalkmamali")
    }

    func testPermissionIsNotMissingWhenScanningIsOff() async {
        let defaults = UserDefaults(suiteName: "scanner-\(UUID())")!
        let scanner = makeScanner(authorized: false, items: [], defaults: defaults)
        scanner.disable()
        await scanner.scan(knownIdentifiers: [])
        XCTAssertFalse(scanner.isPermissionMissing)
    }

    func testDisableTurnsScanningOffAndClearsSuggestion() async {
        let getir = png(width: 200)
        let defaults = UserDefaults(suiteName: "scanner-\(UUID())")!
        let scanner = makeScanner(authorized: true, items: [LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir })],
                                  defaults: defaults)
        await scanner.scan(knownIdentifiers: [])
        XCTAssertNotNil(scanner.suggestion)

        scanner.disable()
        XCTAssertFalse(scanner.isEnabled)
        XCTAssertNil(scanner.suggestion)
        XCTAssertFalse(scanner.isPermissionMissing)
        XCTAssertFalse(defaults.bool(forKey: AppPreferences.screenshotScanEnabledKey))

        await scanner.scan(knownIdentifiers: [])
        XCTAssertNil(scanner.suggestion, "Kapatilinca tarama yapilmaz")
    }
}
