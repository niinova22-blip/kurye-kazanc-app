import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScanWindowTests: XCTestCase {
    func testNormalWindowIs24Hours() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ScanWindow.start(now: now, testMode: false), now.addingTimeInterval(-24 * 3600))
    }

    func testTestModeWindowIs30Days() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ScanWindow.start(now: now, testMode: true), now.addingTimeInterval(-30 * 24 * 3600))
    }
}
