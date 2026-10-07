# Sürüm 1.1 — iOS tarzı arayüz ve cihaz üstü temel — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** TestFlight 1.1.0: Apple tarzı sade arayüz (Bugün / Analiz / Topluluk iskeleti / Profil), doğrulama seviyeli kazanç kayıtları, JSON şablon motoru, ekran görüntüsü kanıtı, paylaş eklentisi, yeni ekran görüntüsü önerisi, analizler ve hedefler.

**Architecture:** Yerel öncelikli; sunucu yok. Saf mantık `KuryeKazanc/Core` içinde (Windows'ta `swift test`). SwiftData SchemaV2'ye hafif + özel göç. Paylaş eklentisi görseli App Group "Gelen Kutusu" klasörüne yazar; uygulama açılınca işler (SwiftData deposu taşınmaz).

**Tech Stack:** Swift 5 modu, SwiftUI, SwiftData, Swift Charts, Vision, PhotoKit, iOS 17+, XcodeGen, Codemagic, XCTest/XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md`

## Global Constraints

- iOS deployment target `17.0`; `SWIFT_VERSION: "5.0"`; yeni üçüncü taraf bağımlılık **yok**.
- `KuryeKazanc/Core` içindeki dosyalar SwiftData/UIKit/SwiftUI/Vision/PhotoKit/CryptoKit **import etmez** (Windows'ta derlenir).
- Kod yorumları mevcut stilde ASCII Türkçe (ç/ğ/ı/ö/ş/ü yok); kullanıcıya görünen metinler doğru Türkçe karakterlerle.
- Para birimi ve tarih biçimi yalnızca `Formatters` üzerinden (`tr_TR`, TRY).
- Bu sürümde **hiçbir veri cihaz dışına gönderilmez**; paylaşım/konum rızaları yalnızca kaydedilir.
- Topluluğa girebilecek seviye yalnızca `verified`; 1.1'de tüm şablonlar `calibrating` olduğundan pratikte hiçbir kayıt `verified` olmaz — bu beklenen davranıştır.
- Görsel dil: sistem renkleri + tek vurgu (yeşil; açık `#248A3D`, koyu `#30D158`); kırmızı yalnızca gider ve "vardiyayı bitir"; gradyan yok; yalnızca Dynamic Type stilleri; büyük rakamlar `.rounded` + `monospacedDigit()`.
- UI testlerinin dayandığı `accessibilityIdentifier`'lar korunur: `dashboard.netEarnings`, `dashboard.netPerHour`, `dashboard.workDuration`, `dashboard.distance`, `dashboard.addMenu`, `dashboard.workToggle`, `dashboard.earningRow`, `history.periodPicker`, `history.netEarnings`, `settings.autoEstimate`, `settings.dataSharing`, `consent.accept`, `form.save`, `form.cancel`, `earningForm.*`, `expenseForm.*`, `onboarding.*`.
- App Group kimliği: `group.com.kuryekazanc.app`. Eklenti bundle ID: `com.kuryekazanc.app.share`.

**Spec'ten bilinçli sapmalar (kullanıcıya bildirildi):**
- SwiftData deposu App Group'a taşınmaz; eklenti yalnızca görsel dosyası bırakır (daha az risk). Widget'lar 1.2'de App Group'a yazılan küçük bir özet JSON'u okuyacak.
- Hedefler `Goal` modeli yerine `@AppStorage` anahtarlarıyla (iki sayı; model gereksiz).
- `text_hash` ve gün düzeyinde mutabakat (spec §4.2-4, §4.3) sunucuyla birlikte 1.3/1.4'e kalır; 1.1'de ekran görüntüsünden oluşan kayıt doğrudan kanıtına bağlanır.

## Review Focus

1. **V1 → V2 göçü:** TestFlight 1.0.0'daki gerçek kayıtlar güncellemede kaybolmamalı; OCR kaynaklı eski kayıtlar `ocrUnverified` olmalı. → Görev 5'te disk üstü göç testi.
2. **Haftalık ekran görüntüsü:** Haftalık toplam tek bir günlük vardiya gibi kaydedilmemeli; kullanıcı uyarılmalı ve kayıt `verified` olamamalı. → Görev 2 (`period == .week` → `ocrUnverified`) ve Görev 7 (uyarı metni) testleri.
3. **OCR sonrası kullanıcı tutarı düzeltirse** kayıt `ocrEdited` olmalı; yalnızca saatleri değiştirirse (ekranda saat yok) seviye düşmemeli. → Görev 7 testleri.
4. **Fotoğraf izni reddedilmiş/sınırlı** iken ekran görüntüsü taraması ve paylaş eklentisi uygulamayı kilitlememeli; öneri satırı sessizce gizlenmeli. → Görev 12 testi (izin yok → boş sonuç).
5. **Gece yarısını geçen vardiya** ısı haritasında iki güne doğru bölünmeli (Pazar 23:00–Pazartesi 01:00). → Görev 3 testi.

---

## Dosya yapısı

| Dosya | Sorumluluk |
|---|---|
| `KuryeKazanc/Core/OCR/OCRTemplate.swift` (yeni) | Codable şablon modeli, parmak izi ve dönem tespiti |
| `KuryeKazanc/Core/OCR/BundledTemplates.swift` (yeni) | Gömülü JSON şablonlar (Trendyol GO, Getir, Yemeksepeti, Migros, genel) |
| `KuryeKazanc/Core/OCR/EarningsScreenshotTemplate.swift` (silinir) | Eski protokol + struct şablonlar |
| `KuryeKazanc/Core/OCR/EarningsScreenshotParser.swift` (değişir) | `OCRTemplate` kullanır; şablon meta verisini döndürür |
| `KuryeKazanc/Core/OCR/RecognizedLine.swift` (yeni) | OCR satırı + normalize sınır kutusu (Codable) |
| `KuryeKazanc/Core/Verification/VerificationLevel.swift` (yeni) | Seviyeler + son seviye kuralı |
| `KuryeKazanc/Core/Verification/ScreenshotVerifier.swift` (yeni) | Gerçek ekran görüntüsü + şablon + tutarlılık değerlendirmesi |
| `KuryeKazanc/Core/Analytics/EarningsAnalytics.swift` (yeni) | Isı haritası, en iyi dilimler, platform karşılaştırması, dönem değişimi |
| `KuryeKazanc/Core/Goals.swift` (yeni) | Hedef ilerlemesi |
| `KuryeKazanc/Models/SchemaV1Snapshot.swift` (yeni) | Dondurulmuş V1 modelleri (göç için) |
| `KuryeKazanc/Models/ScreenshotEvidence.swift` (yeni) | Ekran görüntüsü kanıtı modeli |
| `KuryeKazanc/Models/EarningRecord.swift` (değişir) | `verificationRaw`, `evidence` |
| `KuryeKazanc/App/ModelContainerFactory.swift` (değişir) | SchemaV2 + göç planı |
| `KuryeKazanc/Services/OCR/TextRecognitionService.swift` (değişir) | `[RecognizedLine]` döndürür |
| `KuryeKazanc/Services/Screenshots/ScreenshotImporter.swift` (yeni) | Görsel verisi → OCR → ayrıştırma → değerlendirme |
| `KuryeKazanc/Services/Screenshots/ScreenshotScanner.swift` (yeni) | PhotoKit: son 48 saatin işlenmemiş ekran görüntüleri |
| `KuryeKazanc/Services/Screenshots/ScreenshotInbox.swift` (yeni) | App Group gelen kutusu (eklenti ↔ uygulama) |
| `KuryeKazanc/Views/Design/*.swift` (yeni) | Renk, bileşenler, dokunsal geri bildirim |
| `KuryeKazanc/Views/Today/TodayView.swift` (yeni; `Views/Dashboard` silinir) | Bugün sekmesi |
| `KuryeKazanc/Views/Analysis/AnalysisView.swift` (yeni; `Views/History` silinir) | Analiz sekmesi |
| `KuryeKazanc/Views/Analysis/AnalysisSections.swift` (yeni) | Isı haritası, platform, en iyi dilim bölümleri |
| `KuryeKazanc/Views/Shared/RecordRows.swift` (yeni) | `EarningListRow`, `ExpenseListRow` (eski HistoryView'dan taşınır) |
| `KuryeKazanc/Views/Profile/ProfileView.swift` (yeni; `Views/Settings` silinir) | Profil sekmesi |
| `KuryeKazanc/Views/Profile/ConsentViews.swift` (yeni) | Kazanç ve konum paylaşımı rıza ekranları |
| `KuryeKazanc/Views/Community/CommunityView.swift` (yeni) | Topluluk iskeleti / davet |
| `KuryeKazanc/Views/Onboarding/OnboardingView.swift` (değişir) | 4 adım: araç → platform → konum → paylaşım |
| `KuryeShareExtension/*` (yeni hedef) | Paylaş menüsü eklentisi |
| `project.yml`, `codemagic.yaml`, `Info.plist`, `*.entitlements` | Hedef, App Group, imzalama |

**Doğrulama ortamı:** Core görevleri yerelde `swift test` ile (Windows, saniyeler). Diğer görevler Mac olmadan derlenemez: her görevin sonunda `develop`'a push → Codemagic `ios-ci` (derleme + birim testleri, ~6 dk). UI testleri yalnızca PR'da çalışır; Görev 15'teki PR hepsini koşturur. Build sonucunu görmek: Codemagic → kurye-kazanc → son build (veya `gh`/tarayıcı). Kırmızıysa sonraki göreve geçilmez.

---

### Task 1: JSON şablon modeli ve ayrıştırıcının şablon motoruna geçişi

**Files:**
- Create: `KuryeKazanc/Core/OCR/OCRTemplate.swift`
- Create: `KuryeKazanc/Core/OCR/BundledTemplates.swift`
- Delete: `KuryeKazanc/Core/OCR/EarningsScreenshotTemplate.swift`
- Modify: `KuryeKazanc/Core/OCR/EarningsScreenshotParser.swift`
- Test: `KuryeKazancTests/Core/OCRTemplateTests.swift` (yeni), mevcut `EarningsScreenshotParserTests.swift` değişmeden geçmeli

**Interfaces:**
- Produces: `struct OCRTemplate: Codable, Equatable` (alanlar aşağıda), `OCRTemplate.Status { calibrating, active }`, `OCRTemplate.Period { day, week, unknown }`, `func fingerprintMatches(in normalizedText: String) -> Int`, `func period(in normalizedText: String) -> Period`; `enum BundledTemplates { static let all: [OCRTemplate]; static let generic: OCRTemplate; static func template(id: String) -> OCRTemplate? }`; `ParsedEarning` yeni alanları: `templateID: String? = nil`, `templateVersion: Int? = nil`, `templateStatus: OCRTemplate.Status? = nil`, `fingerprintMatches: Int = 0`, `period: OCRTemplate.Period = .unknown`.

- [ ] **Step 1: Başarısız testleri yaz** — `KuryeKazancTests/Core/OCRTemplateTests.swift`

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class OCRTemplateTests: XCTestCase {
    func testBundledTemplatesDecodeAndCoverMainPlatforms() {
        let codes = Set(BundledTemplates.all.map(\.platformCode))
        XCTAssertEqual(codes, ["trendyol_go", "getir", "yemeksepeti", "migros_hemen"])
        // Gercek ekranla kalibre edilene kadar hicbiri aktif degil
        XCTAssertTrue(BundledTemplates.all.allSatisfy { $0.status == .calibrating })
        XCTAssertEqual(BundledTemplates.generic.platformCode, "")
        XCTAssertNotNil(BundledTemplates.template(id: "getir.earnings"))
    }

    func testFingerprintAndPeriodDetection() {
        let template = BundledTemplates.template(id: "trendyol_go.earnings")!
        let text = TextNormalizer.normalize("Trendyol GO Kazançlarım Haftalık Kazanç Toplam Kazanç ₺3.200")
        XCTAssertGreaterThanOrEqual(template.fingerprintMatches(in: text), 2)
        XCTAssertEqual(template.period(in: text), .week)
        XCTAssertEqual(template.period(in: TextNormalizer.normalize("Bugün Toplam Kazanç")), .day)
        XCTAssertEqual(template.period(in: "toplam"), .unknown)
    }

    func testParserReportsTemplateMetadata() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 14))!
        let parsed = EarningsScreenshotParser(calendar: calendar).parse(
            lines: ["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"],
            referenceDate: reference
        )
        XCTAssertEqual(parsed.templateID, "getir.earnings")
        XCTAssertEqual(parsed.templateVersion, 1)
        XCTAssertEqual(parsed.templateStatus, .calibrating)
        XCTAssertEqual(parsed.period, .day)
        XCTAssertGreaterThanOrEqual(parsed.fingerprintMatches, 1)
    }

    func testUnknownPlatformUsesGenericTemplateWithoutID() {
        let parsed = EarningsScreenshotParser().parse(lines: ["Toplam 500 TL"])
        XCTAssertNil(parsed.templateID)
        XCTAssertNil(parsed.platformCode)
        XCTAssertTrue(parsed.fieldsToReview.contains(.platform))
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `swift test --filter OCRTemplateTests`
Expected: derleme hatası — `cannot find 'BundledTemplates' in scope`.

- [ ] **Step 3: `OCRTemplate.swift` yaz**

```swift
import Foundation

/// Bir platformun kazanc ekrani sablonu. JSON olarak tanimlanir: uygulamaya gomulu kopya (BundledTemplates)
/// ve 1.3'ten itibaren sunucudan indirilen guncel surumler. Etiketler normalize bicimdedir (bkz. TextNormalizer).
///
/// ONEMLI: Gercek ekran ornekleri toplanana kadar tum sablonlar `calibrating` durumundadir;
/// `calibrating` sablonla okunan kayit asla `verified` olmaz.
struct OCRTemplate: Codable, Equatable {
    enum Status: String, Codable { case calibrating, active }
    enum Period: String, Codable { case day, week, unknown }

    var id: String
    var version: Int
    var status: Status
    var platformCode: String
    var detectionKeywords: [String]
    /// Kazanc ekranina ozgu sabit metinler (baslik, sekme adi...). Dogrulama icin en az `minFingerprintMatches` tanesi gorulmeli.
    var fingerprint: [String]
    var minFingerprintMatches: Int
    /// Listeler ONCELIK SIRASINDADIR: daha ozgul etiket once.
    var totalLabels: [String]
    var bonusLabels: [String]
    var packageLabels: [String]
    /// Ekrandaki "toplam" bonusu da iceriyor mu? Iceriyorsa brut = toplam - bonus.
    var totalIncludesBonus: Bool
    /// Paket basi ucret araligi (TL); ic tutarlilik kontrolu icin. Bilinmiyorsa nil.
    var minPackageFee: Double?
    var maxPackageFee: Double?
    var dayLabels: [String]
    var weekLabels: [String]

    func fingerprintMatches(in normalizedText: String) -> Int {
        fingerprint.filter { TextPatterns.containsWord($0, in: normalizedText) }.count
    }

    /// Haftalik ifade gunluk ifadeden onceliklidir ("Bugun" haftalik ekranda da gorunebilir).
    func period(in normalizedText: String) -> Period {
        if weekLabels.contains(where: { TextPatterns.containsWord($0, in: normalizedText) }) { return .week }
        if dayLabels.contains(where: { TextPatterns.containsWord($0, in: normalizedText) }) { return .day }
        return .unknown
    }
}
```

- [ ] **Step 4: `BundledTemplates.swift` yaz** (mevcut Trendyol/Getir etiketleri birebir taşınır; Yemeksepeti ve Migros eklenir)

```swift
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
```

- [ ] **Step 5: Ayrıştırıcıyı güncelle** — `EarningsScreenshotParser.swift`

`ParsedEarning` içine (mevcut alanlardan sonra, varsayılanlı — mevcut `ParsedEarning(...)` çağrıları derlenmeye devam eder):

```swift
    /// Eslesen sablonun kimligi; platform taninamadiysa nil.
    var templateID: String? = nil
    var templateVersion: Int? = nil
    var templateStatus: OCRTemplate.Status? = nil
    /// Ekranda gorulen parmak izi metni sayisi.
    var fingerprintMatches: Int = 0
    /// Ekran gunluk mu haftalik mi?
    var period: OCRTemplate.Period = .unknown
```

`EarningsScreenshotParser` içinde değişiklikler:

```swift
    var templates: [OCRTemplate] = BundledTemplates.all
```

`parse` içinde platform bloğu:

```swift
        // 1) Platform
        let template: OCRTemplate
        let detected = detectTemplate(in: normalized)
        if let detected {
            template = detected
        } else {
            template = BundledTemplates.generic
            review.insert(.platform)
        }
        let fullText = normalized.joined(separator: " ")
```

`return ParsedEarning(` çağrısına son argümanlar eklenir:

```swift
            fieldsToReview: review,
            templateID: detected?.id,
            templateVersion: detected?.version,
            templateStatus: detected?.status,
            fingerprintMatches: detected?.fingerprintMatches(in: fullText) ?? 0,
            period: template.period(in: fullText)
        )
```

`detectTemplate` imzası: `func detectTemplate(in lines: [String]) -> OCRTemplate?` ve içindeki `best` tipi `(template: OCRTemplate, score: Int)?`. Gövde aynı kalır.

- [ ] **Step 6: Eski şablon dosyasını sil**

Run: `git rm KuryeKazanc/Core/OCR/EarningsScreenshotTemplate.swift`

- [ ] **Step 7: Tüm Core testlerini çalıştır**

Run: `swift test`
Expected: tüm testler PASS (eski `EarningsScreenshotParserTests` dahil — etiketler birebir taşındığı için davranış aynı).

- [ ] **Step 8: Commit**

```bash
git add KuryeKazanc/Core/OCR KuryeKazancTests/Core/OCRTemplateTests.swift
git commit -m "feat(core): JSON OCR sablon motoru; Yemeksepeti ve Migros sablonlari (kalibrasyonda)"
```

---

### Task 2: Doğrulama seviyeleri ve ekran görüntüsü değerlendirmesi

**Files:**
- Create: `KuryeKazanc/Core/Verification/VerificationLevel.swift`
- Create: `KuryeKazanc/Core/Verification/ScreenshotVerifier.swift`
- Test: `KuryeKazancTests/Core/ScreenshotVerifierTests.swift`

**Interfaces:**
- Consumes: `ParsedEarning`, `OCRTemplate`, `BundledTemplates` (Task 1).
- Produces:
  - `enum VerificationLevel: String, Codable, CaseIterable { case manual, ocrEdited, ocrUnverified, verified }` + `var countsForCommunity: Bool`, `var displayName: String`, `static func resolve(isFromScreenshot: Bool, userEditedReadValues: Bool, candidate: VerificationLevel) -> VerificationLevel`
  - `enum ScreenshotAuthenticity { static func isGenuine(assetIsScreenshot: Bool?, pixelWidth: Int, pixelHeight: Int, hasCameraMetadata: Bool) -> Bool }`
  - `struct ScreenshotAssessment: Equatable { var isGenuine, templateActive, fingerprintOK, dateRecent, isDailyScreen, internallyConsistent: Bool; var candidate: VerificationLevel; var issues: [String] }`
  - `struct ScreenshotVerifier { var calendar: Calendar; var maxAgeDays = 14; func assess(_ parsed: ParsedEarning, template: OCRTemplate?, isGenuine: Bool, referenceDate: Date) -> ScreenshotAssessment }`

- [ ] **Step 1: Başarısız testleri yaz**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScreenshotVerifierTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 20))! }
    private var verifier: ScreenshotVerifier { ScreenshotVerifier(calendar: calendar) }

    private func activeTemplate() -> OCRTemplate {
        var t = BundledTemplates.template(id: "getir.earnings")!
        t.status = .active
        return t
    }

    private func parsed(total: Double = 980, packages: Int = 11, daysAgo: Int = 0,
                        period: OCRTemplate.Period = .day, fingerprint: Int = 3,
                        review: Set<ParsedEarning.Field> = []) -> ParsedEarning {
        ParsedEarning(
            platformCode: "getir",
            date: calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!,
            packageCount: packages, totalEarning: total, bonus: 0, totalIncludesBonus: true,
            fieldsToReview: review, templateID: "getir.earnings", templateVersion: 1,
            templateStatus: .active, fingerprintMatches: fingerprint, period: period
        )
    }

    // MARK: - Gercek ekran goruntusu

    func testAuthenticity() {
        XCTAssertTrue(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: true, pixelWidth: 1, pixelHeight: 1, hasCameraMetadata: false))
        XCTAssertFalse(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: false, pixelWidth: 1179, pixelHeight: 2556, hasCameraMetadata: false))
        // PhotoKit bilgisi yoksa: bilinen iPhone ekran cozunurlugu + kamera EXIF'i yok
        XCTAssertTrue(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: nil, pixelWidth: 1179, pixelHeight: 2556, hasCameraMetadata: false))
        XCTAssertFalse(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: nil, pixelWidth: 1179, pixelHeight: 2556, hasCameraMetadata: true))
        XCTAssertFalse(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: nil, pixelWidth: 3024, pixelHeight: 4032, hasCameraMetadata: false))
    }

    // MARK: - Aday seviye

    func testAllChecksPass_isVerified() {
        let result = verifier.assess(parsed(), template: activeTemplate(), isGenuine: true, referenceDate: now)
        XCTAssertEqual(result.candidate, .verified, "\(result.issues)")
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testCalibratingTemplate_isUnverified() {
        let result = verifier.assess(parsed(), template: BundledTemplates.template(id: "getir.earnings"), isGenuine: true, referenceDate: now)
        XCTAssertEqual(result.candidate, .ocrUnverified)
        XCTAssertFalse(result.templateActive)
    }

    func testNotGenuine_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(), template: activeTemplate(), isGenuine: false, referenceDate: now).candidate, .ocrUnverified)
    }

    func testWeeklyScreen_isUnverifiedWithIssue() {
        let result = verifier.assess(parsed(period: .week), template: activeTemplate(), isGenuine: true, referenceDate: now)
        XCTAssertEqual(result.candidate, .ocrUnverified)
        XCTAssertFalse(result.isDailyScreen)
        XCTAssertTrue(result.issues.contains { $0.contains("Haftalık") })
    }

    func testOldOrFutureDate_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(daysAgo: 15), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        XCTAssertEqual(verifier.assess(parsed(daysAgo: -1), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        XCTAssertEqual(verifier.assess(parsed(daysAgo: 14), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .verified)
    }

    func testFingerprintBelowMinimum_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(fingerprint: 1), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
    }

    func testInconsistentPackageFee_isUnverified() {
        // 11 paket x en fazla 250 TL = 2.750; 9.000 TL aciklanamaz
        XCTAssertEqual(verifier.assess(parsed(total: 9000), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        // 11 paket x en az 40 TL = 440; 100 TL fazla dusuk
        XCTAssertEqual(verifier.assess(parsed(total: 100), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        // Paket okunamadiysa ucret kontrolu yapilmaz
        XCTAssertEqual(verifier.assess(parsed(total: 9000, packages: 0), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .verified)
    }

    func testUncertainTotalOrPlatform_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(review: [.totalEarning]), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        XCTAssertEqual(verifier.assess(parsed(), template: nil, isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        // Bonus/paket belirsizligi seviyeyi dusurmez
        XCTAssertEqual(verifier.assess(parsed(review: [.bonus]), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .verified)
    }

    // MARK: - Son seviye

    func testResolve() {
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: false, userEditedReadValues: false, candidate: .verified), .manual)
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: true, userEditedReadValues: true, candidate: .verified), .ocrEdited)
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: true, userEditedReadValues: false, candidate: .verified), .verified)
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: true, userEditedReadValues: false, candidate: .ocrUnverified), .ocrUnverified)
        XCTAssertTrue(VerificationLevel.verified.countsForCommunity)
        XCTAssertFalse(VerificationLevel.ocrUnverified.countsForCommunity)
    }
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `swift test --filter ScreenshotVerifierTests`
Expected: derleme hatası — `cannot find 'ScreenshotVerifier' in scope`.

