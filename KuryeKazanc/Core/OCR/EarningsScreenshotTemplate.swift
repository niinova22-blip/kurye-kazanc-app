import Foundation

/// Bir platformun kazanc ekran goruntusunu ayristirma sablonu.
///
/// Etiketler normalize edilmis (kucuk harf, Turkce karakterler ASCII'ye katlanmis) bicimde yazilir:
/// "Toplam Kazanç" -> "toplam kazanc". Listeler ONCELIK SIRASINDADIR: daha ozgul etiket once.
///
/// ONEMLI: Etiketler platformlarin kurye uygulamalarinda yaygin kullanilan ifadelere gore yazildi;
/// gercek ekran goruntuleriyle (TestFlight) kalibre edilmeli. Yeni ifade gorulurse buraya eklenir
/// ve `EarningsScreenshotParserTests`'e o ekranin OCR satirlariyla bir test eklenir.
protocol EarningsScreenshotTemplate {
    var platformCode: String { get }
    /// Ekranda bu platforma ait oldugunu gosteren kelimeler (tam kelime eslesmesi).
    var detectionKeywords: [String] { get }
    var totalLabels: [String] { get }
    var bonusLabels: [String] { get }
    var packageLabels: [String] { get }
    /// Ekrandaki "toplam" bonusu da iceriyor mu? Iceriyorsa brut = toplam - bonus.
    var totalIncludesBonus: Bool { get }
}

struct TrendyolGoTemplate: EarningsScreenshotTemplate {
    let platformCode = "trendyol_go"
    let detectionKeywords = ["trendyol go", "trendyol", "tgo"]
    let totalLabels = [
        "toplam kazanc", "toplam hakedis", "net kazanc", "gunluk kazanc",
        "haftalik kazanc", "toplam tutar", "hakedis", "toplam",
    ]
    let bonusLabels = ["bonus", "prim", "tesvik", "ek odeme", "ekstra kazanc"]
    let packageLabels = [
        "teslimat sayisi", "teslim edilen paket", "teslim edilen", "paket sayisi",
        "tamamlanan teslimat", "teslimat", "paket",
    ]
    let totalIncludesBonus = true
}

struct GetirTemplate: EarningsScreenshotTemplate {
    let platformCode = "getir"
    let detectionKeywords = ["getir", "getirkurye", "getir kurye", "getiryemek", "getirbuyuk"]
    let totalLabels = [
        "toplam kazanc", "toplam kazancin", "toplam hakedis", "toplam tutar",
        "net kazanc", "gunluk kazanc", "hakedis", "kazancin", "toplam",
    ]
    let bonusLabels = ["bonus", "ek kazanc", "prim", "kampanya", "tesvik", "ek odeme"]
    let packageLabels = [
        "siparis sayisi", "teslim edilen siparis", "tamamlanan siparis",
        "teslimat sayisi", "siparis", "teslimat", "paket",
    ]
    let totalIncludesBonus = true
}

/// Platform taninamadiginda kullanilan genel sablon (alanlar yine okunur ama platform kontrol icin isaretlenir).
struct GenericTemplate: EarningsScreenshotTemplate {
    let platformCode = ""
    let detectionKeywords: [String] = []
    let totalLabels = ["toplam kazanc", "toplam hakedis", "toplam tutar", "net kazanc", "hakedis", "toplam"]
    let bonusLabels = ["bonus", "prim", "tesvik", "ek kazanc", "ek odeme"]
    let packageLabels = ["teslimat sayisi", "siparis sayisi", "paket sayisi", "teslimat", "siparis", "paket"]
    let totalIncludesBonus = true
}
