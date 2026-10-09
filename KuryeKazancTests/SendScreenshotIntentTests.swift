import XCTest
@testable import KuryeKazanc

final class SendScreenshotIntentTests: XCTestCase {
    func testStoreDropsImgFileIntoInbox() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID())")
        let inbox = ScreenshotInbox(directory: dir)
        try SendScreenshotIntent.store(Data([9, 9, 9]), in: inbox)
        let pending = inbox.pending()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.pathExtension, "img")
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(pending.first)), Data([9, 9, 9]))
    }
}