- [ ] **Step 3: `VerificationLevel.swift` yaz**

```swift
import Foundation

/// Kazanc kaydinin ne kadar guvenilir oldugu. Topluluk istatistiklerine yalnizca `verified` girer;
/// kisisel analizlerde tum seviyeler kullanilir (seviye yalnizca rozet olarak gorunur).
enum VerificationLevel: String, Codable, CaseIterable {
    /// Elle girildi.
    case manual
    /// Ekran goruntusunden okundu ama kullanici okunan tutar/tarih/platform/paketi degistirdi.
    case ocrEdited
    /// Ekran goruntusunden okundu, degistirilmedi; ancak kontrollerden biri gecmedi (or. sablon kalibrasyonda).
    case ocrUnverified
    /// Tum kontrollerden gecti.
    case verified

    var countsForCommunity: Bool { self == .verified }

    var displayName: String {
        switch self {
        case .manual: "Elle girildi"
        case .ocrEdited: "Ekran görüntüsü, düzenlendi"
        case .ocrUnverified: "Ekran görüntüsü"
        case .verified: "Doğrulandı"
        }
    }

    /// Kayit anindaki son seviye.
    /// - Parameter userEditedReadValues: Ekrandan okunan degerlerden biri degistirildi mi? (Saatler ekranda olmadigindan sayilmaz.)
    static func resolve(isFromScreenshot: Bool, userEditedReadValues: Bool, candidate: VerificationLevel) -> VerificationLevel {
        guard isFromScreenshot else { return .manual }
        if userEditedReadValues { return .ocrEdited }
        return candidate == .verified ? .verified : .ocrUnverified
    }
}
```

- [ ] **Step 4: `ScreenshotVerifier.swift` yaz**

```swift
import Foundation

/// Gorselin gercek bir iPhone ekran goruntusu olup olmadigi.
enum ScreenshotAuthenticity {
    /// Portre piksel boyutlari (genislik x yukseklik). Yeni iPhone ciktikca eklenir.
    static let knownScreenSizes: Set<[Int]> = [
        [640, 1136], [750, 1334], [828, 1792], [1080, 1920], [1080, 2340],
        [1125, 2436], [1170, 2532], [1179, 2556], [1206, 2622], [1242, 2208],
        [1242, 2688], [1260, 2736], [1284, 2778], [1290, 2796], [1320, 2868],
    ]

    /// - Parameter assetIsScreenshot: PhotoKit'in `.photoScreenshot` bilgisi; erisim yoksa nil.
    static func isGenuine(assetIsScreenshot: Bool?, pixelWidth: Int, pixelHeight: Int, hasCameraMetadata: Bool) -> Bool {
        if let assetIsScreenshot { return assetIsScreenshot }
        guard !hasCameraMetadata else { return false }
        let portrait = [min(pixelWidth, pixelHeight), max(pixelWidth, pixelHeight)]
        return knownScreenSizes.contains(portrait)
    }
}

/// Bir ekran goruntusunun dogrulama degerlendirmesi. `candidate`, kullanici degeri degistirmezse alinacak seviyedir.
struct ScreenshotAssessment: Equatable {
    var isGenuine: Bool
    var templateActive: Bool
    var fingerprintOK: Bool
    var dateRecent: Bool
    var isDailyScreen: Bool
    var internallyConsistent: Bool
    var candidate: VerificationLevel
    /// Kullaniciya gosterilecek kisa aciklamalar (neden dogrulanmadi).
    var issues: [String]
}

struct ScreenshotVerifier {
    var calendar: Calendar
    var maxAgeDays = 14

    func assess(_ parsed: ParsedEarning, template: OCRTemplate?, isGenuine: Bool, referenceDate: Date) -> ScreenshotAssessment {
        var issues: [String] = []

        let templateActive = template?.status == .active && parsed.templateID == template?.id
        if template == nil {
            issues.append("Platform ekranı tanınmadı.")
        } else if !templateActive {
            issues.append("Bu platformun ekranı henüz kalibre ediliyor.")
        }

        let fingerprintOK = template.map { parsed.fingerprintMatches >= $0.minFingerprintMatches } ?? false
        if template != nil, !fingerprintOK {
            issues.append("Kazanç ekranına özgü yazılar bulunamadı.")
        }

        if !isGenuine {
            issues.append("Görsel bir iPhone ekran görüntüsü değil.")
        }

        let today = calendar.startOfDay(for: referenceDate)
        let day = calendar.startOfDay(for: parsed.date)
        let age = calendar.dateComponents([.day], from: day, to: today).day ?? Int.max
        let dateRecent = (0...maxAgeDays).contains(age)
        if !dateRecent {
            issues.append("Tarih son \(maxAgeDays) gün içinde değil.")
        }

        let isDailyScreen = parsed.period != .week
        if !isDailyScreen {
            issues.append("Haftalık ekran: vardiya için günlük kazanç ekranını kullan.")
        }

        let readsCore = !parsed.fieldsToReview.contains(.totalEarning) && !parsed.fieldsToReview.contains(.platform)
        if !readsCore {
            issues.append("Toplam tutar veya platform kesin okunamadı.")
        }

        let consistent = isConsistent(parsed, template: template)
        if !consistent {
            issues.append("Paket sayısı ile toplam tutar uyuşmuyor.")
        }

        let allPass = templateActive && fingerprintOK && isGenuine && dateRecent && isDailyScreen && readsCore && consistent
        return ScreenshotAssessment(
            isGenuine: isGenuine, templateActive: templateActive, fingerprintOK: fingerprintOK,
            dateRecent: dateRecent, isDailyScreen: isDailyScreen, internallyConsistent: consistent,
            candidate: allPass ? .verified : .ocrUnverified, issues: issues
        )
    }

    /// Paket basi ucret araligi toplam tutari aciklayabiliyor mu? Bonus ust sinira eklenir.
    private func isConsistent(_ parsed: ParsedEarning, template: OCRTemplate?) -> Bool {
        guard parsed.totalEarning > 0 else { return false }
        guard parsed.packageCount > 0,
              let minFee = template?.minPackageFee, let maxFee = template?.maxPackageFee else { return true }
        let count = Double(parsed.packageCount)
        let lower = count * minFee * 0.8
        let upper = count * maxFee * 1.5 + parsed.bonus
        return (lower...upper).contains(parsed.totalEarning)
    }
}
```

- [ ] **Step 5: Testleri çalıştır**

Run: `swift test`
Expected: tüm testler PASS.

- [ ] **Step 6: Commit**

```bash
git add KuryeKazanc/Core/Verification KuryeKazancTests/Core/ScreenshotVerifierTests.swift
git commit -m "feat(core): dogrulama seviyeleri ve ekran goruntusu degerlendirmesi"
```

---

### Task 3: Analizler — ısı haritası, en iyi dilimler, platform karşılaştırması, dönem değişimi

**Files:**
- Create: `KuryeKazanc/Core/Analytics/EarningsAnalytics.swift`
- Test: `KuryeKazancTests/Core/EarningsAnalyticsTests.swift`

**Interfaces:**
- Consumes: `EarningEntry` (mevcut; `packageCount` alanı bu görevde eklenir, varsayılan `nil`), `EarningsCalculator.mergedDuration`.
- Produces:
  - `EarningEntry.packageCount: Int?` (yeni, `= nil` varsayılanlı; mevcut çağrılar derlenir)
  - `struct HourSlot: Hashable, Comparable { var weekday: Int /* 1=Pazartesi...7=Pazar */; var hour: Int }`
  - `struct SlotStat: Equatable { var minutes: Double; var estimatedNet: Double; var netPerHour: Double? }`
  - `struct PlatformStat: Equatable, Identifiable { var platformCode: String; var total: Double; var hours: Double; var packages: Int; var distanceKm: Double; var netPerHour: Double?; var netPerPackage: Double?; var netPerKm: Double?; var id: String }`
  - `struct EarningsAnalytics { var calendar: Calendar; var costPerKm: Double; func heatmap(_:) -> [HourSlot: SlotStat]; func topSlots(_:limit:minimumMinutes:) -> [RankedSlot]`; `struct RankedSlot: Equatable { var slot: HourSlot; var stat: SlotStat }; func platformStats(_:) -> [PlatformStat]; static func percentChange(current:previous:) -> Double? }`

Not: "tahmini net" = kayıt toplamı − km × km başı maliyet; kayda bağlanamayan manuel giderler dilimlere dağıtılmaz (ekranda "tahmini" yazılır).

- [ ] **Step 1: `EarningEntry`'ye paket alanı ekle** — `KuryeKazanc/Core/EarningsCalculator.swift`

```swift
struct EarningEntry: Equatable {
    var start: Date
    var end: Date
    var gross: Double
    var bonus: Double
    var distanceKm: Double
    var platformCode: String?
    var packageCount: Int? = nil
}
```

ve `KuryeKazanc/Models/ModelEntries.swift`:

```swift
extension EarningRecord {
    var entry: EarningEntry {
        EarningEntry(
            start: startTime, end: endTime, gross: grossEarning, bonus: bonus,
            distanceKm: distanceKm, platformCode: platform?.code, packageCount: packageCount
        )
    }
}
```

