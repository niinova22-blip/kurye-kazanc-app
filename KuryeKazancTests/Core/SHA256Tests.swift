import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class SHA256Tests: XCTestCase {
    func testKnownVectors() {
        XCTAssertEqual(SHA256.hex(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(SHA256.hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(
            SHA256.hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
        )
        // 1.000.000 x "a" yerine iki blok sinirini zorlayan 64 bayt
        XCTAssertEqual(
            SHA256.hex(String(repeating: "a", count: 64)),
            "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"
        )
    }

    func testTextHashSha256NormalizesLikeFNV() {
        let a = TextHash.sha256(["Toplam Kazanç", "  ₺980,00 "])
        let b = TextHash.sha256(["toplam kazanc", "₺980,00", ""])
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64)
        XCTAssertNotEqual(a, TextHash.sha256(["Toplam Kazanç", "₺981,00"]))
        XCTAssertEqual(TextHash.sha256([]), "")
        XCTAssertEqual(TextHash.sha256(["   "]), "")
    }
}
