# Sürüm 1.2 — Otomatik vardiya, otomatik km ve Canlı Etkinlik — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hareketle kendiliğinden başlayan/biten vardiya (otomatik km dahil) ve vardiya boyunca kilit ekranı + Dynamic Island'da Canlı Etkinlik.

**Architecture:** Kararlar saf Core kurallarında (`Core/Shift`, Windows'ta TDD). `AutoShiftCoordinator` tek giriş noktası: önemli konum değişikliği / GPS olayı / uygulama açılışı → CoreMotion geçmişi → `AutoShiftPolicy` → `WorkSessionManager` + bildirim + Canlı Etkinlik. Canlı Etkinlik yeni WidgetKit eklentisi `KuryeLiveActivity`; "Vardiyayı bitir" düğmesi `LiveActivityIntent` ile uygulama sürecinde çalışır.

**Tech Stack:** Swift 5 modu, SwiftUI, CoreLocation, CoreMotion, UserNotifications, ActivityKit, WidgetKit, AppIntents, iOS 17+, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-08-surum-1-2-otomatik-vardiya-design.md` (üst tasarım: `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md`)

## Global Constraints

- **DERLEME / CI / TESTFLIGHT YOK (kullanıcı kararı):** 1.2 için push yapılmaz, Codemagic tetiklenmez, TestFlight'a gönderilmez. Doğrulama: Core için yerelde `swift test`; diğer her görev sonunda **derleme odaklı bağımsız kod incelemesi** (her çağrının imzası kaynağından kontrol edilir). Commit'ler yalnızca yerel `develop`'a.
- iOS deployment target `17.0`; `SWIFT_VERSION: "5.0"`; yeni üçüncü taraf bağımlılık **yok**.
- `KuryeKazanc/Core` dosyaları yalnızca `Foundation` import eder.
- Kod yorumları ASCII Türkçe (ç/ğ/ı/ö/ş/ü yok); kullanıcıya görünen metinler doğru Türkçe.
- Para/süre/mesafe biçimi yalnızca `Formatters` ile.
- Uzun zincirli ifadeler ve büyük `body` yazılmaz (Swift tip denetleyicisi daha önce zaman aşımına uğradı): adım adım kod, açık tipler, küçük alt görünümler.
- Mevcut `accessibilityIdentifier`'lar korunur (`dashboard.workToggle`, `dashboard.shiftStatus` vb.).
- Otomatik mod kapalıyken davranış 1.1 ile birebir aynı kalır (elle vardiya, mevcut GPS takibi).
- Hiçbir konum cihazdan çıkmaz; önemli konum değişikliği koordinatları saklanmaz.
- Elle başlatılan vardiya asla kendiliğinden bitirilmez.

## Review Focus

1. **Duraklayan GPS:** Otomatik vardiyada kurye 20 dk durunca iOS konum güncellemelerini durdurursa vardiya hiç bitmez. → Otomatik vardiyada `pausesLocationUpdatesAutomatically = false` + 60 sn'lik durma denetim zamanlayıcısı (Görev 5, 7); Görev 7 testi: "güncelleme gelmese de zamanlayıcı tikinde biter".
2. **Uygulama kapalıyken uyanma:** Kaydırılarak kapatılmış uygulama önemli konum değişikliğiyle yeniden başlatıldığında koordinatör kurulmalı ve karar vermeli. → `AppEnvironment` + `AppDelegate` (Görev 9); Görev 7 testi: "`handleWake` vardiya yokken başlatır".
3. **İptal sonrası tekrar başlatma (otobüs):** "Bu bir vardiya değil" sonrası 30 dk içinde yeniden başlamamalı. → Görev 2 + Görev 7 testi.
4. **Gece yarısını geçen çalışma saatleri (09:00–01:00):** 00:30'da başlamalı, 02:00'de başlamamalı. → Görev 1 testi.
5. **Kısa sahte vardiya:** Otopark içinde 3 dk araçla dolaşma (<5 dk ve <1 km) bekleyen vardiya ve bildirim üretmemeli. → Görev 2 + Görev 7 testi.

---

## Dosya yapısı

| Dosya | Sorumluluk |
|---|---|
| `KuryeKazanc/Core/Shift/MotionSample.swift` (yeni) | Hareket örneği (tür, güven, başlangıç) |
| `KuryeKazanc/Core/Shift/WorkHours.swift` (yeni) | Çalışma saatleri, gece yarısı aşımı, kodlama |
| `KuryeKazanc/Core/Shift/AutoShiftPolicy.swift` (yeni) | Başlatma / bitirme / kısa vardiya kuralları |
| `KuryeKazanc/Core/Shift/PendingShift.swift` (yeni) | Bekleyen vardiya + liste kuralları (5 adet, 24 sa) |
| `KuryeKazanc/Core/Shift/LiveActivityThrottle.swift` (yeni) | Canlı Etkinlik güncelleme sıklığı |
| `KuryeKazanc/Services/AppPreferences.swift` (değişir) | Yeni anahtarlar |
| `KuryeKazanc/Services/WorkSessionManager.swift` (değişir) | `origin`, `start(at:origin:)`, `cancel()`, `stop(now:end:)`, `region` |
| `KuryeKazanc/Services/LocationService.swift` (değişir) | Önemli konum değişikliği, son hareket zamanı, olay geri çağrısı, otomatik vardiyada duraklamama |
| `KuryeKazanc/Services/Motion/MotionActivityProvider.swift` (yeni) | Protokol + CoreMotion uygulaması |
| `KuryeKazanc/Services/Shift/ShiftNotifications.swift` (yeni) | Bildirim protokolü + UNUserNotificationCenter uygulaması |
| `KuryeKazanc/Services/Shift/LiveActivityController.swift` (yeni) | Protokol + ActivityKit uygulaması |
| `KuryeKazanc/Services/Shift/AutoShiftCoordinator.swift` (yeni) | Merkez: başlat/bitir/iptal, bekleyenler, izin durumu, zamanlayıcı |
| `KuryeKazanc/App/AppEnvironment.swift` (yeni) | Tekil nesne grafiği (uygulama + AppDelegate + Intent ortak) |
| `KuryeKazanc/App/AppDelegate.swift` (yeni) | Arka planda yeniden başlatma, bildirim eylemleri |
| `KuryeKazanc/App/KuryeKazancApp.swift` (değişir) | `AppEnvironment` kullanır |
| `Shared/ShiftActivityAttributes.swift` (yeni) | ActivityKit öznitelikleri (uygulama + eklenti) |
| `Shared/EndShiftIntent.swift` (yeni) | `LiveActivityIntent` + `ShiftIntentBridge` (uygulama + eklenti) |
| `KuryeLiveActivity/*` (yeni hedef) | Kilit ekranı + Dynamic Island görünümü |
| `KuryeKazanc/Views/Profile/AutoShiftSection.swift` (yeni) | Otomatik vardiya anahtarı, çalışma saatleri, izin akışı |
| `KuryeKazanc/Views/Today/TodayView.swift` (değişir) | Vardiya düğmesi koordinatöre gider; bekleyen vardiya ve iptal satırları |
| `KuryeKazanc/ViewModels/EarningFormViewModel.swift` (değişir) | Oturum bölgesi varsa onu kullanır |
| `KuryeKazanc/Views/Onboarding/OnboardingView.swift` (değişir) | İsteğe bağlı "Otomatik vardiyayı aç" |
| `project.yml`, `KuryeKazanc/Supporting/Info.plist`, `codemagic.yaml` | Hedef, izin metinleri, imzalama referansı |

---

### Task 1: Core — hareket örneği ve çalışma saatleri

**Files:**
- Create: `KuryeKazanc/Core/Shift/MotionSample.swift`
- Create: `KuryeKazanc/Core/Shift/WorkHours.swift`
- Test: `KuryeKazancTests/Core/WorkHoursTests.swift`

**Interfaces:**
- Produces: `struct MotionSample: Equatable, Codable { enum Kind: String, Codable { case automotive, cycling, walking, running, stationary, unknown }; enum Confidence: Int, Codable, Comparable { case low, medium, high }; var start: Date; var kind: Kind; var confidence: Confidence; var isMoving: Bool }`; `struct WorkHours: Equatable, Codable { var isAlways: Bool; var startMinute: Int; var endMinute: Int; static let standard: WorkHours; func contains(_ date: Date, calendar: Calendar) -> Bool; func encoded() -> Data; static func decode(_ data: Data?) -> WorkHours }`.

- [ ] **Step 1: Başarısız test** — `KuryeKazancTests/Core/WorkHoursTests.swift`

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class WorkHoursTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    func testStandardWindowCrossesMidnight() {
        let hours = WorkHours.standard // 09:00 - 01:00
        XCTAssertTrue(hours.contains(at(9), calendar: calendar))
        XCTAssertTrue(hours.contains(at(23, 30), calendar: calendar))
        XCTAssertTrue(hours.contains(at(0, 30), calendar: calendar))
        XCTAssertFalse(hours.contains(at(1), calendar: calendar), "Bitis dahil degil")
        XCTAssertFalse(hours.contains(at(2), calendar: calendar))
        XCTAssertFalse(hours.contains(at(8, 59), calendar: calendar))
    }

    func testSameDayWindowAndAlways() {
        let day = WorkHours(isAlways: false, startMinute: 10 * 60, endMinute: 22 * 60)
        XCTAssertTrue(day.contains(at(10), calendar: calendar))
        XCTAssertFalse(day.contains(at(22), calendar: calendar))
        XCTAssertFalse(day.contains(at(9, 59), calendar: calendar))

        let always = WorkHours(isAlways: true, startMinute: 0, endMinute: 0)
        XCTAssertTrue(always.contains(at(3), calendar: calendar))
        // Baslangic == bitis: tum gun
        let fullDay = WorkHours(isAlways: false, startMinute: 600, endMinute: 600)
        XCTAssertTrue(fullDay.contains(at(4), calendar: calendar))
    }

    func testEncodingRoundTripAndFallback() {
        let hours = WorkHours(isAlways: false, startMinute: 8 * 60, endMinute: 23 * 60)
        XCTAssertEqual(WorkHours.decode(hours.encoded()), hours)
        XCTAssertEqual(WorkHours.decode(nil), .standard)
        XCTAssertEqual(WorkHours.decode(Data("bozuk".utf8)), .standard)
    }

    func testMotionSampleIsMoving() {
        let now = Date()
        XCTAssertTrue(MotionSample(start: now, kind: .automotive, confidence: .medium).isMoving)
        XCTAssertTrue(MotionSample(start: now, kind: .cycling, confidence: .high).isMoving)
        XCTAssertFalse(MotionSample(start: now, kind: .automotive, confidence: .low).isMoving)
        XCTAssertFalse(MotionSample(start: now, kind: .walking, confidence: .high).isMoving)
    }
}
```

- [ ] **Step 2: Başarısız olduğunu gör** — Run: `swift test --filter WorkHoursTests` → Expected: derleme hatası `cannot find 'WorkHours' in scope`.

- [ ] **Step 3: `MotionSample.swift`**

```swift
import Foundation

/// CoreMotion'in bildirdigi bir hareket durumu. Bir ornek, bir sonraki ornege (veya simdiye) kadar surer.
struct MotionSample: Equatable, Codable {
    enum Kind: String, Codable {
        case automotive, cycling, walking, running, stationary, unknown
    }

    enum Confidence: Int, Codable, Comparable {
        case low, medium, high

        static func < (lhs: Confidence, rhs: Confidence) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var start: Date
    var kind: Kind
    var confidence: Confidence

    /// Vardiya sayilan hareket: arac veya bisiklet, guven orta/yuksek.
    var isMoving: Bool {
        (kind == .automotive || kind == .cycling) && confidence >= .medium
    }
}
```

- [ ] **Step 4: `WorkHours.swift`**

```swift
import Foundation

/// Otomatik vardiyanin baslayabilecegi saatler (yerel saat). Aralik gece yarisini gecebilir (09:00-01:00).
struct WorkHours: Equatable, Codable {
    var isAlways: Bool
    /// Gun icindeki dakika (0-1439).
    var startMinute: Int
    var endMinute: Int

    static let standard = WorkHours(isAlways: false, startMinute: 9 * 60, endMinute: 60)

    /// Baslangic dahil, bitis haric. Baslangic == bitis ise tum gun.
    func contains(_ date: Date, calendar: Calendar) -> Bool {
        if isAlways || startMinute == endMinute { return true }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute < endMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data?) -> WorkHours {
        guard let data, let value = try? JSONDecoder().decode(WorkHours.self, from: data) else { return .standard }
        return value
    }
}
```

- [ ] **Step 5: Testleri çalıştır** — Run: `swift test` → Expected: tüm testler PASS.

- [ ] **Step 6: Commit**

```bash
git add KuryeKazanc/Core/Shift KuryeKazancTests/Core/WorkHoursTests.swift
git commit -m "feat(core): hareket ornegi ve calisma saatleri"
```

---

### Task 2: Core — otomatik vardiya kuralları

**Files:**
- Create: `KuryeKazanc/Core/Shift/AutoShiftPolicy.swift`
- Test: `KuryeKazancTests/Core/AutoShiftPolicyTests.swift`

**Interfaces:**
- Consumes: `MotionSample`, `WorkHours` (Task 1).
- Produces: `struct AutoShiftPolicy { var requiredMovement: TimeInterval = 180; var lookback: TimeInterval = 600; var stopTolerance: TimeInterval = 60; var stationaryLimit: TimeInterval = 1200; var cancelCooldown: TimeInterval = 1800; var minimumDuration: TimeInterval = 300; var minimumDistanceKm: Double = 1; enum StartDecision: Equatable { case wait, start(at: Date) }; func startDecision(samples: [MotionSample], now: Date, workHours: WorkHours, calendar: Calendar, lastCancel: Date?) -> StartDecision; func shouldStop(lastMovement: Date, now: Date) -> Bool; func isTooShort(duration: TimeInterval, distanceKm: Double) -> Bool }`.

- [ ] **Step 1: Başarısız testler**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class AutoShiftPolicyTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private let policy = AutoShiftPolicy()
    private let always = WorkHours(isAlways: true, startMinute: 0, endMinute: 0)

    /// 2026-10-08 14:00 + saniye
    private func t(_ seconds: TimeInterval, hour: Int = 14) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour))!.addingTimeInterval(seconds)
    }

    private func s(_ seconds: TimeInterval, _ kind: MotionSample.Kind, _ confidence: MotionSample.Confidence = .high, hour: Int = 14) -> MotionSample {
        MotionSample(start: t(seconds, hour: hour), kind: kind, confidence: confidence)
    }

    func testThreeMinutesOfDrivingStartsAtMovementStart() {
        let samples = [s(0, .stationary), s(60, .automotive)]
        let decision = policy.startDecision(samples: samples, now: t(60 + 185), workHours: always, calendar: calendar, lastCancel: nil)
        XCTAssertEqual(decision, .start(at: t(60)))
    }

    func testTwoMinutesIsNotEnough() {
        let samples = [s(0, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(120), workHours: always, calendar: calendar, lastCancel: nil), .wait)
    }

    func testLowConfidenceAndWalkingDoNotCount() {
        XCTAssertEqual(policy.startDecision(samples: [s(0, .automotive, .low)], now: t(400), workHours: always, calendar: calendar, lastCancel: nil), .wait)
        XCTAssertEqual(policy.startDecision(samples: [s(0, .walking)], now: t(400), workHours: always, calendar: calendar, lastCancel: nil), .wait)
        XCTAssertEqual(policy.startDecision(samples: [s(0, .cycling, .medium)], now: t(200), workHours: always, calendar: calendar, lastCancel: nil), .start(at: t(0)))
    }

    func testShortStopDoesNotBreakTheRun() {
        // 100 sn surus, 30 sn kirmizi isik, 100 sn surus -> 200 sn hareket
        let samples = [s(0, .automotive), s(100, .stationary), s(130, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(230), workHours: always, calendar: calendar, lastCancel: nil), .start(at: t(0)))
    }

    func testLongStopBreaksTheRun() {
        // 120 sn surus, 120 sn durma, 120 sn surus -> son kosu yalnizca 120 sn
        let samples = [s(0, .automotive), s(120, .stationary), s(240, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(360), workHours: always, calendar: calendar, lastCancel: nil), .wait)
    }

    func testOnlyLookbackWindowCounts() {
        // Hareket 20 dk once basladi ve suruyor: baslangic pencerenin basina kirpilir
        let samples = [s(0, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(1200), workHours: always, calendar: calendar, lastCancel: nil), .start(at: t(600)))
        // Hareket 15 dk once bitti
        let old = [s(0, .automotive), s(300, .stationary)]
        XCTAssertEqual(policy.startDecision(samples: old, now: t(1200), workHours: always, calendar: calendar, lastCancel: nil), .wait)
    }

    func testOutsideWorkHoursWaits() {
        let samples = [s(0, .automotive, hour: 2)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(300, hour: 2), workHours: .standard, calendar: calendar, lastCancel: nil), .wait)
        let night = [s(0, .automotive, hour: 0)]
        XCTAssertEqual(policy.startDecision(samples: night, now: t(300, hour: 0), workHours: .standard, calendar: calendar, lastCancel: nil), .start(at: t(0, hour: 0)))
    }

    func testCooldownAfterCancel() {
        let samples = [s(0, .automotive)]
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(300), workHours: always, calendar: calendar, lastCancel: t(-1500)), .wait)
        XCTAssertEqual(policy.startDecision(samples: samples, now: t(300), workHours: always, calendar: calendar, lastCancel: t(-1500 - 60)), .start(at: t(0)))
    }

    func testStopAfterTwentyStationaryMinutes() {
        XCTAssertFalse(policy.shouldStop(lastMovement: t(0), now: t(1199)))
        XCTAssertTrue(policy.shouldStop(lastMovement: t(0), now: t(1200)))
    }

    func testTooShortNeedsBothShortAndClose() {
        XCTAssertTrue(policy.isTooShort(duration: 299, distanceKm: 0.9))
        XCTAssertFalse(policy.isTooShort(duration: 300, distanceKm: 0.5), "5 dk ve uzeri tutulur")
        XCTAssertFalse(policy.isTooShort(duration: 120, distanceKm: 1.0), "1 km ve uzeri tutulur")
    }
}
```

- [ ] **Step 2:** Run: `swift test --filter AutoShiftPolicyTests` → Expected: `cannot find 'AutoShiftPolicy' in scope`.

- [ ] **Step 3: `AutoShiftPolicy.swift`**

```swift
import Foundation

/// Otomatik vardiya kurallari (spec 4). Saf: zaman ve ornekler disaridan verilir.
struct AutoShiftPolicy {
    /// Baslatmak icin gereken kesintisiz hareket.
    var requiredMovement: TimeInterval = 180
    /// Geriye bakilan pencere.
    var lookback: TimeInterval = 600
    /// Bu sureden kisa durmalar (kirmizi isik) hareketi bolmez.
    var stopTolerance: TimeInterval = 60
    /// Otomatik vardiya bu kadar duragan kalinca biter.
    var stationaryLimit: TimeInterval = 1200
    /// "Bu bir vardiya degil" sonrasi yeniden baslatma yasagi.
    var cancelCooldown: TimeInterval = 1800
    var minimumDuration: TimeInterval = 300
    var minimumDistanceKm: Double = 1

    enum StartDecision: Equatable {
        case wait
        case start(at: Date)
    }

    func startDecision(
        samples: [MotionSample],
        now: Date,
        workHours: WorkHours,
        calendar: Calendar,
        lastCancel: Date?
    ) -> StartDecision {
        if let lastCancel, now.timeIntervalSince(lastCancel) < cancelCooldown { return .wait }
        guard workHours.contains(now, calendar: calendar) else { return .wait }

        let windowStart = now.addingTimeInterval(-lookback)
        let sorted = samples.sorted { $0.start < $1.start }

        var runStart: Date?
        var moving: TimeInterval = 0
        for index in sorted.indices {
            let sample = sorted[index]
            let rawEnd = index + 1 < sorted.count ? sorted[index + 1].start : now
            let end = min(rawEnd, now)
            let start = max(sample.start, windowStart)
            guard end > start else { continue }
            let duration = end.timeIntervalSince(start)

            if sample.isMoving {
                if runStart == nil {
                    runStart = start
                    moving = 0
                }
                moving += duration
            } else if runStart != nil, duration >= stopTolerance {
                runStart = nil
                moving = 0
            }
        }

        guard let runStart, moving >= requiredMovement else { return .wait }
        return .start(at: runStart)
    }

    func shouldStop(lastMovement: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastMovement) >= stationaryLimit
    }

    /// Hem kisa hem yakin vardiya sessizce atilir.
    func isTooShort(duration: TimeInterval, distanceKm: Double) -> Bool {
        duration < minimumDuration && distanceKm < minimumDistanceKm
    }
}
```

- [ ] **Step 4:** Run: `swift test` → Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Core/Shift/AutoShiftPolicy.swift KuryeKazancTests/Core/AutoShiftPolicyTests.swift
git commit -m "feat(core): otomatik vardiya baslatma/bitirme kurallari"
```

---

### Task 3: Core — bekleyen vardiyalar ve Canlı Etkinlik sıklığı

**Files:**
- Create: `KuryeKazanc/Core/Shift/PendingShift.swift`
- Create: `KuryeKazanc/Core/Shift/LiveActivityThrottle.swift`
- Test: `KuryeKazancTests/Core/PendingShiftTests.swift`

**Interfaces:**
- Produces: `struct PendingShift: Codable, Equatable, Identifiable { var id: UUID; var start: Date; var end: Date; var distanceKm: Double; var createdAt: Date; var province: String?; var district: String?; var neighborhood: String? }`; `enum PendingShiftList { static let maxCount = 5; static let lifetime: TimeInterval = 86_400; static func pruned(_ list: [PendingShift], now: Date) -> [PendingShift]; static func adding(_ shift: PendingShift, to list: [PendingShift], now: Date) -> [PendingShift]; static func encode(_ list: [PendingShift]) -> Data; static func decode(_ data: Data?) -> [PendingShift] }`; `struct LiveActivityThrottle { var normalInterval: TimeInterval = 60; var lowPowerInterval: TimeInterval = 180; var distanceStep: Double = 100; var minimumGap: TimeInterval = 15; func shouldUpdate(lastUpdate: Date?, lastDistanceMeters: Double, now: Date, distanceMeters: Double, isLowPower: Bool) -> Bool }`.

- [ ] **Step 1: Başarısız testler**

```swift
import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class PendingShiftTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func shift(_ minutesAgo: Double, now: Date) -> PendingShift {
        let created = now.addingTimeInterval(-minutesAgo * 60)
        return PendingShift(id: UUID(), start: created.addingTimeInterval(-3600), end: created, distanceKm: 12,
                            createdAt: created, province: nil, district: "Kadıköy", neighborhood: nil)
    }

    func testKeepsNewestFiveAndDropsOlderThanADay() {
        var list: [PendingShift] = []
        for minutes in [600.0, 500, 400, 300, 200, 100] {
            list = PendingShiftList.adding(shift(minutes, now: base), to: list, now: base)
        }
        XCTAssertEqual(list.count, 5)
        XCTAssertEqual(list.first?.createdAt, base.addingTimeInterval(-100 * 60), "En yeni once")

        let stale = PendingShiftList.pruned([shift(24 * 60 + 1, now: base), shift(10, now: base)], now: base)
        XCTAssertEqual(stale.count, 1)
    }

    func testEncodeDecode() {
        let list = [shift(5, now: base)]
        XCTAssertEqual(PendingShiftList.decode(PendingShiftList.encode(list)), list)
        XCTAssertEqual(PendingShiftList.decode(nil), [])
    }

    func testThrottle() {
        let throttle = LiveActivityThrottle()
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: nil, lastDistanceMeters: 0, now: base, distanceMeters: 0, isLowPower: false))
        XCTAssertFalse(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(30), distanceMeters: 50, isLowPower: false))
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(30), distanceMeters: 120, isLowPower: false), "100 m")
        XCTAssertFalse(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(10), distanceMeters: 500, isLowPower: false), "15 sn alt sinir")
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(60), distanceMeters: 0, isLowPower: false))
        XCTAssertFalse(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(120), distanceMeters: 900, isLowPower: true))
        XCTAssertTrue(throttle.shouldUpdate(lastUpdate: base, lastDistanceMeters: 0, now: base.addingTimeInterval(180), distanceMeters: 0, isLowPower: true))
    }
}
```

- [ ] **Step 2:** Run: `swift test --filter PendingShiftTests` → Expected: `cannot find 'PendingShift' in scope`.

- [ ] **Step 3: `PendingShift.swift`**

```swift
import Foundation

/// Kazanci henuz girilmemis, biten otomatik vardiya. Bolge metin olarak tutulur; koordinat saklanmaz.
struct PendingShift: Codable, Equatable, Identifiable {
    var id: UUID
    var start: Date
    var end: Date
    var distanceKm: Double
    var createdAt: Date
    var province: String?
    var district: String?
    var neighborhood: String?
}

enum PendingShiftList {
    static let maxCount = 5
    static let lifetime: TimeInterval = 86_400

    /// 24 saati gecenleri atar; en yeni once siralar ve en fazla 5 tutar.
    static func pruned(_ list: [PendingShift], now: Date) -> [PendingShift] {
        let fresh = list.filter { now.timeIntervalSince($0.createdAt) <= lifetime }
        let sorted = fresh.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(maxCount))
    }

    static func adding(_ shift: PendingShift, to list: [PendingShift], now: Date) -> [PendingShift] {
        pruned(list + [shift], now: now)
    }

    static func encode(_ list: [PendingShift]) -> Data {
        (try? JSONEncoder().encode(list)) ?? Data()
    }

    static func decode(_ data: Data?) -> [PendingShift] {
        guard let data, let list = try? JSONDecoder().decode([PendingShift].self, from: data) else { return [] }
        return list
    }
}
```

- [ ] **Step 4: `LiveActivityThrottle.swift`**

```swift
import Foundation

/// Canli Etkinlik guncelleme sikligi: dakikada bir veya 100 metrede bir (en sik 15 sn);
/// dusuk guc modunda yalnizca 3 dakikada bir.
struct LiveActivityThrottle {
    var normalInterval: TimeInterval = 60
    var lowPowerInterval: TimeInterval = 180
    var distanceStep: Double = 100
    var minimumGap: TimeInterval = 15

    func shouldUpdate(lastUpdate: Date?, lastDistanceMeters: Double, now: Date, distanceMeters: Double, isLowPower: Bool) -> Bool {
        guard let lastUpdate else { return true }
        let elapsed = now.timeIntervalSince(lastUpdate)
        if isLowPower { return elapsed >= lowPowerInterval }
        if elapsed >= normalInterval { return true }
        return elapsed >= minimumGap && distanceMeters - lastDistanceMeters >= distanceStep
    }
}
```

- [ ] **Step 5:** Run: `swift test` → PASS.

- [ ] **Step 6: Commit**

```bash
git add KuryeKazanc/Core/Shift KuryeKazancTests/Core/PendingShiftTests.swift
git commit -m "feat(core): bekleyen vardiya listesi ve Canli Etkinlik guncelleme sikligi"
```

---

### Task 4: WorkSessionManager — kaynak, geri tarihli başlatma, iptal, bölge

**Files:**
- Modify: `KuryeKazanc/Services/WorkSessionManager.swift`
- Modify: `KuryeKazanc/Services/AppPreferences.swift`
- Modify: `KuryeKazanc/ViewModels/EarningFormViewModel.swift` (`resolveRegionIfNeeded`)
- Test: `KuryeKazancTests/FormViewModelTests.swift` (WorkSession testleri bu dosyada)

**Interfaces:**
- Produces: `enum ShiftOrigin: String { case manual, auto }`; `WorkSessionManager.origin: ShiftOrigin?`; `func start(at: Date = .now, origin: ShiftOrigin = .manual)`; `func stop(now: Date = .now, end: Date? = nil) -> WorkSessionSummary?`; `func cancel()`; `WorkSessionSummary.region: PlaceRegion?` (varsayılan nil); `AppPreferences.workSessionOriginKey = "workSessionOrigin"`, `autoShiftEnabledKey = "autoShiftEnabled"`, `workHoursKey = "autoShiftWorkHours"`, `lastAutoCancelKey = "autoShiftLastCancel"`, `pendingShiftsKey = "autoShiftPending"`, `lastMovementKey = "lastMovementDate"`.
- Mevcut `start(now:)` çağrıları (`TodayView`, testler) `start()` / `start(at:)` olur; `now:` etiketi kaldırılır.

- [ ] **Step 1: Testler** — `FormViewModelTests.swift` içindeki `// MARK: - Calisiyorum modu` bölümüne ekle; mevcut `start(now:)` çağrılarını `start(at:)` yap:

```swift
    func testAutoShiftStartsBackdatedAndCanBeCancelled() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let manager = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
        manager.start(at: at(6, 9, 55), origin: .auto)
        XCTAssertEqual(manager.origin, .auto)
        XCTAssertEqual(manager.sessionStart, at(6, 9, 55))

        let restored = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
        XCTAssertEqual(restored.origin, .auto, "Kaynak kalici")

        manager.cancel()
        XCTAssertFalse(manager.isWorking)
        XCTAssertNil(manager.origin)
        XCTAssertNil(manager.stop(), "Iptal sonrasi ozet yok")
    }

    func testStopUsesExplicitEnd() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let manager = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
        manager.start(at: at(6, 10), origin: .auto)
        let summary = manager.stop(now: at(6, 12), end: at(6, 11, 40))
        XCTAssertEqual(summary?.end, at(6, 11, 40), "Bitis son hareket ani")
    }
```

- [ ] **Step 2: `AppPreferences`'a anahtarlar**

```swift
    /// Vardiya elle mi otomatik mi basladi ("manual" / "auto").
    static let workSessionOriginKey = "workSessionOrigin"
    /// Hareketle otomatik vardiya (kullanici acar; izinler o an istenir).
    static let autoShiftEnabledKey = "autoShiftEnabled"
    static let workHoursKey = "autoShiftWorkHours"
    static let lastAutoCancelKey = "autoShiftLastCancel"
    static let pendingShiftsKey = "autoShiftPending"
    /// Son anlamli hareketin zamani (otomatik vardiyanin bitisi icin).
    static let lastMovementKey = "lastMovementDate"
```

- [ ] **Step 3: `WorkSessionManager.swift` değişiklikleri**

`WorkSessionSummary`'ye son alan olarak: `var region: PlaceRegion? = nil`.

Dosyanın başına (struct'tan sonra):

```swift
/// Vardiyanin kaynagi. Otomatik vardiya yalnizca kurallarla biter; elle vardiya yalnizca kullanici bitirir.
enum ShiftOrigin: String {
    case manual, auto
}
```

Sınıfa:

```swift
    private(set) var origin: ShiftOrigin?
```

`init` sonunda (tutarsız durum kontrolünden sonra):

```swift
        if isWorking {
            let raw = defaults.string(forKey: AppPreferences.workSessionOriginKey) ?? ShiftOrigin.manual.rawValue
            origin = ShiftOrigin(rawValue: raw) ?? .manual
        }
```

`start` ve `stop` şöyle değişir, `cancel` eklenir:

```swift
    /// - Parameter at: Otomatik vardiyada hareketin ilk goruldugu an (geri tarihli baslangic).
    func start(at date: Date = .now, origin: ShiftOrigin = .manual) {
        guard !isWorking else { return }
        isWorking = true
        sessionStart = date
        self.origin = origin
        persist()
        location.startTracking(resetDistance: true, keepAliveWhenStationary: origin == .auto)
    }

    /// - Parameter end: Otomatik vardiyada son hareket ani; nil ise `now`.
    @discardableResult
    func stop(now: Date = .now, end: Date? = nil) -> WorkSessionSummary? {
        guard isWorking, let start = sessionStart else { return nil }
        let lastLocation = location.lastLocation
        let km = location.stopTracking()
        isWorking = false
        sessionStart = nil
        origin = nil
        persist()
        let finish = max(end ?? now, start)
        return WorkSessionSummary(start: start, end: finish, distanceKm: km, lastLocation: lastLocation)
    }

    /// Yanlis baslayan otomatik vardiya: iz birakmadan kapatir.
    func cancel() {
        guard isWorking else { return }
        location.stopTracking()
        isWorking = false
        sessionStart = nil
        origin = nil
        persist()
    }
```

`resumeIfNeeded` içindeki çağrı: `location.startTracking(resetDistance: false, keepAliveWhenStationary: origin == .auto)`.

`persist()`'e: `defaults.set(origin?.rawValue, forKey: AppPreferences.workSessionOriginKey)`.

(`startTracking(resetDistance:keepAliveWhenStationary:)` Task 5'te eklenir; iki görev aynı inceleme turunda doğrulanır.)

- [ ] **Step 4: Form bölgesi** — `EarningFormViewModel.resolveRegionIfNeeded` başına, `guard`'dan sonra:

```swift
        if let region = session?.region {
            province = region.province ?? ""
            district = region.district ?? ""
            neighborhood = region.neighborhood ?? ""
            return
        }
```

- [ ] **Step 5: Çağıranları güncelle** — `rg "start\(now:" KuryeKazanc KuryeKazancTests` ile bul; `start(now: X)` → `start(at: X)`.

- [ ] **Step 6: Commit**

```bash
git add KuryeKazanc/Services KuryeKazanc/ViewModels/EarningFormViewModel.swift KuryeKazancTests/FormViewModelTests.swift
git commit -m "feat(shift): vardiya kaynagi, geri tarihli baslatma, iptal, oturum bolgesi"
```

---

### Task 5: LocationService — önemli konum değişikliği, son hareket, olay bildirimi

**Files:**
- Modify: `KuryeKazanc/Services/LocationService.swift`

**Interfaces:**
- Produces: `func startTracking(resetDistance: Bool, keepAliveWhenStationary: Bool = false)`; `private(set) var lastMovementDate: Date?` (kalıcı, `AppPreferences.lastMovementKey`); `var onLocationEvent: (@MainActor () -> Void)?`; `func startSignificantChangeMonitoring()`; `func stopSignificantChangeMonitoring()`; `var isMonitoringSignificantChanges: Bool`; `func markMovement(at: Date)`.

- [ ] **Step 1: Özellikler**

```swift
    private(set) var lastMovementDate: Date?
    private(set) var isMonitoringSignificantChanges = false
    /// Her konum olayinda (GPS veya onemli konum degisikligi) cagrilir: otomatik vardiya karari icin.
    @ObservationIgnored var onLocationEvent: (@MainActor () -> Void)?
    /// Son anlamli hareketin olculdugu nokta (>= 50 m).
    @ObservationIgnored private var movementAnchor: CLLocation?
```

`init` içinde `sessionDistanceMeters` atamasından sonra:

```swift
        self.lastMovementDate = defaults.object(forKey: AppPreferences.lastMovementKey) as? Date
```

- [ ] **Step 2: Takip ve izleme**

`startTracking` imzası ve `beginUpdates`:

```swift
    /// - Parameter keepAliveWhenStationary: Otomatik vardiyada true: iOS durunca konumu duraklatmasin,
    ///   yoksa 20 dk duragan kalma hic olculemez (vardiya bitmez).
    func startTracking(resetDistance: Bool, keepAliveWhenStationary: Bool = false) {
        guard isEnabled else { return }
        if resetDistance {
            sessionDistanceMeters = 0
            defaults.set(0.0, forKey: Self.distanceKey)
        }
        lastAcceptedLocation = nil
        movementAnchor = nil
        manager.pausesLocationUpdatesAutomatically = !keepAliveWhenStationary
        markMovement(at: .now)

        switch authorizationStatus {
        case .notDetermined:
            pendingStart = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        default:
            break
        }
    }

    func markMovement(at date: Date) {
        lastMovementDate = date
        defaults.set(date, forKey: AppPreferences.lastMovementKey)
    }

    /// Otomatik mod: ~500 m'de bir uyandirir; uygulama kapaliysa iOS arka planda yeniden baslatir.
    func startSignificantChangeMonitoring() {
        guard isEnabled, CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        manager.startMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = true
    }

    func stopSignificantChangeMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = false
    }
```

`stopTracking()` içinde `if isTracking { ... }` bloğundan sonra: `manager.pausesLocationUpdatesAutomatically = true`.

- [ ] **Step 3: Olaylar** — `handle(locations:)` sonuna (mesafe döngüsünden sonra, `guard isTracking` dalının dışında kalmayacak şekilde) yapıyı şöyle değiştir:

```swift
    fileprivate func handle(locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastLocation = latest
        resumeOneShot(with: latest)

        if isTracking {
            for location in locations {
                accumulateDistance(with: location)
                updateMovementAnchor(with: location)
            }
        }
        onLocationEvent?()
    }

    /// 50 m'den fazla yer degistirme = anlamli hareket.
    private func updateMovementAnchor(with location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 50 else { return }
        guard let anchor = movementAnchor else {
            movementAnchor = location
            return
        }
        if location.distance(from: anchor) >= 50 {
            movementAnchor = location
            markMovement(at: location.timestamp)
        }
    }
```

- [ ] **Step 4: Commit**

```bash
git add KuryeKazanc/Services/LocationService.swift
git commit -m "feat(location): onemli konum degisikligi, son hareket zamani, olay bildirimi"
```

---

### Task 6: Hareket sağlayıcı, bildirimler, Canlı Etkinlik denetleyicisi (protokoller + iOS uygulamaları)

**Files:**
- Create: `KuryeKazanc/Services/Motion/MotionActivityProvider.swift`
- Create: `KuryeKazanc/Services/Shift/ShiftNotifications.swift`
- Create: `KuryeKazanc/Services/Shift/LiveActivityController.swift`
- Create: `Shared/ShiftActivityAttributes.swift`

**Interfaces:**
- Produces:
  - `protocol MotionActivityProviding { var isAvailable: Bool { get }; var isAuthorized: Bool { get }; func requestAccess() async -> Bool; func samples(from: Date, to: Date) async -> [MotionSample] }`; `final class CoreMotionActivityProvider: MotionActivityProviding`.
  - `protocol ShiftNotifying { func requestAccess() async -> Bool; func autoShiftStarted(); func clearAutoShiftStarted(); func shiftEnded(_ shift: PendingShift) }`; `final class ShiftNotifications: ShiftNotifying`; sabitler `ShiftNotifications.startedCategory = "AUTO_SHIFT_STARTED"`, `endedCategory = "SHIFT_ENDED"`, `cancelAction = "CANCEL_AUTO_SHIFT"`, `pendingIDKey = "pendingShiftID"`; `static func registerCategories()`.
  - `struct ShiftActivityAttributes: ActivityAttributes { struct ContentState: Codable, Hashable { var distanceKm: Double; var todayNet: Double; var netPerHour: Double?; var endedAt: Date? }; var start: Date; var isAuto: Bool }`.
  - `@MainActor protocol LiveActivityControlling { func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState); func update(_ state: ShiftActivityAttributes.ContentState); func finish(_ state: ShiftActivityAttributes.ContentState) }`; `@MainActor final class LiveActivityController: LiveActivityControlling`.

- [ ] **Step 1: `MotionActivityProvider.swift`**

```swift
import Foundation
import CoreMotion

protocol MotionActivityProviding {
    var isAvailable: Bool { get }
    var isAuthorized: Bool { get }
    /// Izin diyalogunu tetikler (CoreMotion icin ilk sorgu izni ister).
    func requestAccess() async -> Bool
    func samples(from start: Date, to end: Date) async -> [MotionSample]
}

/// CMMotionActivityManager sarmalayicisi. Gecmis sorgusu uygulama kapaliyken biriken hareketi de dondurur.
final class CoreMotionActivityProvider: MotionActivityProviding {
    private let manager = CMMotionActivityManager()
    private let queue = OperationQueue()

    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    var isAuthorized: Bool { CMMotionActivityManager.authorizationStatus() == .authorized }

    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        let now = Date()
        _ = await samples(from: now.addingTimeInterval(-60), to: now)
        return isAuthorized
    }

    func samples(from start: Date, to end: Date) async -> [MotionSample] {
        guard isAvailable else { return [] }
        return await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: start, to: end, to: queue) { activities, _ in
                let list: [CMMotionActivity] = activities ?? []
                continuation.resume(returning: list.map(Self.sample(from:)))
            }
        }
    }

    static func sample(from activity: CMMotionActivity) -> MotionSample {
        let kind: MotionSample.Kind
        if activity.automotive {
            kind = .automotive
        } else if activity.cycling {
            kind = .cycling
        } else if activity.running {
            kind = .running
        } else if activity.walking {
            kind = .walking
        } else if activity.stationary {
            kind = .stationary
        } else {
            kind = .unknown
        }
        let confidence: MotionSample.Confidence
        switch activity.confidence {
        case .high: confidence = .high
        case .medium: confidence = .medium
        default: confidence = .low
        }
        return MotionSample(start: activity.startDate, kind: kind, confidence: confidence)
    }
}
```

- [ ] **Step 2: `ShiftNotifications.swift`**

```swift
import Foundation
import UserNotifications

protocol ShiftNotifying {
    func requestAccess() async -> Bool
    func autoShiftStarted()
    func clearAutoShiftStarted()
    func shiftEnded(_ shift: PendingShift)
}

/// Yerel bildirimler: otomatik vardiya basladi (iptal eylemli), vardiya bitti (kazanc ekle).
final class ShiftNotifications: ShiftNotifying {
    static let startedCategory = "AUTO_SHIFT_STARTED"
    static let endedCategory = "SHIFT_ENDED"
    static let cancelAction = "CANCEL_AUTO_SHIFT"
    static let pendingIDKey = "pendingShiftID"
    private static let startedID = "auto-shift-started"

    private let center = UNUserNotificationCenter.current()

    static func registerCategories() {
        let cancel = UNNotificationAction(identifier: cancelAction, title: "Bu bir vardiya değil", options: [.destructive])
        let started = UNNotificationCategory(identifier: startedCategory, actions: [cancel], intentIdentifiers: [], options: [])
        let ended = UNNotificationCategory(identifier: endedCategory, actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([started, ended])
    }

    func requestAccess() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func autoShiftStarted() {
        let content = UNMutableNotificationContent()
        content.title = "Vardiya başladı"
        content.body = "Hareket algılandı; süre ve km kaydediliyor. Yanlışsa basılı tut, “Bu bir vardiya değil”i seç."
        content.categoryIdentifier = Self.startedCategory
        center.add(UNNotificationRequest(identifier: Self.startedID, content: content, trigger: nil))
    }

    func clearAutoShiftStarted() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.startedID])
    }

    func shiftEnded(_ shift: PendingShift) {
        let content = UNMutableNotificationContent()
        content.title = "Vardiya bitti"
        content.body = "\(Formatters.duration(shift.end.timeIntervalSince(shift.start))) · \(Formatters.distance(shift.distanceKm)). Kazancını eklemek için dokun."
        content.categoryIdentifier = Self.endedCategory
        content.userInfo = [Self.pendingIDKey: shift.id.uuidString]
        center.add(UNNotificationRequest(identifier: "shift-ended-\(shift.id.uuidString)", content: content, trigger: nil))
    }
}
```

- [ ] **Step 3: `Shared/ShiftActivityAttributes.swift`**

```swift
import Foundation
import ActivityKit

/// Vardiya Canli Etkinligi. Uygulama ve KuryeLiveActivity eklentisi bu dosyayi birlikte derler.
struct ShiftActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceKm: Double
        var todayNet: Double
        var netPerHour: Double?
        /// Dolu ise vardiya bitti: ozet gosterilir.
        var endedAt: Date?
    }

    var start: Date
    var isAuto: Bool
}
```

- [ ] **Step 4: `LiveActivityController.swift`**

```swift
import Foundation
import ActivityKit

@MainActor
protocol LiveActivityControlling {
    func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState)
    func update(_ state: ShiftActivityAttributes.ContentState)
    func finish(_ state: ShiftActivityAttributes.ContentState)
}

/// ActivityKit: vardiya basinda acar, guncellemeleri iletir, bitince 5 dk ozetle kapatir.
/// Kullanici Canli Etkinlikleri kapattiysa sessizce hicbir sey yapmaz.
@MainActor
final class LiveActivityController: LiveActivityControlling {
    private var activity: Activity<ShiftActivityAttributes>?

    init() {
        // Uygulama yeniden acildiginda suren etkinligi sahiplen
        activity = Activity<ShiftActivityAttributes>.activities.first
    }

    func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity != nil {
            update(state)
            return
        }
        let attributes = ShiftActivityAttributes(start: start, isAuto: isAuto)
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
    }

    func update(_ state: ShiftActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func finish(_ state: ShiftActivityAttributes.ContentState) {
        guard let activity else { return }
        self.activity = nil
        let dismissal = Date().addingTimeInterval(300)
        Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(dismissal)) }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Services/Motion KuryeKazanc/Services/Shift Shared
git commit -m "feat(shift): hareket saglayici, vardiya bildirimleri, Canli Etkinlik denetleyicisi"
```

---

### Task 7: AutoShiftCoordinator

**Files:**
- Create: `KuryeKazanc/Services/Shift/AutoShiftCoordinator.swift`
- Test: `KuryeKazancTests/AutoShiftCoordinatorTests.swift`

**Interfaces:**
- Consumes: Task 1–6.
- Produces:
  - `@MainActor @Observable final class AutoShiftCoordinator`:
    - `enum PermissionProblem: Equatable { case motion, locationAlways }`
    - Observed state: `private(set) var isEnabled: Bool`, `private(set) var pendingShifts: [PendingShift]`, `private(set) var permissionProblem: PermissionProblem?`, `var requestedPendingID: UUID?`.
    - Init: `init(workSession: WorkSessionManager, location: LocationService, motion: MotionActivityProviding, notifier: ShiftNotifying, liveActivity: LiveActivityControlling, defaults: UserDefaults = .standard, calendar: Calendar = .current, policy: AutoShiftPolicy = AutoShiftPolicy(), clock: @escaping () -> Date = { Date() }, todayNet: @escaping () -> Double = { 0 }, permissionCheck: (() -> Bool)? = nil)`.
    - Methods: `var workHours: WorkHours { get set }`, `func resume()`, `func enable() async -> Bool`, `func disable()`, `func handleWake() async`, `func startManualShift()`, `func endShift() -> WorkSessionSummary?`, `func cancelAutoShift()`, `func takePending(id: UUID) -> WorkSessionSummary?`, `func dismissPending(id: UUID)`.
    - Lower-level hook: `func tick()`, the timer entry point exposed for tests.
  - `extension PendingShift { var summary: WorkSessionSummary }`.

- [ ] **Step 1: Testler** — `KuryeKazancTests/AutoShiftCoordinatorTests.swift`

```swift
import XCTest
@testable import KuryeKazanc

@MainActor
final class AutoShiftCoordinatorTests: XCTestCase {
    final class FakeMotion: MotionActivityProviding {
        var isAvailable = true
        var isAuthorized = true
        var list: [MotionSample] = []
        func requestAccess() async -> Bool { isAuthorized }
        func samples(from start: Date, to end: Date) async -> [MotionSample] { list }
    }

    final class FakeNotifier: ShiftNotifying {
        var started = 0, cleared = 0
        var ended: [PendingShift] = []
        func requestAccess() async -> Bool { true }
        func autoShiftStarted() { started += 1 }
        func clearAutoShiftStarted() { cleared += 1 }
        func shiftEnded(_ shift: PendingShift) { ended.append(shift) }
    }

    @MainActor
    final class FakeActivity: LiveActivityControlling {
        var begun = 0, updates = 0, finished = 0
        func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState) { begun += 1 }
        func update(_ state: ShiftActivityAttributes.ContentState) { updates += 1 }
        func finish(_ state: ShiftActivityAttributes.ContentState) { finished += 1 }
    }

    private var now = Date(timeIntervalSince1970: 1_800_000_000)
    private var defaults: UserDefaults!
    private var motion: FakeMotion!
    private var notifier: FakeNotifier!
    private var activity: FakeActivity!
    private var workSession: WorkSessionManager!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "coordinator-\(UUID())")!
        motion = FakeMotion()
        notifier = FakeNotifier()
        activity = FakeActivity()
        workSession = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
    }

    private func makeCoordinator(enabled: Bool = true) -> AutoShiftCoordinator {
        defaults.set(enabled, forKey: AppPreferences.autoShiftEnabledKey)
        let always = WorkHours(isAlways: true, startMinute: 0, endMinute: 0)
        defaults.set(always.encoded(), forKey: AppPreferences.workHoursKey)
        return AutoShiftCoordinator(
            workSession: workSession, location: workSession.location, motion: motion, notifier: notifier,
            liveActivity: activity, defaults: defaults, policy: AutoShiftPolicy(), clock: { [unowned self] in self.now },
            todayNet: { 500 }, permissionCheck: { true }
        )
    }

    private func driving(minutes: Double) {
        motion.list = [MotionSample(start: now.addingTimeInterval(-minutes * 60), kind: .automotive, confidence: .high)]
    }

    func testWakeStartsAutoShiftAndNotifies() async {
        let coordinator = makeCoordinator()
        driving(minutes: 4)
        await coordinator.handleWake()
        XCTAssertTrue(workSession.isWorking)
        XCTAssertEqual(workSession.origin, .auto)
        XCTAssertEqual(workSession.sessionStart, now.addingTimeInterval(-240))
        XCTAssertEqual(notifier.started, 1)
        XCTAssertEqual(activity.begun, 1)
    }

    func testDisabledDoesNothing() async {
        let coordinator = makeCoordinator(enabled: false)
        driving(minutes: 10)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
    }

    func testCancelLeavesNoTraceAndCoolsDown() async {
        let coordinator = makeCoordinator()
        driving(minutes: 4)
        await coordinator.handleWake()
        coordinator.cancelAutoShift()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertTrue(coordinator.pendingShifts.isEmpty)
        XCTAssertEqual(activity.finished, 1)

        now = now.addingTimeInterval(600)
        driving(minutes: 5)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking, "30 dk bekleme")
    }

    func testStationaryTwentyMinutesEndsOnTimerTickWithPending() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        let start = workSession.sessionStart!
        workSession.location.markMovement(at: start.addingTimeInterval(1500))
        now = start.addingTimeInterval(1500 + 1200)
        coordinator.tick()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.pendingShifts.count, 1)
        XCTAssertEqual(coordinator.pendingShifts.first?.end, start.addingTimeInterval(1500), "Bitis son hareket ani")
        XCTAssertEqual(notifier.ended.count, 1)
    }

    func testTooShortAutoShiftIsDiscardedSilently() async {
        let coordinator = makeCoordinator()
        driving(minutes: 3.5)
        await coordinator.handleWake()
        let start = workSession.sessionStart!
        workSession.location.markMovement(at: start.addingTimeInterval(200))
        now = start.addingTimeInterval(200 + 1200)
        coordinator.tick()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertTrue(coordinator.pendingShifts.isEmpty)
        XCTAssertTrue(notifier.ended.isEmpty)
    }

    func testManualShiftNeverAutoEnds() async {
        let coordinator = makeCoordinator()
        coordinator.startManualShift()
        workSession.location.markMovement(at: now)
        now = now.addingTimeInterval(7200)
        coordinator.tick()
        await coordinator.handleWake()
        XCTAssertTrue(workSession.isWorking)
        XCTAssertEqual(workSession.origin, .manual)
    }

    func testTakePendingReturnsSummaryAndRemoves() async {
        let coordinator = makeCoordinator()
        driving(minutes: 30)
        await coordinator.handleWake()
        workSession.location.markMovement(at: now)
        now = now.addingTimeInterval(1300)
        coordinator.tick()
        let id = coordinator.pendingShifts[0].id
        let summary = coordinator.takePending(id: id)
        XCTAssertNotNil(summary)
        XCTAssertTrue(coordinator.pendingShifts.isEmpty)
    }

    func testMissingPermissionReportsProblem() async {
        defaults.set(true, forKey: AppPreferences.autoShiftEnabledKey)
        let coordinator = AutoShiftCoordinator(
            workSession: workSession, location: workSession.location, motion: motion, notifier: notifier,
            liveActivity: activity, defaults: defaults, clock: { [unowned self] in self.now },
            todayNet: { 0 }, permissionCheck: { false }
        )
        driving(minutes: 10)
        await coordinator.handleWake()
        XCTAssertFalse(workSession.isWorking)
        XCTAssertEqual(coordinator.permissionProblem, .locationAlways)
    }
}
```

Not: Testler "Her zaman" izni denetimini `permissionCheck:` ile atlar (varsayılan: `location.hasAlwaysAuthorization`).

- [ ] **Step 2: `AutoShiftCoordinator.swift`**

```swift
import Foundation
import CoreLocation
import Observation

extension PendingShift {
    var summary: WorkSessionSummary {
        let region = PlaceRegion(province: province, district: district, neighborhood: neighborhood)
        return WorkSessionSummary(start: start, end: end, distanceKm: distanceKm, lastLocation: nil, region: region)
    }
}

/// Otomatik vardiyanin merkezi (spec 3-4). Tum vardiya baslatma/bitirme buradan gecer ki
/// Canli Etkinlik ve bildirimler her yolda ayni kalsin.
@MainActor
@Observable
final class AutoShiftCoordinator {
    enum PermissionProblem: Equatable {
        case motion, locationAlways
    }

    private(set) var isEnabled: Bool
    private(set) var pendingShifts: [PendingShift]
    private(set) var permissionProblem: PermissionProblem?
    /// "Vardiya bitti" bildirimine dokunulunca Bugun ekrani bu bekleyen vardiyanin formunu acar.
    var requestedPendingID: UUID?

    @ObservationIgnored let workSession: WorkSessionManager
    @ObservationIgnored private let location: LocationService
    @ObservationIgnored private let motion: MotionActivityProviding
    @ObservationIgnored private let notifier: ShiftNotifying
    @ObservationIgnored private let liveActivity: LiveActivityControlling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let policy: AutoShiftPolicy
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let todayNet: () -> Double
    @ObservationIgnored private let permissionCheck: () -> Bool
    @ObservationIgnored private let throttle = LiveActivityThrottle()
    @ObservationIgnored private var lastActivityUpdate: Date?
    @ObservationIgnored private var lastActivityMeters: Double = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isDeciding = false

    init(
        workSession: WorkSessionManager,
        location: LocationService,
        motion: MotionActivityProviding,
        notifier: ShiftNotifying,
        liveActivity: LiveActivityControlling,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        policy: AutoShiftPolicy = AutoShiftPolicy(),
        clock: @escaping () -> Date = { Date() },
        todayNet: @escaping () -> Double = { 0 },
        permissionCheck: (() -> Bool)? = nil
    ) {
        self.workSession = workSession
        self.location = location
        self.motion = motion
        self.notifier = notifier
        self.liveActivity = liveActivity
        self.defaults = defaults
        self.calendar = calendar
        self.policy = policy
        self.clock = clock
        self.todayNet = todayNet
        self.permissionCheck = permissionCheck ?? { location.hasAlwaysAuthorization }
        self.isEnabled = defaults.bool(forKey: AppPreferences.autoShiftEnabledKey)
        let stored = PendingShiftList.decode(defaults.data(forKey: AppPreferences.pendingShiftsKey))
        self.pendingShifts = PendingShiftList.pruned(stored, now: clock())
    }

    var workHours: WorkHours {
        get { WorkHours.decode(defaults.data(forKey: AppPreferences.workHoursKey)) }
        set { defaults.set(newValue.encoded(), forKey: AppPreferences.workHoursKey) }
    }

    // MARK: - Yasam dongusu

    /// Uygulama acilisi veya arka planda yeniden baslatma: izlemeyi ve suren vardiyayi kurar.
    func resume() {
        location.onLocationEvent = { [weak self] in
            guard let self else { return }
            Task { await self.handleWake() }
        }
        if isEnabled {
            location.startSignificantChangeMonitoring()
        }
        workSession.resumeIfNeeded()
        if workSession.isWorking {
            startTimer()
        }
        refreshPending()
    }

    func enable() async -> Bool {
        guard motion.isAvailable, await motion.requestAccess() else {
            permissionProblem = .motion
            return false
        }
        location.requestAlwaysAuthorization()
        _ = await notifier.requestAccess()
        isEnabled = true
        defaults.set(true, forKey: AppPreferences.autoShiftEnabledKey)
        location.startSignificantChangeMonitoring()
        permissionProblem = permissionCheck() ? nil : .locationAlways
        return true
    }

    func disable() {
        isEnabled = false
        permissionProblem = nil
        defaults.set(false, forKey: AppPreferences.autoShiftEnabledKey)
        location.stopSignificantChangeMonitoring()
    }

    // MARK: - Karar

    /// Konum olayi, zamanlayici veya uygulama acilisi.
    func handleWake() async {
        refreshPending()
        if workSession.isWorking {
            tick()
            return
        }
        guard isEnabled, !isDeciding else { return }
        guard permissionCheck() else {
            permissionProblem = .locationAlways
            return
        }
        guard motion.isAuthorized else {
            permissionProblem = .motion
            return
        }
        permissionProblem = nil
        isDeciding = true
        defer { isDeciding = false }

        let now = clock()
        let samples: [MotionSample] = await motion.samples(from: now.addingTimeInterval(-policy.lookback), to: now)
        let lastCancel = defaults.object(forKey: AppPreferences.lastAutoCancelKey) as? Date
        let decision = policy.startDecision(samples: samples, now: now, workHours: workHours, calendar: calendar, lastCancel: lastCancel)
        guard case .start(let start) = decision, !workSession.isWorking else { return }
        beginShift(at: start, origin: .auto)
        notifier.autoShiftStarted()
    }

    /// Suren vardiya: Canli Etkinligi gunceller; otomatik vardiyada duraganligi denetler.
    func tick() {
        guard workSession.isWorking else {
            stopTimer()
            return
        }
        let now = clock()
        if workSession.origin == .auto {
            let lastMovement: Date = location.lastMovementDate ?? workSession.sessionStart ?? now
            if policy.shouldStop(lastMovement: lastMovement, now: now) {
                finishAutoShift(end: lastMovement)
                return
            }
        }
        pushActivityUpdate(now: now)
    }

    // MARK: - Kullanici eylemleri

    func startManualShift() {
        beginShift(at: clock(), origin: .manual)
    }

    /// Bugun ekrani veya Canli Etkinlik "Vardiyayi bitir". Ozet kazanc formunu doldurur.
    @discardableResult
    func endShift() -> WorkSessionSummary? {
        guard workSession.isWorking else { return nil }
        let state = currentState(endedAt: clock())
        let summary = workSession.stop(now: clock())
        stopTimer()
        liveActivity.finish(state)
        notifier.clearAutoShiftStarted()
        return summary
    }

    func cancelAutoShift() {
        guard workSession.isWorking, workSession.origin == .auto else { return }
        workSession.cancel()
        stopTimer()
        liveActivity.finish(currentState(endedAt: clock()))
        notifier.clearAutoShiftStarted()
        defaults.set(clock(), forKey: AppPreferences.lastAutoCancelKey)
    }

    func takePending(id: UUID) -> WorkSessionSummary? {
        guard let shift = pendingShifts.first(where: { $0.id == id }) else { return nil }
        removePending(id: id)
        return shift.summary
    }

    func dismissPending(id: UUID) {
        removePending(id: id)
    }

    // MARK: - Ic

    private func beginShift(at start: Date, origin: ShiftOrigin) {
        workSession.start(at: start, origin: origin)
        lastActivityUpdate = nil
        lastActivityMeters = 0
        liveActivity.begin(start: start, isAuto: origin == .auto, state: currentState(endedAt: nil))
        startTimer()
    }

    private func finishAutoShift(end: Date) {
        let state = currentState(endedAt: end)
        guard let summary = workSession.stop(now: clock(), end: end) else { return }
        stopTimer()
        liveActivity.finish(state)
        notifier.clearAutoShiftStarted()
        let duration = summary.end.timeIntervalSince(summary.start)
        if policy.isTooShort(duration: duration, distanceKm: summary.distanceKm) { return }

        let pending = PendingShift(
            id: UUID(), start: summary.start, end: summary.end, distanceKm: summary.distanceKm,
            createdAt: clock(), province: nil, district: nil, neighborhood: nil
        )
        storePending(PendingShiftList.adding(pending, to: pendingShifts, now: clock()))
        notifier.shiftEnded(pending)
        if let last = summary.lastLocation {
            Task { await self.attachRegion(to: pending.id, from: last) }
        }
    }

    private func attachRegion(to id: UUID, from last: CLLocation) async {
        guard let region = await location.region(for: last) else { return }
        var list = pendingShifts
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].province = region.province
        list[index].district = region.district
        list[index].neighborhood = region.neighborhood
        storePending(list)
    }

    private func currentState(endedAt: Date?) -> ShiftActivityAttributes.ContentState {
        let net = todayNet()
        let worked: TimeInterval = workSession.sessionStart.map { clock().timeIntervalSince($0) } ?? 0
        let perHour = TodayViewModel.liveNetPerHour(todayNet: net, workedSeconds: 0, elapsed: worked)
        return ShiftActivityAttributes.ContentState(
            distanceKm: workSession.sessionDistanceKm, todayNet: net, netPerHour: perHour, endedAt: endedAt
        )
    }

    private func pushActivityUpdate(now: Date) {
        let meters = workSession.location.sessionDistanceMeters
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard throttle.shouldUpdate(lastUpdate: lastActivityUpdate, lastDistanceMeters: lastActivityMeters,
                                    now: now, distanceMeters: meters, isLowPower: lowPower) else { return }
        lastActivityUpdate = now
        lastActivityMeters = meters
        liveActivity.update(currentState(endedAt: nil))
    }

    private func refreshPending() {
        let pruned = PendingShiftList.pruned(pendingShifts, now: clock())
        if pruned != pendingShifts { storePending(pruned) }
    }

    private func removePending(id: UUID) {
        storePending(pendingShifts.filter { $0.id != id })
    }

    private func storePending(_ list: [PendingShift]) {
        pendingShifts = list
        defaults.set(PendingShiftList.encode(list), forKey: AppPreferences.pendingShiftsKey)
    }

    /// Konum guncellemesi gelmese de (duragan) 60 sn'de bir karar verilir.
    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add KuryeKazanc/Services/Shift/AutoShiftCoordinator.swift KuryeKazancTests/AutoShiftCoordinatorTests.swift
git commit -m "feat(shift): otomatik vardiya koordinatoru"
```

---

### Task 8: Canlı Etkinlik eklentisi ve bitir düğmesi

**Files:**
- Create: `Shared/EndShiftIntent.swift`
- Create: `KuryeLiveActivity/KuryeLiveActivityBundle.swift`
- Create: `KuryeLiveActivity/ShiftLiveActivity.swift`
- Create: `KuryeLiveActivity/Info.plist`
- Modify: `project.yml`

**Interfaces:**
- Consumes: `ShiftActivityAttributes` (Task 6), `Formatters` (Core).
- Produces: `struct EndShiftIntent: LiveActivityIntent`; `enum ShiftIntentBridge { @MainActor static var endShift: (@MainActor () -> Void)? }`.

- [ ] **Step 1: `Shared/EndShiftIntent.swift`**

```swift
import Foundation
import AppIntents

/// Uygulama, acilista vardiyayi bitiren islevi buraya baglar. Eklentide nil kalir
/// (LiveActivityIntent uygulama surecinde calisir).
enum ShiftIntentBridge {
    @MainActor static var endShift: (@MainActor () -> Void)?
}

/// Canli Etkinlikteki "Vardiyayi bitir" dugmesi.
struct EndShiftIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Vardiyayı bitir"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ShiftIntentBridge.endShift?()
        return .result()
    }
}
```

- [ ] **Step 2: `KuryeLiveActivity/KuryeLiveActivityBundle.swift`**

```swift
import SwiftUI
import WidgetKit

@main
struct KuryeLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        ShiftLiveActivity()
    }
}
```

- [ ] **Step 3: `KuryeLiveActivity/ShiftLiveActivity.swift`**

```swift
import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

/// Kilit ekrani + Dynamic Island. Sure `Text(timerInterval:)` ile kendiliginden akar.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            ShiftLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                        .font(.title3.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Formatters.distance(context.state.distanceKm))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ShiftDetailRow(state: context.state)
                }
            } compactLeading: {
                ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                    .frame(maxWidth: 52)
            } compactTrailing: {
                Text(Formatters.distance(context.state.distanceKm))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "scooter")
            }
        }
    }
}

private struct ShiftTimerText: View {
    let start: Date
    let endedAt: Date?

    var body: some View {
        if let endedAt {
            Text(Formatters.duration(endedAt.timeIntervalSince(start)))
                .monospacedDigit()
        } else {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
                .monospacedDigit()
        }
    }
}

private struct ShiftDetailRow: View {
    let state: ShiftActivityAttributes.ContentState

    private var detail: String {
        var parts: [String] = ["Bugün net \(Formatters.currency(state.todayNet))"]
        if let perHour = state.netPerHour {
            parts.append("~\(Formatters.currency(perHour.rounded()))/saat")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if state.endedAt == nil {
                Button(intent: EndShiftIntent()) {
                    Text("Vardiyayı bitir")
                }
                .tint(.red)
            }
        }
    }
}

private struct ShiftLockScreenView: View {
    let attributes: ShiftActivityAttributes
    let state: ShiftActivityAttributes.ContentState

    private var title: String {
        if state.endedAt != nil { return "Vardiya bitti" }
        return attributes.isAuto ? "Vardiya · otomatik" : "Vardiya"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            HStack(alignment: .firstTextBaseline) {
                ShiftTimerText(start: attributes.start, endedAt: state.endedAt)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Spacer()
                Text(Formatters.distance(state.distanceKm))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            ShiftDetailRow(state: state)
        }
        .padding(16)
    }
}
```

- [ ] **Step 4: `KuryeLiveActivity/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
```

- [ ] **Step 5: `project.yml`**

`KuryeKazanc` hedefi `sources`'a `- path: Shared` eklenir; `dependencies`'e:

```yaml
      - target: KuryeLiveActivity
        embed: true
```

`settings.base`'e:

```yaml
        INFOPLIST_KEY_NSSupportsLiveActivities: YES
        INFOPLIST_KEY_NSMotionUsageDescription: "Motorla ya da bisikletle yola çıktığını anlayıp vardiyanı kendiliğinden başlatmak için hareket bilgini kullanıyoruz. Bu bilgi cihazından çıkmaz."
```

Yeni hedef:

```yaml
  # Vardiya Canli Etkinligi (kilit ekrani + Dynamic Island)
  KuryeLiveActivity:
    type: app-extension
    platform: iOS
    sources:
      - path: KuryeLiveActivity
        excludes:
          - "Info.plist"
      - path: Shared
      - path: KuryeKazanc/Core/Formatters.swift
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.kuryekazanc.app.liveactivity
        INFOPLIST_FILE: KuryeLiveActivity/Info.plist
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: "Kurye Kazanç"
        TARGETED_DEVICE_FAMILY: "1"
        SKIP_INSTALL: YES
```

`KuryeKazanc/Supporting/Info.plist` içinde `NSLocationAlwaysAndWhenInUseUsageDescription` metni:

```xml
	<string>Vardiya sırasında mesafeni ölçmek ve otomatik vardiya açıksa yola çıktığını anlayıp vardiyanı kendiliğinden başlatmak için konumunu kullanıyoruz. Konumun cihazından çıkmaz.</string>
```

- [ ] **Step 6: Commit**

```bash
git add Shared KuryeLiveActivity project.yml KuryeKazanc/Supporting/Info.plist
git commit -m "feat: Canli Etkinlik eklentisi ve Vardiyayi bitir dugmesi"
```

---

### Task 9: Uygulama ortamı ve AppDelegate

**Files:**
- Create: `KuryeKazanc/App/AppEnvironment.swift`
- Create: `KuryeKazanc/App/AppDelegate.swift`
- Modify: `KuryeKazanc/App/KuryeKazancApp.swift`

**Interfaces:**
- Produces: `@MainActor final class AppEnvironment { static let shared: AppEnvironment; let container: ModelContainer; let location: LocationService; let workSession: WorkSessionManager; let scanner: ScreenshotScanner; let autoShift: AutoShiftCoordinator }`; `final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate`.

- [ ] **Step 1: `AppEnvironment.swift`**

```swift
import Foundation
import SwiftData

/// Uygulamanin tek nesne grafigi. SwiftUI sahnesi, AppDelegate (arka planda yeniden baslatma,
/// bildirim eylemleri) ve Canli Etkinlik Intent'i ayni orneklere erisir.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let container: ModelContainer
    let location: LocationService
    let workSession: WorkSessionManager
    let scanner: ScreenshotScanner
    let autoShift: AutoShiftCoordinator

    private init() {
        let launch = LaunchOptions.current
        if launch.resetsDefaults, let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        let container = ModelContainerFactory.make(inMemory: launch.isUITesting)
        if launch.loadsSampleData {
            SampleData.insert(into: container.mainContext)
        }
        self.container = container
        // UI testlerinde konum kapali: simulatorde izin diyalogu testleri kilitlemesin
        let location = LocationService(isEnabled: !launch.isUITesting)
        self.location = location
        let workSession = WorkSessionManager(location: location)
        self.workSession = workSession
        scanner = launch.isUITesting
            ? ScreenshotScanner(defaults: UserDefaults(suiteName: "ui-tests") ?? .standard)
            : ScreenshotScanner(library: PhotoKitScreenshotLibrary())
        let shiftDefaults: UserDefaults = launch.isUITesting ? (UserDefaults(suiteName: "ui-tests") ?? .standard) : .standard
        let context = container.mainContext
        autoShift = AutoShiftCoordinator(
            workSession: workSession,
            location: location,
            motion: CoreMotionActivityProvider(),
            notifier: ShiftNotifications(),
            liveActivity: LiveActivityController(),
            defaults: shiftDefaults,
            todayNet: { AppEnvironment.todayNet(in: context) }
        )
        ShiftIntentBridge.endShift = { [weak self] in
            _ = self?.autoShift.endShift()
        }
    }

    /// Bugunun net kazanci (Canli Etkinlik icin).
    static func todayNet(in context: ModelContext) -> Double {
        let start = Calendar.current.startOfDay(for: .now)
        let earnings = (try? context.fetch(FetchDescriptor<EarningRecord>(predicate: #Predicate { $0.date == start }))) ?? []
        let expenses = (try? context.fetch(FetchDescriptor<ExpenseRecord>(predicate: #Predicate { $0.date == start }))) ?? []
        let costPerKm = UserDefaults.standard.object(forKey: AppPreferences.costPerKmKey) as? Double ?? AppPreferences.defaultCostPerKm
        let autoEstimate = UserDefaults.standard.object(forKey: AppPreferences.autoEstimateExpensesKey) as? Bool ?? true
        let summary = TodayViewModel.summary(earnings: earnings, expenses: expenses, costPerKm: costPerKm, autoEstimate: autoEstimate)
        return summary.netEarnings
    }
}
```

- [ ] **Step 2: `AppDelegate.swift`**

```swift
import UIKit
import UserNotifications

/// iOS uygulamayi konum olayiyla arka planda yeniden baslattiginda da otomatik vardiya kurulur.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ShiftNotifications.registerCategories()
        MainActor.assumeIsolated {
            AppEnvironment.shared.autoShift.resume()
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let pendingID = (info[ShiftNotifications.pendingIDKey] as? String).flatMap(UUID.init(uuidString:))
        await MainActor.run {
            let coordinator = AppEnvironment.shared.autoShift
            if action == ShiftNotifications.cancelAction {
                coordinator.cancelAutoShift()
            } else if let pendingID {
                coordinator.requestedPendingID = pendingID
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
```

- [ ] **Step 3: `KuryeKazancApp.swift`** — gövde şöyle olur (`LaunchOptions` aynı kalır):

```swift
@main
struct KuryeKazancApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.location)
                .environment(environment.workSession)
                .environment(environment.scanner)
                .environment(environment.autoShift)
        }
        .modelContainer(environment.container)
    }
}
```

(`workSession.resumeIfNeeded()` artık `autoShift.resume()` içinde çağrılır.)

- [ ] **Step 4: Commit**

```bash
git add KuryeKazanc/App
git commit -m "feat(app): ortak uygulama ortami ve AppDelegate (arka planda yeniden baslatma, bildirim eylemleri)"
```

---

### Task 10: Arayüz — Profil, Bugün, Onboarding

**Files:**
- Create: `KuryeKazanc/Views/Profile/AutoShiftSection.swift`
- Modify: `KuryeKazanc/Views/Profile/ProfileView.swift` (Form'a `AutoShiftSection()` — `locationSection`'dan sonra)
- Modify: `KuryeKazanc/Views/Today/TodayView.swift`
- Modify: `KuryeKazanc/Views/Onboarding/OnboardingView.swift`
- Modify: `KuryeKazancUITests/DashboardUITests.swift`
- Modify: preview'lar (`TodayView` `#Preview`'ına `.environment(AppEnvironment.shared.autoShift)`)

**Interfaces:**
- Consumes: `AutoShiftCoordinator` (Task 7) environment'tan.

- [ ] **Step 1: UI testi** — `DashboardUITests` sınıfına:

```swift
    func testProfileOffersAutoShift() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        let toggle = app.switches["profile.autoShift"]
        for _ in 0..<6 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0", "Varsayilan kapali")
    }
```

- [ ] **Step 2: `AutoShiftSection.swift`**

```swift
import SwiftUI

/// Profil > Otomatik vardiya: anahtar, calisma saatleri, izin uyarisi.
struct AutoShiftSection: View {
    @Environment(AutoShiftCoordinator.self) private var autoShift
    @Environment(\.openURL) private var openURL
    @State private var showIntro = false
    @State private var hours: WorkHours = .standard

    var body: some View {
        Section {
            Toggle("Otomatik vardiya", isOn: Binding(
                get: { autoShift.isEnabled },
                set: { newValue in
                    if newValue {
                        showIntro = true
                    } else {
                        autoShift.disable()
                    }
                }
            ))
            .accessibilityIdentifier("profile.autoShift")

            if autoShift.isEnabled {
                Toggle("Her saatte", isOn: Binding(
                    get: { hours.isAlways },
                    set: { hours.isAlways = $0; save() }
                ))
                if !hours.isAlways {
                    DatePicker("Başlangıç", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                        .environment(\.locale, Formatters.locale)
                    DatePicker("Bitiş", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
                        .environment(\.locale, Formatters.locale)
                }
            }

            if let problem = autoShift.permissionProblem {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label(problemText(problem), systemImage: "exclamationmark.triangle")
                }
                .accessibilityIdentifier("profile.autoShiftPermission")
            }
        } header: {
            Text("Otomatik vardiya")
        } footer: {
            Text("Motorla ya da bisikletle yola çıkınca vardiyan kendiliğinden başlar, km sayılır; 20 dakika durunca biter. Yalnızca bu saatlerde başlar. Konum yalnızca vardiyada ayrıntılı izlenir.")
        }
        .onAppear { hours = autoShift.workHours }
        .sheet(isPresented: $showIntro) {
            AutoShiftIntroView {
                Task { _ = await autoShift.enable() }
            }
        }
    }

    private func problemText(_ problem: AutoShiftCoordinator.PermissionProblem) -> String {
        switch problem {
        case .motion: "Hareket ve Fitness izni kapalı — Ayarlar'dan aç"
        case .locationAlways: "Konum izni “Her zaman” olmalı — Ayarlar'dan aç"
        }
    }

    private func save() {
        autoShift.workHours = hours
    }

    /// Gun icindeki dakika <-> DatePicker tarihi.
    private func minuteBinding(_ keyPath: WritableKeyPath<WorkHours, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute: Int = hours[keyPath: keyPath]
                let day = Calendar.current.startOfDay(for: .now)
                return day.addingTimeInterval(TimeInterval(minute * 60))
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                hours[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                save()
            }
        )
    }
}

/// Otomatik vardiyayi acmadan once kisa aciklama; onayda izinler sirayla istenir.
struct AutoShiftIntroView: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "scooter")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                        Text("Vardiyan kendiliğinden başlasın")
                            .font(.title2.bold())
                        Text("Motorla ya da bisikletle yola çıktığında vardiyanı başlatır ve km'ni sayar; 20 dakika durunca bitirir. Yanlış başlarsa bildirimden tek dokunuşla iptal edersin.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("İstenecek izinler") {
                    Label("Hareket ve Fitness — yola çıktığını anlamak için", systemImage: "figure.walk.motion")
                    Label("Konum “Her zaman” — uygulama kapalıyken de başlatabilmek için", systemImage: "location")
                    Label("Bildirimler — başladı/bitti haberi için", systemImage: "bell")
                }
                Section {
                    Text("Vardiya dışında konum yalnızca kabaca (~500 m) kontrol edilir; konumun cihazından çıkmaz.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Devam") {
                        onContinue()
                        dismiss()
                    }
                    .accessibilityIdentifier("autoShift.continue")
                }
            }
        }
    }
}
```

- [ ] **Step 3: `TodayView` değişiklikleri**

1. `@Environment(AutoShiftCoordinator.self) private var autoShift` eklenir.
2. `toggleWork()`:

```swift
    private func toggleWork() {
        Haptics.impact()
        if workSession.isWorking {
            // Vardiya bitince kazanc formu sure + mesafe + bolgeyle on doldurulmus acilir
            if let summary = autoShift.endShift() {
                activeSheet = .addEarning(session: summary)
            }
        } else {
            autoShift.startManualShift()
        }
    }
```

3. `todayList` içinde `noticesSection`'dan sonra `autoShiftSection` eklenir:

```swift
    @ViewBuilder
    private var autoShiftSection: some View {
        if workSession.isWorking, workSession.origin == .auto {
            Section {
                Button(role: .destructive) {
                    autoShift.cancelAutoShift()
                } label: {
                    Label("Bu bir vardiya değil", systemImage: "xmark.circle")
                }
                .accessibilityIdentifier("today.cancelAutoShift")
            } footer: {
                Text("Vardiya hareketle kendiliğinden başladı.")
            }
        }
        if !autoShift.pendingShifts.isEmpty {
            Section("Biten vardiyalar") {
                ForEach(autoShift.pendingShifts) { shift in
                    Button {
                        openPending(shift.id)
                    } label: {
                        PendingShiftRow(shift: shift)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Sil", role: .destructive) { autoShift.dismissPending(id: shift.id) }
                    }
                    .accessibilityIdentifier("today.pendingShift")
                }
            }
        }
        if autoShift.isEnabled, let problem = autoShift.permissionProblem {
            Section {
                Button(action: openSystemSettings) {
                    Label(problem == .motion ? "Otomatik vardiya için hareket izni gerekli — Ayarlar" : "Otomatik vardiya için konum izni “Her zaman” olmalı — Ayarlar",
                          systemImage: "exclamationmark.triangle")
                }
            }
        }
    }

    private func openPending(_ id: UUID) {
        if let summary = autoShift.takePending(id: id) {
            activeSheet = .addEarning(session: summary)
        }
    }
```

4. Bildirimden gelen istek: `NavigationStack` zincirine

```swift
                .onChange(of: autoShift.requestedPendingID) { _, id in
                    guard let id else { return }
                    autoShift.requestedPendingID = nil
                    openPending(id)
                }
```

5. Dosya sonuna (private):

```swift
private struct PendingShiftRow: View {
    let shift: PendingShift

    private var detail: String {
        var parts: [String] = ["\(Formatters.time(shift.start))–\(Formatters.time(shift.end))", Formatters.distance(shift.distanceKm)]
        if let district = shift.district { parts.append(district) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Kazancını ekle")
                .font(.body.weight(.semibold))
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 4: Onboarding** — `locationStep` sonuna (mevcut izin düğmesinden sonra):

```swift
            Button {
                showAutoShiftIntro = true
            } label: {
                Label("Otomatik vardiyayı aç (isteğe bağlı)", systemImage: "scooter")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("onboarding.autoShift")
```

`@State private var showAutoShiftIntro = false`, `@Environment(AutoShiftCoordinator.self) private var autoShift` ve body zincirine:

```swift
        .sheet(isPresented: $showAutoShiftIntro) {
            AutoShiftIntroView {
                Task { _ = await autoShift.enable() }
            }
        }
```

- [ ] **Step 5: Commit**

```bash
git add KuryeKazanc/Views KuryeKazancUITests
git commit -m "feat(ui): otomatik vardiya ayarlari, biten vardiyalar, iptal satiri, onboarding secenegi"
```

---

### Task 11: İmzalama referansı, notlar, son inceleme

**Files:**
- Modify: `codemagic.yaml` (`ios-release` → `provisioning_profiles`'a `kurye-kazanc-liveactivity-appstore`)
- Modify: `README.md` (İmzalama bölümüne Canlı Etkinlik App ID + profil), `PROGRESS.md`

- [ ] **Step 1:** `codemagic.yaml`:

```yaml
        provisioning_profiles:
          - kurye-kazanc-appstore-v2
          - kurye-kazanc-share-appstore
          - kurye-kazanc-liveactivity-appstore
```

README İmzalama bölümüne madde:

```markdown
6. (1.2+) Canlı Etkinlik eklentisi: App ID `com.kuryekazanc.app.liveactivity` (ek yetenek yok), App Store profili "Kurye Kazanc LiveActivity App Store" → Codemagic referansı `kurye-kazanc-liveactivity-appstore`. **1.3 TestFlight'ından önce, kullanıcıya sorularak** yapılır; yapılmadan `ios-release` imzalamada düşer.
```

- [ ] **Step 2:** `PROGRESS.md`'ye "Oturum 4 — Sürüm 1.2 (derlenmedi)" bölümü: yapılanlar, `swift test` sonucu, derlenmediği ve TestFlight'a gitmediği, 1.3 öncesi imzalama önkoşulu.

- [ ] **Step 3:** Run: `swift test` → Expected: tüm Core testleri PASS.

- [ ] **Step 4: Commit** (push yok)

```bash
git add codemagic.yaml README.md PROGRESS.md
git commit -m "docs: surum 1.2 notlari; Canli Etkinlik imzalama referansi"
```
