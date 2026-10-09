# Sürüm 1.3 — Sunucu temeli (Supabase) — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supabase (Frankfurt) üzerinde şema/RLS/fonksiyonlar + testler; uygulamada anonim oturum, rızaya bağlı vardiya gönderim kuyruğu, uzaktan şablonlar, kalibrasyon gönderimi, Apple ile Giriş + yedek/geri yükleme, "Verilerimi sil", KVKK metin taslakları.

**Architecture:** Kurallar saf Core'da (`Core/Sync`, SHA-256, şablon birleştirme; Windows'ta TDD). Ağ katmanı kendi küçük REST istemcimiz (`Services/Sync/SupabaseClient`, URLSession; GoTrue + PostgREST). Sunucu tarafında doğrudan tablo erişimi yok; yazma `SECURITY DEFINER` RPC'lerle. Sunucu şeması `supabase/migrations/*.sql`, testleri `supabase/tests/*.sql` (pgTAP) ve `scripts/server/*.mjs` (Node) — Management API'nin SQL ucu ile gerçek projeye karşı çalışır (Docker yok).

**Tech Stack:** Swift 5 modu, SwiftUI, SwiftData, AuthenticationServices, Security (Keychain), URLSession, iOS 17; Supabase (Postgres 15+, pgTAP), Node 24 (yerleşik `fetch`).

**Spec:** `docs/superpowers/specs/2026-10-09-surum-1-3-sunucu-design.md` (üst tasarım: `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md`)

## Global Constraints

- Yeni üçüncü taraf bağımlılık **yok** (Swift); Node betikleri yalnızca yerleşik modüller (`fetch`, `fs`, `crypto`).
- `KuryeKazanc/Core` yalnızca `Foundation` import eder.
- iOS kodu bu makinede derlenmez; push/CI **görevler sırasında yok**. İlk derleme (1.2 + 1.3) son görevden sonra kontrolcü tarafından yapılır. Her görev derleme odaklı bağımsız incelemeden geçer.
- Paylaşım (`dataSharingOptIn`), kalibrasyon (`calibrationOptIn`) kapalı ve Apple ile giriş yokken **hiçbir ağ isteği yapılmaz**.
- Gönderilen seviyeler yalnızca `verified` ve `ocrUnverified`; `manual`/`ocrEdited` asla gönderilmez.
- Görsel asla gönderilmez; kalibrasyonda yalnızca maskelenmiş satırlar + kutular.
- Sunucuda kullanıcı başına günlük sınır: 40 vardiya, 20 kalibrasyon örneği.
- Gizli bilgi repoya girmez: Supabase **anon** anahtarı ve proje URL'si gizli değildir (Info.plist'te); `service_role` anahtarı, veritabanı şifresi, Management API erişim belirteci asla repoya yazılmaz (betikler `SUPABASE_ACCESS_TOKEN` ortam değişkeninden okur).
- Yorumlar ASCII Türkçe; kullanıcı metinleri doğru Türkçe; büyük `body` ve uzun zincirli ifade yok.

## Review Focus

1. **Rıza kapalıyken ağ:** Paylaşım kapalı bir kullanıcı kayıt eklediğinde hiçbir istek atılmamalı. → Görev 6 testi (`SyncCoordinator` sahte istemciyle çağrı sayısı 0).
2. **Başkasının verisi:** Kullanıcı A, B'nin `backups` satırını okuyamamalı; anonim kullanıcı `backups`'a yazamamalı; `shifts` hiç okunamamalı. → Görev 3 pgTAP testleri.
3. **Aynı ekran görüntüsü:** Aynı `text_hash` ikinci kez `'duplicate'` döner; yerel kayıt tekrar denenmez. → Görev 3 + Görev 5/6 testleri.
4. **Geri yükleme yinelemesi:** Geri yükleme mevcut kayıtları ikilememeli (id üzerinden birleştirme). → Görev 7 testi.
5. **Rıza geri çekilince kuyruk:** Paylaşım kapatılınca bekleyen gönderimler silinmeli, gönderilmemeli. → Görev 6 testi.

---

## Dosya yapısı

| Dosya | Sorumluluk |
|---|---|
| `KuryeKazanc/Core/Sync/SHA256.swift` | Saf Swift SHA-256 + hex |
| `KuryeKazanc/Core/OCR/TextHash.swift` (değişir) | `sha256(_ lines:)` eklenir |
| `KuryeKazanc/Core/Sync/ShiftPayload.swift` | Gönderim yükü ve kayıttan dönüşüm kuralları |
| `KuryeKazanc/Core/Sync/OutboxPolicy.swift` | Yeniden deneme ve sonuç kuralları |
| `KuryeKazanc/Core/Sync/CalibrationMasker.swift` | Kişisel veri maskesi |
| `KuryeKazanc/Core/OCR/TemplateMerger.swift` | Gömülü + uzak şablon birleştirme |
| `supabase/migrations/20261009000001_init.sql` | Tablolar, RLS, fonksiyonlar, izinler, şablon tohumları |
| `supabase/tests/001_rls_and_functions.sql` | pgTAP testleri (`tests` şeması, `runtests`) |
| `scripts/server/apply.mjs`, `test.mjs`, `e2e.mjs`, `lib.mjs` | Göç uygulama, SQL testleri, uçtan uca |
| `KuryeKazanc/Services/Sync/SupabaseConfig.swift` | Info.plist'ten URL + anon anahtar |
| `KuryeKazanc/Services/Sync/KeychainStore.swift` | Oturumun Keychain'de saklanması |
| `KuryeKazanc/Services/Sync/SupabaseClient.swift` | Auth + RPC + tablo istekleri |
| `KuryeKazanc/Services/Sync/OutboxQueue.swift` | Bekleyen gönderimler (dosya) |
| `KuryeKazanc/Services/Sync/SyncCoordinator.swift` | Rıza/kayıt → kuyruk → gönderim; şablon yenileme; kalibrasyon |
| `KuryeKazanc/Services/Sync/AccountService.swift` | Apple ile Giriş, çıkış, verilerimi sil |
| `KuryeKazanc/Services/Sync/BackupService.swift` | Yedek yükü, yükleme, geri yükleme |
| `KuryeKazanc/Views/Profile/AccountSection.swift`, `CalibrationSection.swift`, `PrivacyView.swift` | Profil arayüzü |
| `docs/legal/kvkk-aydinlatma-taslak.md`, `docs/legal/acik-riza-taslak.md` | KVKK taslakları |

---

### Task 1: Core — SHA-256 ve metin özeti

**Files:**
- Create: `KuryeKazanc/Core/Sync/SHA256.swift`
- Modify: `KuryeKazanc/Core/OCR/TextHash.swift`
- Test: `KuryeKazancTests/Core/SHA256Tests.swift`

**Interfaces:**
- Produces: `enum SHA256 { static func digest(_ data: [UInt8]) -> [UInt8]; static func hex(_ string: String) -> String }`; `TextHash.sha256(_ lines: [String]) -> String` (normalize + boş satır at + "\n" ile birleştir + SHA-256 hex; metin yoksa `""`).

- [ ] **Step 1: Başarısız test**

```swift
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
```

- [ ] **Step 2:** Run: `swift test --filter SHA256Tests` → Expected: `cannot find 'SHA256' in scope`.

- [ ] **Step 3: `SHA256.swift`**