- [ ] **Step 2: Başarısız testleri yaz**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class EarningsAnalyticsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var analytics: EarningsAnalytics { EarningsAnalytics(calendar: calendar, costPerKm: 2) }

    /// 2026-10-05 Pazartesi
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func entry(_ start: Date, _ end: Date, total: Double, km: Double = 0, code: String? = "getir", packages: Int? = nil) -> EarningEntry {
        EarningEntry(start: start, end: end, gross: total, bonus: 0, distanceKm: km, platformCode: code, packageCount: packages)
    }

    func testHeatmapSplitsShiftAcrossHoursProportionally() {
        // Pazartesi 18:30-20:00, 300 TL, 10 km -> tahmini net 280; 90 dk
        let map = analytics.heatmap([entry(at(5, 18, 30), at(5, 20), total: 300, km: 10)])
        let h18 = map[HourSlot(weekday: 1, hour: 18)]!
        let h19 = map[HourSlot(weekday: 1, hour: 19)]!
        XCTAssertEqual(h18.minutes, 30, accuracy: 0.001)
        XCTAssertEqual(h19.minutes, 60, accuracy: 0.001)
        XCTAssertEqual(h18.estimatedNet, 280.0 / 3, accuracy: 0.01)
        XCTAssertEqual(h19.netPerHour!, 280.0 / 1.5, accuracy: 0.01)
        XCTAssertNil(map[HourSlot(weekday: 1, hour: 20)])
    }

    func testHeatmapOvernightShiftCrossesIntoMonday() {
        // Pazar 4 Ekim 23:00 - Pazartesi 01:00
        let map = analytics.heatmap([entry(at(4, 23), at(5, 1), total: 200)])
        XCTAssertEqual(map[HourSlot(weekday: 7, hour: 23)]?.minutes, 60)
        XCTAssertEqual(map[HourSlot(weekday: 1, hour: 0)]?.minutes, 60)
    }

    func testHeatmapAccumulatesSameSlotAcrossWeeks() {
        let map = analytics.heatmap([
            entry(at(5, 19), at(5, 20), total: 100),
            entry(at(12, 19), at(12, 20), total: 300),
        ])
        let slot = map[HourSlot(weekday: 1, hour: 19)]!
        XCTAssertEqual(slot.minutes, 120)
        XCTAssertEqual(slot.netPerHour!, 200, accuracy: 0.001)
    }

    func testTopSlotsRequireMinimumMinutesAndSortByNetPerHour() {
        let entries = [
            entry(at(5, 12), at(5, 13), total: 150),       // Pzt 12: 150/sa
            entry(at(6, 19), at(6, 20), total: 400),       // Sal 19: 400/sa
            entry(at(7, 21), at(7, 21, 20), total: 500),   // Car 21: 20 dk -> esik alti
        ]
        let top = analytics.topSlots(entries, limit: 3, minimumMinutes: 60)
        XCTAssertEqual(top.map { $0.slot }, [HourSlot(weekday: 2, hour: 19), HourSlot(weekday: 1, hour: 12)])
    }

    func testPlatformStats() {
        let stats = analytics.platformStats([
            entry(at(5, 10), at(5, 12), total: 500, km: 25, code: "getir", packages: 10),
            entry(at(5, 13), at(5, 14), total: 200, km: 0, code: "trendyol_go", packages: nil),
        ])
        XCTAssertEqual(stats.map(\.platformCode), ["getir", "trendyol_go"]) // toplama gore azalan
        let getir = stats[0]
        XCTAssertEqual(getir.hours, 2, accuracy: 0.001)
        XCTAssertEqual(getir.netPerHour!, 225, accuracy: 0.001)   // (500 - 50) / 2
        XCTAssertEqual(getir.netPerPackage!, 45, accuracy: 0.001)
        XCTAssertEqual(getir.netPerKm!, 18, accuracy: 0.001)
        XCTAssertNil(stats[1].netPerPackage)
        XCTAssertNil(stats[1].netPerKm)
    }

    func testPercentChange() {
        XCTAssertEqual(EarningsAnalytics.percentChange(current: 1200, previous: 1000)!, 20, accuracy: 0.001)
        XCTAssertEqual(EarningsAnalytics.percentChange(current: 500, previous: 1000)!, -50, accuracy: 0.001)
        XCTAssertNil(EarningsAnalytics.percentChange(current: 500, previous: 0))
    }
}
```

- [ ] **Step 3: Başarısız olduğunu gör**

Run: `swift test --filter EarningsAnalyticsTests`
Expected: derleme hatası — `cannot find 'EarningsAnalytics' in scope`.

- [ ] **Step 4: `EarningsAnalytics.swift` yaz**

```swift
import Foundation

/// Haftanin gunu (1 = Pazartesi ... 7 = Pazar) ve saat (0-23).
struct HourSlot: Hashable, Comparable {
    var weekday: Int
    var hour: Int

    static func < (lhs: HourSlot, rhs: HourSlot) -> Bool {
        (lhs.weekday, lhs.hour) < (rhs.weekday, rhs.hour)
    }
}

struct SlotStat: Equatable {
    var minutes: Double
    /// Kayit toplami - km x km basi maliyet, dilimdeki sureye orantili pay.
    var estimatedNet: Double

    var netPerHour: Double? {
        minutes > 0 ? estimatedNet / (minutes / 60) : nil
    }
}

/// Siralanmis dilim (en iyi saatler).
struct RankedSlot: Equatable {
    var slot: HourSlot
    var stat: SlotStat
}

struct PlatformStat: Equatable, Identifiable {
    var platformCode: String
    var total: Double
    var hours: Double
    var packages: Int
    var distanceKm: Double
    var estimatedNet: Double

    var id: String { platformCode }
    var netPerHour: Double? { hours > 0 ? estimatedNet / hours : nil }
    var netPerPackage: Double? { packages > 0 ? estimatedNet / Double(packages) : nil }
    var netPerKm: Double? { distanceKm > 0 ? estimatedNet / distanceKm : nil }
}

/// Kisisel analizler. Manuel giderler kayda baglanamadigindan dilimlere dagitilmaz; sonuclar "tahmini net"tir.
struct EarningsAnalytics {
    var calendar: Calendar
    var costPerKm: Double

    private func estimatedNet(_ entry: EarningEntry) -> Double {
        entry.gross + entry.bonus - max(0, entry.distanceKm) * max(0, costPerKm)
    }

