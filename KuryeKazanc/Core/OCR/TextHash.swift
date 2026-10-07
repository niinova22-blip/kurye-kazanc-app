import Foundation

/// Ekran goruntusu metninin ozeti: ayni ekran ikinci kez kaydedilmesin diye (spec 4.3).
/// Satirlar `TextNormalizer` ile normalize edilir (buyuk/kucuk harf, Turkce harfler, bosluklar),
/// bos satirlar atilir, "\n" ile birlestirilir ve 64 bit FNV-1a ile ozetlenir (16 karakter kucuk hex).
///
/// Not: Core Windows'ta derlendigi icin CryptoKit kullanilmaz. Sunucuya gidecek SHA-256 `text_hash`
/// (1.3) ayri hesaplanacak; bu deger yalnizca cihaz ustu tekrar kontrolu icindir.
enum TextHash {
    private static let offsetBasis: UInt64 = 0xcbf2_9ce4_8422_2325
    private static let prime: UInt64 = 0x0000_0100_0000_01b3

    static func of(_ lines: [String]) -> String {
        var normalized: [String] = []
        for line in lines {
            let text = TextNormalizer.normalize(line)
            if !text.isEmpty {
                normalized.append(text)
            }
        }
        // Metin yoksa ozet yok: bos ozet hicbir zaman "tekrar" sayilmaz
        guard !normalized.isEmpty else { return "" }
        let joined = normalized.joined(separator: "\n")

        var hash: UInt64 = offsetBasis
        for byte in joined.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        let hex = String(hash, radix: 16, uppercase: false)
        let padding = String(repeating: "0", count: max(0, 16 - hex.count))
        return padding + hex
    }
}