```swift
import Foundation

/// Saf Swift SHA-256 (FIPS 180-4). Core Windows'ta derlendigi icin CryptoKit kullanilmaz.
/// Sunucuya giden `text_hash` icin; guvenlik amacli anahtar turetmede kullanilmaz.
enum SHA256 {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }

    static func digest(_ data: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ]
        var message = data
        let bitLength = UInt64(data.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 {
            message.append(0)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
        }

        var w = [UInt32](repeating: 0, count: 64)
        var blockStart = 0
        while blockStart < message.count {
            for i in 0..<16 {
                let j = blockStart + i * 4
                let b0 = UInt32(message[j]) << 24
                let b1 = UInt32(message[j + 1]) << 16
                let b2 = UInt32(message[j + 2]) << 8
                let b3 = UInt32(message[j + 3])
                w[i] = b0 | b1 | b2 | b3
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = s0 &+ maj
                hh = g; g = f; f = e; e = d &+ t1
                d = c; c = b; b = a; a = t1 &+ t2
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
            blockStart += 64
        }

        var out: [UInt8] = []
        out.reserveCapacity(32)
        for value in h {
            out.append(UInt8((value >> 24) & 0xff))
            out.append(UInt8((value >> 16) & 0xff))
            out.append(UInt8((value >> 8) & 0xff))
            out.append(UInt8(value & 0xff))
        }
        return out
    }

    static func hex(_ string: String) -> String {
        let bytes = digest(Array(string.utf8))
        var result = ""
        for byte in bytes {
            let part = String(byte, radix: 16)
            result += part.count == 1 ? "0" + part : part
        }
        return result
    }
}
```

- [ ] **Step 4:** `TextHash.swift` içine (mevcut `of(_:)` aynı kalır; normalize kısmı ortak yardımcıya alınabilir):

```swift
    /// Sunucuya giden `text_hash` (spec 4.3): ayni normalize metnin SHA-256 ozeti, 64 karakter hex.
    static func sha256(_ lines: [String]) -> String {
        var normalized: [String] = []
        for line in lines {
            let text = TextNormalizer.normalize(line)
            if !text.isEmpty { normalized.append(text) }
        }
        guard !normalized.isEmpty else { return "" }
        return SHA256.hex(normalized.joined(separator: "\n"))
    }
```

- [ ] **Step 5:** Run: `swift test` → PASS. **Step 6: Commit** `feat(core): saf Swift SHA-256 ve sunucu metin ozeti`

---

### Task 2: Core — gönderim yükü, kuyruk kuralları, maskeleme, şablon birleştirme

**Files:**
- Create: `KuryeKazanc/Core/Sync/ShiftPayload.swift`, `OutboxPolicy.swift`, `CalibrationMasker.swift`, `KuryeKazanc/Core/OCR/TemplateMerger.swift`
- Test: `KuryeKazancTests/Core/SyncRulesTests.swift`

**Interfaces:**
- Produces:
  - `struct ShiftPayload: Codable, Equatable { var clientRecordID: String; var platformCode: String; var province: String?; var district: String?; var vehicle: String; var weekday: Int; var startSlot: Int; var durationMin: Int; var gross: Double; var bonus: Double; var packages: Int?; var distanceKm: Double; var level: String; var templateID: String?; var templateVersion: Int?; var textHash: String }` (JSON anahtarları snake_case: `client_record_id`, `platform_code`, `province`, `district`, `vehicle`, `weekday`, `start_slot`, `duration_min`, `gross`, `bonus`, `packages`, `distance_km`, `level`, `template_id`, `template_version`, `text_hash`).
  - `enum ShiftPayloadBuilder { static func make(recordID: UUID, platformCode: String?, province: String?, district: String?, vehicle: String, start: Date, end: Date, gross: Double, bonus: Double, packages: Int?, distanceKm: Double, level: String, templateID: String?, templateVersion: Int?, textHash: String, calendar: Calendar) -> ShiftPayload? }` — `nil` döner: level `verified`/`ocrUnverified` değilse, platform kodu yoksa veya `"other"` ise, textHash boşsa, süre ≤ 0 ise.
  - `enum OutboxResult: String, Codable { case ok, duplicate, rateLimited = "rate_limited", invalid, transient }`; `enum OutboxPolicy { static func isFinal(_ r: OutboxResult) -> Bool; static func nextAttempt(after failures: Int, now: Date) -> Date }` — `ok`/`duplicate`/`invalid` kalıcı; `rateLimited` → ertesi gün 00:05 yerel; `transient` → `min(60 * 2^(failures-1), 21600)` sn sonra.
  - `enum CalibrationMasker { static func mask(_ text: String) -> String }`.
  - `enum TemplateMerger { static func merge(bundled: [OCRTemplate], remote: [OCRTemplate]) -> [OCRTemplate] }` — aynı `id` için yüksek `version` kazanır; yalnızca uzakta olanlar eklenir; sıra: gömülü sırası, sonra yeni uzaklar.

- [ ] **Step 1: Başarısız testler**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class SyncRulesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func make(level: String = "ocrUnverified", platform: String? = "getir", hash: String = "abc", end: Date? = nil) -> ShiftPayload? {
        ShiftPayloadBuilder.make(
            recordID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, platformCode: platform,
            province: "İstanbul", district: "Kadıköy", vehicle: "motorcycle",
            start: date(5, 18, 37), end: end ?? date(5, 21, 10), gross: 900, bonus: 100, packages: 12,
            distanceKm: 41.3, level: level, templateID: "getir.earnings", templateVersion: 1, textHash: hash,
            calendar: calendar
        )
    }

    func testPayloadRoundsAndBuckets() throws {
        let p = try XCTUnwrap(make())
        XCTAssertEqual(p.weekday, 1, "5 Ekim 2026 Pazartesi")
        XCTAssertEqual(p.startSlot, 18 * 4 + 2, "18:37 -> 18:30 dilimi")
        XCTAssertEqual(p.durationMin, 153)
        XCTAssertEqual(p.distanceKm, 41.5, "0,5'e yuvarlanir")
        XCTAssertEqual(p.clientRecordID, "00000000-0000-0000-0000-000000000001")
    }

    func testOnlyEligibleRecordsProducePayload() {
        XCTAssertNotNil(make(level: "verified"))
        XCTAssertNil(make(level: "manual"))
        XCTAssertNil(make(level: "ocrEdited"))
        XCTAssertNil(make(platform: nil))
        XCTAssertNil(make(platform: "other"))
        XCTAssertNil(make(hash: ""))
        XCTAssertNil(make(end: date(5, 18, 37)))
    }

    func testPayloadJSONUsesSnakeCase() throws {
        let p = try XCTUnwrap(make())
        let json = String(decoding: try JSONEncoder().encode(p), as: UTF8.self)
        XCTAssertTrue(json.contains("\"start_slot\""))
        XCTAssertTrue(json.contains("\"text_hash\""))
        XCTAssertTrue(json.contains("\"client_record_id\""))
    }

    func testOutboxPolicy() {
        XCTAssertTrue(OutboxPolicy.isFinal(.ok))
        XCTAssertTrue(OutboxPolicy.isFinal(.duplicate))
        XCTAssertTrue(OutboxPolicy.isFinal(.invalid))
        XCTAssertFalse(OutboxPolicy.isFinal(.transient))
        XCTAssertFalse(OutboxPolicy.isFinal(.rateLimited))
        let now = date(8, 12)
        XCTAssertEqual(OutboxPolicy.nextAttempt(after: 1, now: now), now.addingTimeInterval(60))
        XCTAssertEqual(OutboxPolicy.nextAttempt(after: 3, now: now), now.addingTimeInterval(240))
        XCTAssertEqual(OutboxPolicy.nextAttempt(after: 20, now: now), now.addingTimeInterval(21_600))
    }

    func testMasker() {
        XCTAssertEqual(CalibrationMasker.mask("IBAN TR33 0006 1005 1978 6457 8413 26"), "IBAN ***")
        XCTAssertEqual(CalibrationMasker.mask("TR330006100519786457841326"), "***")
        XCTAssertEqual(CalibrationMasker.mask("Tel: 0532 123 45 67"), "Tel: ***")
        XCTAssertEqual(CalibrationMasker.mask("+90 532 123 4567"), "***")
        XCTAssertEqual(CalibrationMasker.mask("TC 12345678901"), "TC ***")
        XCTAssertEqual(CalibrationMasker.mask("ali.veli@ornek.com"), "***")
        XCTAssertEqual(CalibrationMasker.mask("Toplam Kazanç ₺980,00"), "Toplam Kazanç ₺980,00", "Tutarlar korunur")
        XCTAssertEqual(CalibrationMasker.mask("Sipariş Sayısı 11"), "Sipariş Sayısı 11")
    }

    func testTemplateMerger() {
        var newer = BundledTemplates.template(id: "getir.earnings")!
        newer.version = 2
        newer.status = .active
        var older = BundledTemplates.template(id: "trendyol_go.earnings")!
        older.version = 0
        var extra = BundledTemplates.generic
        extra.id = "bolt.earnings"
        extra.platformCode = "bolt"
        let merged = TemplateMerger.merge(bundled: BundledTemplates.all, remote: [newer, older, extra])
        XCTAssertEqual(merged.count, BundledTemplates.all.count + 1)
        XCTAssertEqual(merged.first { $0.id == "getir.earnings" }?.version, 2)
        XCTAssertEqual(merged.first { $0.id == "trendyol_go.earnings" }?.version, 1, "Eski uzak surum gomuluyu ezmez")
        XCTAssertEqual(merged.last?.id, "bolt.earnings")
    }
}
```

- [ ] **Step 2:** Run: `swift test --filter SyncRulesTests` → Expected: derleme hatası (`ShiftPayload` yok).

- [ ] **Step 3: `ShiftPayload.swift`**

```swift
import Foundation

