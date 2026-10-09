# Sürüm 1.4a — Ekran tipleri, senaryo testleri, kazanç taraması denemesi — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Okuma motorunu üç ekran tipine (özet, liste, sipariş kartı) ve platform adı yazmayan Uber ekranına genişletmek; bunu satır ve görüntü senaryolarıyla otomatik ölçmek; ardından yayın eklentisiyle otomatik yakalamayı telefonda denemek.

**Architecture:** Saf mantık `KuryeKazanc/Core`'da kalır (Windows'ta `swift test`). Şablon JSON'una geriye uyumlu alanlar eklenir; çözümleyici şablonun `layout`'una göre dallanır. Senaryo üreteci Core'dadır; satır katmanı Core testinde, görüntü katmanı (SwiftUI taklit ekran → Vision) uygulama test hedefinde CI simülatöründe çalışır. Deneme (spike) ayrı dalda bir Broadcast Upload Extension'dır.

**Tech Stack:** Swift 5 modu, SwiftUI, SwiftData, Vision, ReplayKit, XCTest; XcodeGen (`project.yml`); GitHub Actions (CI), Codemagic (TestFlight); Supabase (şablon tablosu, değişmez).

**Spec:** `docs/superpowers/specs/2026-10-09-surum-1-4a-ekran-okuma-design.md`

## Global Constraints

- iOS 17.0 en düşük sürüm; `SWIFT_VERSION: "5.0"`; üçüncü taraf bağımlılık eklenmez.
- `KuryeKazanc/Core` içindeki dosyalar SwiftData/UIKit/SwiftUI/Vision import etmez (Windows `swift test` derler).
- Core testleri `#if canImport(KuryeCore) @testable import KuryeCore #else @testable import KuryeKazanc #endif` başlığıyla yazılır.
- Kod yorumları ASCII Türkçe (mevcut dosyalar gibi: "sablon", "satir"); kullanıcıya görünen metinler Türkçe karakterli.
- Tüm yeni ve değişen şablonlar `status: calibrating`; taklit ekranlarla hiçbir şablon `active` yapılmaz.
- Eski şablon JSON'u (yeni alanlar olmadan) aynen çözülmeli; tanınmayan `layout` değeri `summary` sayılır.
- `.order` ve `.week` dönemli kayıtlar sunucuya vardiya olarak gönderilmez.
- Kişisel bilgi içeren gerçek görüntü repoya girmez (ad, telefon, IBAN, TC karartılmış olmalı).
- Push/CI: iş bitmeden push yok; Windows'ta her Core görevinden sonra `swift test` (repo kökünde) yeşil olmalı. Uygulama testleri ilk kez Görev 6 sonunda push ile GitHub Actions'ta koşar.
- Deneme (Görev 10–12) yalnızca `spike/broadcast-capture` dalında; TestFlight'a göndermeden önce kullanıcıya sorulur ve TestFlight 1.3.0 yüklemesi bitmiş olmalıdır.

## Review Focus

