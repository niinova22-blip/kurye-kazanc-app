import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class RecognizedLineTests: XCTestCase {
    func testRoundTrip() {
        let lines = [RecognizedLine(text: "Toplam Kazanç", x: 0.1, y: 0.8, width: 0.3, height: 0.02)]
        XCTAssertEqual(RecognizedLine.decode(RecognizedLine.encode(lines)), lines)
        XCTAssertEqual(RecognizedLine.decode(Data("bozuk".utf8)), [])
    }
}