/// Sunucuya giden vardiya (spec 3). Kisi/konum bilgisi yok: il/ilce, hafta gunu, 15 dk dilim, yuvarlanmis km.
struct ShiftPayload: Codable, Equatable {
    var clientRecordID: String
    var platformCode: String
    var province: String?
    var district: String?
    var vehicle: String
    var weekday: Int
    var startSlot: Int
    var durationMin: Int
    var gross: Double
    var bonus: Double
    var packages: Int?
    var distanceKm: Double
    var level: String
    var templateID: String?
    var templateVersion: Int?
    var textHash: String

    enum CodingKeys: String, CodingKey {
        case clientRecordID = "client_record_id"
        case platformCode = "platform_code"
        case province, district, vehicle, weekday
        case startSlot = "start_slot"
        case durationMin = "duration_min"
        case gross, bonus, packages
        case distanceKm = "distance_km"
        case level
        case templateID = "template_id"
        case templateVersion = "template_version"
        case textHash = "text_hash"
    }
}

enum ShiftPayloadBuilder {
    static let sendableLevels: Set<String> = ["verified", "ocrUnverified"]

    static func make(
        recordID: UUID, platformCode: String?, province: String?, district: String?, vehicle: String,
        start: Date, end: Date, gross: Double, bonus: Double, packages: Int?, distanceKm: Double,
        level: String, templateID: String?, templateVersion: Int?, textHash: String, calendar: Calendar
    ) -> ShiftPayload? {
        guard sendableLevels.contains(level) else { return nil }
        guard let platformCode, platformCode != "other", !platformCode.isEmpty else { return nil }
        guard !textHash.isEmpty, end > start else { return nil }

        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: start)
        // Pazartesi = 1 ... Pazar = 7
        let weekday = ((parts.weekday ?? 2) + 5) % 7 + 1
        let slot = (parts.hour ?? 0) * 4 + (parts.minute ?? 0) / 15
        let minutes = Int((end.timeIntervalSince(start) / 60).rounded())
        let roundedKm = (max(0, distanceKm) * 2).rounded() / 2

        return ShiftPayload(
            clientRecordID: recordID.uuidString.lowercased(), platformCode: platformCode,
            province: province, district: district, vehicle: vehicle, weekday: weekday, startSlot: slot,
            durationMin: minutes, gross: gross, bonus: bonus, packages: packages, distanceKm: roundedKm,
            level: level, templateID: templateID, templateVersion: templateVersion, textHash: textHash
        )
    }
}
```

Not: testte beklenen `clientRecordID` büyük harfli UUID'nin küçük harf hali; test `"00000000-0000-0000-0000-000000000001"` zaten rakam olduğundan aynı.

- [ ] **Step 4: `OutboxPolicy.swift`**

```swift
import Foundation

/// Sunucu yaniti (submit_shift / submit_calibration) ve ag hatalari.
enum OutboxResult: String, Codable {
    case ok
    case duplicate
    case rateLimited = "rate_limited"
    case invalid
    case transient
}

enum OutboxPolicy {
    /// Kalici sonuc: oge kuyruktan duser.
    static func isFinal(_ result: OutboxResult) -> Bool {
        result == .ok || result == .duplicate || result == .invalid
    }

    /// Ussel bekleme: 1 dk, 2 dk, 4 dk ... en fazla 6 saat.
    static func nextAttempt(after failures: Int, now: Date) -> Date {
        let exponent = max(0, min(failures - 1, 20))
        let seconds = min(60 * pow(2.0, Double(exponent)), 21_600)
        return now.addingTimeInterval(seconds)
    }

    /// Gunluk sinir: ertesi gun 00:05 (yerel).
    static func nextDay(after now: Date, calendar: Calendar) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return tomorrow.addingTimeInterval(300)
    }
}
```

- [ ] **Step 5: `CalibrationMasker.swift`**

```swift
import Foundation

/// Kalibrasyon orneginden kisisel veriyi siler (spec 4.4): IBAN, telefon, TC kimlik no, e-posta.
/// Tutarlar ve etiketler korunur.
enum CalibrationMasker {
    private static let patterns: [String] = [
        // IBAN: TR + 24 hane (bosluklu veya bitisik)
        "TR\\s?\\d{2}(?:\\s?\\d){22}",
        // E-posta
        "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
        // Telefon: +90 veya 0 ile baslayan 10 haneli mobil/sabit
        "(?:\\+90\\s?|0)\\(?\\d{3}\\)?[\\s-]?\\d{3}[\\s-]?\\d{2}[\\s-]?\\d{2}",
        // TC kimlik no: 11 hane
        "(?<!\\d)\\d{11}(?!\\d)",
    ]

    static func mask(_ text: String) -> String {
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "***")
        }
        return result
    }
}
```

(IBAN testindeki "TR33 0006 1005 1978 6457 8413 26": `TR` + `33` + 22 hane = 24 hane. Telefon "0532 123 45 67" ve "+90 532 123 4567" desenle eşleşir; uygulayıcı testleri çalıştırıp deseni gerekirse en küçük değişiklikle düzeltir ve raporlar.)

- [ ] **Step 6: `TemplateMerger.swift`**

```swift
import Foundation

