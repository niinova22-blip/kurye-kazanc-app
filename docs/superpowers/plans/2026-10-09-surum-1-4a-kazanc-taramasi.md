# Kazanç taraması (üretim) ve Kısayollar — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deneme yayın eklentisini üretime taşımak: kararlı ve tekrarsız yakalama, "Taramada bulunanlar" ekranı (sipariş kartı birleştirme, seçip kaydetme), Bugün'de tarama düğmesi ve Kısayollar için ekran görüntüsü gönderme eylemi; 1.4.0 olarak TestFlight.

**Architecture:** Saf mantık (anahtar, iki kare filtresi, sonuç oluşturucu) `KuryeKazanc/Core`'da, Windows'ta test edilir. Eklenti bu mantıkla yalnızca kabul edilen karelerin satırlarını App Group'a yazar. Uygulama yakalamaları mevcut çözümleyici/doğrulayıcı/form kaydıyla kayda çevirir.

**Tech Stack:** Swift 5 modu, SwiftUI, SwiftData, Vision, ReplayKit, App Intents, XCTest; XcodeGen; GitHub Actions (CI + TestFlight).

**Spec:** `docs/superpowers/specs/2026-10-09-surum-1-4a-kazanc-taramasi-design.md`

## Global Constraints

- iOS 17.0; `SWIFT_VERSION: "5.0"`; üçüncü taraf bağımlılık yok.
- `KuryeKazanc/Core` SwiftData/UIKit/SwiftUI/Vision import etmez; Core testleri `#if canImport(KuryeCore) … #else … #endif` başlığıyla.
- Kod yorumları ASCII Türkçe; kullanıcı metinleri Türkçe karakterli.
- Görüntü hiçbir yerde saklanmaz; eklenti yalnızca `[RecognizedLine]` yazar.
- `.order` ve `.week` dönemli kayıtlar sunucuya vardiya olarak gönderilmez (mevcut kural korunur).
- Uygulama kodu Windows'ta derlenmez: GitHub Actions'ta doğrulanır; macOS dakikası sınırlı — düzeltmeleri toplayıp tek push, eskiyen çalışmaları `gh run cancel`.
- Deneme dalı `spike/broadcast-capture` birleştirilmez; gereken dosyalar oradan `git checkout spike/broadcast-capture -- <yol>` ile alınır.

## Review Focus

1. **Aynı ekran saat değişimiyle iki kez** — üst şerit hariç + değer anahtarı; Core testinde aynı değerli iki farklı satır kümesi tek kalem olmalı (Görev 2).
2. **Kaydırma sırasında yarım kare** — tek karede görülen anahtar kabul edilmez (Görev 1).
3. **Aynı gün iki platformun sipariş kartları** — ayrı gruplar (Görev 2).
4. **Daha önce kaydedilmiş ekran** — sonuç ekranında seçilemez, kayıt oluşmaz (Görev 4).
5. **Eklenti bellek sınırında öldürülürse** — kabul edilenler kaybolmaz, sonuç ekranı not gösterir (Görev 3/5).

---

### Task 1: Yakalama anahtarı ve iki kare filtresi (Core)

**Files:**
- Create: `KuryeKazanc/Core/Scan/BroadcastCapture.swift`, `KuryeKazanc/Core/Scan/StableCaptureFilter.swift`
- Test: `KuryeKazancTests/Core/StableCaptureFilterTests.swift`

**Interfaces — Produces:** `BroadcastCapture`, `CaptureKey`, `StableCaptureFilter` (aşağıdaki kod).

