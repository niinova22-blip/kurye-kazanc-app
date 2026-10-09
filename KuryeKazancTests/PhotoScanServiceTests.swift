import XCTest
import UIKit
@testable import KuryeKazanc

@MainActor
final class PhotoScanServiceTests: XCTestCase {
    private let earningLines = ["Getir", "Kazançlarım", "Toplam Kazanç", "₺700"]
    private let otherLines = ["Hava durumu", "18°"]

    /// Pencere suzmesi kutuphanenin isi: sahte kutuphane aldigi `since` degerini kaydeder.
    final class Spy {
        var since: Date?
        var usedAllPhotos = false
    }

    struct FakeLibrary: ScreenshotLibrary {
        var items: [LibraryScreenshot]
        var spy = Spy()
        var isAuthorized: Bool { true }
        func requestAccess() async -> Bool { true }
        func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] {
            spy.since = since
            return Array(items.prefix(limit))
        }
        func recentImages(since: Date, limit: Int) async -> [LibraryScreenshot] {
            spy.since = since
            spy.usedAllPhotos = true
            return Array(items.prefix(limit))
        }
    }

    /// Gorsel genisligi hangi metnin donecegini secer.
    struct LinesByWidth: TextRecognizing {
        var earning: [String]
        var other: [String]
        func recognize(in image: UIImage) async throws -> [RecognizedLine] {
            let texts = Int(image.size.width) == 200 ? earning : other
            return texts.map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.1) }
        }
    }

    private func png(width: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 10), format: format).image { _ in }.pngData()!
    }

    private func item(_ id: String, width: CGFloat) -> LibraryScreenshot {
        let data = png(width: width)
        return LibraryScreenshot(identifier: id, createdAt: Date(timeIntervalSince1970: 1_700_000_000)) { data }
    }

    private func makeService(_ library: FakeLibrary) -> PhotoScanService {
        PhotoScanService(
            library: library,
            importer: ScreenshotImporter(recognizer: LinesByWidth(earning: earningLines, other: otherLines),
                                         assetIsScreenshot: { _ in true })
        )
    }

    func testPassesWindowStartToLibraryAndKeepsRecognizedOnly() async {
        let spy = Spy()
        let library = FakeLibrary(items: [item("a", width: 200), item("b", width: 50)], spy: spy)
        let since = Date(timeIntervalSince1970: 1_699_000_000)
        let service = makeService(library)
        let results = await service.scan(since: since, includeAllPhotos: false, knownIdentifiers: [], knownTextHashes: [])
        XCTAssertEqual(spy.since, since)
        XCTAssertFalse(spy.usedAllPhotos)
        XCTAssertEqual(results.map { $0.imported.assetIdentifier }, ["a"])
        XCTAssertEqual(service.progress.done, 2)
        XCTAssertEqual(service.progress.total, 2)
    }

    func testSkipsKnownIdentifiers() async {
        let library = FakeLibrary(items: [item("a", width: 200), item("c", width: 200)])
        let service = makeService(library)
        let results = await service.scan(since: .distantPast, includeAllPhotos: false,
                                         knownIdentifiers: ["a"], knownTextHashes: [])
        XCTAssertEqual(results.map { $0.imported.assetIdentifier }, ["c"])
        XCTAssertEqual(service.progress.total, 1)
    }

    func testKnownIdentifiersFilteredBeforeLimitAndTruncationFlagged() async {
        var items = (0..<70).map { item("k\($0)", width: 200) }
        items += (0..<70).map { item("n\($0)", width: 200) }
        let service = makeService(FakeLibrary(items: items))
        let known = Set((0..<70).map { "k\($0)" })
        _ = await service.scan(since: .distantPast, includeAllPhotos: false, knownIdentifiers: known, knownTextHashes: [])
        XCTAssertEqual(service.progress.total, PhotoScanService.maxImages)
        XCTAssertTrue(service.didTruncate)
    }

    func testRejectedImagesAreNotReprocessedInSession() async {
        let service = makeService(FakeLibrary(items: [item("b", width: 50)]))
        _ = await service.scan(since: .distantPast, includeAllPhotos: false, knownIdentifiers: [], knownTextHashes: [])
        XCTAssertEqual(service.rejectedIdentifiers, ["b"])
        _ = await service.scan(since: .distantPast, includeAllPhotos: false, knownIdentifiers: [], knownTextHashes: [])
        XCTAssertEqual(service.progress.total, 0)
        XCTAssertFalse(service.didTruncate)
    }

    func testAllPhotosModeUsesImageQuery() async {
        let spy = Spy()
        let service = makeService(FakeLibrary(items: [item("a", width: 200)], spy: spy))
        _ = await service.scan(since: .distantPast, includeAllPhotos: true, knownIdentifiers: [], knownTextHashes: [])
        XCTAssertTrue(spy.usedAllPhotos)
    }
}