    /// Pazartesi = 1 ... Pazar = 7 (takvimin firstWeekday ayarindan bagimsiz).
    private func weekday(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    func heatmap(_ entries: [EarningEntry]) -> [HourSlot: SlotStat] {
        var result: [HourSlot: SlotStat] = [:]
        for entry in entries where entry.end > entry.start {
            let totalMinutes = entry.end.timeIntervalSince(entry.start) / 60
            let net = estimatedNet(entry)
            var cursor = entry.start
            while cursor < entry.end {
                let hourStart = calendar.dateInterval(of: .hour, for: cursor)?.start ?? cursor
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? entry.end
                let segmentEnd = min(hourEnd, entry.end)
                let minutes = segmentEnd.timeIntervalSince(cursor) / 60
                let slot = HourSlot(weekday: weekday(of: cursor), hour: calendar.component(.hour, from: cursor))
                var stat = result[slot] ?? SlotStat(minutes: 0, estimatedNet: 0)
                stat.minutes += minutes
                stat.estimatedNet += net * minutes / totalMinutes
                result[slot] = stat
                cursor = segmentEnd
            }
        }
        return result
    }

    func topSlots(_ entries: [EarningEntry], limit: Int = 3, minimumMinutes: Double = 60) -> [RankedSlot] {
        Array(
            heatmap(entries)
                .filter { $0.value.minutes >= minimumMinutes }
                .map { RankedSlot(slot: $0.key, stat: $0.value) }
                .sorted { ($0.stat.netPerHour ?? 0) > ($1.stat.netPerHour ?? 0) }
                .prefix(limit)
        )
    }

    func platformStats(_ entries: [EarningEntry]) -> [PlatformStat] {
        Dictionary(grouping: entries) { $0.platformCode ?? "other" }
            .map { code, items in
                PlatformStat(
                    platformCode: code,
                    total: items.reduce(0) { $0 + $1.gross + $1.bonus },
                    hours: EarningsCalculator.mergedDuration(of: items.map { (start: $0.start, end: $0.end) }) / 3600,
                    packages: items.reduce(0) { $0 + ($1.packageCount ?? 0) },
                    distanceKm: items.reduce(0) { $0 + max(0, $1.distanceKm) },
                    estimatedNet: items.reduce(0) { $0 + estimatedNet($1) }
                )
            }
            .sorted { $0.total > $1.total }
    }

    /// Yuzde degisim; onceki donem 0 ise nil ("—").
    static func percentChange(current: Double, previous: Double) -> Double? {
        guard previous != 0 else { return nil }
        return (current - previous) / abs(previous) * 100
    }
}
```

- [ ] **Step 5: Testleri çalıştır**

Run: `swift test`
Expected: tüm testler PASS.

- [ ] **Step 6: Commit**

```bash
git add KuryeKazanc/Core KuryeKazanc/Models/ModelEntries.swift KuryeKazancTests/Core/EarningsAnalyticsTests.swift
git commit -m "feat(core): isi haritasi, en iyi dilimler, platform karsilastirmasi"
```

---

### Task 4: Hedef ilerlemesi

**Files:**
- Create: `KuryeKazanc/Core/Goals.swift`
- Modify: `KuryeKazanc/Services/AppPreferences.swift`
- Test: `KuryeKazancTests/Core/GoalsTests.swift`

**Interfaces:**
- Produces: `struct GoalProgress: Equatable { var target: Double; var achieved: Double; var fraction: Double; var remaining: Double; var isReached: Bool; var isSet: Bool }`; `AppPreferences.weeklyGoalKey = "weeklyNetGoal"`, `AppPreferences.dailyGoalKey = "dailyNetGoal"`.

- [ ] **Step 1: Başarısız test**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class GoalsTests: XCTestCase {
    func testProgress() {
        let half = GoalProgress(target: 10_000, achieved: 5_000)
        XCTAssertEqual(half.fraction, 0.5)
        XCTAssertEqual(half.remaining, 5_000)
        XCTAssertFalse(half.isReached)

        let over = GoalProgress(target: 1_000, achieved: 1_500)
        XCTAssertEqual(over.fraction, 1)
        XCTAssertEqual(over.remaining, 0)
        XCTAssertTrue(over.isReached)

        let negative = GoalProgress(target: 1_000, achieved: -200)
        XCTAssertEqual(negative.fraction, 0)

        let unset = GoalProgress(target: 0, achieved: 300)
        XCTAssertFalse(unset.isSet)
        XCTAssertEqual(unset.fraction, 0)
    }
}
```

- [ ] **Step 2: Başarısız olduğunu gör** — Run: `swift test --filter GoalsTests` → `cannot find 'GoalProgress'`.

- [ ] **Step 3: Uygula** — `KuryeKazanc/Core/Goals.swift`

```swift
import Foundation

/// Net kazanc hedefi ilerlemesi (halka ve widget icin). Hedef 0 ise "ayarlanmadi".
struct GoalProgress: Equatable {
    var target: Double
    var achieved: Double

    var isSet: Bool { target > 0 }
    var fraction: Double { isSet ? min(1, max(0, achieved / target)) : 0 }
    var remaining: Double { max(0, target - achieved) }
    var isReached: Bool { isSet && achieved >= target }
}
```

`AppPreferences` içine:

```swift
    /// Haftalik / gunluk net kazanc hedefi (TL). 0 = ayarlanmadi.
    static let weeklyGoalKey = "weeklyNetGoal"
    static let dailyGoalKey = "dailyNetGoal"
```

- [ ] **Step 4: Testleri çalıştır** — Run: `swift test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/Goals.swift KuryeKazanc/Services/AppPreferences.swift KuryeKazancTests/Core/GoalsTests.swift
git commit -m "feat(core): hedef ilerlemesi"
```

---

### Task 5: SchemaV2 — doğrulama seviyesi, ekran görüntüsü kanıtı, V1 göçü

**Files:**
- Create: `KuryeKazanc/Core/OCR/RecognizedLine.swift`
- Create: `KuryeKazanc/Models/SchemaV1Snapshot.swift`
- Create: `KuryeKazanc/Models/ScreenshotEvidence.swift`
- Modify: `KuryeKazanc/Models/EarningRecord.swift`
- Modify: `KuryeKazanc/App/ModelContainerFactory.swift`
- Test: `KuryeKazancTests/MigrationTests.swift` (yeni), `KuryeKazancTests/Core/RecognizedLineTests.swift` (yeni)

**Interfaces:**
- Consumes: `VerificationLevel` (Task 2), `OCRTemplate.Period` (Task 1).
- Produces:
  - `struct RecognizedLine: Codable, Equatable { var text: String; var x, y, width, height: Double }` (+ `static func encode(_:) -> Data`, `static func decode(_:) -> [RecognizedLine]`)
  - `EarningRecord.verificationRaw: String`, `EarningRecord.verification: VerificationLevel { get set }`, `EarningRecord.evidence: ScreenshotEvidence?`
  - `@Model final class ScreenshotEvidence` — init imzası aşağıda; `var lines: [RecognizedLine]`, `var period: OCRTemplate.Period`
  - `enum SchemaV2: VersionedSchema` (modeller: Courier, Platform, EarningRecord, ExpenseRecord, ScreenshotEvidence); `ModelContainerFactory.make(inMemory:url:)`

**Neden dondurulmuş V1:** `SchemaV1.models` şu an canlı sınıfları gösteriyor. Canlı `EarningRecord`'a alan eklenince V1 ile V2 aynı sağlama toplamına sahip olur ve SwiftData açılışta "Duplicate version checksums" ile çöker. Bu yüzden V1 modelleri `SchemaV1` içine kopyalanır.

- [ ] **Step 1: `RecognizedLine` için başarısız Core testi**

```swift
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
```

Run: `swift test --filter RecognizedLineTests` → FAIL (`cannot find 'RecognizedLine'`).

- [ ] **Step 2: `RecognizedLine.swift` yaz**

```swift
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
```

Run: `swift test` → PASS. Commit:

```bash
git add KuryeKazanc/Core/OCR/RecognizedLine.swift KuryeKazancTests/Core/RecognizedLineTests.swift
git commit -m "feat(core): RecognizedLine (OCR satiri + kutu)"
```

- [ ] **Step 3: V1 modellerini dondur** — `KuryeKazanc/Models/SchemaV1Snapshot.swift`

Mevcut dört modelin **sürüm 1.0.0'daki halinin birebir kopyası** (yalnızca saklanan alanlar, ilişkiler ve init; hesaplanan özellikler gerekmez):

```swift
import Foundation
import SwiftData

/// 1.0.0 ile yayinlanan sema. DEGISTIRMEYIN: gocun kaynak surumudur.
/// Canli modeller (Courier, EarningRecord...) SchemaV2'yi temsil eder.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Courier.self, Platform.self, EarningRecord.self, ExpenseRecord.self]
    }

    @Model
    final class Courier {
        @Attribute(.unique) var id: UUID
        var name: String
        var vehicleTypeRaw: String
        var createdAt: Date
        @Relationship(deleteRule: .nullify, inverse: \Platform.couriers)
        var defaultPlatforms: [Platform] = []

        init(id: UUID = UUID(), name: String, vehicleTypeRaw: String, createdAt: Date = .now) {
            self.id = id
            self.name = name
            self.vehicleTypeRaw = vehicleTypeRaw
            self.createdAt = createdAt
        }
    }

    @Model
    final class Platform {
        @Attribute(.unique) var id: UUID
        var name: String
        @Attribute(.unique) var code: String
        var sortOrder: Int
        @Relationship(deleteRule: .nullify, inverse: \EarningRecord.platform)
        var earnings: [EarningRecord] = []
        var couriers: [Courier] = []

        init(id: UUID = UUID(), name: String, code: String, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.code = code
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class EarningRecord {
        @Attribute(.unique) var id: UUID
        var anonymousDeviceID: UUID
        var date: Date
        var startTime: Date
        var endTime: Date
        var platform: Platform?
        var province: String?
        var district: String?
        var neighborhood: String?
        var grossEarning: Double
        var bonus: Double
        var distanceKm: Double
        var packageCount: Int?
        var sourceRaw: String
        var createdAt: Date

        init(id: UUID = UUID(), anonymousDeviceID: UUID, date: Date, startTime: Date, endTime: Date,
             grossEarning: Double, bonus: Double = 0, distanceKm: Double = 0, packageCount: Int? = nil,
             sourceRaw: String, createdAt: Date = .now) {
            self.id = id
            self.anonymousDeviceID = anonymousDeviceID
            self.date = date
            self.startTime = startTime
            self.endTime = endTime
            self.grossEarning = grossEarning
            self.bonus = bonus
            self.distanceKm = distanceKm
            self.packageCount = packageCount
            self.sourceRaw = sourceRaw
            self.createdAt = createdAt
        }
    }

    @Model
    final class ExpenseRecord {
        @Attribute(.unique) var id: UUID
        var anonymousDeviceID: UUID
        var date: Date
        var typeRaw: String
        var amount: Double
        var note: String?
        var createdAt: Date

        init(id: UUID = UUID(), anonymousDeviceID: UUID, date: Date, typeRaw: String, amount: Double,
             note: String? = nil, createdAt: Date = .now) {
            self.id = id
            self.anonymousDeviceID = anonymousDeviceID
            self.date = date
            self.typeRaw = typeRaw
            self.amount = amount
            self.note = note
            self.createdAt = createdAt
        }
    }
}
```

- [ ] **Step 4: `ScreenshotEvidence` modeli** — `KuryeKazanc/Models/ScreenshotEvidence.swift`

```swift
import Foundation
import SwiftData

/// Bir kazanc kaydinin dayandigi ekran goruntusu kaniti. Gorselin kendisi SAKLANMAZ
/// (isim, kurye no, IBAN icerebilir); yalnizca OCR satirlari, kutular ve okunan degerler tutulur.
@Model
final class ScreenshotEvidence {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Ekran goruntusunun cekildigi an (PhotoKit/EXIF; bilinmiyorsa nil).
    var capturedAt: Date?
    /// PhotoKit yerel kimligi: ayni goruntu ikinci kez onerilmesin diye.
    var assetIdentifier: String?
    var platformCode: String?
    var templateID: String?
    var templateVersion: Int?
    var periodRaw: String
    var isGenuineScreenshot: Bool
    var linesData: Data
    var parsedTotal: Double
    var parsedBonus: Double
    var parsedPackages: Int
    var parsedDate: Date

    @Relationship(deleteRule: .nullify, inverse: \EarningRecord.evidence)
    var records: [EarningRecord] = []

    var lines: [RecognizedLine] { RecognizedLine.decode(linesData) }
    var period: OCRTemplate.Period { OCRTemplate.Period(rawValue: periodRaw) ?? .unknown }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        capturedAt: Date?,
        assetIdentifier: String?,
        parsed: ParsedEarning,
        lines: [RecognizedLine],
        isGenuineScreenshot: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.capturedAt = capturedAt
        self.assetIdentifier = assetIdentifier
        self.platformCode = parsed.platformCode
        self.templateID = parsed.templateID
        self.templateVersion = parsed.templateVersion
        self.periodRaw = parsed.period.rawValue
        self.isGenuineScreenshot = isGenuineScreenshot
        self.linesData = RecognizedLine.encode(lines)
        self.parsedTotal = parsed.totalEarning
        self.parsedBonus = parsed.bonus
        self.parsedPackages = parsed.packageCount
        self.parsedDate = parsed.date
    }
}
```

- [ ] **Step 5: `EarningRecord`'a alanlar** — `KuryeKazanc/Models/EarningRecord.swift`

`createdAt` satırından sonra:

```swift
    /// Dogrulama seviyesi (bkz. VerificationLevel). V1'den gelen kayitlar gocte ayarlanir.
    var verificationRaw: String = VerificationLevel.manual.rawValue
    /// Kaydin dayandigi ekran goruntusu kaniti (elle girilende nil).
    var evidence: ScreenshotEvidence?

    var verification: VerificationLevel {
        get { VerificationLevel(rawValue: verificationRaw) ?? .manual }
        set { verificationRaw = newValue.rawValue }
    }
```

Init'e parametre ekle (son parametreden önce): `verification: VerificationLevel = .manual,` ve gövdede `self.verificationRaw = verification.rawValue`.

- [ ] **Step 6: SchemaV2 ve göç planı** — `KuryeKazanc/App/ModelContainerFactory.swift` dosyasının tamamı:

```swift
import Foundation
import SwiftData

/// 1.1.0 semasi: dogrulama seviyesi + ekran goruntusu kaniti.
/// Yeni model degisikliginde SchemaV3 eklenir, SchemaV2 modelleri SchemaV1 gibi dondurulur.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Courier.self, Platform.self, EarningRecord.self, ExpenseRecord.self, ScreenshotEvidence.self]
    }
}

enum KuryeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [v1ToV2] }

    /// Yeni alanlar varsayilanli (hafif goc); ardindan OCR kaynakli eski kayitlar `ocrUnverified` yapilir
    /// (kanitlari olmadigi icin `verified` olamazlar).
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let ocr = EarningSource.ocr.rawValue
            let records = try context.fetch(FetchDescriptor<EarningRecord>(
                predicate: #Predicate { $0.sourceRaw == ocr }
            ))
            for record in records {
                record.verification = .ocrUnverified
            }
            try context.save()
        }
    )
}

enum ModelContainerFactory {
    static let schema = Schema(versionedSchema: SchemaV2.self)

    /// - Parameters:
    ///   - inMemory: UI testleri ve SwiftUI onizlemeleri icin diske yazmayan depo.
    ///   - url: Goc testleri icin ozel dosya konumu.
    static func make(inMemory: Bool = false, url: URL? = nil) -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: KuryeMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }
}
```

- [ ] **Step 7: Disk üstü göç testi** — `KuryeKazancTests/MigrationTests.swift`

```swift
import XCTest
import SwiftData
@testable import KuryeKazanc

@MainActor
final class MigrationTests: XCTestCase {
    func testV1StoreMigratesToV2_keepingRecordsAndMarkingOCR() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // 1) 1.0.0 deposu olustur
        do {
            let v1Schema = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(for: v1Schema, configurations: [ModelConfiguration(schema: v1Schema, url: url)])
            let day = Calendar.current.startOfDay(for: .now)
            v1.mainContext.insert(SchemaV1.EarningRecord(
                anonymousDeviceID: UUID(), date: day, startTime: day, endTime: day.addingTimeInterval(3600),
                grossEarning: 500, sourceRaw: "ocr"))
            v1.mainContext.insert(SchemaV1.EarningRecord(
                anonymousDeviceID: UUID(), date: day, startTime: day, endTime: day.addingTimeInterval(3600),
                grossEarning: 300, sourceRaw: "manual"))
            try v1.mainContext.save()
        }

        // 2) 1.1.0 ile ac
        let v2 = ModelContainerFactory.make(url: url)
        let records = try v2.mainContext.fetch(FetchDescriptor<EarningRecord>(sortBy: [SortDescriptor(\.grossEarning)]))
        XCTAssertEqual(records.map(\.grossEarning), [300, 500])
        XCTAssertEqual(records.map(\.verification), [.manual, .ocrUnverified])
        XCTAssertTrue(records.allSatisfy { $0.evidence == nil })
    }

    func testEvidenceLinksToRecord() throws {
        let container = ModelContainerFactory.make(inMemory: true)
        let parsed = ParsedEarning(platformCode: "getir", date: .now, packageCount: 3, totalEarning: 300,
                                   bonus: 0, totalIncludesBonus: true, fieldsToReview: [])
        let evidence = ScreenshotEvidence(capturedAt: nil, assetIdentifier: "A1", parsed: parsed,
                                          lines: [RecognizedLine(text: "Getir", x: 0, y: 0, width: 1, height: 0.1)],
                                          isGenuineScreenshot: true)
        let record = EarningRecord(startTime: .now, endTime: .now, grossEarning: 300, source: .ocr, verification: .ocrUnverified)
        record.evidence = evidence
        container.mainContext.insert(record)
        try container.mainContext.save()

        XCTAssertEqual(evidence.records.count, 1)
        XCTAssertEqual(record.evidence?.lines.first?.text, "Getir")
    }
}
```

- [ ] **Step 8: CI'da doğrula**

```bash
git add KuryeKazanc/Models KuryeKazanc/App/ModelContainerFactory.swift KuryeKazancTests/MigrationTests.swift
git commit -m "feat(model): SchemaV2 - dogrulama seviyesi ve ekran goruntusu kaniti; V1 gocu"
git push origin develop
```

Expected: Codemagic `ios-ci` yeşil; `MigrationTests` 2/2 ve mevcut `ModelTests`, `FormViewModelTests` geçer.

---

### Task 6: OCR servisi kutularla + ekran görüntüsü içe aktarıcı

**Files:**
- Modify: `KuryeKazanc/Services/OCR/TextRecognitionService.swift`
- Create: `KuryeKazanc/Services/Screenshots/ScreenshotImporter.swift`
- Modify: `KuryeKazancTests/FormViewModelTests.swift` (sahte tanıyıcı yeni imzaya)
- Test: `KuryeKazancTests/ScreenshotImporterTests.swift`

**Interfaces:**
- Consumes: `RecognizedLine`, `EarningsScreenshotParser`, `ScreenshotVerifier`, `ScreenshotAuthenticity`, `BundledTemplates`.
- Produces:
  - `protocol TextRecognizing { func recognize(in image: UIImage) async throws -> [RecognizedLine] }`
  - `struct ImportedScreenshot { var lines: [RecognizedLine]; var parsed: ParsedEarning; var assessment: ScreenshotAssessment; var capturedAt: Date?; var assetIdentifier: String?; var isGenuine: Bool }`
  - `struct ScreenshotImporter { init(recognizer: TextRecognizing = VisionTextRecognitionService(), parser: EarningsScreenshotParser = .init(), verifier: ScreenshotVerifier = .init(calendar: .current)); func importImage(data: Data, assetIdentifier: String?, referenceDate: Date = .now) async throws -> ImportedScreenshot }`

- [ ] **Step 1: Tanıyıcıyı kutularla döndür** — `TextRecognitionService.swift`

Protokolü ve `VisionTextRecognitionService`'i şöyle değiştir (hata türü ve `CGImagePropertyOrientation` uzantısı aynı kalır):

```swift
/// Goruntudeki metni satir satir dondurur (yukaridan asagi), normalize sinir kutulariyla.
protocol TextRecognizing {
    func recognize(in image: UIImage) async throws -> [RecognizedLine]
}

/// Apple Vision - VNRecognizeTextRequest ile cihaz uzerinde OCR (internet gerekmez, veri cihazdan cikmaz).
struct VisionTextRecognitionService: TextRecognizing {
    func recognize(in image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { throw TextRecognitionError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        let lines: [RecognizedLine] = try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Sayilar ve marka isimleri dil duzeltmesiyle bozulabiliyor
            request.usesLanguageCorrection = false
            let preferred = ["tr-TR", "en-US"]
            if let supported = try? request.supportedRecognitionLanguages() {
                let languages = preferred.filter(supported.contains)
                if !languages.isEmpty { request.recognitionLanguages = languages }
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            return Self.orderedLines(from: request.results ?? [])
        }.value

        guard !lines.isEmpty else { throw TextRecognitionError.noTextFound }
        return lines
    }

    /// Gozlemleri okuma sirasina dizer: yukaridan asagi, ayni satirdakiler soldan saga birlestirilir;
    /// satirin kutusu parcalarin birlesimidir. (Vision koordinatlari: orijin sol alt, y yukari dogru artar.)
    static func orderedLines(from observations: [VNRecognizedTextObservation]) -> [RecognizedLine] {
        let items = observations.compactMap { obs -> (text: String, box: CGRect)? in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return (text, obs.boundingBox)
        }
        .sorted { $0.box.midY > $1.box.midY }

        var rows: [[(text: String, box: CGRect)]] = []
        for item in items {
            if var last = rows.last, let ref = last.first,
               abs(ref.box.midY - item.box.midY) < min(ref.box.height, item.box.height) * 0.5 {
                last.append(item)
                rows[rows.count - 1] = last
            } else {
                rows.append([item])
            }
        }
        return rows.map { row in
            let sorted = row.sorted { $0.box.minX < $1.box.minX }
            let box = sorted.dropFirst().reduce(sorted[0].box) { $0.union($1.box) }
            return RecognizedLine(
                text: sorted.map(\.text).joined(separator: " "),
                x: box.minX, y: box.minY, width: box.width, height: box.height
            )
        }
    }
}
```

- [ ] **Step 2: İçe aktarıcı** — `KuryeKazanc/Services/Screenshots/ScreenshotImporter.swift`

```swift
import Foundation
import ImageIO
import Photos
import UIKit

/// Ekran goruntusu -> OCR -> ayristirma -> dogrulama degerlendirmesi. Form, paylas eklentisi gelen kutusu
/// ve otomatik tarama ayni yolu kullanir.
struct ImportedScreenshot {
    var lines: [RecognizedLine]
    var parsed: ParsedEarning
    var assessment: ScreenshotAssessment
    var capturedAt: Date?
    var assetIdentifier: String?
    var isGenuine: Bool
}

struct ScreenshotImporter {
    var recognizer: TextRecognizing = VisionTextRecognitionService()
    var parser = EarningsScreenshotParser()
    var verifier = ScreenshotVerifier(calendar: .current)
    /// Test icin: PhotoKit sorgusu yerine sabit deger.
    var assetIsScreenshot: (String) -> Bool? = ScreenshotImporter.photoKitIsScreenshot

    func importImage(data: Data, assetIdentifier: String?, referenceDate: Date = .now) async throws -> ImportedScreenshot {
        guard let image = UIImage(data: data) else { throw TextRecognitionError.invalidImage }
        let lines = try await recognizer.recognize(in: image)
        let parsed = parser.parse(lines: lines.map(\.text), referenceDate: referenceDate)

        let metadata = Self.metadata(of: data)
        let isGenuine = ScreenshotAuthenticity.isGenuine(
            assetIsScreenshot: assetIdentifier.flatMap(assetIsScreenshot),
            pixelWidth: metadata.pixelWidth, pixelHeight: metadata.pixelHeight,
            hasCameraMetadata: metadata.hasCameraMetadata
        )
        let template = parsed.templateID.flatMap { id in parser.templates.first { $0.id == id } }
        let assessment = verifier.assess(parsed, template: template, isGenuine: isGenuine, referenceDate: referenceDate)

        return ImportedScreenshot(
            lines: lines, parsed: parsed, assessment: assessment,
            capturedAt: metadata.capturedAt, assetIdentifier: assetIdentifier, isGenuine: isGenuine
        )
    }

    struct ImageMetadata {
        var pixelWidth: Int
        var pixelHeight: Int
        var hasCameraMetadata: Bool
        var capturedAt: Date?
    }

    /// Piksel boyutu, kamera EXIF'i (Make/LensMake) ve cekim tarihi.
    static func metadata(of data: Data) -> ImageMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return ImageMetadata(pixelWidth: 0, pixelHeight: 0, hasCameraMetadata: false, capturedAt: nil)
        }
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let hasCamera = tiff?[kCGImagePropertyTIFFMake] != nil || exif?[kCGImagePropertyExifLensMake] != nil
        var captured: Date?
        if let text = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            captured = formatter.date(from: text)
        }
        return ImageMetadata(
            pixelWidth: props[kCGImagePropertyPixelWidth] as? Int ?? 0,
            pixelHeight: props[kCGImagePropertyPixelHeight] as? Int ?? 0,
            hasCameraMetadata: hasCamera,
            capturedAt: captured
        )
    }

    /// Fotograf erisimi yoksa nil (boyut/EXIF kontrolune duser).
    static func photoKitIsScreenshot(_ identifier: String) -> Bool? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return nil }
        return asset.mediaSubtypes.contains(.photoScreenshot)
    }
}
```

- [ ] **Step 3: Test** — `KuryeKazancTests/ScreenshotImporterTests.swift`

```swift
import XCTest
import UIKit
@testable import KuryeKazanc

final class ScreenshotImporterTests: XCTestCase {
    struct FakeRecognizer: TextRecognizing {
        var lines: [String]
        func recognize(in image: UIImage) async throws -> [RecognizedLine] {
            lines.enumerated().map { RecognizedLine(text: $1, x: 0, y: 1 - Double($0) * 0.05, width: 0.5, height: 0.04) }
        }
    }

    /// Bilinen iPhone ekran boyutunda (1179x2556) EXIF'siz PNG.
    private func screenshotPNG() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1179, height: 2556), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1179, height: 2556))
        }
        return image.pngData()!
    }

    func testImportParsesAndAssesses() async throws {
        let importer = ScreenshotImporter(
            recognizer: FakeRecognizer(lines: ["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"]),
            assetIsScreenshot: { _ in nil }
        )
        let result = try await importer.importImage(data: screenshotPNG(), assetIdentifier: nil)
        XCTAssertEqual(result.parsed.platformCode, "getir")
        XCTAssertEqual(result.parsed.totalEarning, 980, accuracy: 0.001)
        XCTAssertTrue(result.isGenuine)
        // Sablon kalibrasyonda -> dogrulanmamis
        XCTAssertEqual(result.assessment.candidate, .ocrUnverified)
        XCTAssertEqual(result.lines.count, 7)
    }

    func testPhotoKitSaysNotScreenshot() async throws {
        let importer = ScreenshotImporter(
            recognizer: FakeRecognizer(lines: ["Getir", "Toplam Kazanç", "₺500"]),
            assetIsScreenshot: { _ in false }
        )
        let result = try await importer.importImage(data: screenshotPNG(), assetIdentifier: "X")
        XCTAssertFalse(result.isGenuine)
    }
}
```

- [ ] **Step 4: Form testindeki sahte tanıyıcıyı güncelle** — `FormViewModelTests.swift` içinde `FakeRecognizer`:

```swift
        struct FakeRecognizer: TextRecognizing {
            func recognize(in image: UIImage) async throws -> [RecognizedLine] {
                // mevcut testteki satir dizisi aynen kalir; her satir RecognizedLine'a sarilir
                ["Getir", "Toplam Kazanç", "₺850,00", "Sipariş Sayısı", "12"]
                    .map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.05) }
            }
        }
```

(Mevcut testteki satırlar farklıysa o satırlar aynen korunur; yalnızca dönüş tipi değişir.) `EarningFormViewModel.importScreenshot` Task 7'de içe aktarıcıya geçer; bu adımda derlenmesi için geçici olarak `let lines = try await recognizer.recognize(in: image).map(\.text)` yazılır.

- [ ] **Step 5: Commit + CI**

```bash
git add KuryeKazanc/Services KuryeKazanc/ViewModels/EarningFormViewModel.swift KuryeKazancTests
git commit -m "feat(ocr): kutulu OCR satirlari ve ekran goruntusu ice aktarici"
git push origin develop
```

Expected: `ios-ci` yeşil, `ScreenshotImporterTests` 2/2.

---

### Task 7: Kazanç formu — kanıt kaydı, doğrulama seviyesi, haftalık ekran uyarısı

**Files:**
- Modify: `KuryeKazanc/ViewModels/EarningFormViewModel.swift`
- Modify: `KuryeKazanc/Views/Earnings/EarningFormView.swift`
- Test: `KuryeKazancTests/FormViewModelTests.swift`

**Interfaces:**
- Consumes: `ScreenshotImporter`, `ImportedScreenshot` (Task 6), `ScreenshotEvidence`, `EarningRecord.verification` (Task 5), `VerificationLevel.resolve` (Task 2).
- Produces:
  - `EarningFormViewModel.init(record:session:defaultPlatform:imported:now:calendar:)` — `imported: ImportedScreenshot? = nil` verilirse form doğrudan o sonuçla doldurulur (gelen kutusu ve tarama için).
  - `func importScreenshot(data: Data, assetIdentifier: String?, importer: ScreenshotImporter, platforms: [Platform], referenceDate: Date = .now) async`
  - `func apply(_ imported: ImportedScreenshot, platforms: [Platform])`
  - `var assessmentIssues: [String]` (formda gösterilir), `var pendingVerification: VerificationLevel` (kaydedilince alınacak seviye)
  - `EarningFormView.init(record:session:defaultPlatform:imported:opensPhotoPicker:)`

- [ ] **Step 1: Başarısız testler** — `FormViewModelTests.swift` sonuna:

```swift
    // MARK: - Dogrulama seviyesi

    private func imported(total: Double = 1000, bonus: Double = 100, candidate: VerificationLevel = .ocrUnverified,
                          period: OCRTemplate.Period = .day) -> ImportedScreenshot {
        let parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(5, 0)), packageCount: 12,
            totalEarning: total, bonus: bonus, totalIncludesBonus: true, fieldsToReview: [],
            templateID: "getir.earnings", templateVersion: 1, templateStatus: .calibrating,
            fingerprintMatches: 3, period: period
        )
        let assessment = ScreenshotAssessment(
            isGenuine: true, templateActive: candidate == .verified, fingerprintOK: true, dateRecent: true,
            isDailyScreen: period != .week, internallyConsistent: true, candidate: candidate,
            issues: period == .week ? ["Haftalık ekran: vardiya için günlük kazanç ekranını kullan."] : []
        )
        return ImportedScreenshot(lines: [RecognizedLine(text: "Getir", x: 0, y: 0, width: 1, height: 0.1)],
                                  parsed: parsed, assessment: assessment, capturedAt: nil,
                                  assetIdentifier: "asset-1", isGenuine: true)
    }

    func testScreenshotSave_storesEvidenceAndCandidateLevel() throws {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(candidate: .verified), now: at(6, 18), calendar: calendar)
        vm.startTime = at(5, 10); vm.endTime = at(5, 16) // saat degisikligi seviyeyi dusurmez
        let record = try vm.save(in: context)
        XCTAssertEqual(record.verification, .verified)
        XCTAssertEqual(record.source, .ocr)
        XCTAssertEqual(record.evidence?.assetIdentifier, "asset-1")
        XCTAssertEqual(record.evidence?.parsedTotal, 1000)
    }

    func testScreenshotSave_editedAmountBecomesOcrEdited() throws {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(candidate: .verified), now: at(6, 18), calendar: calendar)
        vm.grossText = "950"
        let record = try vm.save(in: context)
        XCTAssertEqual(record.verification, .ocrEdited)
        XCTAssertNotNil(record.evidence, "Kanit duzenlemede de saklanir")
    }

    func testScreenshotSave_reformattedSameValueIsNotAnEdit() throws {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(), now: at(6, 18), calendar: calendar)
        vm.grossText = "900,00" // ayni deger, farkli yazim
        XCTAssertEqual(try vm.save(in: context).verification, .ocrUnverified)
    }

    func testWeeklyScreenShowsIssue() {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(period: .week), now: at(6, 18), calendar: calendar)
        XCTAssertTrue(vm.assessmentIssues.contains { $0.contains("Haftalık") })
        XCTAssertEqual(vm.pendingVerification, .ocrUnverified)
    }

    func testManualSave_isManualWithoutEvidence() throws {
        let vm = EarningFormViewModel(defaultPlatform: platforms.first, now: at(6, 18), calendar: calendar)
        vm.grossText = "500"
        let record = try vm.save(in: context)
        XCTAssertEqual(record.verification, .manual)
        XCTAssertNil(record.evidence)
    }

    func testEditingOcrRecordKeepsLevelUnlessValuesChange() throws {
        let first = EarningFormViewModel(defaultPlatform: nil, imported: imported(), now: at(6, 18), calendar: calendar)
        let record = try first.save(in: context)

        let edit = EarningFormViewModel(record: record, now: at(6, 19), calendar: calendar)
        edit.district = "Kadıköy"
        XCTAssertEqual(try edit.save(in: context).verification, .ocrUnverified)

        let edit2 = EarningFormViewModel(record: record, now: at(6, 19), calendar: calendar)
        edit2.bonusText = "150"
        XCTAssertEqual(try edit2.save(in: context).verification, .ocrEdited)
    }
```

- [ ] **Step 2: ViewModel değişiklikleri** — `EarningFormViewModel.swift`

Yeni durum alanları (`recognizedLines` yerine):

```swift
    /// Son ekran goruntusu ice aktarimi (kanit + degerlendirme).
    private(set) var imported: ImportedScreenshot?
    /// Ekrandan okunan degerlerin karsilastirma tabani (kullanici degistirdi mi?).
    @ObservationIgnored private var readBaseline: ReadValues?

    /// Ekrandan okunan (saatler haric) degerler.
    struct ReadValues: Equatable {
        var platformCode: String?
        var day: Date
        var gross: Double
        var bonus: Double
        var packages: Int?
    }

    var assessmentIssues: [String] { imported?.assessment.issues ?? [] }

    /// Kaydedilince alinacak seviye.
    var pendingVerification: VerificationLevel {
        if let editingRecord, imported == nil {
            // Duzenleme: okunan degerler degistiyse ocrEdited, yoksa mevcut seviye
            guard editingRecord.source == .ocr else { return .manual }
            return userEditedReadValues ? .ocrEdited : editingRecord.verification
        }
        return VerificationLevel.resolve(
            isFromScreenshot: imported != nil,
            userEditedReadValues: userEditedReadValues,
            candidate: imported?.assessment.candidate ?? .manual
        )
    }

    private var currentReadValues: ReadValues {
        ReadValues(
            platformCode: platform?.code,
            day: calendar.startOfDay(for: date),
            gross: TurkishNumberParser.parseDecimal(grossText) ?? -1,
            bonus: TurkishNumberParser.parseDecimal(bonusText) ?? 0,
            packages: TurkishNumberParser.parseInt(packageText)
        )
    }

    private var userEditedReadValues: Bool {
        guard let readBaseline else { return false }
        let current = currentReadValues
        return current.platformCode != readBaseline.platformCode
            || current.day != readBaseline.day
            || abs(current.gross - readBaseline.gross) > 0.005
            || abs(current.bonus - readBaseline.bonus) > 0.005
            || (current.packages ?? 0) != (readBaseline.packages ?? 0)
    }
```

`init` imzasına `imported: ImportedScreenshot? = nil,` (`defaultPlatform`'dan sonra) eklenir. `if let record { ... }` dalının sonuna, OCR kaynaklı kayıt düzenlenirken taban alınır:

```swift
            if record.source == .ocr {
                readBaseline = currentReadValues
            }
```

`init` gövdesinin en sonuna:

```swift
        if let imported {
            apply(imported, platforms: defaultPlatform.map { [$0] } ?? [])
        }
```

Not: `apply` platformu `platforms` listesinden eşleştirir; init'te tam liste yoktur. Bu yüzden View, `imported` ile açılan formda `.task` içinde `viewModel.apply(imported, platforms: platforms)` ile yeniden uygular (Step 3). Init'teki çağrı alanları hemen doldurur, platformu View tamamlar.

Mevcut `importScreenshot(_:recognizer:parser:platforms:referenceDate:)` şununla değiştirilir:

```swift
    func importScreenshot(
        data: Data,
        assetIdentifier: String?,
        importer: ScreenshotImporter = ScreenshotImporter(),
        platforms: [Platform],
        referenceDate: Date = .now
    ) async {
        ocrState = .processing
        do {
            let result = try await importer.importImage(data: data, assetIdentifier: assetIdentifier, referenceDate: referenceDate)
            apply(result, platforms: platforms)
            ocrState = .finished
        } catch {
            ocrState = .failed(error.localizedDescription)
        }
    }

    func apply(_ imported: ImportedScreenshot, platforms: [Platform]) {
        self.imported = imported
        apply(imported.parsed, platforms: platforms)
        readBaseline = currentReadValues
    }
```

`ocrDiagnosticReport` içinde `recognizedLines` → `imported?.lines.map(\.text) ?? []` (yerel `let recognizedLines = ...` ile).

`save(in:)` içinde, `record.province = ...` satırından önce:

```swift
        record.verification = pendingVerification
        if let imported, record.evidence == nil {
            record.evidence = ScreenshotEvidence(
                capturedAt: imported.capturedAt,
                assetIdentifier: imported.assetIdentifier,
                parsed: imported.parsed,
                lines: imported.lines,
                isGenuineScreenshot: imported.isGenuine
            )
        }
```

(`pendingVerification` kayıttan **önce** hesaplanır; yeni kayıtta `editingRecord` nil olduğundan ilk dal çalışmaz.)

- [ ] **Step 3: Form görünümü** — `EarningFormView.swift`

- `init`'e `imported: ImportedScreenshot? = nil, opensPhotoPicker: Bool = false` eklenir; `recognizer` parametresi kaldırılır, yerine `importer: ScreenshotImporter = ScreenshotImporter()` saklanır. `@State private var showPhotoPicker: Bool` `opensPhotoPicker` ile başlar.
- `PhotosPicker` çağrısı `PhotosPicker(selection: $photoItem, matching: .screenshots, photoLibrary: .shared())` olur (yerel kimlik için) ve `.photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .screenshots, photoLibrary: .shared())` Form'a eklenir.
- `loadScreenshot`:

```swift
    private func loadScreenshot(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.ocrState = .failed("Görsel yüklenemedi.")
            return
        }
        await viewModel.importScreenshot(data: data, assetIdentifier: item.itemIdentifier,
                                         importer: importer, platforms: platforms)
    }
```

- `.task` içine (bölge çözümlemesinden önce): `if let imported = initialImported { viewModel.apply(imported, platforms: platforms) }` (`initialImported` init'te saklanır).
- OCR bölümünde `.finished` durumunda doğrulama özeti:

```swift
            case .finished:
                VerificationBadge(level: viewModel.pendingVerification)
                ForEach(viewModel.assessmentIssues, id: \.self) { issue in
                    Label(issue, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
```

(`VerificationBadge` Task 8'de oluşturulur; Task 7 Task 8'den önce derlenecekse bu satır Task 8'in son adımında eklenir. Sıra: Task 8 → Task 7 uygulanabilir; ikisi aynı push'ta CI'a gidebilir.)

- Footer metni: `"Trendyol GO, Getir, Yemeksepeti ve Migros kazanç ekranları tanınır. Görüntü cihazında işlenir; görselin kendisi saklanmaz."`

- [ ] **Step 4: Commit + CI**

```bash
git add KuryeKazanc/ViewModels/EarningFormViewModel.swift KuryeKazanc/Views/Earnings KuryeKazancTests/FormViewModelTests.swift
git commit -m "feat(form): ekran goruntusu kaniti ve dogrulama seviyesi kaydi"
git push origin develop
```

Expected: `ios-ci` yeşil; yeni 6 test dahil `FormViewModelTests` geçer.

---

### Task 8: Tasarım sistemi

**Files:**
- Modify: `KuryeKazanc/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `KuryeKazanc/Views/Design/Theme.swift`
- Create: `KuryeKazanc/Views/Design/Components.swift`
- Create: `KuryeKazanc/Views/Design/Haptics.swift`
- Modify: `KuryeKazanc/Views/Components/ReviewHighlight.swift` → `KuryeKazanc/Views/Design/ReviewHighlight.swift` (taşınır, içerik aynı)

**Interfaces:**
- Produces: `enum Theme { static let accent: Color; static let negative: Color; static let surface: Color; static let groupedBackground: Color; static let cornerRadius: CGFloat = 12 }`; `struct HeroAmount: View { init(title: String, value: Double, identifier: String) }`; `struct MetricStrip: View { init(_ items: [MetricStrip.Item]) }` (`Item(title:value:identifier:)`); `struct VerificationBadge: View { init(level: VerificationLevel) }`; `struct GoalRing: View { init(progress: GoalProgress, lineWidth: CGFloat = 10) }`; `struct PrimaryActionButtonStyle: ButtonStyle { init(isDestructive: Bool = false) }`; `enum Haptics { static func success(); static func impact() }`.

- [ ] **Step 1: Vurgu rengi (açık/koyu)** — `AccentColor.colorset/Contents.json`

```json
{
  "colors": [
    {
      "color": { "color-space": "srgb", "components": { "red": "0.141", "green": "0.541", "blue": "0.239", "alpha": "1.000" } },
      "idiom": "universal"
    },
    {
      "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
      "color": { "color-space": "srgb", "components": { "red": "0.188", "green": "0.820", "blue": "0.345", "alpha": "1.000" } },
      "idiom": "universal"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

- [ ] **Step 2: `Theme.swift`**

```swift
import SwiftUI

/// Tek tasarim kaynagi. Kural: sistem renkleri + tek vurgu (yesil). Kirmizi yalnizca gider ve "bitir".
enum Theme {
    static let accent = Color.accentColor
    static let negative = Color.red
    static let surface = Color(.secondarySystemGroupedBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let cornerRadius: CGFloat = 12
}
```

- [ ] **Step 3: `Components.swift`**

```swift
import SwiftUI

/// Buyuk ana rakam (Bugun'un net kazanci, Analiz'in donem neti).
struct HeroAmount: View {
    let title: String
    let value: Double
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Formatters.currency(value))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(value < 0 ? Theme.negative : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// Yan yana kucuk metrikler: deger ustte, baslik altta. Kart degil; ayraclarla bolunmus tek satir.
struct MetricStrip: View {
    struct Item: Identifiable {
        var title: String
        var value: String
        var identifier: String
        var id: String { identifier }
    }

    let items: [Item]

    init(_ items: [Item]) { self.items = items }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().frame(height: 28).padding(.horizontal, 12)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value)
                        .font(.headline)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityIdentifier(item.identifier)
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Kayit satirindaki dogrulama rozeti: yalnizca simge + kisa metin, renkli dolgu yok.
struct VerificationBadge: View {
    let level: VerificationLevel

    var body: some View {
        Label(level.displayName, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(level == .verified ? Theme.accent : .secondary)
            .labelStyle(.titleAndIcon)
            .accessibilityIdentifier("verification.\(level.rawValue)")
    }

    private var symbol: String {
        switch level {
        case .manual: "pencil"
        case .ocrEdited: "text.viewfinder"
        case .ocrUnverified: "text.viewfinder"
        case .verified: "checkmark.seal.fill"
        }
    }
}

/// Fitness tarzi hedef halkasi.
struct GoalRing: View {
    let progress: GoalProgress
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(Theme.accent.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress.fraction)
        }
        .accessibilityElement()
        .accessibilityLabel("Hedef")
        .accessibilityValue("Yüzde \(Int(progress.fraction * 100))")
    }
}

/// Tam genislikte ana eylem dugmesi (Vardiyayi baslat/bitir, onboarding Devam).
struct PrimaryActionButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(isDestructive ? Theme.negative : Theme.accent, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
```

- [ ] **Step 4: `Haptics.swift`**

```swift
import UIKit

/// Dokunsal geri bildirim: kayit, vardiya baslat/bitir.
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
```

- [ ] **Step 5: ReviewHighlight'ı taşı**

Run: `git mv KuryeKazanc/Views/Components/ReviewHighlight.swift KuryeKazanc/Views/Design/ReviewHighlight.swift`

- [ ] **Step 6: Commit** (CI, Task 7 ile birlikte push edilir)

```bash
git add KuryeKazanc/Resources KuryeKazanc/Views/Design KuryeKazanc/Views/Components
git commit -m "feat(design): tasarim sistemi - yesil vurgu, ana rakam, metrik seridi, rozet, hedef halkasi"
```

---

### Task 9: Bugün sekmesi

**Files:**
- Create: `KuryeKazanc/Views/Today/TodayView.swift`
- Create: `KuryeKazanc/Views/Shared/RecordRows.swift` (`EarningListRow`, `ExpenseListRow`, `ExpenseType.symbolName` — `HistoryView.swift`'ten taşınır, satır rozeti değişir)
- Delete: `KuryeKazanc/Views/Dashboard/DashboardView.swift`
- Rename: `KuryeKazanc/ViewModels/DashboardViewModel.swift` → `TodayViewModel.swift` (`enum TodayViewModel`, içerik aynı + `weekGoal` yardımcı)
- Modify: `KuryeKazanc/App/RootView.swift`
- Test: `KuryeKazancUITests/DashboardUITests.swift`

**Interfaces:**
- Consumes: `HeroAmount`, `MetricStrip`, `GoalRing`, `VerificationBadge`, `PrimaryActionButtonStyle`, `Haptics` (Task 8); `GoalProgress`, `AppPreferences.weeklyGoalKey` (Task 4); `PeriodRange`; `EarningFormView(record:session:defaultPlatform:imported:opensPhotoPicker:)` (Task 7); `ScreenshotSuggestion` görünümü Task 12'de eklenir.
- Produces: `struct TodayView: View { init(day: Date = .now) }`; `EarningListRow(record:showsDate:)`, `ExpenseListRow(record:showsDate:)`.

Düzen (yukarıdan aşağı, `List` + `.insetGrouped`, büyük başlık "Bugün", alt başlık olarak gün adı):
1. Bölüm (arka plansız üst bölüm): `HeroAmount("Net kazanç")`; altında `MetricStrip` [Net ₺/sa (`dashboard.netPerHour`), Çalışma (`dashboard.workDuration`), Mesafe (`dashboard.distance`)]; haftalık hedef ayarlıysa sağda 56 pt `GoalRing` ve "Haftalık hedef %X".
2. Vardiya düğmesi: `PrimaryActionButtonStyle` — "Vardiyayı başlat" / "Vardiyayı bitir" (kırmızı); vardiya sürerken altında `TimelineView` ile "1 sa 12 dk · 8,4 km". `dashboard.workToggle`. Başlat/bitir'de `Haptics.impact()`.
3. "Kazançlar" bölümü: satırlar (`dashboard.earningRow`), kaydırarak sil, dokununca düzenle. Boşsa tek satırlık açıklama: "Platformun kazanç ekranının görüntüsünü ekle — + düğmesinden."
4. "Giderler" bölümü (varsa), satırlar kırmızı tutarla.
- Toolbar: sağda `Menu` (`dashboard.addMenu`, simge `plus`): "Ekran görüntüsü" (`text.viewfinder`) → `.addEarning(opensPicker: true)`; "Elle kazanç" (`square.and.pencil`); "Gider" (`fuelpump`).
- Gradyanlı kart, `MetricTile`, `NetEarningsCard`, `WorkModeButton` kaldırılır.

- [ ] **Step 1: UI testlerini yeni düzene göre güncelle** (önce testler) — `DashboardUITests.swift`

`app.buttons["Kazanç ekle"].tap()` → `app.buttons["Elle kazanç"].tap()`; `app.buttons["Gider ekle"].tap()` → `app.buttons["Gider"].tap()`. Yeni test:

```swift
    func testAddMenuOffersScreenshotFirst() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        XCTAssertTrue(app.buttons["Ekran görüntüsü"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Elle kazanç"].exists)
        XCTAssertTrue(app.buttons["Gider"].exists)
    }

    func testSampleRecordsShowVerificationBadges() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        // Ornek veride bir elle, bir ekran goruntusu kaydi var
        XCTAssertTrue(app.descendants(matching: .any)["verification.manual"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["verification.ocrUnverified"].exists)
    }
```

`SampleData`'da Getir kaydına `verification: .ocrUnverified` eklenir.

- [ ] **Step 2: `RecordRows.swift`** — `EarningListRow` eski koddan taşınır; "OCR" kapsülü yerine alt satırda `VerificationBadge(level: record.verification)` (yalnızca `manual` değilse ya da her zaman — her zaman göster, test bunu bekler):

```swift
struct EarningListRow: View {
    let record: EarningRecord
    var showsDate = false

    private var subtitle: String {
        var parts: [String] = []
        if showsDate {
            parts.append(record.date.formatted(Date.FormatStyle().locale(Formatters.locale).day().month(.abbreviated).weekday(.abbreviated)))
        }
        parts.append("\(Formatters.time(record.startTime))–\(Formatters.time(record.endTime))")
        if let district = record.district { parts.append(district) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.platform?.name ?? "Platform yok")
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VerificationBadge(level: record.verification)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Formatters.currency(record.totalEarning))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                if let packages = record.packageCount, packages > 0 {
                    Text("\(packages) paket").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
```

`ExpenseListRow` ve `ExpenseType.symbolName` eski koddan aynen taşınır (tutar rengi `Theme.negative`).

- [ ] **Step 3: `TodayView.swift`** — Sheet enum'u eskisiyle aynı + `addEarning(session: WorkSessionSummary?, opensPicker: Bool)` ve `importedScreenshot(ImportedScreenshot)` (Task 12/13 bunu kullanır; id: `"imported-\(UUID())"` yerine `"imported"`). Haftalık hedef için ikinci sorgu:

```swift
    @Query private var weekEarnings: [EarningRecord]
    @Query private var weekExpenses: [ExpenseRecord]
    @AppStorage(AppPreferences.weeklyGoalKey) private var weeklyGoal = 0.0
```

`init(day:)` içinde `PeriodRange().interval(of: .week, containing: day)` ile `weekEarnings`/`weekExpenses` sorguları kurulur (`$0.date >= start && $0.date < end`). Hedef: `GoalProgress(target: weeklyGoal, achieved: calculator.summarizeByDay(...).values.total.netEarnings)`.

Gövde iskeleti:

```swift
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .center, spacing: 16) {
                        HeroAmount(title: "Net kazanç", value: summary.netEarnings, identifier: "dashboard.netEarnings")
                        if goal.isSet {
                            VStack(spacing: 4) {
                                GoalRing(progress: goal).frame(width: 56, height: 56)
                                Text("Hafta %\(Int(goal.fraction * 100))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    MetricStrip([
                        .init(title: "Net ₺/saat", value: Formatters.perHour(summary.netPerHour), identifier: "dashboard.netPerHour"),
                        .init(title: "Çalışma", value: Formatters.duration(summary.workDuration), identifier: "dashboard.workDuration"),
                        .init(title: "Mesafe", value: Formatters.distance(summary.distanceKm), identifier: "dashboard.distance"),
                    ])
                    if summary.usesEstimatedExpenses {
                        Text("Yakıt ve bakım km başına tahmini: \(Formatters.currency(summary.estimatedExpenses))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .listRowSeparator(.hidden)

                Section {
                    shiftButton
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                earningsSection
                if !todaysExpenses.isEmpty { expensesSection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bugün")
            .toolbar { /* ToolbarItem(.topBarLeading): Formatters.longDay(day), ToolbarItem(.topBarTrailing): addMenu */ }
            .sheet(item: $activeSheet) { /* eski switch + yeni durumlar */ }
        }
```

`shiftButton`:

```swift
    private var shiftButton: some View {
        VStack(spacing: 8) {
            Button(workSession.isWorking ? "Vardiyayı bitir" : "Vardiyayı başlat", action: toggleWork)
                .buttonStyle(PrimaryActionButtonStyle(isDestructive: workSession.isWorking))
                .accessibilityIdentifier("dashboard.workToggle")
            if workSession.isWorking, let start = workSession.sessionStart {
                TimelineView(.periodic(from: start, by: 30)) { context in
                    Text(shiftStatus(elapsed: context.date.timeIntervalSince(start)))
                        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
            } else {
                Text("Süre ve mesafe ölçülür; konum yalnızca vardiya boyunca kullanılır.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
```

`shiftStatus` eski `WorkModeButton.statusText` mantığıdır ("Süre: …" yerine "1 sa 12 dk · 8,4 km"; konum izni yoksa "· mesafe ölçülmüyor"). `toggleWork()` eskisiyle aynı + `Haptics.impact()`.

- [ ] **Step 4: `RootView` sekmeleri** — `MainTabView`:

```swift
        TabView {
            TodayView(day: today)
                .id(today)
                .tabItem { Label("Bugün", systemImage: "sun.max") }
            AnalysisView()
                .tabItem { Label("Analiz", systemImage: "chart.bar.xaxis") }
            CommunityView()
                .tabItem { Label("Topluluk", systemImage: "person.3") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
```

`AnalysisView`, `CommunityView`, `ProfileView` Task 10–11'de oluşur; bu üç görev **tek CI push'unda** birlikte doğrulanır (Task 11 sonu).

- [ ] **Step 5: Eski dosyaları sil, commit**

```bash
git rm KuryeKazanc/Views/Dashboard/DashboardView.swift
git mv KuryeKazanc/ViewModels/DashboardViewModel.swift KuryeKazanc/ViewModels/TodayViewModel.swift
git add -A KuryeKazanc KuryeKazancUITests
git commit -m "feat(ui): Bugun sekmesi - sade ana rakam, metrik seridi, hedef halkasi, vardiya dugmesi"
```

---

### Task 10: Analiz sekmesi

**Files:**
- Create: `KuryeKazanc/Views/Analysis/AnalysisView.swift` (eski `HistoryView` + `HistoryContentView` + `SummaryGrid` buraya taşınır ve sadeleşir)
- Create: `KuryeKazanc/Views/Analysis/AnalysisSections.swift`
- Delete: `KuryeKazanc/Views/History/HistoryView.swift`
- Test: `KuryeKazancUITests/DashboardUITests.swift`

**Interfaces:**
- Consumes: `EarningsAnalytics`, `HourSlot`, `PlatformStat` (Task 3); `HeroAmount`, `MetricStrip` (Task 8); `EarningListRow`, `ExpenseListRow` (Task 9).
- Produces: `struct AnalysisView: View`; `struct HeatmapSection: View { init(map: [HourSlot: SlotStat]) }`; `struct PlatformComparisonSection: View { init(stats: [PlatformStat], names: [String: String]) }`; `struct BestSlotsSection: View { init(slots: [RankedSlot]) }`.

Düzen: başlık "Analiz" (büyük); üstte `Picker` (`history.periodPicker`) + dönem gezgini (eski başlık aynen). Bölümler sırasıyla:
1. Özet: `HeroAmount("Net kazanç", identifier: "history.netEarnings")`, altında `"Önceki döneme göre +%12"` (`EarningsAnalytics.percentChange`; önceki dönem `periods.shift(anchor, kind:, by: -1)` aralığı için ek `@Query`), `MetricStrip` [Net ₺/sa, Çalışma, Mesafe], ikinci `MetricStrip` [Brüt, Gider, Tahmini gider].
2. "Günlük net" grafiği (gün dışı dönemlerde; eski Chart, renk `Theme.accent`/`Theme.negative`).
3. `BestSlotsSection` — "En kârlı saatlerin" (en fazla 3 satır: "Salı 19:00–20:00 · 400 ₺/sa"; tüm kayıtlar üzerinden değil, **son 8 hafta** üzerinden — ayrı `@Query`, `date >= now - 56 gün`).
4. `HeatmapSection` — aynı 8 haftalık veriyle; Swift Charts `RectangleMark(x: saat, y: gün)`, renk yoğunluğu `netPerHour`; dokunulan hücre için `chartOverlay` yerine basitçe en altta açıklama satırı ("Koyu = saat başı daha çok net"). Veri yoksa bölüm gizlenir.
5. `PlatformComparisonSection` — her platform için satır: ad + toplam, altında "Net ₺/sa · ₺/sipariş · ₺/km" (nil olanlar "—").
6. Kazançlar / Giderler listeleri (eski davranış: kaydırarak sil, dokunarak düzenle).
- "Tahmini net, km başı maliyet düşülerek hesaplanır." dipnotu 3–5. bölümlerin footer'ında.

- [ ] **Step 1: UI testi** — `testHistoryAndSettingsTabs` içinde sekme adı `"Geçmiş"` → `"Analiz"`, `"Ayarlar"` → `"Profil"`. Yeni:

```swift
    func testAnalysisShowsPlatformComparison() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.tabBars.buttons["Analiz"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Analiz"].tap()
        app.segmentedControls["history.periodPicker"].buttons["Gün"].tap()
        let platforms = app.staticTexts["analysis.platform.getir"]
        for _ in 0..<4 where !platforms.exists { app.swipeUp() }
        XCTAssertTrue(platforms.exists)
    }
```

- [ ] **Step 2: `AnalysisSections.swift`**

```swift
import SwiftUI
import Charts

private let weekdayNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
private let weekdayLongNames = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]

struct BestSlotsSection: View {
    let slots: [RankedSlot]

    var body: some View {
        Section {
            ForEach(slots, id: \.slot) { item in
                LabeledContent {
                    Text(Formatters.perHour(item.stat.netPerHour)).monospacedDigit()
                } label: {
                    Text("\(weekdayLongNames[item.slot.weekday - 1]) \(String(format: "%02d:00–%02d:00", item.slot.hour, (item.slot.hour + 1) % 24))")
                }
            }
        } header: {
            Text("En kârlı saatlerin")
        } footer: {
            Text("Son 8 hafta, en az 1 saat çalıştığın dilimler. Tahmini net: km başı maliyet düşülür.")
        }
    }
}

struct HeatmapSection: View {
    let map: [HourSlot: SlotStat]

    private var cells: [RankedSlot] {
        map.filter { $0.value.netPerHour != nil }.map { RankedSlot(slot: $0.key, stat: $0.value) }
    }

    var body: some View {
        Section {
            Chart(cells, id: \.slot) { cell in
                RectangleMark(
                    x: .value("Saat", cell.slot.hour),
                    y: .value("Gün", weekdayNames[cell.slot.weekday - 1]),
                    width: .ratio(0.9), height: .ratio(0.9)
                )
                .foregroundStyle(by: .value("Net ₺/sa", cell.stat.netPerHour ?? 0))
            }
            .chartForegroundStyleScale(range: Gradient(colors: [Theme.accent.opacity(0.15), Theme.accent]))
            .chartYScale(domain: weekdayNames)
            .chartXScale(domain: 0...23)
            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
            .chartLegend(.hidden)
            .frame(height: 220)
            .padding(.vertical, 8)
            .accessibilityLabel("Gün ve saate göre net kazanç ısı haritası")
        } header: {
            Text("Ne zaman çalışmalı")
        } footer: {
            Text("Koyu hücre = saat başı daha yüksek net. Son 8 hafta.")
        }
    }
}

struct PlatformComparisonSection: View {
    let stats: [PlatformStat]
    /// platformCode -> gorunen ad
    let names: [String: String]

    var body: some View {
        Section("Platform karşılaştırması") {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(names[stat.platformCode] ?? "Diğer").font(.body.weight(.semibold))
                        Spacer()
                        Text(Formatters.currency(stat.total)).monospacedDigit()
                    }
                    Text([
                        Formatters.perHour(stat.netPerHour),
                        stat.netPerPackage.map { Formatters.currency($0) + "/sipariş" } ?? "—/sipariş",
                        stat.netPerKm.map { Formatters.currency($0) + "/km" } ?? "—/km",
                    ].joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("analysis.platform.\(stat.platformCode)")
            }
        }
    }
}
```

- [ ] **Step 3: `AnalysisView.swift`** — eski `HistoryView` yapısı korunur (`AnalysisView` + iç `AnalysisContentView(interval:previous:kind:)`); `List`'in bölümleri yukarıdaki sırayla. `AnalysisContentView` ek sorgular:

```swift
    @Query private var previousEarnings: [EarningRecord]
    @Query private var previousExpenses: [ExpenseRecord]
    @Query private var recentEarnings: [EarningRecord] // son 8 hafta, isi haritasi + en iyi dilimler
```

`init(interval:previous:kind:)` içinde `let recentStart = Calendar.current.date(byAdding: .day, value: -56, to: .now)!` ile `recentEarnings` filtresi `$0.date >= recentStart`. `platformNames`: `Dictionary(uniqueKeysWithValues: platforms.map { ($0.code, $0.name) })` (`@Query(sort: \Platform.sortOrder) private var platforms`). `SummaryGrid` silinir; yerine özet bölümü (HeroAmount + değişim + iki MetricStrip).

- [ ] **Step 4: Commit** (CI Task 11 sonunda)

```bash
git rm KuryeKazanc/Views/History/HistoryView.swift
git add KuryeKazanc/Views/Analysis KuryeKazancUITests
git commit -m "feat(ui): Analiz sekmesi - isi haritasi, en karli saatler, platform karsilastirmasi"
```

---

### Task 11: Profil ve Topluluk sekmeleri, ayrı rızalar, hedefler

**Files:**
- Create: `KuryeKazanc/Views/Profile/ProfileView.swift` (eski `SettingsView` içeriği + yeni bölümler)
- Create: `KuryeKazanc/Views/Profile/ConsentViews.swift` (`DataSharingConsentView` taşınır, metni güncellenir; yeni `LocationSharingConsentView`)
- Create: `KuryeKazanc/Views/Community/CommunityView.swift`
- Delete: `KuryeKazanc/Views/Settings/SettingsView.swift`
- Modify: `KuryeKazanc/Services/AppPreferences.swift`
- Test: `KuryeKazancUITests/DashboardUITests.swift`

**Interfaces:**
- Consumes: `AppPreferences.weeklyGoalKey/dailyGoalKey` (Task 4).
- Produces: `AppPreferences.locationSharingOptInKey = "locationSharingOptIn"`, `AppPreferences.locationSharingConsentDateKey = "locationSharingConsentDate"`; `struct ProfileView: View`; `struct CommunityView: View`.

Profil bölümleri (sırasıyla, `Form`): **Profil** (ad, araç, platformlarım — eski) · **Hedefler** (Haftalık net hedef `TextField` + ₺, `profile.weeklyGoal`; Günlük net hedef `profile.dailyGoal`; footer "Bugün ekranındaki halka haftalık hedefi gösterir.") · **Gider hesaplama** (eski) · **Konum izni** (eski) · **Paylaşım** — iki ayrı `Toggle`: "Kazançlarımı anonim paylaş" (`settings.dataSharing`, eski davranış: açmak rıza ekranı ister) ve "Konum yoğunluğunu paylaş" (`profile.locationSharing`; yalnızca kazanç paylaşımı açıkken etkin; açmak `LocationSharingConsentView` ister). Footer: "Bu sürümde hiçbir veri gönderilmez; tercihlerin kaydedilir. Paylaşım, topluluk özellikleri açıldığında başlar ve yalnızca ekran görüntüsüyle doğrulanmış kazançlar kullanılır." · **Veri** (Tüm kayıtları sil — eski) · **Hakkında** (sürüm).

Kazanç paylaşımı kapatılınca konum paylaşımı da kapanır (rıza tarihleri silinir).

`DataSharingConsentView` "Paylaşılacaklar" listesi güncellenir: "Kazanç, bonus, paket sayısı (yalnızca ekran görüntüsüyle doğrulananlar)", "Çalışma süresi ve mesafe (yuvarlanmış)", "Platform, il ve ilçe", "Haftanın günü ve 15 dakikalık zaman dilimi"; "Asla": "Adın ve profil bilgilerin", "Ekran görüntülerinin kendisi", "Semt ve tam konumun", "Telefon numarası, e-posta". Alt metin: "Karşılığında bölgendeki kuryelerle karşılaştırmayı görürsün. İstediğin an kapatıp sunucudaki verilerini sildirebilirsin."

`LocationSharingConsentView`: başlık "Konum yoğunluğu"; Paylaşılacaklar: "Vardiya sırasında bulunduğun ~500 m'lik bölge hücreleri", "Tarih ve 15 dakikalık zaman dilimi", "Hücrede geçen ve durarak geçen süre"; Asla: "Ham GPS koordinatı veya güzergâh", "Vardiyanın ilk ve son 10 dakikası (evinin bulunamaması için)", "Hesabınla bağlantı (her hafta değişen takma kimlik kullanılır)". Not: "Konum verisi hesabına bağlı olmadığı için sonradan tek tek silinemez." Onay düğmesi `consent.location.accept`.

`CommunityView` (paylaşım kapalıyken ve açıkken aynı iskelet; 1.1'de veri yok):

```swift
import SwiftUI

/// 1.4'te ilce karsilastirmasi ve harita gelecek. Simdilik ne gelecegini anlatan sade ekran.
struct CommunityView: View {
    @AppStorage(AppPreferences.dataSharingOptInKey) private var sharing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.accent)
                        Text("Bölgendeki kuryelerle karşılaştır")
                            .font(.title3.weight(.semibold))
                        Text("İlçende saat başı ortalama net kazanç, en yoğun saatler ve kazanç haritası. Yalnızca ekran görüntüsüyle doğrulanmış veriler kullanılır.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                Section {
                    if sharing {
                        Label("Paylaşım açık. Topluluk özellikleri açıldığında burada görünecek.", systemImage: "checkmark.circle")
                            .foregroundStyle(Theme.accent)
                    } else {
                        Label("Görmek için Profil'den anonim paylaşımı aç.", systemImage: "person.badge.shield.checkmark")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Kimsenin kazancı tek başına görünmez: bir bölge en az 5 farklı kuryeden veri gelmeden gösterilmez.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Topluluk")
            .accessibilityIdentifier("community.root")
        }
    }
}
```

- [ ] **Step 1: UI testleri** — `testDataSharingRequiresExplicitConsent` içinde sekme `"Ayarlar"` → `"Profil"`. Yeni:

```swift
    func testLocationSharingRequiresEarningsSharingAndOwnConsent() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        let location = app.switches["profile.locationSharing"]
        for _ in 0..<5 where !location.exists { app.swipeUp() }
        XCTAssertTrue(location.exists)
        XCTAssertFalse(location.isEnabled, "Kazanc paylasimi kapaliyken konum paylasimi acilamamali")
    }

    func testCommunityTabExists() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Topluluk"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Topluluk"].tap()
        XCTAssertTrue(app.staticTexts["Bölgendeki kuryelerle karşılaştır"].waitForExistence(timeout: 5))
    }
```

- [ ] **Step 2: `AppPreferences`'a anahtarlar**

```swift
    /// Konum yogunlugu paylasimi (kazanc paylasimindan AYRI acik riza). Varsayilan KAPALI.
    static let locationSharingOptInKey = "locationSharingOptIn"
    static let locationSharingConsentDateKey = "locationSharingConsentDate"
```

- [ ] **Step 3: `ProfileView.swift`, `ConsentViews.swift`, `CommunityView.swift`** — yukarıdaki düzenle; eski `SettingsView` kodu (profil, gider, konum, veri, hakkında, `DefaultPlatformsView`) birebir taşınır, `navigationTitle("Profil")`. Hedefler bölümü:

```swift
    private var goalsSection: some View {
        Section {
            goalField("Haftalık net hedef", text: $weeklyGoalText, identifier: "profile.weeklyGoal") { weeklyGoal = $0 }
            goalField("Günlük net hedef", text: $dailyGoalText, identifier: "profile.dailyGoal") { dailyGoal = $0 }
        } header: {
            Text("Hedefler")
        } footer: {
            Text("Bugün ekranındaki halka haftalık hedefi gösterir. Boş bırakırsan hedef kapalı olur.")
        }
    }

    private func goalField(_ title: String, text: Binding<String>, identifier: String, onValue: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .onChange(of: text.wrappedValue) { _, value in
                    onValue(value.nilIfBlank.flatMap(TurkishNumberParser.parseDecimal).map { max(0, $0) } ?? 0)
                }
                .accessibilityIdentifier(identifier)
            Text("₺").foregroundStyle(.secondary)
        }
    }
```

(`@AppStorage(AppPreferences.weeklyGoalKey) private var weeklyGoal = 0.0`, aynı şekilde `dailyGoal`; `@State weeklyGoalText/dailyGoalText` `onAppear`'da `weeklyGoal > 0 ? TurkishNumberParser.format(weeklyGoal) : ""`.)

Paylaşım bölümü:

```swift
    private var sharingSection: some View {
        Section {
            Toggle("Kazançlarımı anonim paylaş", isOn: Binding(
                get: { dataSharingOptIn },
                set: { newValue in
                    if newValue {
                        showConsentSheet = true
                    } else {
                        dataSharingOptIn = false
                        consentTimestamp = 0
                        locationSharingOptIn = false
                        locationConsentTimestamp = 0
                    }
                }
            ))
            .accessibilityIdentifier("settings.dataSharing")

            Toggle("Konum yoğunluğunu paylaş", isOn: Binding(
                get: { locationSharingOptIn },
                set: { newValue in
                    if newValue {
                        showLocationConsentSheet = true
                    } else {
                        locationSharingOptIn = false
                        locationConsentTimestamp = 0
                    }
                }
            ))
            .disabled(!dataSharingOptIn)
            .accessibilityIdentifier("profile.locationSharing")
        } header: {
            Text("Paylaşım")
        } footer: {
            Text("Varsayılan olarak kapalıdır. Bu sürümde hiçbir veri gönderilmez; tercihlerin kaydedilir. Topluluk özellikleri açıldığında yalnızca ekran görüntüsüyle doğrulanmış kazançlar paylaşılır.")
        }
    }
```

- [ ] **Step 4: Commit + CI (Task 9–11 birlikte)**

```bash
git rm KuryeKazanc/Views/Settings/SettingsView.swift
git add -A KuryeKazanc KuryeKazancUITests
git commit -m "feat(ui): Profil (hedefler, ayri rizalar) ve Topluluk iskeleti"
git push origin develop
```

Expected: `ios-ci` yeşil (derleme + birim testleri). UI testleri bu push'ta atlanır; Codemagic'te elle `RUN_UI_TESTS=true` ile bir kez çalıştırılarak 4 sekme testleri doğrulanır (Codemagic → Start new build → ios-ci → develop → Environment variables: `RUN_UI_TESTS=true`).

---

### Task 12: Yeni ekran görüntüsü önerisi (otomatik tarama)

**Files:**
- Create: `KuryeKazanc/Services/Screenshots/ScreenshotScanner.swift`
- Modify: `KuryeKazanc/Views/Today/TodayView.swift`
- Modify: `KuryeKazanc/Services/AppPreferences.swift`
- Modify: `project.yml` (`INFOPLIST_KEY_NSPhotoLibraryUsageDescription`)
- Test: `KuryeKazancTests/ScreenshotScannerTests.swift`

**Interfaces:**
- Consumes: `ScreenshotImporter`, `ImportedScreenshot` (Task 6); `ScreenshotEvidence.assetIdentifier` (Task 5); `TodayView.Sheet.importedScreenshot` (Task 9).
- Produces:
  - `protocol ScreenshotLibrary { var isAuthorized: Bool { get }; func requestAccess() async -> Bool; func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] }` + `struct LibraryScreenshot { var identifier: String; var createdAt: Date?; var data: () async -> Data? }` + `struct PhotoKitScreenshotLibrary: ScreenshotLibrary`
  - `@MainActor @Observable final class ScreenshotScanner { private(set) var suggestion: ImportedScreenshot?; init(library: ScreenshotLibrary, importer: ScreenshotImporter, defaults: UserDefaults = .standard); func scan(knownIdentifiers: Set<String>, now: Date = .now) async; func dismissSuggestion() }`
  - `AppPreferences.screenshotScanEnabledKey = "screenshotScanEnabled"`, `AppPreferences.dismissedScreenshotIDsKey = "dismissedScreenshotIDs"`

Kurallar: tarama yalnızca kullanıcı "Ekran görüntülerini otomatik bul" dediyse (`screenshotScanEnabled`) ve izin varsa çalışır; **açılışta izin istemez**. Son 48 saat, en yeni 5 görüntü; bilinen (kanıtı olan) ve reddedilen kimlikler atlanır; platform tanınan ilk görüntü öneri olur. İzin yok/reddedildi → öneri `nil`, hata gösterilmez.

- [ ] **Step 1: Başarısız test**

```swift
import XCTest
import UIKit
@testable import KuryeKazanc

@MainActor
final class ScreenshotScannerTests: XCTestCase {
    struct FakeLibrary: ScreenshotLibrary {
        var isAuthorized: Bool
        var items: [LibraryScreenshot]
        func requestAccess() async -> Bool { isAuthorized }
        func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] { Array(items.prefix(limit)) }
    }

    struct LinesByData: TextRecognizing {
        func recognize(in image: UIImage) async throws -> [RecognizedLine] {
            // Gorsel genisligi hangi metnin donecegini secer (test kolayligi)
            let lines = image.size.width > 100
                ? ["Getir", "Toplam Kazanç", "₺700"]
                : ["Hava durumu", "18°"]
            return lines.map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.1) }
        }
    }

    private func png(width: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 10), format: format).image { _ in }.pngData()!
    }

    private func makeScanner(authorized: Bool, items: [LibraryScreenshot]) -> ScreenshotScanner {
        let defaults = UserDefaults(suiteName: "scanner-\(UUID())")!
        defaults.set(true, forKey: AppPreferences.screenshotScanEnabledKey)
        return ScreenshotScanner(
            library: FakeLibrary(isAuthorized: authorized, items: items),
            importer: ScreenshotImporter(recognizer: LinesByData(), assetIsScreenshot: { _ in true }),
            defaults: defaults
        )
    }

    func testSuggestsFirstRecognizedPlatformScreenshot() async {
        let other = png(width: 50), getir = png(width: 200)
        let scanner = makeScanner(authorized: true, items: [
            LibraryScreenshot(identifier: "weather", createdAt: .now, data: { other }),
            LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir }),
        ])
        await scanner.scan(knownIdentifiers: [])
        XCTAssertEqual(scanner.suggestion?.assetIdentifier, "getir")
        XCTAssertEqual(scanner.suggestion?.parsed.platformCode, "getir")
    }

    func testSkipsKnownAndDismissed() async {
        let getir = png(width: 200)
        let scanner = makeScanner(authorized: true, items: [LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir })])
        await scanner.scan(knownIdentifiers: ["getir"])
        XCTAssertNil(scanner.suggestion)

        let scanner2 = makeScanner(authorized: true, items: [LibraryScreenshot(identifier: "g2", createdAt: .now, data: { getir })])
        await scanner2.scan(knownIdentifiers: [])
        scanner2.dismissSuggestion()
        await scanner2.scan(knownIdentifiers: [])
        XCTAssertNil(scanner2.suggestion)
    }

    func testNoPermissionMeansNoSuggestionAndNoCrash() async {
        let getir = png(width: 200)
        let scanner = makeScanner(authorized: false, items: [LibraryScreenshot(identifier: "getir", createdAt: .now, data: { getir })])
        await scanner.scan(knownIdentifiers: [])
        XCTAssertNil(scanner.suggestion)
    }
}
```

- [ ] **Step 2: `ScreenshotScanner.swift`**

```swift
import Foundation
import Observation
import Photos
import UIKit

struct LibraryScreenshot {
    var identifier: String
    var createdAt: Date?
    var data: () async -> Data?
}

protocol ScreenshotLibrary {
    var isAuthorized: Bool { get }
    func requestAccess() async -> Bool
    func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot]
}

/// PhotoKit: yalnizca ekran goruntusu alt turundeki fotograflar. Sinirli erisimde yalnizca secilenler gorunur.
struct PhotoKitScreenshotLibrary: ScreenshotLibrary {
    var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] {
        guard isAuthorized else { return [] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaSubtypes & %d) != 0 AND creationDate >= %@",
            PHAssetMediaSubtype.photoScreenshot.rawValue, since as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var result: [LibraryScreenshot] = []
        assets.enumerateObjects { asset, _, _ in
            result.append(LibraryScreenshot(identifier: asset.localIdentifier, createdAt: asset.creationDate) {
                await withCheckedContinuation { continuation in
                    let request = PHImageRequestOptions()
                    request.isNetworkAccessAllowed = true
                    request.deliveryMode = .highQualityFormat
                    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: request) { data, _, _, _ in
                        continuation.resume(returning: data)
                    }
                }
            })
        }
        return result
    }
}

/// Uygulama acilinca son 48 saatin islenmemis kazanc ekran goruntusunu bulup oneri olarak sunar.
@MainActor
@Observable
final class ScreenshotScanner {
    private(set) var suggestion: ImportedScreenshot?

    @ObservationIgnored private let library: ScreenshotLibrary
    @ObservationIgnored private let importer: ScreenshotImporter
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isScanning = false

    init(library: ScreenshotLibrary = PhotoKitScreenshotLibrary(),
         importer: ScreenshotImporter = ScreenshotImporter(),
         defaults: UserDefaults = .standard) {
        self.library = library
        self.importer = importer
        self.defaults = defaults
    }

    var isEnabled: Bool { defaults.bool(forKey: AppPreferences.screenshotScanEnabledKey) }

    /// Kullanici "otomatik bul"u actiginda: izin ister, verilirse tercihi kaydeder.
    func enable() async -> Bool {
        let granted = await library.requestAccess()
        defaults.set(granted, forKey: AppPreferences.screenshotScanEnabledKey)
        return granted
    }

    func scan(knownIdentifiers: Set<String>, now: Date = .now) async {
        guard isEnabled, library.isAuthorized, !isScanning else {
            suggestion = nil
            return
        }
        isScanning = true
        defer { isScanning = false }

        let dismissed = Set(defaults.stringArray(forKey: AppPreferences.dismissedScreenshotIDsKey) ?? [])
        let since = now.addingTimeInterval(-48 * 3600)
        for item in await library.recentScreenshots(since: since, limit: 5) {
            guard !knownIdentifiers.contains(item.identifier), !dismissed.contains(item.identifier),
                  let data = await item.data(),
                  let result = try? await importer.importImage(data: data, assetIdentifier: item.identifier, referenceDate: now),
                  result.parsed.platformCode != nil else { continue }
            var imported = result
            imported.capturedAt = imported.capturedAt ?? item.createdAt
            suggestion = imported
            return
        }
        suggestion = nil
    }

    func dismissSuggestion() {
        guard let id = suggestion?.assetIdentifier else { return }
        var dismissed = defaults.stringArray(forKey: AppPreferences.dismissedScreenshotIDsKey) ?? []
        dismissed.append(id)
        defaults.set(Array(dismissed.suffix(200)), forKey: AppPreferences.dismissedScreenshotIDsKey)
        suggestion = nil
    }

    /// Oneri forma aktarilinca listeden duser (kayit edilirse kanit kimligi zaten "bilinen" olur).
    func consumeSuggestion() -> ImportedScreenshot? {
        defer { suggestion = nil }
        return suggestion
    }
}
```

`AppPreferences`:

```swift
    /// Son 48 saatin ekran goruntulerini otomatik tara (kullanici acar; izin o an istenir).
    static let screenshotScanEnabledKey = "screenshotScanEnabled"
    static let dismissedScreenshotIDsKey = "dismissedScreenshotIDs"
```

`project.yml` → `KuryeKazanc` hedefinin `settings.base`'ine:

```yaml
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "Platformunun kazanç ekranının yeni ekran görüntülerini bulup kayda dönüştürmek için. Görüntüler cihazında işlenir, hiçbir yere gönderilmez."
```

- [ ] **Step 3: Bugün ekranına öneri**

`KuryeKazancApp`: `@State private var scanner = ScreenshotScanner(library: PhotoKitScreenshotLibrary())`; UI testinde (`launch.isUITesting`) taramayı kapatmak için `ScreenshotScanner(defaults: UserDefaults(suiteName: "ui-tests")!)` (tarama kapalı). `.environment(scanner)`.

`TodayView`:
- `@Environment(ScreenshotScanner.self) private var scanner`, `@Environment(\.scenePhase) private var scenePhase`, `@Query private var evidences: [ScreenshotEvidence]` (yalnızca `assetIdentifier` için).
- `.task { await scanner.scan(knownIdentifiers: knownIDs) }` ve `.onChange(of: scenePhase)` → `.active` iken aynı çağrı. `knownIDs = Set(evidences.compactMap(\.assetIdentifier))`.
- En üst bölümden önce, öneri varsa:

```swift
                if let suggestion = scanner.suggestion {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "text.viewfinder").font(.title2).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yeni kazanç ekranı bulundu").font(.subheadline.weight(.semibold))
                                Text("\(platformName(suggestion.parsed.platformCode)) · \(Formatters.currency(suggestion.parsed.totalEarning))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Ekle") {
                                if let imported = scanner.consumeSuggestion() { activeSheet = .importedScreenshot(imported) }
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("today.suggestion.add")
                        }
                        .swipeActions { Button("Gizle", role: .destructive) { scanner.dismissSuggestion() } }
                    }
                }
```

- Kazanç listesi boşken ve `!scanner.isEnabled` ise ek satır: `Button("Ekran görüntülerini otomatik bul") { Task { if await scanner.enable() { await scanner.scan(knownIdentifiers: knownIDs) } } }` (`today.enableScan`).
- `.importedScreenshot(let imported)` sheet'i: `EarningFormView(defaultPlatform: defaultPlatform, imported: imported)`.

- [ ] **Step 4: Commit + CI**

```bash
git add KuryeKazanc project.yml KuryeKazancTests/ScreenshotScannerTests.swift
git commit -m "feat: yeni ekran goruntusu onerisi (son 48 saat, izin yalnizca kullanici isteyince)"
git push origin develop
```

Expected: `ios-ci` yeşil, `ScreenshotScannerTests` 3/3.

---

### Task 13: Paylaş menüsü eklentisi ve App Group gelen kutusu

**Files:**
- Create: `KuryeKazanc/Services/Screenshots/ScreenshotInbox.swift`
- Create: `KuryeShareExtension/ShareViewController.swift`
- Create: `KuryeShareExtension/Info.plist`
- Create: `KuryeShareExtension/KuryeShareExtension.entitlements`
- Create: `KuryeKazanc/Supporting/KuryeKazanc.entitlements`
- Modify: `project.yml`, `codemagic.yaml`, `KuryeKazanc/Views/Today/TodayView.swift`, `KuryeKazanc/App/KuryeKazancApp.swift`
- Test: `KuryeKazancTests/ScreenshotInboxTests.swift`

**Interfaces:**
- Consumes: `ScreenshotImporter` (Task 6), `TodayView.Sheet.importedScreenshot` (Task 9).
- Produces: `struct ScreenshotInbox { static let appGroupID = "group.com.kuryekazanc.app"; init(directory: URL?); static var shared: ScreenshotInbox; func add(_ data: Data) throws; func pending() -> [URL]; func remove(_ url: URL) }`. (`ScreenshotInbox.swift` hem uygulama hem eklenti hedefinde derlenir — yalnızca Foundation kullanır.)

**Önkoşul (kullanıcı/elle, bir kez — Apple Developer + Codemagic):**
1. developer.apple.com → Identifiers → App Groups → `+` → `group.com.kuryekazanc.app`.
2. Identifiers → `com.kuryekazanc.app` → App Groups yeteneğini aç → grubu seç → Kaydet (mevcut profil geçersizleşir).
3. Identifiers → `+` App ID → `com.kuryekazanc.app.share`, App Groups açık, aynı grup.
4. Profiles → "Kurye Kazanc App Store" profilini yeniden oluştur (Edit → Save); yeni App Store profili: `com.kuryekazanc.app.share` → "Kurye Kazanc Share App Store".
5. Codemagic → Teams → Code signing identities → iOS provisioning profiles → Fetch profiles → ikisini de çek; referans adları: `kurye-kazanc-appstore` (güncel) ve `kurye-kazanc-share-appstore`.

(Bu adımlar tarayıcıda Claude ile de yapılabilir; kullanıcı onayıyla.)

- [ ] **Step 1: Başarısız test**

```swift
import XCTest
@testable import KuryeKazanc

final class ScreenshotInboxTests: XCTestCase {
    func testAddListRemove() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID())")
        let inbox = ScreenshotInbox(directory: dir)
        try inbox.add(Data([1, 2, 3]))
        try inbox.add(Data([4]))
        let pending = inbox.pending()
        XCTAssertEqual(pending.count, 2)
        inbox.remove(pending[0])
        XCTAssertEqual(inbox.pending().count, 1)
    }

    func testMissingAppGroupIsHarmless() throws {
        let inbox = ScreenshotInbox(directory: nil)
        XCTAssertThrowsError(try inbox.add(Data([1])))
        XCTAssertEqual(inbox.pending(), [])
    }
}
```

- [ ] **Step 2: `ScreenshotInbox.swift`**

```swift
import Foundation

/// Paylas eklentisi ile uygulama arasindaki gelen kutusu (App Group klasoru).
/// Eklenti gorseli buraya birakir; uygulama acilinca isler ve siler. SwiftData deposu paylasilmaz.
struct ScreenshotInbox {
    static let appGroupID = "group.com.kuryekazanc.app"

    enum InboxError: Error { case unavailable }

    let directory: URL?

    init(directory: URL?) {
        self.directory = directory
    }

    static var shared: ScreenshotInbox {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        return ScreenshotInbox(directory: base?.appendingPathComponent("Inbox", isDirectory: true))
    }

    func add(_ data: Data) throws {
        guard let directory else { throw InboxError.unavailable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString).img"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    /// Eskiden yeniye.
    func pending() -> [URL] {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "img" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
```

- [ ] **Step 3: Eklenti** — `KuryeShareExtension/ShareViewController.swift`

```swift
import UIKit
import UniformTypeIdentifiers

/// Fotograflar > Paylas > Kurye Kazanc: gorselleri gelen kutusuna birakir ve kisa bir onay gosterir.
/// OCR burada yapilmaz (eklenti bellek siniri); uygulama acilinca islenir.
final class ShareViewController: UIViewController {
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.text = "Kurye Kazanç'a ekleniyor…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])
        Task { await handle() }
    }

    private func handle() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        var saved = 0
        for provider in providers.prefix(5) {
            if let data = await loadData(provider), (try? ScreenshotInbox.shared.add(data)) != nil {
                saved += 1
            }
        }
        label.text = saved > 0
            ? "Eklendi. Kurye Kazanç'ı açınca kayda dönüştürülecek."
            : "Görsel eklenemedi."
        try? await Task.sleep(for: .seconds(1.2))
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
```

`KuryeShareExtension/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionAttributes</key>
		<dict>
			<key>NSExtensionActivationRule</key>
			<dict>
				<key>NSExtensionActivationSupportsImageWithMaxCount</key>
				<integer>5</integer>
			</dict>
		</dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.share-services</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
	</dict>
</dict>
</plist>
```

İki `.entitlements` dosyası (uygulama ve eklenti) aynı içerikte:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.kuryekazanc.app</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 4: `project.yml`** — `KuryeKazanc` hedefine `CODE_SIGN_ENTITLEMENTS: KuryeKazanc/Supporting/KuryeKazanc.entitlements` ve bağımlılık:

```yaml
    dependencies:
      - target: KuryeShareExtension
        embed: true
```

Yeni hedef:

```yaml
  KuryeShareExtension:
    type: app-extension
    platform: iOS
    sources:
      - path: KuryeShareExtension
        excludes:
          - "Info.plist"
          - "*.entitlements"
      - path: KuryeKazanc/Services/Screenshots/ScreenshotInbox.swift
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kuryekazanc.app.share
        INFOPLIST_FILE: KuryeShareExtension/Info.plist
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: "Kurye Kazanç"
        CODE_SIGN_ENTITLEMENTS: KuryeShareExtension/KuryeShareExtension.entitlements
        TARGETED_DEVICE_FAMILY: "1"
        SKIP_INSTALL: YES
```

- [ ] **Step 5: `codemagic.yaml`** — `ios-release` imzalaması:

```yaml
      ios_signing:
        provisioning_profiles:
          - kurye-kazanc-appstore
          - kurye-kazanc-share-appstore
        certificates:
          - selfwake-distribution
```

(`ios-ci` imzasız derler; değişiklik gerekmez.)

- [ ] **Step 6: Uygulamada gelen kutusunu işle** — `TodayView`'a:

```swift
    @State private var inboxQueue: [ImportedScreenshot] = []
    private let inbox = ScreenshotInbox.shared

    private func processInbox() async {
        let importer = ScreenshotImporter()
        for url in inbox.pending() {
            defer { inbox.remove(url) }
            guard let data = try? Data(contentsOf: url),
                  let result = try? await importer.importImage(data: data, assetIdentifier: nil) else { continue }
            inboxQueue.append(result)
        }
        if activeSheet == nil, !inboxQueue.isEmpty {
            activeSheet = .importedScreenshot(inboxQueue.removeFirst())
        }
    }
```

`.task` ve `scenePhase == .active` içinde `await processInbox()` çağrılır. Sheet kapanınca (`onDismiss`) kuyrukta öğe varsa bir sonraki açılır: `.sheet(item: $activeSheet, onDismiss: { if !inboxQueue.isEmpty { activeSheet = .importedScreenshot(inboxQueue.removeFirst()) } })`. UI testinde (`-ui-testing`) gelen kutusu `ScreenshotInbox(directory: nil)` olur — `KuryeKazancApp`'ten environment ile verilir: `.environment(\.screenshotInbox, ...)` yerine sade çözüm: `TodayView`'da `private let inbox = LaunchOptions.current.isUITesting ? ScreenshotInbox(directory: nil) : .shared`.

- [ ] **Step 7: Commit + CI**

```bash
git add KuryeShareExtension KuryeKazanc project.yml codemagic.yaml KuryeKazancTests/ScreenshotInboxTests.swift
git commit -m "feat: paylas menusu eklentisi ve App Group gelen kutusu"
git push origin develop
```

Expected: `ios-ci` yeşil (eklenti imzasız derlenir), `ScreenshotInboxTests` 2/2. İmzalı derleme Task 15'teki `ios-release`'te doğrulanır; önkoşul adımları yapılmadıysa orada "No matching profiles" hatası verir.

---

### Task 14: Onboarding — 4 sade adım

**Files:**
- Modify: `KuryeKazanc/ViewModels/OnboardingViewModel.swift`
- Modify: `KuryeKazanc/Views/Onboarding/OnboardingView.swift`
- Test: `KuryeKazancUITests/DashboardUITests.swift` (`OnboardingUITests`), `KuryeKazancTests/FormViewModelTests.swift` (onboarding testi varsa)

**Interfaces:**
- Consumes: `PrimaryActionButtonStyle` (Task 8), `DataSharingConsentView` (Task 11), `AppPreferences.dataSharingOptInKey`.
- Produces: `OnboardingViewModel.Step { vehicle, platforms, location, sharing }`; `var wantsSharing: Bool` (son adımda; `complete` true ise rıza tarihiyle `dataSharingOptIn` yazar — rıza ekranı gösterildikten sonra).

Düzen: üstte nokta göstergesi (4 nokta, seçili = vurgu), ortada başlık + açıklama + seçenekler (`List` yerine sade satırlar, seçili olan `checkmark.circle.fill`), altta tam genişlik `PrimaryActionButtonStyle` "Devam"/"Başla" (`onboarding.next`) ve solda metin düğmesi "Geri" (`onboarding.back`). İsim alanı kaldırılır (Profil'den girilir; `Courier.name` = "Kurye").
1. **Araç** — "Neyle çalışıyorsun?" (eski satırlar).
2. **Platformlar** — "Hangi platformlarda?" (en az 1).
3. **Konum** — "Konum yalnızca vardiyada" (eski içerik; metin: "Vardiyayı başlattığında mesafeni ölçer, bitirince durur. Kayıtlara yalnızca ilçe eklenir.").
4. **Paylaşım** — "Bölgendeki kuryelerle karşılaştır" + "Anonim paylaşıma katıl" düğmesi (rıza ekranını açar, `onboarding.sharing`) + "Şimdilik geç" bilgisi; zorunlu değil. Başlık metni `Text("Bölgendeki kuryelerle karşılaştır")`.

- [ ] **Step 1: UI testini güncelle** — `testOnboardingFlowReachesDashboard`:

```swift
    func testOnboardingFlowReachesDashboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults"]
        app.launch()

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(app.buttons["onboarding.vehicle.scooter"].waitForExistence(timeout: 10))
        app.buttons["onboarding.vehicle.scooter"].tap()
        next.tap()                                   // -> platformlar

        XCTAssertTrue(app.buttons["onboarding.platform.getir"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "Platform secmeden devam edilmemeli")
        app.buttons["onboarding.platform.getir"].tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()                                   // -> konum

        XCTAssertTrue(app.staticTexts["Konum yalnızca vardiyada"].waitForExistence(timeout: 5))
        next.tap()                                   // -> paylasim

        XCTAssertTrue(app.staticTexts["Bölgendeki kuryelerle karşılaştır"].waitForExistence(timeout: 5))
        next.tap()                                   // Basla (paylasim acilmadan)

        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
    }
```

- [ ] **Step 2: ViewModel**

```swift
    enum Step: Int, CaseIterable {
        case vehicle, platforms, location, sharing
    }

    var step: Step = .vehicle
    var vehicleType: VehicleType = .motorcycle
    var selectedPlatformCodes: Set<String> = []

    var canContinue: Bool {
        step == .platforms ? !selectedPlatformCodes.isEmpty : true
    }

    var isLastStep: Bool { step == .sharing }
```

`complete(in:platforms:defaults:)` içinde `courier.name = name.nilIfBlank ?? "Kurye"` → `if courier.name.isEmpty { courier.name = "Kurye" }`; `name` özelliği kaldırılır. Paylaşım rızası `OnboardingView` içinde `DataSharingConsentView` onayında doğrudan `@AppStorage` ile yazılır (Profil ile aynı anahtarlar) — ViewModel'e ek durum gerekmez.

- [ ] **Step 3: Görünüm** — yukarıdaki düzen; `welcomeStep` ve isim alanı silinir; `permissionsStep` → `locationStep`; yeni `sharingStep`:

```swift
    private var sharingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bölgendeki kuryelerle karşılaştır")
                .font(.title.bold())
            Text("Anonim paylaşıma katılırsan, topluluk özellikleri açıldığında ilçendeki saat başı ortalama net kazancı ve en yoğun saatleri görürsün. Yalnızca ekran görüntüsüyle doğrulanmış kazançlar kullanılır; adın ve tam konumun asla paylaşılmaz.")
                .foregroundStyle(.secondary)
            if dataSharingOptIn {
                Label("Katıldın — Profil'den istediğin an kapatabilirsin.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Button("Anonim paylaşıma katıl") { showConsent = true }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding.sharing")
                Text("İstersen geçebilirsin; uygulama paylaşım olmadan da tam çalışır.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showConsent) {
            DataSharingConsentView {
                dataSharingOptIn = true
                consentTimestamp = Date.now.timeIntervalSince1970
            }
        }
    }
```

(`DataSharingConsentView` Task 11'de `private` değil `internal` yapılır.)

- [ ] **Step 4: Commit + CI**

```bash
git add KuryeKazanc/ViewModels/OnboardingViewModel.swift KuryeKazanc/Views/Onboarding KuryeKazancUITests
git commit -m "feat(ui): onboarding 4 adim - arac, platform, konum, istege bagli paylasim"
git push origin develop
```

Expected: `ios-ci` yeşil.

---

### Task 15: Sürüm 1.1.0, notlar ve TestFlight

**Files:**
- Modify: `project.yml` (`MARKETING_VERSION: "1.1.0"`)
- Modify: `TESTFLIGHT_NOTES.md`, `PROGRESS.md`, `README.md`

- [ ] **Step 1: Sürüm** — `project.yml`: `MARKETING_VERSION: "1.1.0"`.

- [ ] **Step 2: `TESTFLIGHT_NOTES.md` en üstüne**

```markdown
## 1.1.0

Yeni:
- Yeni, sade arayüz: Bugün / Analiz / Topluluk / Profil.
- Kazanç ekranının ekran görüntüsünü Fotoğraflar > Paylaş > Kurye Kazanç ile gönderebilirsin.
- "Ekran görüntülerini otomatik bul": son 48 saatin kazanç ekranlarını önerir.
- Analiz: en kârlı saatlerin, gün×saat ısı haritası, platform karşılaştırması (₺/saat, ₺/sipariş, ₺/km).
- Haftalık ve günlük net hedef; Bugün ekranında halka.
- Kayıtlarda doğrulama rozeti (Elle / Ekran görüntüsü / Doğrulandı).

Lütfen test et:
1. Güncellemeden sonra eski kayıtların duruyor mu? (1.0.0 kayıtları korunmalı)
2. Trendyol GO / Getir / Yemeksepeti / Migros kazanç ekranının görüntüsünü Paylaş menüsüyle gönder; uygulamayı açınca form doluyor mu?
3. Profil > Hedefler'e haftalık hedef gir; Bugün'deki halka doğru mu?
4. Analiz > Hafta: en kârlı saatler mantıklı mı?
5. Yanlış okunan ekranlarda "okunan metni geliştiriciye gönder" ile rapor yolla — şablonları bu raporlarla kalibre ediyoruz.
```

- [ ] **Step 3: `PROGRESS.md`'ye oturum bölümü ekle** (yapılanlar, test sayıları, açık konular: şablon kalibrasyonu, 1.2 planı), `README.md` klasör yapısına `Views/Design`, `Views/Today`, `Views/Analysis`, `Views/Profile`, `Views/Community`, `Services/Screenshots`, `KuryeShareExtension/` satırları.

- [ ] **Step 4: Yerel Core testleri + commit**

Run: `swift test`
Expected: tüm Core testleri PASS.

```bash
git add project.yml TESTFLIGHT_NOTES.md PROGRESS.md README.md
git commit -m "chore: surum 1.1.0, TestFlight notlari"
git push origin develop
```

- [ ] **Step 5: PR → UI testleri → birleştir → TestFlight**

```bash
gh pr create --base main --head develop --title "Sürüm 1.1.0: iOS tarzı arayüz ve cihaz üstü temel" --body "Plan: docs/superpowers/plans/2026-10-07-surum-1-1-arayuz-ve-cihaz-ustu.md"
```

Expected: PR'da `ios-ci` (UI testleri dahil) yeşil. Önkoşullar (Task 13) tamamsa birleştir → `ios-release` → TestFlight 1.1.0. `ios-release` imzalamada düşerse Task 13 önkoşul adımlarını kontrol et.
