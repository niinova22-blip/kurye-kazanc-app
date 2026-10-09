import XCTest
@testable import KuryeKazanc

final class BroadcastCaptureStoreTests: XCTestCase {
    private func makeStore() -> BroadcastCaptureStore {
        BroadcastCaptureStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("captures-\(UUID())"))
    }

    private func capture(_ text: String) -> BroadcastCapture {
        BroadcastCapture(capturedAt: Date(timeIntervalSince1970: 1_000),
                         lines: [RecognizedLine(text: text, x: 0, y: 0, width: 1, height: 1)])
    }

    func testSaveThenPendingOldestFirstAndLoad() throws {
        let store = makeStore()
        try store.save(capture("a"))
        Thread.sleep(forTimeInterval: 0.01)
        try store.save(capture("b"))
        let pending = store.pending()
        XCTAssertEqual(pending.count, 2)
        XCTAssertEqual(store.load(pending[0])?.lines.first?.text, "a")
        XCTAssertEqual(store.load(pending[1])?.lines.first?.text, "b")
    }

    func testCorruptFileLoadsAsNil() throws {
        let store = makeStore()
        try store.save(capture("a"))
        let url = try XCTUnwrap(store.pending().first)
        try Data("bozuk".utf8).write(to: url)
        XCTAssertNil(store.load(url))
    }

    func testRemoveAndRemoveAll() throws {
        let store = makeStore()
        try store.save(capture("a"))
        Thread.sleep(forTimeInterval: 0.01)
        try store.save(capture("b"))
        store.remove(try XCTUnwrap(store.pending().first))
        XCTAssertEqual(store.pending().count, 1)
        store.removeAll()
        XCTAssertEqual(store.pending(), [])
    }

    func testMissingAppGroupIsHarmless() {
        let store = BroadcastCaptureStore(directory: nil)
        XCTAssertThrowsError(try store.save(capture("a")))
        XCTAssertEqual(store.pending(), [])
    }
}