1. **Eski/ileri sürüm şablon JSON'u** (sunucudan gelen, yeni alanları olmayan ya da bilinmeyen `layout: "grid"` içeren) — uygulama çökmeden çözmeli, bilinmeyen tip `summary` sayılmalı. → Görev 1'de test.
2. **Liste ekranında referans numaraları** ("#1420" satırı tutarın altında) — iş numarası tutar sanılmamalı. → Görev 4'te test.
3. **Saat gibi görünen süreler** ("12:30" tek başına süre değil, "02:15 saat" süre) — vardiya saatleri bozulmamalı. → Görev 2'de test.
4. **Haftalık süre** (Uber'de "23 sa 32 dk" haftalık) — formdaki vardiya saatlerine 23 saatlik vardiya olarak yazılmamalı. → Görev 6'da test.
5. **Parmak izi ile yanlış şablon** — platform adı olan Getir ekranı, parmak izi daha çok eşleşen başka şablona düşmemeli (ad eşleşmesi önce gelir). → Görev 3'te test.

---

## Dosya yapısı

| Dosya | Sorumluluk |
|---|---|
| `KuryeKazanc/Core/OCR/OCRTemplate.swift` (değişir) | `Layout`, `Period.order`, yeni alanlar, geriye uyumlu çözme |
| `KuryeKazanc/Core/OCR/TextPatterns.swift` (değişir) | `duration(in:)`, `containsDateRange(_:)`, `strippingReferenceNumbers(_:)` |
| `KuryeKazanc/Core/OCR/EarningsScreenshotParser.swift` (değişir) | Şablon seçimi (ad → parmak izi), layout'a göre çözümleme, süre |
| `KuryeKazanc/Core/OCR/BundledTemplates.swift` (değişir) | Yeni şablonlar |
| `KuryeKazanc/Core/Verification/ScreenshotVerifier.swift` (değişir) | `.order` günlük ekran sayılmaz |
| `KuryeKazanc/Core/Scenarios/ScreenScenario.swift` (yeni) | Senaryo modeli, satır üretimi, beklenen sonuç kontrolü |
| `KuryeKazanc/Core/Scenarios/ScenarioGenerator.swift` (yeni) | Temel düzenler × çeşitlemeler, tohumlu üreteç |
| `KuryeKazanc/Core/Scenarios/ScenarioTally.swift` (yeni) | Platform × alan doğruluk sayımı, rapor, taban karşılaştırma |
| `KuryeKazanc/Services/Sync/SyncCoordinator.swift` (değişir) | `.order` gönderilmez |
| `KuryeKazanc/ViewModels/EarningFormViewModel.swift` (değişir) | Süre → vardiya saatleri, sipariş kartı uyarısı, KDV notu |
| `KuryeKazanc/Views/Earnings/EarningFormView.swift` (değişir) | KDV notunun gösterimi |
| `KuryeKazanc/Views/Tester/MockEarningsScreen.swift` (yeni) | Senaryodan SwiftUI taklit ekran + `render` |
| `KuryeKazancTests/ScenarioImageTests.swift` (yeni) | Görüntü katmanı, rapor, taban, gerçek görüntüler |
| `KuryeKazancTests/Fixtures/scenario-baseline.json` (yeni, Görev 8 sonunda) | Taban doğruluk |
| `.github/workflows/ios-ci.yml` (değişir) | Rapor yolu ve özet adımı |
| Core testleri: `TemplateCompatibilityTests.swift`, `DurationPatternTests.swift`, `TemplateSelectionTests.swift`, `LayoutParsingTests.swift`, `NewTemplatesTests.swift`, `ScenarioParserTests.swift`, `ScenarioTallyTests.swift` (hepsi `KuryeKazancTests/Core/`, yeni) | |

---

### Task 1: Şablon alanları ve geriye uyumlu çözme

**Files:**
- Modify: `KuryeKazanc/Core/OCR/OCRTemplate.swift`
- Test: `KuryeKazancTests/Core/TemplateCompatibilityTests.swift` (yeni)

**Interfaces:**
- Produces: `OCRTemplate.Layout` (`summary`, `list`, `orderCard`), `OCRTemplate.Period.order`, `OCRTemplate.layout: Layout`, `durationLabels: [String]`, `rowLabels: [String]`, `amountsExcludeVAT: Bool`. Bellekteki üye-bazlı `init` yeni alanları varsayılan değerli son parametreler olarak alır (mevcut çağrılar değişmez).

- [ ] **Step 1: Write the failing test**

`KuryeKazancTests/Core/TemplateCompatibilityTests.swift`:

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Sunucudan gelen eski / ileri surum sablon JSON'u cokmeden cozulmeli (Review Focus 1).
final class TemplateCompatibilityTests: XCTestCase {
    private let oldJSON = #"""
    {"id":"x.earnings","version":1,"status":"calibrating","platformCode":"getir",
     "detectionKeywords":["getir"],"fingerprint":["kazanclarim"],"minFingerprintMatches":1,
     "totalLabels":["toplam"],"bonusLabels":[],"packageLabels":[],"totalIncludesBonus":true,
     "dayLabels":["bugun"],"weekLabels":["bu hafta"]}
    """#

    func testOldJSONWithoutNewFields_usesDefaults() throws {
        let template = try JSONDecoder().decode(OCRTemplate.self, from: Data(oldJSON.utf8))
        XCTAssertEqual(template.layout, .summary)
        XCTAssertEqual(template.durationLabels, [])
        XCTAssertEqual(template.rowLabels, [])
        XCTAssertFalse(template.amountsExcludeVAT)
        XCTAssertNil(template.minPackageFee)
    }

    func testUnknownLayout_fallsBackToSummary() throws {
        let json = oldJSON.replacingOccurrences(of: #""version":1,"#, with: #""version":1,"layout":"grid","#)
        let template = try JSONDecoder().decode(OCRTemplate.self, from: Data(json.utf8))
        XCTAssertEqual(template.layout, .summary)
    }

    func testNewFields_roundTrip() throws {
        var template = try JSONDecoder().decode(OCRTemplate.self, from: Data(oldJSON.utf8))
        template.layout = .list
        template.durationLabels = ["cevrimici"]
        template.rowLabels = ["tasima ucreti"]
        template.amountsExcludeVAT = true
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(OCRTemplate.self, from: data)
        XCTAssertEqual(decoded, template)
    }

    func testOrderPeriodRawValue() {
        XCTAssertEqual(OCRTemplate.Period(rawValue: "order"), .order)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TemplateCompatibilityTests`
Expected: FAIL (derleme hatası: `layout`, `Period.order` yok)

- [ ] **Step 3: Implement**

`OCRTemplate.swift` içinde `struct OCRTemplate` gövdesini şöyle değiştir (mevcut `fingerprintMatches` ve `period` fonksiyonları kalır; `period` Görev 3'te değişecek):

```swift
struct OCRTemplate: Codable, Equatable {
    enum Status: String, Codable { case calibrating, active }
    enum Period: String, Codable { case day, week, order, unknown }
    /// Ekran tipi: ozet (toplam + adet), liste (satirlar toplanir), siparis karti (tek siparis).
    enum Layout: String, Codable { case summary, list, orderCard }

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
    // 1.4a: JSON'da yoksa varsayilan (eski sunucu sablonlari bozulmaz)
    var layout: Layout = .summary
    var durationLabels: [String] = []
    /// `list` tipinde toplanacak satirlarin etiketi.
    var rowLabels: [String] = []
    /// Ekrandaki tutarlar KDV haric (yalnizca bilgi).
    var amountsExcludeVAT: Bool = false

    // ... mevcut fingerprintMatches(in:) ve period(in:) burada kalir
}

extension OCRTemplate {
    enum CodingKeys: String, CodingKey {
        case id, version, status, platformCode, detectionKeywords, fingerprint, minFingerprintMatches
        case totalLabels, bonusLabels, packageLabels, totalIncludesBonus, minPackageFee, maxPackageFee
        case dayLabels, weekLabels, layout, durationLabels, rowLabels, amountsExcludeVAT
    }

    /// Uye-bazli init korunsun diye uzantida. Yeni alanlar yoksa varsayilan; bilinmeyen layout -> summary.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        version = try c.decode(Int.self, forKey: .version)
        status = try c.decode(Status.self, forKey: .status)
        platformCode = try c.decode(String.self, forKey: .platformCode)
        detectionKeywords = try c.decode([String].self, forKey: .detectionKeywords)
        fingerprint = try c.decode([String].self, forKey: .fingerprint)
        minFingerprintMatches = try c.decode(Int.self, forKey: .minFingerprintMatches)
        totalLabels = try c.decode([String].self, forKey: .totalLabels)
        bonusLabels = try c.decode([String].self, forKey: .bonusLabels)
        packageLabels = try c.decode([String].self, forKey: .packageLabels)
        totalIncludesBonus = try c.decode(Bool.self, forKey: .totalIncludesBonus)
        minPackageFee = try c.decodeIfPresent(Double.self, forKey: .minPackageFee)
        maxPackageFee = try c.decodeIfPresent(Double.self, forKey: .maxPackageFee)
        dayLabels = try c.decode([String].self, forKey: .dayLabels)
        weekLabels = try c.decode([String].self, forKey: .weekLabels)
        let layoutRaw = try c.decodeIfPresent(String.self, forKey: .layout)
        layout = layoutRaw.flatMap(Layout.init(rawValue:)) ?? .summary
        durationLabels = try c.decodeIfPresent([String].self, forKey: .durationLabels) ?? []
        rowLabels = try c.decodeIfPresent([String].self, forKey: .rowLabels) ?? []
        amountsExcludeVAT = try c.decodeIfPresent(Bool.self, forKey: .amountsExcludeVAT) ?? false
    }
}
```

`BundledTemplates.generic` üye-bazlı init ile kuruluyor; yeni parametreler varsayılanlı olduğundan değişiklik gerekmez.

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: tümü PASS (mevcut 100 + 4 yeni)

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/OCR/OCRTemplate.swift KuryeKazancTests/Core/TemplateCompatibilityTests.swift
git commit -m "feat(core): sablona ekran tipi, sure ve KDV alanlari; geriye uyumlu cozme"
```

---

### Task 2: Çalışma süresi ve yardımcı kalıplar

**Files:**
- Modify: `KuryeKazanc/Core/OCR/TextPatterns.swift`
- Test: `KuryeKazancTests/Core/DurationPatternTests.swift` (yeni)

**Interfaces:**
- Produces: `TextPatterns.duration(in: String) -> TimeInterval?` (saniye; normalize satır), `TextPatterns.containsDateRange(_ text: String) -> Bool` ("4 sub - 10 sub", "4 subat - 10 subat"), `TextPatterns.strippingReferenceNumbers(_ line: String) -> String` ("#1420", "no 1420", "№78347" kaldırılır).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class DurationPatternTests: XCTestCase {
    private func d(_ text: String) -> TimeInterval? {
        TextPatterns.duration(in: TextNormalizer.normalize(text))
    }

    func testHourMinuteForms() {
        XCTAssertEqual(d("23 sa 32 dk"), 23 * 3600 + 32 * 60)
        XCTAssertEqual(d("23sa 32dk"), 23 * 3600 + 32 * 60)
        XCTAssertEqual(d("23h 32m"), 23 * 3600 + 32 * 60)
        XCTAssertEqual(d("Çevrimiçi 5 saat 5 dakika"), 5 * 3600 + 5 * 60)
    }

    func testSingleUnits() {
        XCTAssertEqual(d("5 saat"), 5 * 3600)
        XCTAssertEqual(d("45 dk"), 45 * 60)
        XCTAssertEqual(d("02:15 saat"), 2 * 3600 + 15 * 60)
    }

    /// Review Focus 3: saat gibi gorunen degerler sure degildir.
    func testNotDurations() {
        XCTAssertNil(d("12:30"))
        XCTAssertNil(d("3 paket"))
        XCTAssertNil(d("Toplam 500 TL"))
        XCTAssertNil(d("23 sa 75 dk"))   // gecersiz dakika
        XCTAssertNil(d("400 saat"))      // haftalik ustu (> 168 sa) gercekci degil
    }

    func testDateRange() {
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("4 Şub - 10 Şub")))
        XCTAssertTrue(TextPatterns.containsDateRange(TextNormalizer.normalize("28 Eylül – 4 Ekim")))
        XCTAssertFalse(TextPatterns.containsDateRange(TextNormalizer.normalize("4 Şubat")))
        XCTAssertFalse(TextPatterns.containsDateRange("10 - 20 paket"))
    }

    func testStrippingReferenceNumbers() {
        XCTAssertEqual(TextPatterns.strippingReferenceNumbers("tasima ucreti #1420").trimmingCharacters(in: .whitespaces), "tasima ucreti")
        XCTAssertEqual(TextPatterns.strippingReferenceNumbers("siparis №78347 bugun"), "siparis   bugun")
        XCTAssertEqual(TextPatterns.strippingReferenceNumbers("siparis no 123").trimmingCharacters(in: .whitespaces), "siparis")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DurationPatternTests`
Expected: FAIL (fonksiyonlar yok)

- [ ] **Step 3: Implement**

`TextPatterns` enum'una ekle:

```swift
    // MARK: - Sure (1.4a)

    private static let hourMinuteRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,3})\s*(?:saat|sa|h)\.?\s*(\d{1,2})\s*(?:dakika|dk|min|m)(?!\p{L})"#
    )
    private static let clockHoursRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,3}):(\d{2})\s*(?:saat|sa|h)(?!\p{L})"#
    )
    private static let hoursOnlyRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,3})\s*(?:saat|sa|h)(?!\p{L})"#
    )
    private static let minutesOnlyRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,4})\s*(?:dakika|dk|min)(?!\p{L})"#
    )
    /// Bir haftadan uzun sure gercekci degil (OCR hatasi).
    private static let maxDurationHours = 168

    /// "23 sa 32 dk", "23h 32m", "5 saat", "45 dk", "02:15 saat". Tek basina "12:30" sure DEGILDIR.
    static func duration(in line: String) -> TimeInterval? {
        let range = NSRange(line.startIndex..., in: line)
        func value(_ match: NSTextCheckingResult, _ group: Int) -> Int? {
            guard let r = Range(match.range(at: group), in: line) else { return nil }
            return Int(line[r])
        }
        func make(hours: Int, minutes: Int) -> TimeInterval? {
            guard minutes < 60, hours <= maxDurationHours, hours + minutes > 0 else { return nil }
            return TimeInterval(hours * 3600 + minutes * 60)
        }
        if let m = hourMinuteRegex.firstMatch(in: line, range: range),
           let h = value(m, 1), let min = value(m, 2) {
            return make(hours: h, minutes: min)
        }
        if let m = clockHoursRegex.firstMatch(in: line, range: range),
           let h = value(m, 1), let min = value(m, 2) {
            return make(hours: h, minutes: min)
        }
        if let m = hoursOnlyRegex.firstMatch(in: line, range: range), let h = value(m, 1) {
            return make(hours: h, minutes: 0)
        }
        if let m = minutesOnlyRegex.firstMatch(in: line, range: range), let min = value(m, 1) {
            return min < 24 * 60 ? TimeInterval(min * 60) : nil
        }
        return nil
    }

    // MARK: - Tarih araligi (haftalik ozet)

    private static let dateRangeRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)\d{1,2}\s*(?:oca|sub|mar|nis|may|haz|tem|agu|eyl|eki|kas|ara)\p{L}*\s*[-–]\s*\d{1,2}\s*(?:oca|sub|mar|nis|may|haz|tem|agu|eyl|eki|kas|ara)\p{L}*"#
    )

    /// "4 sub - 10 sub" gibi gun-ay araligi (normalize metin).
    static func containsDateRange(_ text: String) -> Bool {
        dateRangeRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: - Referans numaralari

    private static let referenceRegex = try! NSRegularExpression(pattern: #"(?:#|№|\bno\s*)\d+"#)

    /// "#1420", "№78347", "no 123" gibi is/siparis numaralarini cikarir ki tutar sanilmasin.
    static func strippingReferenceNumbers(_ line: String) -> String {
        let range = NSRange(line.startIndex..., in: line)
        return referenceRegex.stringByReplacingMatches(in: line, range: range, withTemplate: " ")
    }
```

Not: `testStrippingReferenceNumbers`'daki ikinci beklenti "siparis   bugun" (üç boşluk: önceki boşluk + yer tutucu + sonraki boşluk). Uygulama farklı boşluk üretirse testi `split(separator: " ")` karşılaştırmasına çevir, davranışı değil.

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: tümü PASS

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/OCR/TextPatterns.swift KuryeKazancTests/Core/DurationPatternTests.swift
git commit -m "feat(core): calisma suresi, tarih araligi ve referans numarasi kaliplari"
```

---

### Task 3: Şablon seçimi (ad → parmak izi) ve haftalık aralık

**Files:**
- Modify: `KuryeKazanc/Core/OCR/EarningsScreenshotParser.swift` (`detectTemplate`)
- Modify: `KuryeKazanc/Core/OCR/OCRTemplate.swift` (`period(in:)`)
- Test: `KuryeKazancTests/Core/TemplateSelectionTests.swift` (yeni)

**Interfaces:**
- Consumes: Görev 1 alanları; Görev 2 `containsDateRange`.
- Produces: `EarningsScreenshotParser.detectTemplate(in: [String]) -> OCRTemplate?` kuralları: (1) ad eşleşmesi, eşitlikte parmak izi sayısı; (2) ad yoksa yalnızca `minFingerprintMatches >= 3` şablonlar, `fingerprintMatches >= minFingerprintMatches`, en çok eşleşen, eşitlikte `fingerprint.count` büyük olan. `OCRTemplate.fingerprintOnlyThreshold = 3`. `period(in:)` tarih aralığında `.week` döner.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class TemplateSelectionTests: XCTestCase {
    private func template(id: String, keywords: [String], fingerprint: [String], min: Int) -> OCRTemplate {
        OCRTemplate(
            id: id, version: 1, status: .calibrating, platformCode: id,
            detectionKeywords: keywords, fingerprint: fingerprint, minFingerprintMatches: min,
            totalLabels: ["toplam"], bonusLabels: [], packageLabels: [], totalIncludesBonus: true,
            minPackageFee: nil, maxPackageFee: nil, dayLabels: [], weekLabels: []
        )
    }

    private func normalized(_ lines: [String]) -> [String] { lines.map(TextNormalizer.normalize) }

    func testFingerprintOnly_selectsWhenThresholdMet() {
        let uber = template(id: "uber", keywords: [], fingerprint: ["kazanclar", "cevrimici", "teslimat", "bakiye"], min: 3)
        let parser = EarningsScreenshotParser(templates: [uber])
        XCTAssertEqual(parser.detectTemplate(in: normalized(["Kazançlar", "Çevrimiçi 5 sa", "54 Teslimat"]))?.id, "uber")
        XCTAssertNil(parser.detectTemplate(in: normalized(["Kazançlar", "Çevrimiçi 5 sa"])))
    }

    func testFingerprintOnly_ignoresLowThresholdTemplates() {
        let loose = template(id: "loose", keywords: [], fingerprint: ["toplam", "kazanc"], min: 2)
        let parser = EarningsScreenshotParser(templates: [loose])
        XCTAssertNil(parser.detectTemplate(in: normalized(["Toplam", "Kazanç"])))
    }

    /// Review Focus 5: ad eslesmesi her zaman parmak izinden once gelir.
    func testNameMatchBeatsStrongerFingerprint() {
        let getir = template(id: "getir", keywords: ["getir"], fingerprint: ["kazanclarim"], min: 1)
        let other = template(id: "other", keywords: [], fingerprint: ["kazanclarim", "toplam kazanc", "siparis sayisi"], min: 3)
        let parser = EarningsScreenshotParser(templates: [other, getir])
        let lines = normalized(["Getir", "Kazançlarım", "Toplam Kazanç", "Sipariş Sayısı"])
        XCTAssertEqual(parser.detectTemplate(in: lines)?.id, "getir")
    }

    func testSameKeyword_tieBrokenByFingerprint() {
        let summary = template(id: "ys.earnings", keywords: ["yemeksepeti"], fingerprint: ["odemeler", "toplam kazanc"], min: 2)
        let order = template(id: "ys.order", keywords: ["yemeksepeti"], fingerprint: ["kabul et", "reddet", "ek dahil"], min: 3)
        let parser = EarningsScreenshotParser(templates: [summary, order])
        XCTAssertEqual(parser.detectTemplate(in: normalized(["Yemeksepeti", "Kabul et", "Reddet", "₺37 ek dahil"]))?.id, "ys.order")
        XCTAssertEqual(parser.detectTemplate(in: normalized(["Yemeksepeti", "Ödemeler", "Toplam Kazanç"]))?.id, "ys.earnings")
    }

    func testDateRangeMeansWeek() {
        let t = template(id: "u", keywords: [], fingerprint: [], min: 0)
        XCTAssertEqual(t.period(in: TextNormalizer.normalize("Kazançlar 4 Şub - 10 Şub")), .week)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TemplateSelectionTests`
Expected: FAIL (`testFingerprintOnly_selectsWhenThresholdMet`, `testSameKeyword_tieBrokenByFingerprint`, `testDateRangeMeansWeek`)

- [ ] **Step 3: Implement**

`OCRTemplate` içine sabit ve `period` değişikliği:

```swift
    /// Platform adi yoksa yalnizca bu kadar ya da daha cok parmak izi isteyen sablonlar secilebilir.
    static let fingerprintOnlyThreshold = 3

    /// Haftalik ifade gunluk ifadeden onceliklidir ("Bugun" haftalik ekranda da gorunebilir).
    /// "4 sub - 10 sub" gibi tarih araligi da haftalik sayilir.
    func period(in normalizedText: String) -> Period {
        if weekLabels.contains(where: { TextPatterns.containsWord($0, in: normalizedText) }) { return .week }
        if TextPatterns.containsDateRange(normalizedText) { return .week }
        if dayLabels.contains(where: { TextPatterns.containsWord($0, in: normalizedText) }) { return .day }
        return .unknown
    }
```

`EarningsScreenshotParser.detectTemplate` yerine:

```swift
    /// 1) Platform adi (esitlikte parmak izi), 2) ad yoksa guclu parmak izi, 3) nil (generic).
    func detectTemplate(in lines: [String]) -> OCRTemplate? {
        let text = lines.joined(separator: " ")
        var best: (template: OCRTemplate, score: Int, fingerprint: Int)?
        for template in templates {
            let score = template.detectionKeywords.reduce(0) { count, keyword in
                count + (TextPatterns.containsWord(keyword, in: text) ? 1 : 0)
            }
            guard score > 0 else { continue }
            let fingerprint = template.fingerprintMatches(in: text)
            if let current = best, (score, fingerprint) <= (current.score, current.fingerprint) { continue }
            best = (template, score, fingerprint)
        }
        if let best { return best.template }

        var byFingerprint: (template: OCRTemplate, matches: Int)?
        for template in templates where template.minFingerprintMatches >= OCRTemplate.fingerprintOnlyThreshold {
            let matches = template.fingerprintMatches(in: text)
            guard matches >= template.minFingerprintMatches else { continue }
            if let current = byFingerprint {
                if matches < current.matches { continue }
                if matches == current.matches, template.fingerprint.count <= current.template.fingerprint.count { continue }
            }
            byFingerprint = (template, matches)
        }
        return byFingerprint?.template
    }
```

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: tümü PASS (mevcut çözümleyici testleri dahil; mevcut şablonların `minFingerprintMatches` değeri 2 olduğundan parmak izi yolu onları etkilemez)

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/OCR/EarningsScreenshotParser.swift KuryeKazanc/Core/OCR/OCRTemplate.swift KuryeKazancTests/Core/TemplateSelectionTests.swift
git commit -m "feat(core): ad yoksa parmak iziyle sablon secimi; tarih araligi haftalik"
```

---

### Task 4: Ekran tipine göre çözümleme ve süre

**Files:**
- Modify: `KuryeKazanc/Core/OCR/EarningsScreenshotParser.swift`
- Test: `KuryeKazancTests/Core/LayoutParsingTests.swift` (yeni)

**Interfaces:**
- Consumes: Görev 1–3.
- Produces: `ParsedEarning` yeni alanlar (son üç, varsayılanlı): `workDuration: TimeInterval? = nil`, `layout: OCRTemplate.Layout = .summary`, `amountsExcludeVAT: Bool = false`. Kurallar:
  - `summary`: mevcut akış + süre.
  - `list`: `rowLabels` satırlarındaki **para birimli** tutarlar toplanır (referans numaraları önce silinir; komşu satıra bakılırsa yalnızca para birimi işareti olan ve ≥4 harf içermeyen satır); paket = satır sayısı; bonus = 0 ve **kontrol işareti yok**; ekranda `totalLabels` ile bir toplam varsa ve satır toplamından %1'den fazla farklıysa `.totalEarning` kontrol; hiç satır yoksa summary gibi en büyük tutar + kontrol.
  - `orderCard`: toplam = `totalLabels` ile, yoksa para birimli en büyük tutar (bulunursa kontrol işareti yok); bonus = `bonusLabels` içeren satırdaki ilk tutar, yoksa 0 (kontrol yok); paket = 1 (kontrol yok); `period = .order`.
  - Süre: `durationLabels` içeren satırda etiketten sonra, yoksa komşu satırlar (+1, -1, +2); etiket yoksa ya da bulunamazsa `nil` (kontrol alanı değil).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class LayoutParsingTests: XCTestCase {
    private func template(_ layout: OCRTemplate.Layout, total: [String] = ["toplam"], bonus: [String] = [],
                          rows: [String] = [], duration: [String] = []) -> OCRTemplate {
        OCRTemplate(
            id: "t.\(layout.rawValue)", version: 1, status: .calibrating, platformCode: "t",
            detectionKeywords: ["testapp"], fingerprint: [], minFingerprintMatches: 0,
            totalLabels: total, bonusLabels: bonus, packageLabels: ["teslimat"], totalIncludesBonus: true,
            minPackageFee: nil, maxPackageFee: nil, dayLabels: ["bugun"], weekLabels: ["bu hafta"],
            layout: layout, durationLabels: duration, rowLabels: rows, amountsExcludeVAT: layout == .orderCard
        )
    }

    private func parse(_ t: OCRTemplate, _ lines: [String]) -> ParsedEarning {
        EarningsScreenshotParser(templates: [t]).parse(lines: lines)
    }

    func testList_sumsRowsAndCountsThem() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Faturalar 3",
                          "Taşıma Ücreti 303,3₺", "#1420",
                          "Taşıma Ücreti 900₺", "#903",
                          "Taşıma Ücreti 56₺", "#314"])
        XCTAssertEqual(r.totalEarning, 1259.3, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 3)
        XCTAssertEqual(r.bonus, 0)
        XCTAssertEqual(r.layout, .list)
        XCTAssertFalse(r.fieldsToReview.contains(.totalEarning))
        XCTAssertFalse(r.fieldsToReview.contains(.bonus))
        XCTAssertFalse(r.fieldsToReview.contains(.packageCount))
    }

    /// Review Focus 2: tutar alt satirdaysa bile is numarasi tutar sayilmaz.
    func testList_valueOnNextLine_ignoresReferenceNumbers() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Taşıma Ücreti", "#1420", "303,3 ₺", "Taşıma Ücreti", "#903", "70 ₺"])
        XCTAssertEqual(r.totalEarning, 373.3, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 2)
    }

    func testList_shownTotalMismatch_flagsTotal() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Taşıma Ücreti 100₺", "Taşıma Ücreti 100₺", "Toplam 500₺"])
        XCTAssertEqual(r.totalEarning, 200, accuracy: 0.001)
        XCTAssertTrue(r.fieldsToReview.contains(.totalEarning))
    }

    func testList_noRows_fallsBackWithReview() {
        let t = template(.list, rows: ["tasima ucreti"])
        let r = parse(t, ["TestApp", "Toplam 450₺"])
        XCTAssertEqual(r.totalEarning, 450, accuracy: 0.001)
        XCTAssertTrue(r.fieldsToReview.contains(.totalEarning))
    }

    func testOrderCard_largestCurrencyAmountAndExtra() {
        let t = template(.orderCard, total: [], bonus: ["dahil", "includes"])
        let r = parse(t, ["TestApp", "Kabul oranı %89", "₺147,50", "₺37,00 ek dahil", "Teslim al 1,6 km - 12 dk", "Kabul et"])
        XCTAssertEqual(r.totalEarning, 147.5, accuracy: 0.001)
        XCTAssertEqual(r.bonus, 37, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 1)
        XCTAssertEqual(r.period, .order)
        XCTAssertTrue(r.amountsExcludeVAT)
        XCTAssertFalse(r.fieldsToReview.contains(.totalEarning))
        XCTAssertFalse(r.fieldsToReview.contains(.packageCount))
        XCTAssertFalse(r.fieldsToReview.contains(.bonus))
    }

    func testOrderCard_labelledAmountWithoutCurrency() {
        let t = template(.orderCard, total: ["nakit kazanc"])
        let r = parse(t, ["TestApp", "Sipariş №78347 Bugün", "Nakit kazanç", "430", "Gönderi Notu"])
        XCTAssertEqual(r.totalEarning, 430, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 1)
    }

    func testSummary_readsDurationNextToLabel() {
        let t = template(.summary, total: ["kazanclar"], duration: ["cevrimici", "online"])
        let r = parse(t, ["TestApp", "Kazançlar", "₺6.459,90", "Çevrimiçi 23 sa 32 dk", "54 Teslimat"])
        XCTAssertEqual(r.totalEarning, 6459.9, accuracy: 0.001)
        XCTAssertEqual(r.workDuration, 23 * 3600 + 32 * 60)
        XCTAssertEqual(r.packageCount, 54)

        let split = parse(t, ["TestApp", "Online", "23h 32m"])
        XCTAssertEqual(split.workDuration, 23 * 3600 + 32 * 60)
    }

    func testDuration_absentIsNilNotReviewed() {
        let t = template(.summary, duration: ["cevrimici"])
        let r = parse(t, ["TestApp", "Toplam 500₺"])
        XCTAssertNil(r.workDuration)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LayoutParsingTests`
Expected: FAIL (derleme: `workDuration`, `layout` alanları yok)

- [ ] **Step 3: Implement**

`ParsedEarning`'e (struct sonuna, `period`'dan sonra) ekle:

```swift
    /// Ekrandaki calisma suresi (or. "Cevrimici 23 sa 32 dk"); okunamazsa nil. Kontrol alani degildir.
    var workDuration: TimeInterval? = nil
    var layout: OCRTemplate.Layout = .summary
    /// Sablona gore ekrandaki tutarlar KDV haric (bilgi).
    var amountsExcludeVAT: Bool = false
```

`parse(lines:referenceDate:)` gövdesinde "2) Toplam kazanc"tan "4) Paket"e kadar olan bölümü şu dallanmayla değiştir, kalan tarih kısmı aynı kalır:

```swift
        // 2-4) Toplam, bonus, adet: ekran tipine gore
        var total: Double?
        var bonus: Double
        var packages: Int
        switch template.layout {
        case .summary:
            let excludedForTotal = template.bonusLabels + template.packageLabels
            total = findAmount(labels: template.totalLabels, excluding: excludedForTotal, in: normalized)
            if total == nil {
                total = largestAmount(in: normalized)
                review.insert(.totalEarning)
            }
            if let found = findAmount(labels: template.bonusLabels, excluding: [], in: normalized) {
                bonus = found
            } else {
                bonus = 0
                review.insert(.bonus)
            }
            if let found = findCount(labels: template.packageLabels, in: normalized) {
                packages = found
            } else {
                packages = 0
                review.insert(.packageCount)
            }
        case .list:
            let rows = listRowAmounts(labels: template.rowLabels, in: normalized)
            bonus = 0
            if rows.isEmpty {
                total = findAmount(labels: template.totalLabels, excluding: [], in: normalized) ?? largestAmount(in: normalized)
                packages = 0
                review.formUnion([.totalEarning, .packageCount])
            } else {
                let sum = rows.reduce(0, +)
                total = sum
                packages = rows.count
                if let shown = findAmount(labels: template.totalLabels, excluding: template.rowLabels, in: normalized),
                   abs(shown - sum) > max(shown, 1) * 0.01 {
                    review.insert(.totalEarning)
                }
            }
        case .orderCard:
            total = findAmount(labels: template.totalLabels, excluding: template.bonusLabels, in: normalized)
                ?? largestCurrencyAmount(in: normalized)
            if total == nil { review.insert(.totalEarning) }
            bonus = firstAmountInLine(containing: template.bonusLabels, in: normalized) ?? 0
            packages = 1
        }
```

Dönüş ifadesinde `bonus: bonus!` → `bonus: bonus`, `packageCount: packages!` → `packageCount: packages`; `period:` satırını ve yeni alanları şöyle yaz:

```swift
            period: template.layout == .orderCard ? .order : template.period(in: fullText),
            workDuration: findDuration(labels: template.durationLabels, in: normalized),
            layout: template.layout,
            amountsExcludeVAT: template.amountsExcludeVAT
```

Yeni yardımcılar (struct içinde, `// MARK: - Tutar` altında):

```swift
    /// Para birimi isaretli tutarlarin en buyugu (siparis karti: km/dk/yuzde sayilmaz).
    func largestCurrencyAmount(in lines: [String]) -> Double? {
        lines.filter(TextPatterns.hasCurrencyMarker).flatMap(TextPatterns.allAmounts).max()
    }

    func firstAmountInLine(containing labels: [String], in lines: [String]) -> Double? {
        for label in labels {
            if let line = lines.first(where: { TextPatterns.containsWord(label, in: $0) }),
               let value = TextPatterns.firstAmount(in: line) {
                return value
            }
        }
        return nil
    }

    /// Liste ekrani: her etiket satirinin para birimli tutari (Review Focus 2: is numaralari tutar degildir).
    func listRowAmounts(labels: [String], in lines: [String]) -> [Double] {
        let cleaned = lines.map(TextPatterns.strippingReferenceNumbers)
        var amounts: [Double] = []
        for (index, line) in cleaned.enumerated() {
            guard let label = labels.first(where: { line.contains($0) }), let range = line.range(of: label) else { continue }
            let rest = String(line[range.upperBound...])
            if TextPatterns.hasCurrencyMarker(rest), let value = TextPatterns.firstAmount(in: rest) {
                amounts.append(value)
                continue
            }
            for offset in [1, 2, -1] {
                let neighbor = index + offset
                guard cleaned.indices.contains(neighbor) else { continue }
                let candidate = cleaned[neighbor]
                if labels.contains(where: { candidate.contains($0) }) { break }
                guard TextPatterns.hasCurrencyMarker(candidate),
                      !TextPatterns.containsLetters(candidate, minimum: 4),
                      let value = TextPatterns.firstAmount(in: candidate) else { continue }
                amounts.append(value)
                break
            }
        }
        return amounts
    }

    // MARK: - Sure

    func findDuration(labels: [String], in lines: [String]) -> TimeInterval? {
        for label in labels {
            for (index, line) in lines.enumerated() where TextPatterns.containsWord(label, in: line) {
                if let range = line.range(of: label),
                   let value = TextPatterns.duration(in: String(line[range.upperBound...])) {
                    return value
                }
                for offset in [1, -1, 2] {
                    let neighbor = index + offset
                    guard lines.indices.contains(neighbor) else { continue }
                    if let value = TextPatterns.duration(in: lines[neighbor]) { return value }
                }
            }
        }
        return nil
    }
```

Not: `testList_valueOnNextLine_ignoresReferenceNumbers`'da "#1420" satırı referans silinince boşalır; para birimi olmadığı için atlanır ve +2 komşu ("303,3 ₺") alınır. Bir sonraki etiket satırına gelinirse arama durur (başka satırın tutarı çalınmaz).

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: tümü PASS (mevcut `EarningsScreenshotParserTests` dahil — summary akışı aynı)

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/OCR/EarningsScreenshotParser.swift KuryeKazancTests/Core/LayoutParsingTests.swift
git commit -m "feat(core): liste ve siparis karti ekranlari, calisma suresi okuma"
```

---

### Task 5: Yeni şablonlar

**Files:**
- Modify: `KuryeKazanc/Core/OCR/BundledTemplates.swift` (JSON)
- Modify: `KuryeKazancTests/Core/OCRTemplateTests.swift` (`testBundledTemplatesDecodeAndCoverMainPlatforms`)
- Test: `KuryeKazancTests/Core/NewTemplatesTests.swift` (yeni)

**Interfaces:**
- Consumes: Görev 1–4.
- Produces: şablon kimlikleri `uber.earnings` (platformCode `uber`), `thekurye.invoices` (`thekurye`), `yemeksepeti.order` (`yemeksepeti`), `banabikurye.order` (`banabikurye`); `yemeksepeti.earnings` v2. `uber`, `thekurye`, `banabikurye` uygulamanın `Platform.defaults` listesinde yok → formda platform kontrol işareti alır (bilerek; platform listesi bu planın kapsamı dışında).

- [ ] **Step 1: Write the failing test**

`NewTemplatesTests.swift`:

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Satirlar App Store magaza gorsellerindeki duzenden turetildi (spec §2); gercek ekranla kalibre edilmedi.
final class NewTemplatesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var reference: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14))! }
    private func parse(_ lines: [String]) -> ParsedEarning {
        EarningsScreenshotParser(calendar: calendar).parse(lines: lines, referenceDate: reference)
    }

    func testUberEarnings_turkish() {
        let r = parse(["9:41", "Kazançlar", "4 Şub - 10 Şub", "₺6.459,90", "Çevrimiçi 23 sa 32 dk",
                       "54 Teslimat", "73 Puan", "Ayrıntıları gör", "Bakiye: ₺1.550,00", "Sonraki ödeme 11 Şub"])
        XCTAssertEqual(r.templateID, "uber.earnings")
        XCTAssertEqual(r.platformCode, "uber")
        XCTAssertEqual(r.totalEarning, 6459.9, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 54)
        XCTAssertEqual(r.workDuration, 23 * 3600 + 32 * 60)
        XCTAssertEqual(r.period, .week)
    }

    func testUberEarnings_english() {
        let r = parse(["Earnings", "Feb 4 - Feb 10", "£645.99", "Online 23h 32m", "54 Trips", "73 Points",
                       "See details", "Balance: £155.00"])
        XCTAssertEqual(r.templateID, "uber.earnings")
        XCTAssertEqual(r.packageCount, 54)
        XCTAssertEqual(r.workDuration, 23 * 3600 + 32 * 60)
    }

    func testTheKuryeInvoices() {
        let r = parse(["The Kurye", "Faturalar 3", "Taşıma Ücreti 303.3₺", "#1420", "Taşıma Ücreti 900₺", "#903",
                       "Taşıma Ücreti 56₺", "#314", "Tümünü Seç", "Fatura Oluştur"])
        XCTAssertEqual(r.templateID, "thekurye.invoices")
        XCTAssertEqual(r.totalEarning, 1259.3, accuracy: 0.001)
        XCTAssertEqual(r.packageCount, 3)
    }

    func testYemeksepetiOrderCard() {
        let r = parse(["Kabul oranı %89", "Reddet", "₺147,50", "₺37,00 ek dahil", "Teslim al 1,6 km - 12 dk", "Kabul et"])
        XCTAssertEqual(r.templateID, "yemeksepeti.order")
        XCTAssertEqual(r.totalEarning, 147.5, accuracy: 0.001)
        XCTAssertEqual(r.bonus, 37, accuracy: 0.001)
        XCTAssertEqual(r.period, .order)
        XCTAssertTrue(r.amountsExcludeVAT)
    }

    func testBanabikuryeOrderCard() {
        let r = parse(["Sipariş №78347 Bugün", "Tanım Tarif Chat Ödeme", "Nakit kazanç", "430", "Gönderi Notu"])
        XCTAssertEqual(r.templateID, "banabikurye.order")
        XCTAssertEqual(r.totalEarning, 430, accuracy: 0.001)
        XCTAssertEqual(r.period, .order)
    }

    func testYemeksepetiSummary_isVATExclusiveV2() {
        let t = BundledTemplates.template(id: "yemeksepeti.earnings")!
        XCTAssertEqual(t.version, 2)
        XCTAssertTrue(t.amountsExcludeVAT)
    }

    /// Mevcut Getir ekrani yeni parmak izi sablonlarina dusmemeli.
    func testExistingGetirScreenUnaffected() {
        let r = parse(["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"])
        XCTAssertEqual(r.templateID, "getir.earnings")
        XCTAssertEqual(r.period, .day)
    }
}
```

`OCRTemplateTests.testBundledTemplatesDecodeAndCoverMainPlatforms` içindeki küme beklentisini değiştir:

```swift
        XCTAssertEqual(codes, ["trendyol_go", "getir", "yemeksepeti", "migros_hemen", "uber", "thekurye", "banabikurye"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter "NewTemplatesTests|OCRTemplateTests"`
Expected: FAIL (şablonlar yok)

- [ ] **Step 3: Implement**

`BundledTemplates.json` içinde `yemeksepeti.earnings` nesnesinde `"version": 1` → `"version": 2` yap ve sonuna `, "amountsExcludeVAT": true` ekle. Dizinin sonuna (migros nesnesinden sonra, virgülle) ekle:

```json
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
```

Not (testUberEarnings_english): "£645.99" para birimi işareti TL değil; `kazanclar/earnings` etiketinden sonraki komşu satır "Feb 4 - Feb 10" ≥4 harf içerdiğinden atlanır, +2 satır "£645.99" tutarı verir. Test bu yüzden toplamı doğrulamaz, yalnızca şablon/adet/süre.

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: tümü PASS. Bir senaryo beklenenden farklı okunursa önce çözümleyici kuralını (Görev 4) değil şablon etiketlerini düzelt; etiket düzeltmesi yetmiyorsa nedenini commit mesajına yaz.

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/OCR/BundledTemplates.swift KuryeKazancTests/Core/NewTemplatesTests.swift KuryeKazancTests/Core/OCRTemplateTests.swift
git commit -m "feat(core): Uber kazanclar, TheKurye faturalar, Yemeksepeti/Banabikurye siparis karti sablonlari"
```

---

### Task 6: Uygulama tarafı — doğrulama, gönderim, form

**Files:**
- Modify: `KuryeKazanc/Core/Verification/ScreenshotVerifier.swift:65-68`
- Modify: `KuryeKazanc/Services/Sync/SyncCoordinator.swift:98`
- Modify: `KuryeKazanc/ViewModels/EarningFormViewModel.swift` (`apply(_ imported:)`, `apply(_ parsed:)`, yeni `amountNote`)
- Modify: `KuryeKazanc/Views/Earnings/EarningFormView.swift` (`.finished` dalı)
- Test: `KuryeKazancTests/Core/ScreenshotVerifierTests.swift`, `KuryeKazancTests/SyncCoordinatorTests.swift`, `KuryeKazancTests/FormViewModelTests.swift`

**Interfaces:**
- Consumes: `ParsedEarning.workDuration`, `.period == .order`, `.amountsExcludeVAT`.
- Produces: `ScreenshotVerifier` sipariş kartı için `isDailyScreen == false` ve issue `"Tek sipariş ekranı: günlük kazanç ekranını kullan."`; `EarningFormViewModel.amountNote: String?`; form, süre varsa ve dönem `.week` değilse ve süre ≤ 16 saatse `startTime = endTime - süre` yapar ve `.hours`'u kontrol listesine eklemez.

- [ ] **Step 1: Write the failing tests**

`ScreenshotVerifierTests` sonuna:

```swift
    func testOrderCard_isNotDailyScreen() {
        let result = verifier.assess(parsed(period: .order), template: activeTemplate(), isGenuine: true, referenceDate: now)
        XCTAssertEqual(result.candidate, .ocrUnverified)
        XCTAssertFalse(result.isDailyScreen)
        XCTAssertTrue(result.issues.contains { $0.contains("Tek sipariş") })
    }
```

`SyncCoordinatorTests.testWeeklyEvidence_notQueued` altına:

```swift
    func testOrderEvidence_notQueued() async {
        setConsents(sharing: true, calibration: false)
        let sync = makeCoordinator(client: fake)
        let record = makeRecord(level: .ocrUnverified)
        record.evidence?.periodRaw = OCRTemplate.Period.order.rawValue

        sync.recordSaved(record, vehicle: "motorcycle")
        await sync.flush()

        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertTrue(fake.submittedShifts.isEmpty)
    }
```

`FormViewModelTests` (MARK: - Kazanc formu altında):

```swift
    func testApplyOCR_dailyDurationSetsHoursWithoutReview() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.endTime = at(6, 17)
        var parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(6, 0)), packageCount: 12,
            totalEarning: 1000, bonus: 0, totalIncludesBonus: true, fieldsToReview: []
        )
        parsed.period = .day
        parsed.workDuration = 6 * 3600 + 30 * 60
        vm.apply(parsed, platforms: platforms)

        XCTAssertEqual(vm.resolvedInterval().start, at(6, 10, 30))
        XCTAssertEqual(vm.resolvedInterval().end, at(6, 17))
        XCTAssertFalse(vm.fieldsToReview.contains(.hours))
    }

    /// Review Focus 4: haftalik sure tek vardiya saatine yazilmaz.
    func testApplyOCR_weeklyDurationIgnored() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.startTime = at(6, 10)
        vm.endTime = at(6, 16)
        var parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(6, 0)), packageCount: 54,
            totalEarning: 6000, bonus: 0, totalIncludesBonus: true, fieldsToReview: []
        )
        parsed.period = .week
        parsed.workDuration = 23 * 3600 + 32 * 60
        vm.apply(parsed, platforms: platforms)

        XCTAssertEqual(vm.resolvedInterval().start, at(6, 10))
        XCTAssertTrue(vm.fieldsToReview.contains(.hours))
    }

    func testImportedOrderCard_forcesReviewAndVATNote() {
        var item = imported(period: .order)
        item.parsed.amountsExcludeVAT = true
        item.assessment.issues = ["Tek sipariş ekranı: günlük kazanç ekranını kullan."]
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: item, now: at(6, 18), calendar: calendar)
        XCTAssertTrue(vm.fieldsToReview.contains(.gross))
        XCTAssertTrue(vm.assessmentIssues.contains { $0.contains("Tek sipariş") })
        XCTAssertEqual(vm.amountNote, "Bu ekrandaki tutarlar KDV hariç gösteriliyor.")
    }
```

Not: `imported(period:)` yardımcısı `isDailyScreen: period != .week` kuruyor; `.order` için `false` olmalı — yardımcıdaki bu satırı `isDailyScreen: period == .day || period == .unknown` yap.

- [ ] **Step 2: Run tests to verify they fail**

Run (Windows, yalnızca Core): `swift test --filter ScreenshotVerifierTests`
Expected: FAIL `testOrderCard_isNotDailyScreen`. Uygulama testleri (Sync/Form) Windows'ta çalışmaz; CI'da doğrulanır (Step 4).

- [ ] **Step 3: Implement**

`ScreenshotVerifier.swift` (satır 65–68):

```swift
        let isDailyScreen = parsed.period == .day || parsed.period == .unknown
        if parsed.period == .week {
            issues.append("Haftalık ekran: vardiya için günlük kazanç ekranını kullan.")
        } else if parsed.period == .order {
            issues.append("Tek sipariş ekranı: günlük kazanç ekranını kullan.")
        }
```

`SyncCoordinator.shiftPayloadData` (satır 97–98):

```swift
        // Haftalik ozet ve tek siparis karti vardiya degildir: gonderilmez (yalnizca gunluk / belirsiz donem).
        guard let evidence = record.evidence, evidence.period != .week, evidence.period != .order else { return nil }
```

`EarningFormViewModel.apply(_ imported:...)` içinde:

```swift
        if imported.parsed.period == .week || imported.parsed.period == .order {
            // Haftalik toplam / tek siparis tek vardiya gibi sessizce kaydedilmesin: "Kontrol ettim" onayi zorunlu
            fieldsToReview.formUnion([.gross, .date])
        }
```

`apply(_ parsed:...)` sonunda `review.insert(.hours)` satırını şununla değiştir:

```swift
        // Ekranda gunluk calisma suresi varsa vardiya saatini ondan kur; yoksa varsayilan saatler kontrol edilmeli.
        if let duration = parsed.workDuration, parsed.period != .week, duration <= Self.maxShiftDuration {
            startTime = endTime.addingTimeInterval(-duration)
        } else {
            review.insert(.hours)
        }
```

ve sınıfa:

```swift
    /// Tek vardiya icin en uzun sure; uzunu haftalik/hatali okuma sayilir.
    static let maxShiftDuration: TimeInterval = 16 * 3600

    /// Sablon tutarlarin KDV haric oldugunu soyluyorsa bilgi notu.
    var amountNote: String? {
        imported?.parsed.amountsExcludeVAT == true ? "Bu ekrandaki tutarlar KDV hariç gösteriliyor." : nil
    }
```

`EarningFormView.swift` `.finished` dalında `ForEach(viewModel.assessmentIssues ...)` bloğundan sonra:

```swift
                if let note = viewModel.amountNote {
                    Label(note, systemImage: "percent")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("earningForm.vatNote")
                }
```

Not: `endTime` ile `startTime` aynı güne `combine` ile taşındıktan sonra hesaplanır (mevcut `apply` sırası: tarih → tutarlar → kontrol alanları); süre satırını fonksiyonun **sonuna** koy ki `endTime` OCR tarihine taşınmış olsun. Gece yarısını geçen süre `resolvedInterval()` tarafından zaten yönetilir.

- [ ] **Step 4: Run tests**

Windows: `swift test` → PASS. Sonra push (Global Constraints: Görev 1–6 birlikte ilk kez):

```bash
git add -A KuryeKazanc KuryeKazancTests
git commit -m "feat: siparis karti gonderilmez ve vardiya sayilmaz, ekrandaki sure vardiya saatine, KDV notu"
git push origin develop
```

`gh run list --limit 1` → `gh run watch <id> --exit-status`. Expected: `iOS CI` yeşil (birim testleri: mevcut 234 + yeni). Kırmızıysa hatayı düzeltip yeni commit; push.

- [ ] **Step 5: Commit** — Step 4'te yapıldı.

---

### Task 7: Senaryo modeli, üreteç ve satır katmanı

**Files:**
- Create: `KuryeKazanc/Core/Scenarios/ScreenScenario.swift`
- Create: `KuryeKazanc/Core/Scenarios/ScenarioGenerator.swift`
- Test: `KuryeKazancTests/Core/ScenarioParserTests.swift`

**Interfaces:**
- Consumes: Görev 5 şablon kimlikleri.
- Produces:
  - `struct ScenarioRow: Equatable { var label: String; var value: String; var valueFirst: Bool = false; var splittable: Bool = true }`
  - `enum ScenarioField: String, CaseIterable, Codable { case template, total, bonus, packages, duration, period }`
  - `struct ScenarioExpectation: Equatable, Codable { var templateID: String?; var total: Double; var bonus: Double?; var packages: Int?; var duration: TimeInterval?; var period: OCRTemplate.Period?; func check(_ parsed: ParsedEarning) -> [ScenarioField: Bool] }` — `nil` beklenen alan kontrol edilmez (sözlükte yer almaz); tutarlar ±0,01.
  - `struct ScreenScenario: Equatable, Identifiable` alanları: `id: String`, `templateID: String`, `platformCode: String`, `header: [String]`, `rows: [ScenarioRow]`, `footer: [String]`, `theme: Theme`, `device: Device`, `textStyle: TextStyle`, `splitRows: Bool`, `noise: Bool`, `expected: ScenarioExpectation`; `func styled(_ text: String) -> String`; `func ocrLines() -> [String]`. `Theme { light, dark }`, `Device { se, standard, proMax; var points: (width: Double, height: Double) }` (375×667, 393×852, 430×932), `TextStyle { turkish, ascii, upper }`.
  - `struct ScenarioGenerator { var seed: UInt64 = 20261009; func all() -> [ScreenScenario] }` — en az 100 senaryo, kimlikler benzersiz, aynı tohumla aynı sonuç.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Katman A: senaryo -> OCR satirlari -> cozumleyici. Satir katmaninda OCR gurultusu yok: hepsi gecmeli.
final class ScenarioParserTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    func testGeneratorIsDeterministicAndLargeEnough() {
        let a = ScenarioGenerator().all()
        let b = ScenarioGenerator().all()
        XCTAssertEqual(a, b)
        XCTAssertGreaterThanOrEqual(a.count, 100)
        XCTAssertEqual(Set(a.map(\.id)).count, a.count, "Senaryo kimlikleri benzersiz olmali")
        XCTAssertEqual(Set(a.map(\.templateID)).count, 8, "Her temel duzen en az bir kez")
    }

    func testStyles() {
        let s = ScenarioGenerator().all().first { $0.textStyle == .ascii }!
        XCTAssertEqual(s.styled("Toplam Kazanç Şık"), "Toplam Kazanc Sik")
        let u = ScenarioGenerator().all().first { $0.textStyle == .upper }!
        XCTAssertEqual(u.styled("Sipariş"), "SİPARİŞ")
    }

    func testAllScenariosParseAtLineLevel() {
        let parser = EarningsScreenshotParser(calendar: calendar)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14))!
        var failures: [String] = []
        for scenario in ScenarioGenerator().all() {
            let parsed = parser.parse(lines: scenario.ocrLines(), referenceDate: reference)
            for (field, ok) in scenario.expected.check(parsed) where !ok {
                failures.append("\(scenario.id) \(field.rawValue): satirlar=\(scenario.ocrLines())")
            }
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count) hata:\n" + failures.prefix(15).joined(separator: "\n"))
    }

    func testExpectationCheck() {
        let e = ScenarioExpectation(templateID: "getir.earnings", total: 980, bonus: nil, packages: 11, duration: nil, period: .day)
        let p = ParsedEarning(platformCode: "getir", date: .now, packageCount: 11, totalEarning: 980.004, bonus: 5,
                              totalIncludesBonus: true, fieldsToReview: [], templateID: "getir.earnings", period: .day)
        XCTAssertEqual(e.check(p), [.template: true, .total: true, .packages: true, .period: true])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ScenarioParserTests`
Expected: FAIL (tipler yok)

- [ ] **Step 3: Implement**

`KuryeKazanc/Core/Scenarios/ScreenScenario.swift`:

```swift
import Foundation

/// Senaryo testleri (spec 1.4a §4): taklit kazanc ekraninin tarifi ve beklenen okuma.
/// Ayni senaryo satir katmaninda (Core) ve goruntu katmaninda (SwiftUI + Vision) kullanilir.
struct ScenarioRow: Equatable {
    var label: String
    var value: String
    /// "54 Teslimat" gibi deger etiketten once.
    var valueFirst: Bool = false
    /// Cesitlemede etiket ve deger ayri satirlara bolunebilir mi?
    var splittable: Bool = true
}

enum ScenarioField: String, CaseIterable, Codable {
    case template, total, bonus, packages, duration, period
}

struct ScenarioExpectation: Equatable, Codable {
    var templateID: String?
    var total: Double
    var bonus: Double?
    var packages: Int?
    var duration: TimeInterval?
    var period: OCRTemplate.Period?

    /// Beklenen (nil olmayan) her alan icin dogru/yanlis.
    func check(_ parsed: ParsedEarning) -> [ScenarioField: Bool] {
        var result: [ScenarioField: Bool] = [:]
        result[.template] = parsed.templateID == templateID
        result[.total] = abs(parsed.totalEarning - total) < 0.01
        if let bonus { result[.bonus] = abs(parsed.bonus - bonus) < 0.01 }
        if let packages { result[.packages] = parsed.packageCount == packages }
        if let duration { result[.duration] = parsed.workDuration.map { abs($0 - duration) < 1 } ?? false }
        if let period { result[.period] = parsed.period == period }
        return result
    }
}

struct ScreenScenario: Equatable, Identifiable {
    enum Theme: String, CaseIterable { case light, dark }
    enum Device: String, CaseIterable {
        case se, standard, proMax
        var points: (width: Double, height: Double) {
            switch self {
            case .se: (375, 667)
            case .standard: (393, 852)
            case .proMax: (430, 932)
            }
        }
    }
    enum TextStyle: String, CaseIterable { case turkish, ascii, upper }

    var id: String
    var templateID: String
    var platformCode: String
    var header: [String]
    var rows: [ScenarioRow]
    var footer: [String]
    var theme: Theme
    var device: Device
    var textStyle: TextStyle
    var splitRows: Bool
    var noise: Bool
    var expected: ScenarioExpectation

    static func == (lhs: ScreenScenario, rhs: ScreenScenario) -> Bool {
        lhs.id == rhs.id && lhs.header == rhs.header && lhs.rows == rhs.rows && lhs.footer == rhs.footer
            && lhs.theme == rhs.theme && lhs.device == rhs.device && lhs.textStyle == rhs.textStyle
            && lhs.splitRows == rhs.splitRows && lhs.noise == rhs.noise && lhs.expected == rhs.expected
    }

    private static let asciiFold: [Character: Character] = [
        "ı": "i", "ğ": "g", "ü": "u", "ş": "s", "ö": "o", "ç": "c",
        "İ": "I", "Ğ": "G", "Ü": "U", "Ş": "S", "Ö": "O", "Ç": "C",
    ]

    func styled(_ text: String) -> String {
        switch textStyle {
        case .turkish: text
        case .ascii: String(text.map { Self.asciiFold[$0] ?? $0 })
        case .upper: text.uppercased(with: Locale(identifier: "tr_TR"))
        }
    }

    static let topNoise = ["9:41", "Menü"]
    static let bottomNoise = ["Ana Sayfa", "Profil"]

    /// Vision'in yukaridan asagi okuma sirasina benzer satirlar.
    func ocrLines() -> [String] {
        var lines: [String] = noise ? Self.topNoise : []
        lines += header.map(styled)
        for row in rows {
            let label = styled(row.label)
            if row.label.isEmpty {
                lines.append(row.value)
            } else if splitRows && row.splittable {
                lines += row.valueFirst ? [row.value, label] : [label, row.value]
            } else {
                lines.append(row.valueFirst ? "\(row.value) \(label)" : "\(label) \(row.value)")
            }
        }
        lines += footer.map(styled)
        if noise { lines += Self.bottomNoise }
        return lines
    }
}
```

`KuryeKazanc/Core/Scenarios/ScenarioGenerator.swift`:

```swift
import Foundation

/// Temel duzenler x cesitlemeler (spec 1.4a §4.1). Sabit tohum: her calistirmada ayni senaryolar.
struct ScenarioGenerator {
    var seed: UInt64 = 20261009

    /// SplitMix64: platformdan bagimsiz, tekrarlanabilir.
    private struct Random {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func int(_ range: ClosedRange<Int>) -> Int {
            range.lowerBound + Int(next() % UInt64(range.count))
        }
    }

    enum AmountFormat: CaseIterable { case trailing, leading, tl }

    static func format(_ value: Double, _ format: AmountFormat) -> String {
        let cents = Int((value * 100).rounded())
        let whole = cents / 100
        let fraction = cents % 100
        var digits = String(whole)
        var grouped = ""
        while digits.count > 3 {
            grouped = "." + String(digits.suffix(3)) + grouped
            digits = String(digits.dropLast(3))
        }
        let number = digits + grouped + "," + String(format: "%02d", fraction)
        switch format {
        case .trailing: return "\(number) ₺"
        case .leading: return "₺\(number)"
        case .tl: return "\(number) TL"
        }
    }

    private struct Base {
        var templateID: String
        var platformCode: String
        var make: (inout Random, AmountFormat) -> (header: [String], rows: [ScenarioRow], footer: [String], expected: ScenarioExpectation)
    }

    private var bases: [Base] {
        [
            Base(templateID: "trendyol_go.earnings", platformCode: "trendyol_go") { rng, f in
                let total = Double(rng.int(80_000...400_000)) / 100
                let bonus = Double(rng.int(0...20)) * 10
                let packages = rng.int(5...40)
                return (["Trendyol GO", "Kazançlarım", "Bugün"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Teslimat Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Bonus", value: Self.format(bonus, f))],
                        [], ScenarioExpectation(templateID: "trendyol_go.earnings", total: total, bonus: bonus,
                                                packages: packages, duration: nil, period: .day))
            },
            Base(templateID: "getir.earnings", platformCode: "getir") { rng, f in
                let total = Double(rng.int(60_000...350_000)) / 100
                let bonus = Double(rng.int(0...15)) * 10
                let packages = rng.int(5...35)
                return (["Getir", "Kazançlarım", "Bugün"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Sipariş Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Ek Kazanç", value: Self.format(bonus, f))],
                        [], ScenarioExpectation(templateID: "getir.earnings", total: total, bonus: bonus,
                                                packages: packages, duration: nil, period: .day))
            },
            Base(templateID: "yemeksepeti.earnings", platformCode: "yemeksepeti") { rng, f in
                let total = Double(rng.int(50_000...300_000)) / 100
                let tip = Double(rng.int(0...10)) * 10
                let packages = rng.int(5...30)
                return (["Yemeksepeti", "Ödemeler", "Bugün"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Sipariş Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Bahşiş", value: Self.format(tip, f))],
                        [], ScenarioExpectation(templateID: "yemeksepeti.earnings", total: total, bonus: tip,
                                                packages: packages, duration: nil, period: .day))
            },
            Base(templateID: "migros_hemen.earnings", platformCode: "migros_hemen") { rng, f in
                let total = Double(rng.int(300_000...1_500_000)) / 100
                let bonus = Double(rng.int(0...30)) * 10
                let packages = rng.int(30...150)
                return (["Migros Hemen", "Kazançlarım", "Bu Hafta"],
                        [ScenarioRow(label: "Toplam Kazanç", value: Self.format(total, f)),
                         ScenarioRow(label: "Teslimat Sayısı", value: "\(packages)"),
                         ScenarioRow(label: "Prim", value: Self.format(bonus, f))],
                        [], ScenarioExpectation(templateID: "migros_hemen.earnings", total: total, bonus: bonus,
                                                packages: packages, duration: nil, period: .week))
            },
            Base(templateID: "uber.earnings", platformCode: "uber") { rng, f in
                let total = Double(rng.int(300_000...1_500_000)) / 100
                let packages = rng.int(30...120)
                let hours = rng.int(10...60)
                let minutes = rng.int(0...59)
                return (["Kazançlar", "4 Şub - 10 Şub"],
                        [ScenarioRow(label: "", value: Self.format(total, f), splittable: false),
                         ScenarioRow(label: "Çevrimiçi", value: "\(hours) sa \(minutes) dk"),
                         ScenarioRow(label: "Teslimat", value: "\(packages)", valueFirst: true),
                         ScenarioRow(label: "Puan", value: "\(rng.int(10...99))", valueFirst: true, splittable: false)],
                        ["Ayrıntıları gör", "Bakiye: " + Self.format(Double(rng.int(1_000...50_000)) / 100, f)],
                        ScenarioExpectation(templateID: "uber.earnings", total: total, bonus: nil, packages: packages,
                                            duration: TimeInterval(hours * 3600 + minutes * 60), period: .week))
            },
            Base(templateID: "thekurye.invoices", platformCode: "thekurye") { rng, f in
                let count = rng.int(2...6)
                var rows: [ScenarioRow] = []
                var sum = 0.0
                for _ in 0..<count {
                    let fee = Double(rng.int(5_000...40_000)) / 100
                    sum += fee
                    rows.append(ScenarioRow(label: "Taşıma Ücreti", value: Self.format(fee, f), splittable: false))
                    rows.append(ScenarioRow(label: "", value: "#\(rng.int(100...9999))", splittable: false))
                }
                return (["The Kurye", "Faturalar \(count)"], rows, ["Tümünü Seç", "Fatura Oluştur"],
                        ScenarioExpectation(templateID: "thekurye.invoices", total: (sum * 100).rounded() / 100,
                                            bonus: nil, packages: count, duration: nil, period: nil))
            },
            Base(templateID: "yemeksepeti.order", platformCode: "yemeksepeti") { rng, f in
                let extra = Double(rng.int(0...6_000)) / 100
                let total = extra + Double(rng.int(4_000...20_000)) / 100
                return (["Kabul oranı %\(rng.int(60...99))", "Reddet"],
                        [ScenarioRow(label: "", value: Self.format(total, f), splittable: false),
                         ScenarioRow(label: "ek dahil", value: Self.format(extra, f), valueFirst: true, splittable: false)],
                        ["Teslim al 1,6 km - 12 dk", "Kabul et"],
                        ScenarioExpectation(templateID: "yemeksepeti.order", total: total, bonus: extra, packages: 1,
                                            duration: nil, period: .order))
            },
            Base(templateID: "banabikurye.order", platformCode: "banabikurye") { rng, _ in
                let total = Double(rng.int(50...900))
                return (["Sipariş №\(rng.int(10_000...99_999)) Bugün", "Tanım Tarif Chat Ödeme"],
                        [ScenarioRow(label: "Nakit kazanç", value: "\(Int(total))")],
                        ["Gönderi Notu"],
                        ScenarioExpectation(templateID: "banabikurye.order", total: total, bonus: nil, packages: 1,
                                            duration: nil, period: .order))
            },
        ]
    }

    func all() -> [ScreenScenario] {
        var rng = Random(state: seed)
        var result: [ScreenScenario] = []
        var index = 0
        for base in bases {
            for style in ScreenScenario.TextStyle.allCases {
                for split in [false, true] {
                    for format in AmountFormat.allCases {
                        let made = base.make(&rng, format)
                        let theme = ScreenScenario.Theme.allCases[index % 2]
                        let device = ScreenScenario.Device.allCases[index % 3]
                        result.append(ScreenScenario(
                            id: "\(base.templateID)-\(style.rawValue)-\(split ? "split" : "inline")-\(format)",
                            templateID: base.templateID, platformCode: base.platformCode,
                            header: made.header, rows: made.rows, footer: made.footer,
                            theme: theme, device: device, textStyle: style, splitRows: split,
                            noise: index % 2 == 0, expected: made.expected
                        ))
                        index += 1
                    }
                }
            }
        }
        return result
    }
}
```

8 temel × 3 yazım × 2 bölme × 3 biçim = 144 senaryo. `String(format:)` Foundation'dandır (Windows'ta çalışır).

- [ ] **Step 4: Run tests**

Run: `swift test --filter ScenarioParserTests`
Expected: PASS. `testAllScenariosParseAtLineLevel` başarısız olursa her hata satırı için karar ver:
  - Senaryo gerçekçi değilse (ör. etiket/ değer düzeni platformda olamaz) senaryoyu düzelt, `ScenarioGenerator`'da yorumla gerekçe yaz.
  - Gerçekçiyse çözümleyiciyi/şablonu düzelt ve bu durum için Görev 4/5 testlerine tek bir birim test ekle.
  Ardından `swift test` (tümü) PASS.

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/Scenarios KuryeKazancTests/Core/ScenarioParserTests.swift
git commit -m "test(core): senaryo modeli, tohumlu uretec ve satir katmani (144 senaryo)"
```

---

### Task 8: Görüntü katmanı, rapor ve taban

**Files:**
- Create: `KuryeKazanc/Core/Scenarios/ScenarioTally.swift`
- Create: `KuryeKazanc/Views/Tester/MockEarningsScreen.swift`
- Create: `KuryeKazancTests/ScenarioImageTests.swift`
- Create (Step 6): `KuryeKazancTests/Fixtures/scenario-baseline.json`, `KuryeKazancTests/Fixtures/RealScreens/README.md`
- Modify: `.github/workflows/ios-ci.yml` (birim test adımı + özet adımı)
- Test: `KuryeKazancTests/Core/ScenarioTallyTests.swift`

**Interfaces:**
- Consumes: Görev 7 (`ScreenScenario`, `ScenarioExpectation.check`, `ScenarioField`).
- Produces:
  - `struct ScenarioTally { mutating func add(platform: String, results: [ScenarioField: Bool]); func accuracy() -> [String: Double]; func markdown(title: String) -> String; func drops(from baseline: [String: Double], tolerance: Double) -> [String]; func baselineJSON() -> String }` — anahtar `"<platform>/<alan>"`, değer yüzde (0–100, bir ondalık).
  - `MockEarningsScreen(scenario:)` (SwiftUI `View`) ve `@MainActor static func render(_ scenario: ScreenScenario) -> UIImage` (ölçek 3).

- [ ] **Step 1: Write the failing test (Core)**

`KuryeKazancTests/Core/ScenarioTallyTests.swift`:

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScenarioTallyTests: XCTestCase {
    func testAccuracyDropsAndReport() {
        var tally = ScenarioTally()
        tally.add(platform: "getir", results: [.total: true, .packages: true])
        tally.add(platform: "getir", results: [.total: false, .packages: true])
        tally.add(platform: "uber", results: [.duration: true])

        XCTAssertEqual(tally.accuracy(), ["getir/total": 50, "getir/packages": 100, "uber/duration": 100])
        XCTAssertEqual(tally.drops(from: ["getir/total": 60, "getir/packages": 100], tolerance: 5), ["getir/total: 60.0 -> 50.0"])
        XCTAssertEqual(tally.drops(from: ["getir/total": 54], tolerance: 5), [])
        // Sutun sirasi ScenarioField.allCases: template, total, bonus, packages, duration, period
        XCTAssertTrue(tally.markdown(title: "Taklit").contains("| getir | – | 50.0 | – | 100.0 | – | – |"))

        let decoded = try? JSONDecoder().decode([String: Double].self, from: Data(tally.baselineJSON().utf8))
        XCTAssertEqual(decoded, tally.accuracy())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ScenarioTallyTests`
Expected: FAIL (tip yok)

- [ ] **Step 3: Implement Core tally**

`KuryeKazanc/Core/Scenarios/ScenarioTally.swift`:

```swift
import Foundation

/// Platform x alan dogruluk sayimi (spec 1.4a §4.3). Yuzde, bir ondalik.
struct ScenarioTally {
    private var counts: [String: (ok: Int, total: Int)] = [:]

    mutating func add(platform: String, results: [ScenarioField: Bool]) {
        for (field, ok) in results {
            let key = "\(platform)/\(field.rawValue)"
            var entry = counts[key] ?? (0, 0)
            entry.total += 1
            if ok { entry.ok += 1 }
            counts[key] = entry
        }
    }

    func accuracy() -> [String: Double] {
        counts.mapValues { ($0.total == 0 ? 0 : Double($0.ok) / Double($0.total) * 1000).rounded() / 10 }
    }

    /// Tabandan `tolerance` puandan fazla dusen hucreler ("anahtar: taban -> simdi").
    func drops(from baseline: [String: Double], tolerance: Double) -> [String] {
        let now = accuracy()
        return baseline.keys.sorted().compactMap { key in
            guard let base = baseline[key], let current = now[key], base - current > tolerance else { return nil }
            return "\(key): \(String(format: "%.1f", base)) -> \(String(format: "%.1f", current))"
        }
    }

    /// Satirlar platform, sutunlar alan.
    func markdown(title: String) -> String {
        let acc = accuracy()
        let platforms = Set(acc.keys.map { String($0.split(separator: "/")[0]) }).sorted()
        let fields = ScenarioField.allCases.map(\.rawValue)
        var lines = ["### \(title)", "", "| platform | " + fields.joined(separator: " | ") + " |",
                     "|---|" + fields.map { _ in "---" }.joined(separator: "|") + "|"]
        for platform in platforms {
            let cells = fields.map { field in acc["\(platform)/\(field)"].map { String(format: "%.1f", $0) } ?? "–" }
            lines.append("| \(platform) | " + cells.joined(separator: " | ") + " |")
        }
        return lines.joined(separator: "\n")
    }

    func baselineJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(accuracy())).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
```

Run: `swift test` → PASS. Commit:

```bash
git add KuryeKazanc/Core/Scenarios/ScenarioTally.swift KuryeKazancTests/Core/ScenarioTallyTests.swift
git commit -m "test(core): senaryo dogruluk sayimi ve taban karsilastirmasi"
```

- [ ] **Step 4: Taklit ekran (uygulama hedefi)**

`KuryeKazanc/Views/Tester/MockEarningsScreen.swift`:

```swift
import SwiftUI
import UIKit

/// Senaryodan taklit kazanc ekrani (spec 1.4a §4.3). Testlerde goruntuye cevrilir; TestFlight'ta "Deneme ekranlari".
struct MockEarningsScreen: View {
    let scenario: ScreenScenario

    private var accent: Color {
        switch scenario.platformCode {
        case "trendyol_go": .orange
        case "getir": .purple
        case "yemeksepeti": .red
        case "migros_hemen": Color(red: 1, green: 0.5, blue: 0)
        case "uber": .black
        case "thekurye": .cyan
        case "banabikurye": .green
        default: .gray
        }
    }

    private var background: Color { scenario.theme == .dark ? .black : .white }
    private var foreground: Color { scenario.theme == .dark ? .white : .black }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if scenario.noise {
                HStack { Text(ScreenScenario.topNoise[0]); Spacer(); Text(ScreenScenario.topNoise[1]) }
                    .font(.footnote)
            }
            ForEach(Array(scenario.header.enumerated()), id: \.offset) { index, line in
                Text(scenario.styled(line))
                    .font(index == 0 ? .title2.bold() : .headline)
                    .foregroundStyle(index == 0 ? accent : foreground)
            }
            ForEach(Array(scenario.rows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
            ForEach(Array(scenario.footer.enumerated()), id: \.offset) { _, line in
                Text(scenario.styled(line)).font(.subheadline)
            }
            Spacer()
            if scenario.noise {
                HStack { Text(ScreenScenario.bottomNoise[0]); Spacer(); Text(ScreenScenario.bottomNoise[1]) }
                    .font(.footnote)
            }
        }
        .padding(20)
        .foregroundStyle(foreground)
        .frame(width: scenario.device.points.width, height: scenario.device.points.height, alignment: .topLeading)
        .background(background)
    }

    @ViewBuilder
    private func rowView(_ row: ScenarioRow) -> some View {
        let label = scenario.styled(row.label)
        if row.label.isEmpty {
            Text(row.value).font(.largeTitle.bold())
        } else if scenario.splitRows && row.splittable {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.valueFirst ? row.value : label).font(row.valueFirst ? .title3.bold() : .subheadline)
                Text(row.valueFirst ? label : row.value).font(row.valueFirst ? .subheadline : .title3.bold())
            }
        } else {
            HStack {
                Text(row.valueFirst ? row.value : label)
                Spacer()
                Text(row.valueFirst ? label : row.value).bold()
            }
            .font(.body)
            .padding(10)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @MainActor
    static func render(_ scenario: ScreenScenario) -> UIImage {
        let renderer = ImageRenderer(content: MockEarningsScreen(scenario: scenario))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}
```

Not: Satır içi düzende değer sağa yaslıdır; Vision aynı y'deki parçaları `orderedLines` ile birleştirir ("Toplam Kazanç 1.245,50 ₺"). `valueFirst` + inline ("54" sol, "Teslimat" sağ) Uber düzenine karşılık gelir.

- [ ] **Step 5: Görüntü testleri + CI raporu**

`KuryeKazancTests/ScenarioImageTests.swift`:

```swift
import XCTest
import UIKit
@testable import KuryeKazanc

/// Katman B (spec 1.4a §4.3): taklit ekran -> goruntu -> Vision -> cozumleyici. Simulatorde (CI) calisir.
@MainActor
final class ScenarioImageTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var reference: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14))! }
    private var fixtures: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures") }

    func testMockScreensMeetBaseline() async throws {
        let recognizer = VisionTextRecognitionService()
        let parser = EarningsScreenshotParser(calendar: calendar)
        var tally = ScenarioTally()
        for scenario in ScenarioGenerator().all() {
            let image = MockEarningsScreen.render(scenario)
            let lines = (try? await recognizer.recognize(in: image).map(\.text)) ?? []
            let parsed = parser.parse(lines: lines, referenceDate: reference)
            tally.add(platform: scenario.platformCode, results: scenario.expected.check(parsed))
        }
        let report = tally.markdown(title: "Taklit ekranlar (Vision)")
        appendReport(report)
        print(report)

        let baselineURL = fixtures.appendingPathComponent("scenario-baseline.json")
        guard let data = try? Data(contentsOf: baselineURL),
              let baseline = try? JSONDecoder().decode([String: Double].self, from: data) else {
            let json = tally.baselineJSON()
            appendReport("\nTaban dosyasi yok. Olculen deger (Fixtures/scenario-baseline.json olarak kaydet):\n```json\n\(json)\n```")
            print("SCENARIO_BASELINE_BEGIN\n\(json)\nSCENARIO_BASELINE_END")
            return
        }
        let drops = tally.drops(from: baseline, tolerance: 5)
        XCTAssertTrue(drops.isEmpty, "Dogruluk tabanin altina dustu:\n" + drops.joined(separator: "\n"))
    }

    /// Gercek (karartilmis) ekranlar: Fixtures/RealScreens/<platform>/<ad>.png + <ad>.json (ScenarioExpectation).
    func testRealScreens() async throws {
        let root = fixtures.appendingPathComponent("RealScreens")
        let files = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "png" }
        guard !files.isEmpty else { throw XCTSkip("Henuz gercek ekran yok") }
        let recognizer = VisionTextRecognitionService()
        let parser = EarningsScreenshotParser(calendar: calendar)
        var tally = ScenarioTally()
        for file in files {
            let expectationURL = file.deletingPathExtension().appendingPathExtension("json")
            guard let image = UIImage(contentsOfFile: file.path),
                  let data = try? Data(contentsOf: expectationURL),
                  let expected = try? JSONDecoder().decode(ScenarioExpectation.self, from: data) else {
                XCTFail("Okunamadi: \(file.lastPathComponent)")
                continue
            }
            let lines = (try? await recognizer.recognize(in: image).map(\.text)) ?? []
            let parsed = parser.parse(lines: lines, referenceDate: reference)
            tally.add(platform: file.deletingLastPathComponent().lastPathComponent, results: expected.check(parsed))
        }
        let report = tally.markdown(title: "Gercek ekranlar")
        appendReport(report)
        print(report)
    }

    private func appendReport(_ text: String) {
        guard let path = ProcessInfo.processInfo.environment["SCENARIO_REPORT"] else { return }
        let url = URL(fileURLWithPath: path)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + text + "\n\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
```

`KuryeKazancTests/Fixtures/RealScreens/README.md`:

```markdown
# Gercek ekran ornekleri

`<platform>/<ad>.png` + ayni adli `<ad>.json`. JSON, `ScenarioExpectation` bicimindedir:

    {"templateID": "getir.earnings", "total": 980, "bonus": 0, "packages": 11, "duration": null, "period": "day"}

Kisisel bilgiler (ad, telefon, IBAN, TC kimlik, adres) gorselde KARARTILMIS olmali; aksi halde repoya eklenmez.
```

`.github/workflows/ios-ci.yml` — "Birim testleri (XCTest)" adımında `xcodebuild`'den önce ortam değişkeni ve sonrasına özet adımı:

```yaml
      - name: Birim testleri (XCTest)
        run: |
          set -o pipefail
          mkdir -p build
          export TEST_RUNNER_SCENARIO_REPORT="$GITHUB_WORKSPACE/build/scenario-report.md"
          xcodebuild test-without-building \
            -project "$XCODE_PROJECT" \
            -scheme "$XCODE_SCHEME" \
            -destination "id=$SIM_ID" \
            -derivedDataPath build/DerivedData \
            -only-testing:KuryeKazancTests \
            -resultBundlePath build/results/UnitTests.xcresult \
            | xcbeautify --renderer github-actions

      - name: Senaryo raporu
        if: always()
        run: |
          if [ -f build/scenario-report.md ]; then cat build/scenario-report.md >> "$GITHUB_STEP_SUMMARY"; fi
```

(`TEST_RUNNER_` önekli değişkeni xcodebuild test sürecine önekisiz `SCENARIO_REPORT` olarak geçirir.)

Push ve CI:

```bash
git add KuryeKazanc/Views/Tester KuryeKazancTests/ScenarioImageTests.swift KuryeKazancTests/Fixtures .github/workflows/ios-ci.yml
git commit -m "test: goruntu senaryolari (SwiftUI taklit ekran + Vision), CI ozet raporu"
git push origin develop
```

`gh run watch <id> --exit-status` → Expected: yeşil (taban yokken test geçer ve ölçümü yazar). Birim test adımı öncekinden en fazla ~2 dk uzun olmalı; daha uzunsa `ScenarioImageTests`'te `ScenarioGenerator().all().enumerated().filter { $0.offset % 2 == 0 }` ile örnekle ve commit et.

- [ ] **Step 6: Tabanı kaydet**

```bash
gh run view <id> --log | sed -n '/SCENARIO_BASELINE_BEGIN/,/SCENARIO_BASELINE_END/p' | sed '1d;$d' | sed 's/^.*\t//' > KuryeKazancTests/Fixtures/scenario-baseline.json
```

Dosyanın geçerli JSON olduğunu doğrula (`python -c "import json;json.load(open('KuryeKazancTests/Fixtures/scenario-baseline.json'))"`), satır öneklerinden temizlenmiş olmalı; değilse özet sayfasındaki JSON bloğunu elle kopyala. Ölçülen değerleri kullanıcıya özetle (platform bazında en zayıf alanlar).

```bash
git add KuryeKazancTests/Fixtures/scenario-baseline.json
git commit -m "test: senaryo dogruluk tabani (CI olcumu)"
git push origin develop
```

Expected: CI yeşil, test tabanla karşılaştırıyor.

---

### Task 9: Sunucu şablonları ve kayıtlar

**Files:**
- Modify: `PROGRESS.md` (yeni oturum bölümü)
- Modify: `supabase/README.md` (şablon tohumlama notu)

**Interfaces:**
- Consumes: Görev 5 şablonları.

- [ ] **Step 1: Tohumlama zamanı notu**

`supabase/README.md` "Notlar" listesine ekle:

```markdown
- Yeni ekran tipli sablonlar (`layout: list/orderCard`, 1.4a) yalnizca 1.4a uygulamasi TestFlight'a cikinca
  `seed_templates.mjs` ile yazilir: 1.3 uygulamasi `layout`'u tanimaz ve bu sablonlari ozet ekran gibi okur.
```

- [ ] **Step 2: PROGRESS**

`PROGRESS.md` sonuna yeni bölüm (tarih, yapılanlar: şablon alanları, seçim kuralı, liste/sipariş kartı, süre, yeni şablonlar, uygulama değişiklikleri, senaryo testleri ve ölçülen taban özeti; açık konular: gerçek ekran örnekleri, sunucu tohumlama 1.4a TestFlight'ında; sonraki adım: Görev 10–12 deneme).

- [ ] **Step 3: Commit**

```bash
git add PROGRESS.md supabase/README.md
git commit -m "docs: PROGRESS 1.4a okuma motoru ve senaryo testleri"
git push origin develop
```

---

### Task 10: Deneme önkoşulları (Apple + Codemagic)

**Files:**
- Modify (deneme dalında): `codemagic.yaml` (`ios-release` profilleri)

Bu görev tarayıcıda yapılır (Apple Developer, Codemagic). Otomatik mod engellerse kullanıcıya adımları ver.

- [ ] **Step 1:** Kullanıcıya sor: "Deneme sürümü için `com.kuryekazanc.app.broadcast` App ID'si ve profil oluşturayım mı? TestFlight 1.3.0 yüklemesi bitti mi?" — iki cevap da evet olmadan devam etme.
- [ ] **Step 2:** developer.apple.com → Identifiers → + → App IDs → App → Description "Kurye Kazanc Broadcast", Bundle ID (Explicit) `com.kuryekazanc.app.broadcast`, Capabilities: **App Groups** → Register; ardından App ID'yi aç → App Groups → Configure → `group.com.kuryekazanc.app` → Save.
- [ ] **Step 3:** Profiles → + → App Store Connect → App ID `com.kuryekazanc.app.broadcast` → sertifika: ana uygulama profilindeki Distribution (12 Eyl 2027) → ad "Kurye Kazanc Broadcast App Store" → Generate.
- [ ] **Step 4:** Codemagic → Settings → Code signing identities → iOS provisioning profiles → Fetch profiles → "Kurye Kazanc Broadcast App Store" → referans `kurye-kazanc-broadcast-appstore` → Download selected.
- [ ] **Step 5:** `git switch -c spike/broadcast-capture develop`; `codemagic.yaml` `ios-release.environment.ios_signing.provisioning_profiles` listesine `- kurye-kazanc-broadcast-appstore` ekle; commit `ci(spike): yayin eklentisi profili`.

---

### Task 11: Yayın eklentisi ve deneme ekranları (spike, atılabilir kod)

**Files (yalnızca `spike/broadcast-capture`):**
- Create: `KuryeBroadcast/SampleHandler.swift`, `KuryeBroadcast/BroadcastLog.swift`, `KuryeBroadcast/Info.plist`, `KuryeBroadcast/KuryeBroadcast.entitlements`
- Create: `KuryeKazanc/Views/Tester/SpikeSection.swift`
- Modify: `project.yml` (yeni hedef + uygulama bağımlılığı), `KuryeKazanc/Views/Profile/ProfileView.swift` (bölümü göster)

**Interfaces:**
- Consumes: Core (`EarningsScreenshotParser`, `TextHash`, `RecognizedLine`), `VisionTextRecognitionService.orderedLines(from:)`, `MockEarningsScreen`, `ScenarioGenerator`, `BuildEnvironment.showsTesterTools`, `ScreenshotInbox.appGroupID`.
- Produces: App Group'ta `BroadcastLog.json` ve `BroadcastCaptures/<ms>.json` (`[RecognizedLine]` + şablon kimliği). Deneme, gelen kutusuna (`Inbox/*.img`) yazmaz: uygulama o klasörü görüntü sanıp işler; üretim tasarımı bunu ayrıca çözer (spec §5.1'den bilinçli sapma, yalnızca deneme).

- [ ] **Step 1: `project.yml` hedefi**

`targets:` altına:

```yaml
  # DENEME (spike/broadcast-capture): ekran yayinindan kazanc ekrani yakalama
  KuryeBroadcast:
    type: app-extension
    platform: iOS
    sources:
      - path: KuryeBroadcast
        excludes:
          - "Info.plist"
          - "*.entitlements"
      - path: KuryeKazanc/Core
      - path: KuryeKazanc/Services/OCR/TextRecognitionService.swift
      - path: KuryeKazanc/Services/Screenshots/ScreenshotInbox.swift
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kuryekazanc.app.broadcast
        INFOPLIST_FILE: KuryeBroadcast/Info.plist
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: "Kurye Kazanç Tarama"
        CODE_SIGN_ENTITLEMENTS: KuryeBroadcast/KuryeBroadcast.entitlements
        TARGETED_DEVICE_FAMILY: "1"
        SKIP_INSTALL: YES
```

ve `KuryeKazanc.dependencies` listesine `- target: KuryeBroadcast` / `embed: true`.

`KuryeBroadcast/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.broadcast-services-upload</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).SampleHandler</string>
		<key>RPBroadcastProcessMode</key>
		<string>RPBroadcastProcessModeSampleBuffer</string>
	</dict>
</dict>
</plist>
```

`KuryeBroadcast/KuryeBroadcast.entitlements`: paylaş eklentisininkiyle aynı içerik (`com.apple.security.application-groups` → `group.com.kuryekazanc.app`).

- [ ] **Step 2: Günlük**

`KuryeBroadcast/BroadcastLog.swift`:

```swift
import Foundation

/// Deneme olcumleri; App Group'ta JSON. Uygulamadaki "Tarama gunlugu" okur.
struct BroadcastLog: Codable {
    var startedAt: Date = .now
    var finishedAt: Date?
    var processed = 0
    var skippedRate = 0
    var unrecognized = 0
    var duplicates = 0
    var captured: [String] = []        // sablon kimlikleri
    var peakMemoryMB: Double = 0
    var maxOCRSeconds: Double = 0
    var totalOCRSeconds: Double = 0

    static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ScreenshotInbox.appGroupID)
    }
    static var url: URL? { directory?.appendingPathComponent("BroadcastLog.json") }
    static var capturesDirectory: URL? { directory?.appendingPathComponent("BroadcastCaptures", isDirectory: true) }

    func save() {
        guard let url = Self.url, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> BroadcastLog? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BroadcastLog.self, from: data)
    }

    /// Surecin fiziksel bellek izi (MB).
    static func currentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}
```

`BroadcastLog.swift` uygulama hedefinde de gerekir: `project.yml` `KuryeKazanc.sources`'a `- path: KuryeBroadcast/BroadcastLog.swift` ekle.

- [ ] **Step 3: SampleHandler**

`KuryeBroadcast/SampleHandler.swift`:

```swift
import ReplayKit
import Vision
import CoreImage

/// DENEME: saniyede en fazla 1 kare; kucult, oku, sablon taninirsa satirlari kaydet. Goruntu saklanmaz.
final class SampleHandler: RPBroadcastSampleHandler {
    private var log = BroadcastLog()
    private var lastProcessed = Date.distantPast
    private var recentHashes: [String] = []
    private let parser = EarningsScreenshotParser()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        log = BroadcastLog()
        log.save()
    }

    override func broadcastFinished() {
        log.finishedAt = .now
        log.save()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = Date()
        guard now.timeIntervalSince(lastProcessed) >= 1,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            log.skippedRate += 1
            return
        }
        lastProcessed = now
        autoreleasepool { process(pixelBuffer) }
        log.peakMemoryMB = max(log.peakMemoryMB, BroadcastLog.currentMemoryMB())
        if log.processed % 10 == 0 { log.save() }
    }

    private func process(_ pixelBuffer: CVPixelBuffer) {
        log.processed += 1
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let longSide = max(image.extent.width, image.extent.height)
        let scale = min(1, 1280 / longSide)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return }

        let started = Date()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["tr-TR", "en-US"]
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        let seconds = Date().timeIntervalSince(started)
        log.totalOCRSeconds += seconds
        log.maxOCRSeconds = max(log.maxOCRSeconds, seconds)

        let lines = VisionTextRecognitionService.orderedLines(from: request.results ?? [])
        let parsed = parser.parse(lines: lines.map(\.text))
        guard let templateID = parsed.templateID else {
            log.unrecognized += 1
            return
        }
        let hash = TextHash.of(lines.map(\.text))
        guard !recentHashes.contains(hash) else {
            log.duplicates += 1
            return
        }
        recentHashes.append(hash)
        if recentHashes.count > 50 { recentHashes.removeFirst() }
        log.captured.append(templateID)
        save(lines: lines, templateID: templateID)
    }

    private func save(lines: [RecognizedLine], templateID: String) {
        guard let directory = BroadcastLog.capturesDirectory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(templateID).json"
        try? RecognizedLine.encode(lines).write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
```

Not: `TextHash.of` ve `VisionTextRecognitionService.orderedLines` mevcut API'lerdir (Görev öncesi `grep -n "static func of" KuryeKazanc/Core/OCR/TextHash.swift` ile imzayı doğrula; farklıysa çağrıyı ona uydur). `.accurate` ile bellek 40 MB'ı aşarsa (günlükte görülür) `recognitionLevel = .fast` ile ikinci deneme sürümü yapılır (spec §5.4).

- [ ] **Step 4: Uygulamadaki deneme bölümü**

`KuryeKazanc/Views/Tester/SpikeSection.swift`:

```swift
import SwiftUI
import ReplayKit

/// DENEME (yalnizca TestFlight/DEBUG): yayin baslat, taklit ekranlar, tarama gunlugu.
struct SpikeSection: View {
    var body: some View {
        Section("Deneme: kazanç taraması") {
            BroadcastPickerButton()
                .frame(height: 44)
            NavigationLink("Deneme ekranları") { MockScreensPager() }
            NavigationLink("Tarama günlüğü") { BroadcastLogView() }
        }
    }
}

private struct BroadcastPickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = "com.kuryekazanc.app.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

private struct MockScreensPager: View {
    private let scenarios = ScenarioGenerator().all().filter { $0.textStyle == .turkish && !$0.splitRows }
    var body: some View {
        TabView {
            ForEach(scenarios) { scenario in
                MockEarningsScreen(scenario: scenario)
            }
        }
        .tabViewStyle(.page)
        .ignoresSafeArea()
    }
}

private struct BroadcastLogView: View {
    @State private var log = BroadcastLog.load()
    var body: some View {
        List {
            if let log {
                LabeledContent("Başlangıç", value: log.startedAt.formatted())
                LabeledContent("Bitiş", value: log.finishedAt?.formatted() ?? "sürüyor / yarıda kaldı")
                LabeledContent("İşlenen kare", value: "\(log.processed)")
                LabeledContent("Tanınmayan", value: "\(log.unrecognized)")
                LabeledContent("Tekrar", value: "\(log.duplicates)")
                LabeledContent("Yakalanan", value: "\(log.captured.count)")
                LabeledContent("En yüksek bellek", value: String(format: "%.1f MB", log.peakMemoryMB))
                LabeledContent("En uzun okuma", value: String(format: "%.2f sn", log.maxOCRSeconds))
                LabeledContent("Ortalama okuma", value: String(format: "%.2f sn", log.processed == 0 ? 0 : log.totalOCRSeconds / Double(log.processed)))
                Section("Yakalanan şablonlar") {
                    ForEach(Array(log.captured.enumerated()), id: \.offset) { _, id in Text(id) }
                }
            } else {
                Text("Henüz tarama yapılmadı.")
            }
        }
        .refreshable { log = BroadcastLog.load() }
        .navigationTitle("Tarama günlüğü")
    }
}
```

`ProfileView.swift`'te test araçlarının gösterildiği yerde (`grep -n "showsTesterTools" KuryeKazanc/Views/Profile/ProfileView.swift`; yoksa `Form`/`List`'in son bölümünden önce) ekle:

```swift
            if BuildEnvironment.showsTesterTools {
                SpikeSection()
            }
```

- [ ] **Step 5: CI ve commit**

```bash
git add project.yml KuryeBroadcast KuryeKazanc/Views/Tester/SpikeSection.swift KuryeKazanc/Views/Profile/ProfileView.swift
git commit -m "spike: yayin eklentisiyle kazanc ekrani yakalama denemesi"
git push -u origin spike/broadcast-capture
```

`gh run watch` → `iOS CI` yeşil (eklenti derleniyor; mevcut testler geçiyor). Derleme hatası varsa düzelt.

---

### Task 12: Deneme sürümü, kullanıcı testi ve karar

- [ ] **Step 1:** Kullanıcıya sor: "Deneme sürümünü TestFlight'a (yalnızca İç Test) göndereyim mi?" Evet olmadan devam etme. TestFlight 1.3.0 tamamlanmış olmalı.
- [ ] **Step 2:** `git push origin spike/broadcast-capture:release/spike-capture` → Codemagic `ios-release` (otomatik mod engellerse komutu kullanıcıya ver). Codemagic sayfasından izle; imzalama hatasında Görev 10 profilini kontrol et.
- [ ] **Step 3:** Kullanıcıya test tarifi (Türkçe, adım adım):
  1. TestFlight'tan güncelle → Profil → "Deneme: kazanç taraması" → yayın düğmesi → "Kurye Kazanç Tarama" → Yayını Başlat; pil yüzdesini not et.
  2. "Deneme ekranları"nda her ekranda ~2 sn durarak kaydır; araya Mesajlar ve Ayarlar'a geçip dön; toplam ~5 dk.
  3. Kırmızı göstergeden yayını durdur; pil yüzdesini not et.
  4. "Tarama günlüğü" ekranının görüntüsünü gönder.
  5. Kısayollar testi (spec §5.2): Kısayollar → Otomasyon → + → Uygulama → Ayarlar → "Açıldığında" → "Hemen çalıştır" → eylemler: "Bekle" 3 sn → "Ekran Görüntüsü Al" → "Paylaş" (Kurye Kazanç) → Ayarlar'ı aç; sonucu bildir.
- [ ] **Step 4:** Ölçütleri değerlendir (spec §1: bellek < 40 MB, her ekran yakalandı, tekrar yok, çökme yok; pil). Sonucu ve kararı `PROGRESS.md`'ye yaz (spec §5.4: üretim tasarımına geç / `.fast` ile tekrar / Kısayollar ana yol). `develop`'a yalnızca PROGRESS commit'i; deneme dalı birleştirilmez.

```bash
git switch develop
git add PROGRESS.md
git commit -m "docs: kazanc taramasi denemesi sonucu ve karar"
git push origin develop
```
