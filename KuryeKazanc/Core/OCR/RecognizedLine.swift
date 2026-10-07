import Foundation

/// OCR'in okudugu bir satir ve normalize sinir kutusu (Vision koordinatlari: 0-1, orijin sol alt).
/// Kanit olarak cihazda saklanir; sablon guncellenince geriye donuk yeniden dogrulama icin kullanilir.
struct RecognizedLine: Codable, Equatable {
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static func encode(_ lines: [RecognizedLine]) -> Data {
        (try? JSONEncoder().encode(lines)) ?? Data()
    }

    static func decode(_ data: Data) -> [RecognizedLine] {
        (try? JSONDecoder().decode([RecognizedLine].self, from: data)) ?? []
    }
}