/// Gomulu ve sunucudan gelen sablonlari birlestirir (spec 4.4). Ayni id icin yuksek surum kazanir.
enum TemplateMerger {
    static func merge(bundled: [OCRTemplate], remote: [OCRTemplate]) -> [OCRTemplate] {
        var best: [String: OCRTemplate] = [:]
        for template in remote {
            if let existing = best[template.id], existing.version >= template.version { continue }
            best[template.id] = template
        }
        var result: [OCRTemplate] = []
        var used: Set<String> = []
        for template in bundled {
            if let candidate = best[template.id], candidate.version > template.version {
                result.append(candidate)
            } else {
                result.append(template)
            }
            used.insert(template.id)
        }
        for template in remote where !used.contains(template.id) {
            if let chosen = best[template.id], chosen == template {
                result.append(template)
                used.insert(template.id)
            }
        }
        return result
    }
}
```

- [ ] **Step 7:** Run: `swift test` → PASS. **Step 8: Commit** `feat(core): gonderim yuku, kuyruk kurallari, kalibrasyon maskesi, sablon birlestirme`

---

### Task 3: Sunucu şeması, pgTAP testleri ve Node betikleri

**Files:**
- Create: `supabase/migrations/20261009000001_init.sql`
- Create: `supabase/tests/001_rls_and_functions.sql`
- Create: `scripts/server/lib.mjs`, `scripts/server/apply.mjs`, `scripts/server/test.mjs`, `scripts/server/e2e.mjs`, `scripts/server/seed_templates.mjs`
- Create: `supabase/README.md`

**Interfaces:**
- Produces (SQL): tablolar `public.shifts`, `public.ocr_templates`, `public.calibration_samples`, `public.backups`; fonksiyonlar `public.submit_shift(payload jsonb) returns text`, `public.submit_calibration(payload jsonb) returns text`, `public.delete_my_data() returns void`; `tests` şemasında `test_*` pgTAP fonksiyonları.
- Produces (Node): `node scripts/server/apply.mjs` (göçleri sırayla, `public.schema_migrations` ile bir kez), `node scripts/server/test.mjs` (pgTAP `runtests('tests')`, başarısızlıkta çıkış kodu 1), `node scripts/server/e2e.mjs` (anon anahtarla uçtan uca), `node scripts/server/seed_templates.mjs` (gömülü JSON şablonları `ocr_templates`'e yazar). Ortam değişkenleri: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.

**Bu görevde gerçek projeye bağlanılmaz** (proje henüz yok): dosyalar yazılır, `node --check` ile sözdizimi doğrulanır. Gerçek çalıştırmayı kontrolcü proje kurulduktan sonra yapar.

- [ ] **Step 1: `supabase/migrations/20261009000001_init.sql`**

```sql
-- Kurye Kazanc 1.3: sunucu semasi (spec 2026-10-09 §3).
-- Dogrudan tablo erisimi yok; yazma SECURITY DEFINER fonksiyonlarla.

create extension if not exists pgtap with schema extensions;

create table if not exists public.shifts (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    client_record_id uuid not null,
    platform_code text not null check (platform_code ~ '^[a-z_]{2,32}$'),
    province text check (char_length(province) <= 64),
    district text check (char_length(district) <= 64),
    vehicle text not null check (vehicle in ('motorcycle','scooter','bicycle','car','onFoot')),
    weekday smallint not null check (weekday between 1 and 7),
    start_slot smallint not null check (start_slot between 0 and 95),
    duration_min integer not null check (duration_min between 1 and 1200),
    gross numeric(10,2) not null check (gross >= 0 and gross <= 100000),
    bonus numeric(10,2) not null default 0 check (bonus >= 0 and bonus <= 100000),
    packages integer check (packages is null or packages between 0 and 500),
    distance_km numeric(6,1) not null default 0 check (distance_km >= 0 and distance_km <= 1500),
    level text not null check (level in ('verified','ocrUnverified')),
    template_id text,
    template_version integer,
    text_hash text not null unique check (text_hash ~ '^[0-9a-f]{64}$'),
    created_at timestamptz not null default now()
);
create index if not exists shifts_user_created on public.shifts (user_id, created_at);

create table if not exists public.ocr_templates (
    id text not null,
    platform_code text not null,
    version integer not null check (version >= 1),
    status text not null check (status in ('calibrating','active')),
    body jsonb not null,
    updated_at timestamptz not null default now(),
    primary key (id, version)
);

create table if not exists public.calibration_samples (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    platform_code text,
    template_id text,
    lines jsonb not null check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) between 1 and 200),
    created_at timestamptz not null default now()
);
create index if not exists calibration_user_created on public.calibration_samples (user_id, created_at);

create table if not exists public.backups (
    user_id uuid primary key references auth.users(id) on delete cascade,
    payload jsonb not null,
    updated_at timestamptz not null default now()
);

alter table public.shifts enable row level security;
alter table public.ocr_templates enable row level security;
alter table public.calibration_samples enable row level security;
alter table public.backups enable row level security;

-- Sablonlar herkese acik okunur
drop policy if exists templates_read on public.ocr_templates;
create policy templates_read on public.ocr_templates for select to anon, authenticated using (true);

-- Yedek: yalnizca sahibi ve anonim olmayan kullanici
drop policy if exists backups_owner_select on public.backups;
create policy backups_owner_select on public.backups for select to authenticated
    using (user_id = auth.uid());
