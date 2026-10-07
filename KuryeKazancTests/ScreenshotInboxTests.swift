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
}