- [ ] **Step 1: Failing test**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class StableCaptureFilterTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func parsed(_ template: String?, total: Double, day: Int = 9, period: OCRTemplate.Period = .day) -> ParsedEarning {
        ParsedEarning(platformCode: "getir",
                      date: calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 15))!,
                      packageCount: 3, totalEarning: total, bonus: 0, totalIncludesBonus: true,
                      fieldsToReview: [], templateID: template, period: period)
    }

    func testKey_roundsCentsAndDay_nilWithoutTemplateOrTotal() {
        let a = CaptureKey(parsed: parsed("getir.earnings", total: 980.004), calendar: calendar)
        let b = CaptureKey(parsed: parsed("getir.earnings", total: 980.0), calendar: calendar)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a?.totalCents, 98000)
        XCTAssertNil(CaptureKey(parsed: parsed(nil, total: 980), calendar: calendar))
        XCTAssertNil(CaptureKey(parsed: parsed("getir.earnings", total: 0), calendar: calendar))
    }

    func testTwoConsecutiveFramesAccept_singleFrameDoesNot() {
        let k1 = CaptureKey(parsed: parsed("getir.earnings", total: 100), calendar: calendar)
        let k2 = CaptureKey(parsed: parsed("getir.earnings", total: 200), calendar: calendar)
        var f = StableCaptureFilter()
        XCTAssertNil(f.offer(k1))          // ilk gorulus
        XCTAssertNil(f.offer(k2))          // yarim kare / farkli ekran
        XCTAssertNil(f.offer(k1))          // araya baska kare girdi: yeniden ilk gorulus
        XCTAssertEqual(f.offer(k1), k1)    // art arda ikinci: kabul
        XCTAssertNil(f.offer(k1))          // ayni ekranda kalmak tekrar uretmez
        XCTAssertEqual(f.duplicateCount, 1)
        XCTAssertEqual(f.unconfirmedCount, 1) // k2 hic onaylanmadi
    }

    func testUnrecognizedFrameBreaksSequence() {
        let k = CaptureKey(parsed: parsed("uber.earnings", total: 500, period: .week), calendar: calendar)
        var f = StableCaptureFilter()
        XCTAssertNil(f.offer(k))
        XCTAssertNil(f.offer(nil))
        XCTAssertNil(f.offer(k))
        XCTAssertEqual(f.offer(k), k)
        XCTAssertEqual(f.unconfirmedCount, 0)
    }

    func testCaptureCodableRoundTrip() throws {
        let c = BroadcastCapture(capturedAt: Date(timeIntervalSince1970: 1_791_565_000),
                                 lines: [RecognizedLine(text: "Getir", x: 0, y: 0.9, width: 0.3, height: 0.03)])
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(BroadcastCapture.self, from: data), c)
    }
}
```

- [ ] **Step 2:** `swift test --filter StableCaptureFilterTests` → FAIL (tipler yok).

- [ ] **Step 3: Implement**

`KuryeKazanc/Core/Scan/BroadcastCapture.swift`:

```swift
import Foundation

/// Yayin eklentisinin kabul ettigi bir kazanc ekrani: yalnizca okunan satirlar (gorsel saklanmaz).
struct BroadcastCapture: Codable, Equatable {
    var capturedAt: Date
    var lines: [RecognizedLine]
}

/// Ayni ekrani tanimlayan deger anahtari: saat/durum cubugu degisse de ayni kalir.
struct CaptureKey: Hashable {
    var templateID: String
    var totalCents: Int
    var day: Date
    var period: OCRTemplate.Period

    /// Sablon taninmadiysa ya da toplam yoksa nil (kare sayilmaz).
    init?(parsed: ParsedEarning, calendar: Calendar) {
        guard let templateID = parsed.templateID, parsed.totalEarning > 0 else { return nil }
        self.templateID = templateID
        self.totalCents = Int((parsed.totalEarning * 100).rounded())
        self.day = calendar.startOfDay(for: parsed.date)
        self.period = parsed.period
    }
}
```

`KuryeKazanc/Core/Scan/StableCaptureFilter.swift`:

```swift
import Foundation

/// Iki kare kurali: bir ekran art arda iki karede ayni anahtarla okunursa kabul edilir (kaydirma
/// sirasindaki yarim kareler elenir). Kabul edilen anahtar tarama boyunca bir kez doner.
struct StableCaptureFilter {
    private(set) var accepted: Set<CaptureKey> = []
    private var previous: CaptureKey?
    private var seenOnce: Set<CaptureKey> = []
    /// Kabul edilmis ekranin yeniden okunma sayisi.
    private(set) var duplicateCount = 0

    /// Tek karede gorulup hic onaylanmayan farkli ekran sayisi (kacmis olabilir).
    var unconfirmedCount: Int { seenOnce.count }