drop policy if exists backups_owner_insert on public.backups;
create policy backups_owner_insert on public.backups for insert to authenticated
    with check (user_id = auth.uid() and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
drop policy if exists backups_owner_update on public.backups;
create policy backups_owner_update on public.backups for update to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid() and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
drop policy if exists backups_owner_delete on public.backups;
create policy backups_owner_delete on public.backups for delete to authenticated
    using (user_id = auth.uid());

-- shifts ve calibration_samples icin hicbir politika yok: dogrudan erisim kapali.
revoke all on public.shifts from anon, authenticated;
revoke all on public.calibration_samples from anon, authenticated;
grant select on public.ocr_templates to anon, authenticated;
grant select, insert, update, delete on public.backups to authenticated;

create or replace function public.submit_shift(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    uid uuid := auth.uid();
    today_count integer;
begin
    if uid is null then
        return 'invalid';
    end if;
    select count(*) into today_count from public.shifts
        where user_id = uid and created_at >= date_trunc('day', now());
    if today_count >= 40 then
        return 'rate_limited';
    end if;
    begin
        insert into public.shifts (
            user_id, client_record_id, platform_code, province, district, vehicle, weekday, start_slot,
            duration_min, gross, bonus, packages, distance_km, level, template_id, template_version, text_hash
        ) values (
            uid,
            (payload ->> 'client_record_id')::uuid,
            payload ->> 'platform_code',
            nullif(payload ->> 'province', ''),
            nullif(payload ->> 'district', ''),
            payload ->> 'vehicle',
            (payload ->> 'weekday')::smallint,
            (payload ->> 'start_slot')::smallint,
            (payload ->> 'duration_min')::integer,
            (payload ->> 'gross')::numeric,
            coalesce((payload ->> 'bonus')::numeric, 0),
            (payload ->> 'packages')::integer,
            coalesce((payload ->> 'distance_km')::numeric, 0),
            payload ->> 'level',
            payload ->> 'template_id',
            (payload ->> 'template_version')::integer,
            payload ->> 'text_hash'
        );
    exception
        when unique_violation then
            return 'duplicate';
        when check_violation or not_null_violation or invalid_text_representation
             or numeric_value_out_of_range or invalid_parameter_value then
            return 'invalid';
    end;
    return 'ok';
end;
$$;

create or replace function public.submit_calibration(payload jsonb)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    uid uuid := auth.uid();
    today_count integer;
begin
    if uid is null then
        return 'invalid';
    end if;
    select count(*) into today_count from public.calibration_samples
        where user_id = uid and created_at >= date_trunc('day', now());
    if today_count >= 20 then
        return 'rate_limited';
    end if;
    begin
        insert into public.calibration_samples (user_id, platform_code, template_id, lines)
        values (uid, payload ->> 'platform_code', payload ->> 'template_id', payload -> 'lines');
    exception
        when check_violation or not_null_violation then
            return 'invalid';
    end;
    return 'ok';
end;
$$;

create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        return;
    end if;
    delete from public.shifts where user_id = uid;
    delete from public.calibration_samples where user_id = uid;
    delete from public.backups where user_id = uid;
end;
$$;

revoke all on function public.submit_shift(jsonb) from public, anon;
revoke all on function public.submit_calibration(jsonb) from public, anon;
revoke all on function public.delete_my_data() from public, anon;
grant execute on function public.submit_shift(jsonb) to authenticated;
grant execute on function public.submit_calibration(jsonb) to authenticated;
grant execute on function public.delete_my_data() to authenticated;
```

- [ ] **Step 2: `supabase/tests/001_rls_and_functions.sql`** (pgTAP; `runtests('tests')` her `test_*` fonksiyonunu geri alınan bir işlemde çalıştırır)

```sql
-- pgTAP testleri: node scripts/server/test.mjs ile calistirilir.
create schema if not exists tests;

create or replace function tests._login(uid uuid, anonymous boolean)
returns void language plpgsql as $$
begin
    perform set_config('request.jwt.claims',
        json_build_object('sub', uid, 'role', 'authenticated', 'is_anonymous', anonymous)::text, true);
    perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function tests._logout()
returns void language plpgsql as $$
begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function tests._user(uid uuid, anonymous boolean)
returns void language plpgsql as $$
begin
    insert into auth.users (id, instance_id, aud, role, email, is_anonymous, created_at, updated_at)
    values (uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            case when anonymous then null else uid::text || '@test.local' end, anonymous, now(), now())
    on conflict (id) do nothing;
end;
$$;

create or replace function tests._payload(hash text)
returns jsonb language sql as $$
    select jsonb_build_object(
        'client_record_id', gen_random_uuid(), 'platform_code', 'getir', 'province', 'İstanbul',
        'district', 'Kadıköy', 'vehicle', 'motorcycle', 'weekday', 1, 'start_slot', 74,
        'duration_min', 153, 'gross', 900, 'bonus', 100, 'packages', 12, 'distance_km', 41.5,
        'level', 'ocrUnverified', 'template_id', 'getir.earnings', 'template_version', 1,
        'text_hash', hash)
$$;

create or replace function tests.test_submit_shift_ok_and_duplicate()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    h text := repeat('a', 64);
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is(public.submit_shift(tests._payload(h)), 'ok', 'ilk gonderim kabul');
    return next is(public.submit_shift(tests._payload(h)), 'duplicate', 'ayni text_hash reddedilir');
    perform tests._logout();
end;
$$;

create or replace function tests.test_submit_shift_rejects_invalid()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    return next is(public.submit_shift(tests._payload(repeat('b', 64)) || '{"level":"manual"}'), 'invalid', 'manual seviye gonderilemez');
    return next is(public.submit_shift(tests._payload('kisa')), 'invalid', 'gecersiz hash');
    return next is(public.submit_shift(tests._payload(repeat('c', 64)) || '{"weekday":9}'), 'invalid', 'gecersiz hafta gunu');
    perform tests._logout();
end;
$$;

create or replace function tests.test_rate_limit()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    i integer;
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    for i in 1..40 loop
        perform public.submit_shift(tests._payload(lpad(to_hex(i), 64, '0')));
    end loop;
    return next is(public.submit_shift(tests._payload(repeat('d', 64))), 'rate_limited', 'gunde 40 sinir');
    perform tests._logout();
end;
$$;

create or replace function tests.test_shifts_not_readable()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
begin
    perform tests._user(a, true);
    perform tests._login(a, true);
    perform public.submit_shift(tests._payload(repeat('e', 64)));
    return next throws_ok('select count(*) from public.shifts', '42501', null, 'shifts dogrudan okunamaz');
    return next throws_ok('select count(*) from public.calibration_samples', '42501', null, 'kalibrasyon okunamaz');
    perform tests._logout();
end;
$$;

create or replace function tests.test_backups_owner_only()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    b uuid := gen_random_uuid();
    anon uuid := gen_random_uuid();
begin
    perform tests._user(a, false);
    perform tests._user(b, false);
    perform tests._user(anon, true);

    perform tests._login(a, false);
    insert into public.backups (user_id, payload) values (a, '{"v":1}');
    perform tests._login(b, false);
    return next is((select count(*)::int from public.backups), 0, 'B, A''nin yedegini goremez');
    return next throws_ok(
        format('insert into public.backups (user_id, payload) values (%L, %L)', a, '{"x":1}'),
        '42501', null, 'B, A adina yazamaz');
    perform tests._login(anon, true);
    return next throws_ok(
        format('insert into public.backups (user_id, payload) values (%L, %L)', anon, '{"x":1}'),
        '42501', null, 'anonim kullanici yedek yazamaz');
    perform tests._login(a, false);
    return next is((select count(*)::int from public.backups), 1, 'A kendi yedegini gorur');
    perform tests._logout();
end;
$$;

create or replace function tests.test_delete_my_data()
returns setof text language plpgsql as $$
declare
    a uuid := gen_random_uuid();
    b uuid := gen_random_uuid();
begin
    perform tests._user(a, false);
    perform tests._user(b, false);
    perform tests._login(b, false);
    perform public.submit_shift(tests._payload(repeat('f', 64)));
    perform tests._login(a, false);
    perform public.submit_shift(tests._payload(repeat('1', 64)));
    insert into public.backups (user_id, payload) values (a, '{"v":1}');
    perform public.delete_my_data();
    perform tests._logout();
    return next is((select count(*)::int from public.shifts where user_id = a), 0, 'A vardiyalari silindi');
    return next is((select count(*)::int from public.backups where user_id = a), 0, 'A yedegi silindi');
    return next is((select count(*)::int from public.shifts where user_id = b), 1, 'B dokunulmadi');
end;
$$;

create or replace function tests.test_templates_public_read()
returns setof text language plpgsql as $$
begin
    insert into public.ocr_templates (id, platform_code, version, status, body)
    values ('test.earnings', 'test', 1, 'calibrating', '{}')
    on conflict do nothing;
    perform set_config('role', 'anon', true);
    return next ok((select count(*) from public.ocr_templates where id = 'test.earnings') = 1, 'anon sablon okur');
    return next throws_ok($q$insert into public.ocr_templates (id, platform_code, version, status, body) values ('x','x',1,'active','{}')$q$,
        '42501', null, 'anon sablon yazamaz');
    perform tests._logout();
end;
$$;
```

- [ ] **Step 3: `scripts/server/lib.mjs`**

```js
// Ortak yardimcilar: Management API SQL ucu ve REST cagrilari. Gizli degerler yalnizca ortam degiskeninden.
export function env(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Eksik ortam degiskeni: ${name}`);
    process.exit(2);
  }
  return value;
}

export async function sql(query) {
  const ref = env('SUPABASE_PROJECT_REF');
  const token = env('SUPABASE_ACCESS_TOKEN');
  const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`SQL hatasi ${res.status}: ${text}`);
  return text ? JSON.parse(text) : [];
}
```

- [ ] **Step 4: `scripts/server/apply.mjs`**

```js
// supabase/migrations/*.sql dosyalarini sirayla, bir kez uygular.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { sql } from './lib.mjs';

const dir = 'supabase/migrations';
await sql('create table if not exists public.schema_migrations (name text primary key, applied_at timestamptz default now())');
await sql('revoke all on public.schema_migrations from anon, authenticated');
const done = new Set((await sql('select name from public.schema_migrations')).map((r) => r.name));
for (const name of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
  if (done.has(name)) { console.log(`atlandi: ${name}`); continue; }
  await sql(readFileSync(join(dir, name), 'utf8'));
  await sql(`insert into public.schema_migrations (name) values ('${name.replace(/'/g, "''")}')`);
  console.log(`uygulandi: ${name}`);
}
```

- [ ] **Step 5: `scripts/server/test.mjs`**

```js
// pgTAP testlerini yukler ve calistirir. Basarisizlikta cikis kodu 1.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { sql } from './lib.mjs';

const dir = 'supabase/tests';
for (const name of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
  await sql(readFileSync(join(dir, name), 'utf8'));
}
const rows = await sql("select * from extensions.runtests('tests'::name)");
const lines = rows.map((r) => Object.values(r)[0]);
for (const line of lines) console.log(line);
const failed = lines.filter((l) => /^\s*not ok/.test(l));
console.log(failed.length === 0 ? 'TUM TESTLER GECTI' : `${failed.length} TEST BASARISIZ`);
process.exit(failed.length === 0 ? 0 : 1);
```

- [ ] **Step 6: `scripts/server/e2e.mjs`** — anon anahtarla gerçek uçlar: anonim kayıt (`POST /auth/v1/signup` gövde `{}`), `rpc/submit_shift` (`ok`, aynı hash ile `duplicate`), `GET /rest/v1/shifts` (okunamaz: 401/403/404 ya da boş değil hata), `GET /rest/v1/ocr_templates` (≥4 satır), `rpc/delete_my_data` (204/200). Her adım `OK`/`HATA` yazar; biri başarısızsa çıkış 1.

```js
import { randomUUID, createHash } from 'node:crypto';
import { env } from './lib.mjs';

const url = env('SUPABASE_URL');
const anon = env('SUPABASE_ANON_KEY');
let failures = 0;
const check = (cond, label) => { console.log(`${cond ? 'OK  ' : 'HATA'} ${label}`); if (!cond) failures++; };

const signup = await fetch(`${url}/auth/v1/signup`, {
  method: 'POST', headers: { apikey: anon, 'Content-Type': 'application/json' }, body: '{}',
});
const session = await signup.json();
check(signup.ok && session.access_token, 'anonim oturum');
const auth = { apikey: anon, Authorization: `Bearer ${session.access_token}`, 'Content-Type': 'application/json' };

const payload = {
  client_record_id: randomUUID(), platform_code: 'getir', province: 'İstanbul', district: 'Kadıköy',
  vehicle: 'motorcycle', weekday: 1, start_slot: 74, duration_min: 153, gross: 900, bonus: 100,
  packages: 12, distance_km: 41.5, level: 'ocrUnverified', template_id: 'getir.earnings',
  template_version: 1, text_hash: createHash('sha256').update(randomUUID()).digest('hex'),
};
const rpc = (fn, body) => fetch(`${url}/rest/v1/rpc/${fn}`, { method: 'POST', headers: auth, body: JSON.stringify(body) });

const first = await (await rpc('submit_shift', { payload })).json();
check(first === 'ok', `ilk gonderim: ${JSON.stringify(first)}`);
const second = await (await rpc('submit_shift', { payload })).json();
check(second === 'duplicate', `tekrar: ${JSON.stringify(second)}`);
const read = await fetch(`${url}/rest/v1/shifts?select=*`, { headers: auth });
check(!read.ok, `shifts okunamaz (HTTP ${read.status})`);
const templates = await (await fetch(`${url}/rest/v1/ocr_templates?select=id,version,status`, { headers: { apikey: anon } })).json();
check(Array.isArray(templates) && templates.length >= 4, `sablonlar okunur (${templates.length})`);
const del = await rpc('delete_my_data', {});
check(del.ok, `verilerimi sil (HTTP ${del.status})`);
process.exit(failures === 0 ? 0 : 1);
```

- [ ] **Step 7: `scripts/server/seed_templates.mjs`** — `KuryeKazanc/Core/OCR/BundledTemplates.swift` içindeki `#"""`…`"""#` JSON dizisini okuyup her şablonu `insert … on conflict (id, version) do update set body = excluded.body, status = excluded.status, updated_at = now()` ile yazar (`body` = şablonun tüm JSON nesnesi).

```js
import { readFileSync } from 'node:fs';
import { sql } from './lib.mjs';

const source = readFileSync('KuryeKazanc/Core/OCR/BundledTemplates.swift', 'utf8');
const match = source.match(/#"""\s*([\s\S]*?)\s*"""#/);
if (!match) { console.error('JSON bulunamadi'); process.exit(1); }
const templates = JSON.parse(match[1]);
for (const t of templates) {
  const body = JSON.stringify(t).replace(/'/g, "''");
  await sql(`insert into public.ocr_templates (id, platform_code, version, status, body)
    values ('${t.id}', '${t.platformCode}', ${t.version}, '${t.status}', '${body}'::jsonb)
    on conflict (id, version) do update set body = excluded.body, status = excluded.status, updated_at = now()`);
  console.log(`sablon: ${t.id} v${t.version}`);
}
```

- [ ] **Step 8: `supabase/README.md`** — kurulum ve çalıştırma: proje (eu-central-1), Authentication → Anonymous sign-ins açık, Apple sağlayıcı (Client IDs: `com.kuryekazanc.app`), e-posta kapalı; ortam değişkenleri; `node scripts/server/apply.mjs`, `seed_templates.mjs`, `test.mjs`, `e2e.mjs` sırası. Gizli değerlerin repoya girmeyeceği notu.

- [ ] **Step 9:** Run: `node --check scripts/server/lib.mjs && node --check scripts/server/apply.mjs && node --check scripts/server/test.mjs && node --check scripts/server/e2e.mjs && node --check scripts/server/seed_templates.mjs` → Expected: çıktı yok (sözdizimi geçerli). **Commit** `feat(server): Supabase semasi, RLS, fonksiyonlar, pgTAP testleri ve betikler`

---

### Task 4: Supabase istemcisi ve oturum

**Files:**
- Create: `KuryeKazanc/Services/Sync/SupabaseConfig.swift`, `KeychainStore.swift`, `SupabaseClient.swift`
- Modify: `KuryeKazanc/Supporting/Info.plist` (`SupabaseURL`, `SupabaseAnonKey` — değerler boş bırakılır; kontrolcü proje kurulunca doldurur)
- Test: `KuryeKazancTests/SupabaseClientTests.swift`

**Interfaces:**
- Produces:
  - `struct SupabaseConfig { let url: URL; let anonKey: String; static var fromBundle: SupabaseConfig? }` — Info.plist değerleri boşsa `nil` (sunucu kapalı sayılır).
  - `struct AuthSession: Codable, Equatable { var accessToken: String; var refreshToken: String; var expiresAt: Date; var userID: String; var isAnonymous: Bool }`
  - `protocol SessionStore { func load() -> AuthSession?; func save(_ s: AuthSession?) }`; `final class KeychainStore: SessionStore` (servis `com.kuryekazanc.app.session`).
  - `protocol SupabaseServing { func submitShift(_ p: ShiftPayload) async -> OutboxResult; func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult; func fetchTemplates() async -> [OCRTemplate]?; func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession; func uploadBackup(_ payload: Data) async throws; func downloadBackup() async throws -> Data?; func deleteMyData() async throws; func signOut(); var session: AuthSession? { get } }`
  - `final class SupabaseClient: SupabaseServing` — `init(config: SupabaseConfig, store: SessionStore, transport: URLSession = .shared, clock: @escaping () -> Date = { Date() })`. Oturum yoksa veya süresi 60 sn içinde dolacaksa önce yenileme (`/auth/v1/token?grant_type=refresh_token`), yenileme başarısızsa yeni anonim kayıt (`POST /auth/v1/signup`, gövde `{}`). RPC sonucu JSON metin (`"ok"` vb.) → `OutboxResult(rawValue:) ?? .invalid`; HTTP 5xx/ağ hatası → `.transient`; 401 bir kez yenileyip tekrar dener.

Uç noktalar (tümünde `apikey: anonKey`; oturumluda `Authorization: Bearer <access>`):
- Anonim: `POST {url}/auth/v1/signup` gövde `{}` → `{access_token, refresh_token, expires_in, user:{id, is_anonymous}}`
- Yenileme: `POST {url}/auth/v1/token?grant_type=refresh_token` gövde `{"refresh_token": …}`
- Apple: `POST {url}/auth/v1/token?grant_type=id_token` gövde `{"provider":"apple","id_token":…,"nonce":…}`
- RPC: `POST {url}/rest/v1/rpc/submit_shift` gövde `{"payload": ShiftPayload}`; `rpc/submit_calibration` gövde `{"payload": {"platform_code":…, "template_id":…, "lines":[{text,x,y,width,height}]}}`; `rpc/delete_my_data` gövde `{}`
- Şablonlar: `GET {url}/rest/v1/ocr_templates?select=body` → `[{body: OCRTemplate JSON}]`
- Yedek: `POST {url}/rest/v1/backups` başlık `Prefer: resolution=merge-duplicates`, gövde `{"user_id": uid, "payload": <json>}`; okuma `GET {url}/rest/v1/backups?select=payload&user_id=eq.<uid>`
- Çıkış: yerel oturumu siler (`store.save(nil)`); sunucu çağrısı gerekmez.

- [ ] **Step 1: Testler** — `URLProtocol` alt sınıfı `StubProtocol` ile (istek → yanıt sözlüğü). Testler: (a) oturum yokken `submitShift` önce `/auth/v1/signup`, sonra `/rest/v1/rpc/submit_shift` çağırır ve gövdede `"payload"` ve `"text_hash"` vardır; `"ok"` → `.ok`; (b) `"duplicate"` → `.duplicate`; (c) 503 → `.transient`; (d) süresi dolmuş oturumla önce `grant_type=refresh_token`; (e) `fetchTemplates` `[{"body": …}]` çözer; (f) `SupabaseConfig.fromBundle` boş değerde `nil` (bunun yerine `SupabaseConfig(urlString:anonKey:)` yardımcı init'i test edilir).
- [ ] **Step 2: Uygulama** — yukarıdaki arayüzle; `JSONSerialization` yerine `Codable`; tarih `expires_in` saniyesinden `clock() + expires_in`. Keychain: `kSecClassGenericPassword`, `kSecAttrService`, `kSecAttrAccount = "session"`, `kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlock` (arka planda uyanınca okunabilsin).
- [ ] **Step 3: Commit** `feat(sync): Supabase REST istemcisi ve Keychain oturumu`

---

### Task 5: Gönderim kuyruğu ve eşitleme koordinatörü

**Files:**
- Create: `KuryeKazanc/Services/Sync/OutboxQueue.swift`, `KuryeKazanc/Services/Sync/SyncCoordinator.swift`
- Modify: `KuryeKazanc/Services/AppPreferences.swift` (`calibrationOptInKey`, `lastSyncDateKey`, `templatesFetchedAtKey`, `sentRecordIDsKey`)
- Test: `KuryeKazancTests/SyncCoordinatorTests.swift`

**Interfaces:**
- Consumes: `ShiftPayloadBuilder`, `OutboxPolicy`, `OutboxResult`, `TemplateMerger`, `TextHash.sha256`, `SupabaseServing`.
- Produces:
  - `struct OutboxItem: Codable, Equatable { var id: UUID; var kind: Kind; var payload: Data; var failures: Int; var notBefore: Date; enum Kind: String, Codable { case shift, calibration } }`
  - `final class OutboxQueue { init(fileURL: URL); var items: [OutboxItem] { get }; func enqueue(_ item: OutboxItem); func remove(id: UUID); func replace(_ item: OutboxItem); func removeAll() }` — dosyaya JSON (atomik yazım).
  - `@MainActor @Observable final class SyncCoordinator { init(client: SupabaseServing?, queue: OutboxQueue, defaults: UserDefaults = .standard, calendar: Calendar = .current, clock: @escaping () -> Date = { Date() }); private(set) var lastSyncDate: Date?; private(set) var remoteTemplates: [OCRTemplate]; var isSharingEnabled: Bool { get }; func recordSaved(_ record: EarningRecord, vehicle: String); func sharingConsentChanged(enabled: Bool); func flush() async; func refreshTemplatesIfNeeded() async; func sendCalibration(_ evidence: ScreenshotEvidence) async -> OutboxResult; func mergedTemplates() -> [OCRTemplate] }`
- Kurallar:
  - `client == nil` (config yok) → her şey no-op.
  - `recordSaved`: paylaşım kapalıysa hiçbir şey; kayıt `sentRecordIDs` içindeyse hiçbir şey; `evidence` yoksa hiçbir şey; yük `ShiftPayloadBuilder.make(... textHash: TextHash.sha256(evidence.lines.map(\.text)) ...)`; nil ise hiçbir şey; değilse kuyruğa `.shift` ekle (aynı kayıt id'si için eski öğeyi değiştir).
  - `sharingConsentChanged(enabled: false)` → `queue.removeAll()` (yalnızca `.shift` öğeleri) ; `true` → hiçbir şey (yeni kayıtlar eklenir; geçmiş kayıtlar gönderilmez).
  - `flush`: `notBefore <= now` olanları sırayla gönderir; `isFinal` ise kuyruktan çıkar ve `ok`/`duplicate` kayıt id'sini `sentRecordIDs`'e ekler; `rateLimited` → `notBefore = OutboxPolicy.nextDay`; `transient` → `failures += 1`, `notBefore = nextAttempt`; en az bir `ok` varsa `lastSyncDate = now`.
  - `refreshTemplatesIfNeeded`: paylaşım veya kalibrasyon açık değilse no-op (ağ yok kuralı); son çekimden 12 saat geçmediyse no-op; sonuç `Application Support/remote_templates.json`'a yazılır, `remoteTemplates` güncellenir.
  - `sendCalibration`: kalibrasyon rızası yoksa `.invalid` (istek yok); satırlar `CalibrationMasker.mask` ile maskelenir.
- Ayrıca `EarningsScreenshotParser` kullanan yerler (`ScreenshotImporter`) `mergedTemplates()` ile beslenir: `ScreenshotImporter`'a `templates: [OCRTemplate]? = nil` init parametresi; nil ise mevcut davranış. (Bağlantı Görev 8'de.)

- [ ] **Step 1: Testler** (sahte `SupabaseServing` çağrı sayaçlarıyla; `OutboxQueue` geçici dosyada):
  - paylaşım kapalı → `recordSaved` + `flush` sonrası istemci çağrı sayısı **0** (Review Focus 1);
  - paylaşım açık, `ocrUnverified` + kanıtlı kayıt → bir öğe; `flush` → `.ok`, kuyruk boş, `sentRecordIDs` içerir; ikinci `recordSaved` aynı kayıt için eklemez;
  - `manual` kayıt → kuyruk boş;
  - `.duplicate` → kuyruktan çıkar (Review Focus 3);
  - `.transient` → kuyrukta kalır, `failures == 1`, `notBefore` 60 sn sonra; hemen tekrar `flush` göndermez;
  - `sharingConsentChanged(false)` → kuyruk boş, sonra `flush` çağrı 0 (Review Focus 5);
  - kalibrasyon rızası yokken `sendCalibration` → `.invalid`, çağrı 0; varken maskelenmiş satır gönderilir (IBAN içeren satır `***` olur).
- [ ] **Step 2: Uygulama** ve **Step 3: Commit** `feat(sync): gonderim kuyrugu ve esitleme koordinatoru`

---

### Task 6: Apple ile Giriş, yedekleme ve "Verilerimi sil"

**Files:**
- Create: `KuryeKazanc/Services/Sync/AccountService.swift`, `KuryeKazanc/Services/Sync/BackupService.swift`
- Modify: `KuryeKazanc/Supporting/KuryeKazanc.entitlements` (`com.apple.developer.applesignin` = `["Default"]`)
- Test: `KuryeKazancTests/BackupServiceTests.swift`

**Interfaces:**
- Produces:
  - `struct BackupPayload: Codable, Equatable { var version: Int; var earnings: [EarningDTO]; var expenses: [ExpenseDTO]; var preferences: [String: Double]; var createdAt: Date }` (`EarningDTO`: id, start, end, platformCode, province, district, neighborhood, gross, bonus, distanceKm, packageCount, sourceRaw, verificationRaw, createdAt; `ExpenseDTO`: id, date, typeRaw, amount, note, createdAt). Kanıt (OCR metni) yedeğe **girmez**.
  - `@MainActor enum BackupService { static func makePayload(context: ModelContext, defaults: UserDefaults) throws -> BackupPayload; static func restore(_ payload: BackupPayload, into context: ModelContext, platforms: [Platform]) throws -> (added: Int, skipped: Int) }` — id'si mevcut kayıtlar atlanır (Review Focus 4); tercihler: `costPerKm`, `weeklyNetGoal`, `dailyNetGoal`.
  - `@MainActor @Observable final class AccountService { init(client: SupabaseServing?, defaults: UserDefaults = .standard); private(set) var isSignedInWithApple: Bool; private(set) var lastBackupDate: Date?; func makeNonce() -> (raw: String, hashed: String); func completeAppleSignIn(idToken: String, rawNonce: String) async throws; func backupNow(context: ModelContext) async throws; func restore(context: ModelContext, platforms: [Platform]) async throws -> (added: Int, skipped: Int); func deleteMyData(context: ModelContext) async throws; func signOut() }`
  - Nonce: 32 rastgele bayt → base64url (`raw`), `hashed = SHA256.hex(raw)` (Core).
  - `deleteMyData`: sunucuda `delete_my_data` (oturum varsa) + `signOut()` + yerel olarak `context.deleteAllRecords()` **yapılmaz** (yerel veri kullanıcıya ait; Profil'deki mevcut "Tüm kayıtları sil" ayrı). Paylaşım rızaları kapatılır, kuyruk boşaltılır (SyncCoordinator üzerinden — Görev 8 bağlar).
  - Otomatik yedek: Apple ile girişliyse ve son yedekten 24 saat geçtiyse `recordSaved` sonrası arka planda `backupNow` (Görev 8 bağlar).
- [ ] **Step 1: Testler** — bellek içi `ModelContainerFactory.make(inMemory: true)`: 2 kazanç + 1 gider → `makePayload` → yeni bellek içi kapsayıcıya `restore` → sayılar eşit; aynı yük ikinci kez `restore` → `added == 0`, `skipped == 3`; kanıtlı kayıt yükte kanıt taşımaz; nonce `hashed` 64 hex.
- [ ] **Step 2: Uygulama**, **Step 3: Commit** `feat(account): Apple ile Giris, yedekleme/geri yukleme, verilerimi sil`

---

### Task 7: Profil arayüzü, kalibrasyon düğmesi, KVKK taslakları

**Files:**
- Create: `KuryeKazanc/Views/Profile/AccountSection.swift`, `CalibrationSection.swift`, `PrivacyView.swift`
- Create: `docs/legal/kvkk-aydinlatma-taslak.md`, `docs/legal/acik-riza-taslak.md`
- Modify: `KuryeKazanc/Views/Profile/ProfileView.swift` (bölümler: `sharingSection`'dan sonra `AccountSection()`, `CalibrationSection()`; "Hakkında"da "Gizlilik ve KVKK" bağlantısı), `KuryeKazanc/Views/Earnings/EarningFormView.swift` (kalibrasyon açıksa ve form OCR kanıtlıysa "Kalibrasyona gönder" düğmesi; sonuç etiketi), `KuryeKazancUITests/DashboardUITests.swift`

**Arayüz:**
- `AccountSection` ("Hesap ve yedek"): girişli değilse `SignInWithAppleButton(.signIn)` (AuthenticationServices; `onRequest` → `request.requestedScopes = []`, `request.nonce = hashed`; `onCompletion` → `ASAuthorizationAppleIDCredential.identityToken` → `completeAppleSignIn`). Girişliyse: "Şimdi yedekle" (`profile.backupNow`), "Yedekten geri yükle" (onay diyaloğu; sonuç "N kayıt eklendi"), "Son yedek: …", "Çıkış yap". Altında "Verilerimi sil" (yıkıcı, onay diyaloğu metni: "Sunucudaki gönderilmiş vardiyaların, kalibrasyon örneklerin ve yedeğin silinir; paylaşım kapanır. Telefondaki kayıtların silinmez.") `profile.deleteMyData`. Sunucu yapılandırılmamışsa (`SupabaseConfig.fromBundle == nil`) bölüm "Sunucu bu sürümde kapalı" satırı gösterir.
- `CalibrationSection` ("Kalibrasyon"): ayrı rıza anahtarı `profile.calibration` (açarken `CalibrationConsentView`: ne gönderilir — maskelenmiş OCR satırları ve konumları; asla — görsel, IBAN, telefon, TC, e-posta, isim); footer: "Platform ekranlarını tanımamıza yardım eder."
- `PrivacyView`: `docs/legal` taslaklarının uygulama içi kısa sürümü (ScrollView + Text), "Taslak — hukuki inceleme bekliyor" notu.
- Form: `calibrationOptIn` açık ve `viewModel.imported != nil` iken OCR bölümünde "Kalibrasyona gönder" (`earningForm.calibrate`); sonuç: `ok` → "Gönderildi, teşekkürler", `rateLimited` → "Bugünlük sınır doldu", diğer → "Gönderilemedi".
- KVKK taslakları: veri sorumlusu (geliştirici adı yer tutucu `[Veri sorumlusu]`), işlenen veriler (spec §3 sütunları), amaç, hukuki sebep (açık rıza), aktarım (AB / Supabase, Frankfurt — yurt dışına aktarım açık rızası), saklama süresi, haklar (KVKK m.11), başvuru yolu, "Verilerimi sil".
- UI testi: Profil'de `profile.calibration` anahtarı varsayılan "0".

- [ ] Uygula, **Commit** `feat(ui): hesap ve yedek, kalibrasyon, gizlilik; KVKK taslaklari`

---

### Task 8: Bağlantılar ve sürüm

**Files:**
- Modify: `KuryeKazanc/App/AppEnvironment.swift` (`SupabaseClient?` — config varsa; `OutboxQueue` (Application Support/outbox.json); `SyncCoordinator`; `AccountService`; UI testlerinde `client = nil`), `KuryeKazanc/App/KuryeKazancApp.swift` (environment'a `sync`, `account`; scene `.active` → `Task { await sync.refreshTemplatesIfNeeded(); await sync.flush() }`), `KuryeKazanc/ViewModels/EarningFormViewModel.swift` veya `EarningFormView.swift` (kayıt sonrası `sync.recordSaved(record, vehicle:)` + girişliyse 24 saatte bir yedek), `KuryeKazanc/Views/Profile/ProfileView.swift` (`dataSharingOptIn` kapatılınca `sync.sharingConsentChanged(enabled: false)`; "Tüm kayıtları sil" ayrı kalır), `KuryeKazanc/Services/Screenshots/ScreenshotImporter.swift` (`parser.templates = sync.mergedTemplates()` — importer oluşturulan yerlerde), `project.yml` (`MARKETING_VERSION: "1.3.0"`), `TESTFLIGHT_NOTES.md` (en üste "## 1.3.0": 1.2 + 1.3 yenilikleri ve test listesi), `PROGRESS.md`, `README.md` (Sunucu bölümü: `supabase/README.md` bağlantısı).
- [ ] Uygula; `swift test`; **Commit** `feat: esitleme ve hesap baglantilari; surum 1.3.0`

---

## Görevler sonrası (kontrolcü — plan dışı yürütme adımları, kullanıcı onaylı)

1. Supabase projesini tarayıcıda oluştur (eu-central-1), Auth ayarları (anonim açık, Apple sağlayıcı Client ID `com.kuryekazanc.app`, e-posta kapalı). Erişim belirteci için kullanıcıdan `! npx supabase login` veya hesap belirteci iste; ortam değişkeniyle betikleri çalıştır: `apply.mjs` → `seed_templates.mjs` → `test.mjs` → `e2e.mjs`. URL + anon anahtarı Info.plist'e yaz, commit.
2. Apple Developer: `com.kuryekazanc.app` App ID'sinde **Sign in with Apple** yeteneği (profil yeniden üretilir → Codemagic'e yeni referansla çek, `codemagic.yaml` güncelle); Canlı Etkinlik App ID + profil (`kurye-kazanc-liveactivity-appstore`) — **kullanıcıya sorarak**.
3. İlk derleme: develop push → Codemagic `ios-ci`; hataları düzelt; tüm dal için son inceleme.
4. TestFlight'tan önce kullanıcıya sor.
