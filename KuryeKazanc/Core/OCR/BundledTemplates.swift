import Foundation

/// Uygulamaya gomulu sablonlar. Sunucu (1.3) yoksa veya erisilemezse bunlar kullanilir.
/// Yeni gercek ekran ornegi geldikce: etiket/parmak izi buraya eklenir, `version` artirilir ve
/// `EarningsScreenshotParserTests`'e o ekranin OCR satirlariyla test eklenir.
enum BundledTemplates {
    static let all: [OCRTemplate] = decode(json)

    /// 1.9: uygulama yalnizca iki firmanin ekranlarini okur (Yemeksepeti Express, Paket Taxi). Diger sablonlar
    /// ayristirici testleri icin JSON'da durur ama uygulamada kullanilmaz.
    static let supportedPlatformCodes: Set<String> = ["yemeksepeti", "migros_hemen", "pt_migros", "pt_restoran"]

    static var supported: [OCRTemplate] { all.filter { supportedPlatformCodes.contains($0.platformCode) } }

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
        "id": "trendyol_go.earnings", "version": 2, "status": "calibrating", "platformCode": "trendyol_go",
        "detectionKeywords": ["trendyol go", "trendyol", "tgo"],
        "fingerprint": ["kazanclarim", "kazanc raporu", "toplam kazanc", "teslimat sayisi", "hakedis"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam hakedis", "net kazanc", "gunluk kazanc", "haftalik kazanc", "toplam tutar", "hakedis", "toplam"],
        "bonusLabels": ["bonus", "prim", "tesvik", "ek odeme", "ekstra kazanc"],
        "packageLabels": ["teslimat sayisi", "teslim edilen paket", "teslim edilen", "paket sayisi", "tamamlanan teslimat", "teslimat", "paket"],
        "durationLabels": ["calisma suresi", "cevrimici sure", "cevrimici", "online sure", "aktif sure"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 250,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"]
      },
      {
        "id": "getir.earnings", "version": 2, "status": "calibrating", "platformCode": "getir",
        "detectionKeywords": ["getir", "getirkurye", "getir kurye", "getiryemek", "getirbuyuk"],
        "fingerprint": ["kazanclarim", "toplam kazanc", "siparis sayisi", "hakedis", "kazancin"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam kazancin", "toplam hakedis", "toplam tutar", "net kazanc", "gunluk kazanc", "hakedis", "kazancin", "toplam"],
        "bonusLabels": ["bonus", "ek kazanc", "prim", "kampanya", "tesvik", "ek odeme"],
        "packageLabels": ["siparis sayisi", "teslim edilen siparis", "tamamlanan siparis", "teslimat sayisi", "siparis", "teslimat", "paket"],
        "durationLabels": ["calisma suresi", "cevrimici sure", "cevrimici", "online sure", "aktif sure"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 250,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"]
      },
      {
        "id": "yemeksepeti.earnings", "version": 3, "status": "calibrating", "platformCode": "yemeksepeti",
        "detectionKeywords": ["yemeksepeti", "yemeksepeti express", "ys express", "banabi"],
        "fingerprint": ["odemeler", "siparis tutari", "toplam kazanc", "bahsis", "mesafe"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam odeme", "toplam tutar", "net kazanc", "kazanc", "toplam"],
        "bonusLabels": ["bonus", "ek kazanc", "bahsis", "prim", "tesvik"],
        "packageLabels": ["siparis sayisi", "teslim edilen siparis", "tamamlanan siparis", "siparis", "teslimat"],
        "durationLabels": ["calisma suresi", "cevrimici sure", "cevrimici", "online sure", "aktif sure"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 300,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"], "amountsExcludeVAT": true
      },
      {
        "id": "migros_hemen.earnings", "version": 2, "status": "calibrating", "platformCode": "migros_hemen",
        "detectionKeywords": ["migros hemen", "migros yemek", "migros"],
        "fingerprint": ["kazanclarim", "toplam kazanc", "teslimat sayisi", "hakedis"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam kazanc", "toplam hakedis", "toplam tutar", "net kazanc", "hakedis", "toplam"],
        "bonusLabels": ["bonus", "prim", "tesvik", "ek odeme"],
        "packageLabels": ["teslimat sayisi", "siparis sayisi", "paket sayisi", "teslimat", "siparis", "paket"],
        "durationLabels": ["calisma suresi", "cevrimici sure", "cevrimici", "online sure", "aktif sure"],
        "totalIncludesBonus": true, "minPackageFee": 40, "maxPackageFee": 250,
        "dayLabels": ["bugun", "gunluk", "dun"], "weekLabels": ["haftalik", "bu hafta", "gecen hafta"]
      },
      {
        "id": "uber.earnings", "version": 1, "status": "calibrating", "platformCode": "uber", "layout": "summary",
        "detectionKeywords": [],
        "fingerprint": ["kazanclar", "earnings", "cevrimici", "online", "seyahat", "trips", "teslimat", "puan", "points", "bakiye", "balance", "sonraki odeme", "next payment", "ayrintilari gor", "see details"],
        "minFingerprintMatches": 3,
        "totalLabels": ["kazanclar", "earnings"],
        "bonusLabels": ["promosyon", "promotions", "bonus", "ek kazanc"],
        "packageLabels": ["teslimat", "seyahat", "trips", "deliveries"],
        "durationLabels": ["cevrimici", "online"],
        "totalIncludesBonus": true, "minPackageFee": null, "maxPackageFee": null,
        "dayLabels": ["bugun", "today"], "weekLabels": ["bu hafta", "this week", "gecen hafta", "last week"]
      },
      {
        "id": "thekurye.invoices", "version": 1, "status": "calibrating", "platformCode": "thekurye", "layout": "list",
        "detectionKeywords": ["the kurye", "thekurye"],
        "fingerprint": ["faturalar", "tasima ucreti", "fatura olustur", "tumunu sec"],
        "minFingerprintMatches": 2,
        "totalLabels": ["toplam"], "bonusLabels": [], "packageLabels": [],
        "rowLabels": ["tasima ucreti"],
        "totalIncludesBonus": true, "minPackageFee": null, "maxPackageFee": null,
        "dayLabels": ["bugun"], "weekLabels": ["bu hafta"]
      },
      {
        "id": "yemeksepeti.order", "version": 1, "status": "calibrating", "platformCode": "yemeksepeti", "layout": "orderCard",
        "detectionKeywords": [],
        "fingerprint": ["kabul orani", "acceptance", "reddet", "decline", "kabul et", "accept", "teslim al", "pick up", "ek dahil", "includes"],
        "minFingerprintMatches": 3,
        "totalLabels": [], "bonusLabels": ["dahil", "includes", "icinde"], "packageLabels": [],
        "totalIncludesBonus": true, "minPackageFee": null, "maxPackageFee": null,
        "dayLabels": [], "weekLabels": [], "amountsExcludeVAT": true
      },
      {
        "id": "banabikurye.order", "version": 1, "status": "calibrating", "platformCode": "banabikurye", "layout": "orderCard",
        "detectionKeywords": ["banabikurye", "bbk"],
        "fingerprint": ["nakit kazanc", "gonderi notu", "siparis", "tanim", "tarif", "odeme", "fazla kazanc", "gonderiler"],
        "minFingerprintMatches": 3,
        "totalLabels": ["nakit kazanc", "nakit"], "bonusLabels": [], "packageLabels": [],
        "totalIncludesBonus": true, "minPackageFee": null, "maxPackageFee": null,
        "dayLabels": ["bugun"], "weekLabels": []
      }
    ]
    """#
}