    mutating func offer(_ key: CaptureKey?) -> CaptureKey? {
        defer { previous = key }
        guard let key else { return nil }
        if accepted.contains(key) {
            duplicateCount += 1
            return nil
        }
        if key == previous {
            accepted.insert(key)
            seenOnce.remove(key)
            return key
        }
        seenOnce.insert(key)
        return nil
    }
}
```

- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Commit `feat(core): tarama anahtari ve iki kare filtresi`.

---

### Task 2: Sonuç oluşturucu (Core)

**Files:**
- Create: `KuryeKazanc/Core/Scan/ScanResultBuilder.swift`
- Test: `KuryeKazancTests/Core/ScanResultBuilderTests.swift`

**Interfaces:**
- Consumes: `CaptureKey`, `TextHash.of(_:)`, `ParsedEarning`.
- Produces:
  - `struct ScanInput { var parsed: ParsedEarning; var lines: [RecognizedLine]; var capturedAt: Date }`
  - `struct ScanItem: Identifiable, Equatable { enum Kind: Equatable { case daily, weekly, orderGroup(count: Int), unknown }; var id: String; var kind: Kind; var parsed: ParsedEarning; var lines: [RecognizedLine]; var capturedAt: Date; var textHash: String }`
  - `struct ScanResultBuilder { var calendar: Calendar; func build(_ inputs: [ScanInput]) -> [ScanItem] }` — anahtarı olmayan girdiler atılır; aynı anahtar bir kez (ilk görülen); `.order` girdileri `platformCode ?? templateID` + gün bazında tek kaleme birleşir (toplam ve bonus toplanır, paket = kart sayısı, `fieldsToReview` birleşimi, satırlar art arda, `capturedAt` en sonuncusu, dönem `.order`, `kind = .orderGroup(count)`); diğerleri `.day → .daily`, `.week → .weekly`, `.unknown → .unknown`; sonuç `capturedAt`'e göre sıralı; `textHash = TextHash.of(lines.map(\.text))`.

- [ ] **Step 1: Failing test**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScanResultBuilderTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var builder: ScanResultBuilder { ScanResultBuilder(calendar: calendar) }

    private func input(_ template: String?, platform: String = "getir", total: Double, bonus: Double = 0,
                       period: OCRTemplate.Period = .day, day: Int = 9, at second: Int, text: String) -> ScanInput {
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 14))!
        let parsed = ParsedEarning(platformCode: platform, date: date, packageCount: period == .order ? 1 : 10,
                                   totalEarning: total, bonus: bonus, totalIncludesBonus: true,
                                   fieldsToReview: [], templateID: template, period: period)
        return ScanInput(parsed: parsed, lines: [RecognizedLine(text: text, x: 0, y: 0, width: 1, height: 0.1)],
                         capturedAt: Date(timeIntervalSince1970: TimeInterval(1_791_565_000 + second)))
    }

    /// Review Focus 1: ayni degerler, farkli metin (saat degisti) -> tek kalem.
    func testSameValuesDifferentText_oneItem() {
        let items = builder.build([
            input("getir.earnings", total: 980, at: 0, text: "20:14 Getir 980"),
            input("getir.earnings", total: 980, at: 60, text: "20:15 Getir 980"),
        ])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].kind, .daily)
    }

    func testUnrecognizedDropped_weeklyKind() {
        let items = builder.build([
            input(nil, total: 50, at: 0, text: "Mesajlar"),
            input("uber.earnings", platform: "uber", total: 6459.9, period: .week, at: 5, text: "Kazançlar"),
        ])
        XCTAssertEqual(items.map(\.kind), [.weekly])
    }

    func testOrderCardsMergedPerDayAndPlatform() {
        let items = builder.build([
            input("yemeksepeti.order", platform: "yemeksepeti", total: 147.5, bonus: 37, period: .order, at: 0, text: "a"),
            input("yemeksepeti.order", platform: "yemeksepeti", total: 120, bonus: 0, period: .order, at: 10, text: "b"),
            // Review Focus 3: ayni gun baska platform ayri grup
            input("banabikurye.order", platform: "banabikurye", total: 430, period: .order, at: 20, text: "c"),
            // ertesi gun ayri grup
            input("yemeksepeti.order", platform: "yemeksepeti", total: 90, period: .order, day: 10, at: 30, text: "d"),
        ])
        XCTAssertEqual(items.count, 3)
        let ys = items.first { $0.parsed.platformCode == "yemeksepeti" && calendar.component(.day, from: $0.parsed.date) == 9 }!
        XCTAssertEqual(ys.kind, .orderGroup(count: 2))
        XCTAssertEqual(ys.parsed.totalEarning, 267.5, accuracy: 0.001)
        XCTAssertEqual(ys.parsed.bonus, 37, accuracy: 0.001)
        XCTAssertEqual(ys.parsed.packageCount, 2)
        XCTAssertEqual(ys.parsed.period, .order)
        XCTAssertEqual(ys.lines.map(\.text), ["a", "b"])
        XCTAssertEqual(ys.textHash, TextHash.of(["a", "b"]))
    }

    func testSameOrderCardTwice_countedOnce() {
        let items = builder.build([
            input("yemeksepeti.order", platform: "yemeksepeti", total: 147.5, period: .order, at: 0, text: "a"),
            input("yemeksepeti.order", platform: "yemeksepeti", total: 147.5, period: .order, at: 5, text: "a2"),
        ])
        XCTAssertEqual(items.first?.kind, .orderGroup(count: 1))
    }

    func testSortedByCaptureTime() {
        let items = builder.build([
            input("trendyol_go.earnings", platform: "trendyol_go", total: 1245.5, at: 50, text: "t"),
            input("getir.earnings", total: 980, at: 0, text: "g"),
        ])
        XCTAssertEqual(items.map { $0.parsed.platformCode }, ["getir", "trendyol_go"])
    }
}
```

