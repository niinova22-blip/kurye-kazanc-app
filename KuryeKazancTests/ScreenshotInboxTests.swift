import XCTest
@testable import KuryeKazanc

final class ScreenshotInboxTests: XCTestCase {
    func testAddListRemove() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID())")
        let inbox = ScreenshotInbox(directory: dir)
        try inbox.add(Data([1, 2, 3]))
        try inbox.add(Data([4]))
        let pending = inbox.pending()
        XCTAssertEqual(pending.count, 2)
        inbox.remove(pending[0])
        XCTAssertEqual(inbox.pending().count, 1)
    }

    func testMissingAppGroupIsHarmless() throws {
        let inbox = ScreenshotInbox(directory: nil)
        XCTAssertThrowsError(try inbox.add(Data([1])))
        XCTAssertEqual(inbox.pending(), [])
    }

    func testClaimHidesFileFromPendingSoItIsProcessedOnce() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID())")
        let inbox = ScreenshotInbox(directory: dir)
        try inbox.add(Data([7, 8]))
        let url = try XCTUnwrap(inbox.pending().first)
        let claimed = try XCTUnwrap(inbox.claim(url))
        XCTAssertEqual(inbox.pending(), [], "Ikinci tarama ayni dosyayi gormemeli")
        XCTAssertNil(inbox.claim(url), "Ayni dosya iki kez alinamaz")
        XCTAssertEqual(try Data(contentsOf: claimed), Data([7, 8]))
        inbox.remove(claimed)
    }
}
