import Foundation

/// Uygulamaya gomulu sablonlar. Sunucu (1.3) yoksa veya erisilemezse bunlar kullanilir.
/// Yeni gercek ekran ornegi geldikce: etiket/parmak izi buraya eklenir, `version` artirilir ve
/// `EarningsScreenshotParserTests`'e o ekranin OCR satirlariyla test eklenir.
enum BundledTemplates {
    static let all: [OCRTemplate] = decode(json)

    static let generic = OCRTemplate(
        id: "generic", version: 1, status: .calibrating, platformCode: "",
        detectionKeywords: [], fingerprint: [], minFingerprintMatches: 0,
        totalLabels: ["toplam kazanc", "toplam hakedis", "toplam tutar", "net kazanc", "hakedis", "toplam"],
        bonusLabels: ["bonus", "prim", "tesvik", "ek kazanc", "ek odeme"],
        packageLabels: ["teslimat sayisi", "siparis sayisi", "paket sayisi", "teslimat", "siparis", "paket"],
        totalIncludesBonus: true, minPackageFee: nil, maxPackageFee: nil,
        dayLabels: ["bugun", "gunluk", "dun"], weekLabels: ["haftalik", "bu hafta", "gecen hafta"]
    )

    static func template(id: String) -> OCRTemplate? {
        all.first { $0.id == id }
    }

    static func decode(_ text: String) -> [OCRTemplate] {
        do {
            return try JSONDecoder().decode([OCRTemplate].self, from: Data(text.utf8))
        } catch {
            assertionFailure("Gomulu sablon JSON'u bozuk: \(error)")
            return []
        }
    }

    static let json = #"""
    [
      {
        "id": "trendyol_go.earnings", "version": 1, "status": "calibrating", "platformCode": "trendyol_go",
        "detectionKeywords": ["trendyol go", "trendyol", "tgo"],
        "fingerprint": ["kazanclarim", "kazanc raporu", "toplam kazanc", "teslimat sayisi", "hakedis"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam hakedis", "net kazanc", "gunluk kazanc", "haftalik kazanc", "toplam tutar", "hakedis", "toplam"],
        "bonusLabels": ["bonus", "prim", "tesvik", "ek odeme", "ekstra kazanc"],
        "packageLabels": ["teslimat sayisi", "teslim edilen paket", "teslim edilen", "paket sayisi", "tamamlanan teslimat", "teslimat", "paket"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 250,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"]
      },
      {
        "id": "getir.earnings", "version": 1, "status": "calibrating", "platformCode": "getir",
        "detectionKeywords": ["getir", "getirkurye", "getir kurye", "getiryemek", "getirbuyuk"],
        "fingerprint": ["kazanclarim", "toplam kazanc", "siparis sayisi", "hakedis", "kazancin"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam kazancin", "toplam hakedis", "toplam tutar", "net kazanc", "gunluk kazanc", "hakedis", "kazancin", "toplam"],
        "bonusLabels": ["bonus", "ek kazanc", "prim", "kampanya", "tesvik", "ek odeme"],
        "packageLabels": ["siparis sayisi", "teslim edilen siparis", "tamamlanan siparis", "teslimat sayisi", "siparis", "teslimat", "paket"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 250,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"]
      },
      {
        "id": "yemeksepeti.earnings", "version": 1, "status": "calibrating", "platformCode": "yemeksepeti",
        "detectionKeywords": ["yemeksepeti", "yemeksepeti express", "ys express", "banabi"],
        "fingerprint": ["odemeler", "siparis tutari", "toplam kazanc", "bahsis", "mesafe"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam odeme", "toplam tutar", "net kazanc", "kazanc", "toplam"],
        "bonusLabels": ["bonus", "ek kazanc", "bahsis", "prim", "tesvik"],
        "packageLabels": ["siparis sayisi", "teslim edilen siparis", "tamamlanan siparis", "siparis", "teslimat"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 300,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"]
      },
      {
        "id": "migros_hemen.earnings", "version": 1, "status": "calibrating", "platformCode": "migros_hemen",
        "detectionKeywords": ["migros hemen", "migros yemek", "migros"],
        "fingerprint": ["kazanclarim", "toplam kazanc", "teslimat sayisi", "hakedis"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam hakedis", "toplam tutar", "net kazanc", "hakedis", "toplam"],
        "bonusLabels": ["bonus", "prim", "tesvik", "ek odeme"],
        "packageLabels": ["teslimat sayisi", "siparis sayisi", "paket sayisi", "teslimat", "siparis", "paket"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 250,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"]
      }
    ]
    """#
}