- [ ] **Step 2:** `swift test --filter ScanResultBuilderTests` → FAIL.
- [ ] **Step 3:** Implement `ScanResultBuilder.swift` per the Interfaces block (tek dosya: `ScanInput`, `ScanItem`, `ScanResultBuilder`). `id`: tekil kalemde `"\(key.templateID)-\(Int(key.day.timeIntervalSince1970))-\(key.totalCents)-\(key.period.rawValue)"`, sipariş grubunda `"orders-\(platform)-\(Int(day.timeIntervalSince1970))"`.
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Commit `feat(core): tarama sonuc olusturucu ve siparis karti birlestirme`.

---

### Task 3: Yayın eklentisi (üretim) ve yakalama deposu

**Files:**
- From spike (`git checkout spike/broadcast-capture -- KuryeBroadcast KuryeKazanc/Views/Tester/SpikeSection.swift`), then modify:
- Modify: `KuryeBroadcast/SampleHandler.swift`, `KuryeBroadcast/BroadcastLog.swift`
- Create: `KuryeKazanc/Services/Screenshots/BroadcastCaptureStore.swift`
- Modify: `project.yml` (spike'taki `KuryeBroadcast` hedefi + `KuryeKazanc` bağımlılığı + `KuryeBroadcast/BroadcastLog.swift` uygulama kaynaklarında; ayrıca `BroadcastCaptureStore.swift` eklenti kaynaklarında)
- Rename/modify: `SpikeSection.swift` → `KuryeKazanc/Views/Tester/ScanLogView.swift` (yalnızca "Tarama günlüğü" görünümü; yayın düğmesi ve deneme ekranları KALDIRILIR) ve `ProfileView` test araçları bölümünde `NavigationLink("Tarama günlüğü")`.

**Interfaces:**
- Consumes: Görev 1–2 (`BroadcastCapture`, `CaptureKey`, `StableCaptureFilter`).
- Produces: `struct BroadcastCaptureStore { static var shared: BroadcastCaptureStore; init(directory: URL?); func save(_ capture: BroadcastCapture) throws; func pending() -> [URL] /* eskiden yeniye */; func load(_ url: URL) -> BroadcastCapture? /* bozuksa nil */; func remove(_ url: URL); func removeAll() }` — klasör `group.com.kuryekazanc.app/BroadcastCaptures`, dosya `<ms>-<uuid>.json`. `BroadcastLog`'a `unconfirmed: Int` ve `accepted: Int` eklenir (`captured` dizisi kalabilir).

**Kurallar (SampleHandler):**
- Saniyede en fazla 1 kare (mevcut). Vision isteğinde `regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 0.94)` (Vision koordinatı: alt sol köken; üst %6 hariç).
- Kare → `parser.parse` → `CaptureKey(parsed:calendar:)` → `filter.offer(key)`; dönen anahtar varsa `BroadcastCaptureStore.shared.save(BroadcastCapture(capturedAt: .now, lines: lines))` ve `log.accepted += 1`; `log.duplicates = filter.duplicateCount`, `log.unconfirmed = filter.unconfirmedCount`; anahtar nil ise `log.unrecognized += 1`.
- Bellek tepesi ölçümü ve her karede günlük kaydı (spike'taki düzeltilmiş hali) korunur.
- `broadcastStarted`'da `filter` sıfırlanır.

- [ ] Steps: dosyaları spike'tan al, kuralları uygula, `BroadcastCaptureStore` yaz (+ app test `BroadcastCaptureStoreTests` geçici klasörle: save/pending sırası/load/bozuk dosya nil/remove), deneme UI'ını kaldır, `swift test`, commit, push develop, CI yeşil (`gh run watch`). Commit: `feat: kazanc taramasi eklentisi uretim surumu (ust serit haric, iki kare, deger tabanli tekrar)`.

---

### Task 4: Sonuç görünüm modeli ve kaydetme

**Files:**
- Create: `KuryeKazanc/ViewModels/ScanResultsViewModel.swift`
- Modify: `KuryeKazanc/Services/Screenshots/ScreenshotImporter.swift` (yeni `importCapture`)
- Test: `KuryeKazancTests/ScanResultsViewModelTests.swift`

**Interfaces:**
- Consumes: `BroadcastCaptureStore`, `ScanResultBuilder`, `ScreenshotVerifier`, `EarningFormViewModel(defaultPlatform:imported:now:calendar:)` + `save(in:)`, `EarningsScreenshotParser(templates:)`.
- Produces:
  - `ScreenshotImporter.importCapture(lines: [RecognizedLine], capturedAt: Date, referenceDate: Date = .now) -> ImportedScreenshot` — çözümleme `capturedAt`'e göre, `isGenuine = true` (sistem yayını), değerlendirme mevcut doğrulayıcıyla, `textHash = TextHash.of(lines.map(\.text))`, `assetIdentifier = nil`.
  - `@MainActor @Observable final class ScanResultsViewModel { struct Row: Identifiable { let item: ScanItem; var isSelected: Bool; let isAlreadySaved: Bool; var id: String { item.id } }; private(set) var rows: [Row]; var interrupted: Bool /* günlükte bitiş yok */; init(store: BroadcastCaptureStore, templates: [OCRTemplate]?, knownTextHashes: Set<String>, interrupted: Bool, calendar: Calendar = .current, now: Date = .now); func load(); var selectedCount: Int; func save(in context: ModelContext, platforms: [Platform]) throws -> [EarningRecord]; func discard() }`.
- Kurallar: varsayılan seçim `.daily` ve `.orderGroup` için açık, `.weekly`/`.unknown` kapalı; `isAlreadySaved` (`knownTextHashes` içerir) seçilemez. Sipariş grubu için `ImportedScreenshot`, birleştirilmiş `ParsedEarning` ve grup satırlarıyla kurulur (değerlendirme dönem `.order` olduğundan günlük değil → en fazla `ocrUnverified`). Kaydetme: her seçili satır için `EarningFormViewModel(defaultPlatform: nil, imported: …)`; form platformu bulunamazsa kaydetmeden atlar ve `skipped` sayar (`var skippedCount`); kayıttan sonra (başarılı ya da atlanan) tüm yakalama dosyaları silinir. `discard()` dosyaları siler.

- [ ] Steps: TDD (testler: liste/varsayılan seçim, zaten kayıtlı satır seçilemez ve kaydedilmez — Review Focus 4, kaydetme sonrası kayıt sayısı ve `source == .ocr`, sipariş grubu kaydı `packageCount` = kart sayısı, dosyaların silinmesi, bozuk dosya atlanır). Commit `feat: tarama sonuclari gorunum modeli ve kaydetme`. CI yeşil.

---

### Task 5: Arayüz — sonuç ekranı, Bugün düğmesi, tanıtım

**Files:**
- Create: `KuryeKazanc/Views/Scan/ScanResultsView.swift`, `KuryeKazanc/Views/Scan/ScanButton.swift`, `KuryeKazanc/Views/Scan/ScanIntroView.swift`
- Modify: `KuryeKazanc/Views/Today/TodayView.swift` (düğme + bekleyen yakalama varsa sayfa), `KuryeKazanc/Views/Profile/ProfileView.swift` (açıklama satırı)

**Kurallar:**
- `ScanButton`: `RPSystemBroadcastPickerView` (`preferredExtension = "com.kuryekazanc.app.broadcast"`, mikrofon kapalı) + "Kazanç taraması" etiketi; ilk dokunuştan önce (`@AppStorage("scanIntroSeen")` false ise) `ScanIntroView` sayfası: 1) "Taramayı başlat", 2) "Platform uygulamalarında kazanç panelini aç, birkaç saniye bekle, kapat", 3) "Durdurunca bulunanları onaylarsın" + "Görüntü saklanmaz, yalnızca okunan rakamlar".
- `TodayView`: mevcut gelen kutusu işlemesinin olduğu yerde (açılış ve ön plana dönüş) `BroadcastCaptureStore.shared.pending()` boş değilse `ScanResultsView` sayfası açılır. UI testlerinde depo `nil` klasörle (mevcut `ScreenshotInbox(directory: nil)` deseni).
- `ScanResultsView`: başlık "Taramada bulunanlar"; satır: platform adı (bilinmiyorsa şablon kimliği), tarih, toplam (₺), tür etiketi ("Günlük", "Haftalık özet — vardiya değil", "N sipariş", "Belirsiz"), "Zaten kayıtlı" ise soluk ve seçilemez; `interrupted` ise üstte "Tarama beklenmedik şekilde durdu; bulunanlar aşağıda."; boşsa "Kazanç ekranı bulunamadı — platform uygulamasında kazanç panelini açtığından emin ol."; alt düğmeler "Kaydet (n)" ve "Vazgeç"; kayıttan sonra kayıt sonrası mevcut akış (eşitleme `recordSaved`, yedek) her kayıt için çağrılır (TodayView'deki form kaydı sonrası çağrılarla aynı).
- Profil: "Kazanç taraması" açıklama satırı (Bugün'deki düğmeye yönlendirir).
- Erişilebilirlik kimlikleri: `scan.button`, `scan.results.save`, `scan.results.discard`.

- [ ] Steps: uygula, CI (birim + UI testleri PR'da), commit `feat(ui): taramada bulunanlar, Bugun'de tarama dugmesi, tanitim`.

---

### Task 6: Kısayollar eylemi

**Files:**
- Create: `KuryeKazanc/Services/Screenshots/SendScreenshotIntent.swift`
- Modify: `KuryeKazanc/Views/Profile/ProfileView.swift` ("Kısayollar ile" tarifi)
- Test: `KuryeKazancTests/SendScreenshotIntentTests.swift`

**Kurallar:** `struct SendScreenshotIntent: AppIntent` — başlık "Kurye Kazanç'a ekran görüntüsü gönder", parametre `@Parameter(title: "Görüntü", supportedContentTypes: [.image]) var image: IntentFile`; `perform()` görüntü verisini `ScreenshotInbox.shared.add(data)` ile bırakır, `.result(dialog: "Gönderildi; Kurye Kazanç'ı açınca okunur.")`; `openAppWhenRun = false`. Test edilebilirlik için gelen kutusunu enjekte eden `static func store(_ data: Data, in inbox: ScreenshotInbox) throws` yardımcı fonksiyonu; test geçici klasörle `.img` dosyası oluştuğunu doğrular. `AppShortcutsProvider` ile "Kurye Kazanç'a ekran görüntüsü gönder" kısayolu. Profil tarifi: "Kısayollar > Otomasyon > Uygulama (platform uygulaması) > Kapatıldığında değil Açıldığında > Bekle 3 sn > Ekran Görüntüsü Al > Kurye Kazanç'a ekran görüntüsü gönder".

- [ ] Steps: uygula, CI, commit `feat: Kisayollar icin ekran goruntusu gonderme eylemi`.

---

### Task 7: Sürüm 1.4.0, notlar ve yayın

**Files:** `project.yml` (`MARKETING_VERSION: "1.4.0"`), `TESTFLIGHT_NOTES.md` (en üste `## 1.4.0` bölümü: yeni okuma motoru, kazanç taraması nasıl kullanılır, Kısayollar eylemi, "Lütfen test et" listesi — masaüstündeki senaryo görselleriyle ve varsa gerçek platform ekranlarıyla), `PROGRESS.md` (oturum bölümü), `supabase/README.md` (değişiklik yok, kontrol).

- [ ] Steps: belgeleri yaz, commit, push develop, CI yeşil; `develop → main` PR aç (UI testleri PR'da). Birleştirme kullanıcıya bırakılır (otomatik mod `main` birleştirmesini engelliyor); birleşince `ios-release.yml` TestFlight 1.4.0'ı yükler (tetiklenmezse `gh workflow run ios-release.yml --ref main`).
