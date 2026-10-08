# PROGRESS

Her oturumun sonunda yeni bir bölüm **eklenir** (eski bölümler değiştirilmez).
Yeni oturuma başlarken önce bu dosyayı okuyun; "Tamamlandı" olarak işaretlenenleri tekrar yapmayın.

## V1 yol haritası

| # | Özellik | Durum |
|---|---|---|
| 1 | Proje iskeleti (XcodeGen), CI/CD (codemagic.yaml), veri modelleri, ana ekran taslağı | ✅ Oturum 1 |
| 2 | Onboarding (profil, araç tipi, sık kullanılan platformlar) | ⏳ |
| 3 | Kazanç ekle – manuel form | ⏳ |
| 4 | OCR: Vision + Trendyol GO / Getir regex şablonları + onay/düzenleme ekranı | ⏳ |
| 5 | Gider ekle formu | ⏳ |
| 6 | LocationService: "Çalışıyorum" modunda arka plan takibi, mesafe, CLGeocoder ile ilçe/semt | ⏳ |
| 7 | Geçmiş/Analiz: günlük/haftalık/aylık özet, platform bazında toplam | ⏳ |
| 8 | Ayarlar: km başı maliyet, otomatik tahmin, konum izni, veri paylaşım opt-in | ⏳ |
| 9 | Gerçek uygulama ikonu, VersionedSchema (göç planı), ilk TestFlight | ⏳ |

---

## Oturum 1 — 2026-10-05

**Commit mesajı önerisi:** `chore: proje iskeleti, CI/CD, SwiftData modelleri ve ana ekran taslağı (#1)`

### Yapılanlar
- **Proje yapısı:** Windows'ta Xcode olmadığı için `.xcodeproj` elle yazılmadı; `project.yml` (XcodeGen) eklendi, proje CI'da üretiliyor. iOS 17+, Swift 5 modu, 3 hedef (uygulama, birim test, UI test), ortak `KuryeKazanc` şeması.
- **Info.plist:** `GENERATE_INFOPLIST_FILE` + kısmi plist (konum izin metinleri, `UIBackgroundModes: location`, `ITSAppUsesNonExemptEncryption = false`).
- **Veri modelleri (SwiftData):** `Courier`, `Platform`, `EarningRecord`, `ExpenseRecord`.
  - Enum'lar (`VehicleType`, `EarningSource`, `ExpenseType`) `...Raw: String` olarak saklanıyor (predicate uyumu + bozuk veriye dayanıklılık).
  - Anonim paylaşıma hazırlık: kayıtlar `anonymousDeviceID` (cihazda üretilen rastgele UUID, UserDefaults'ta) taşır; `Courier`'a ilişki yok; ham GPS koordinatı yok, yalnızca il/ilçe/semt. V1'de hiçbir yere gönderilmiyor.
  - `EarningRecord`'a OCR için `packageCount` (paket sayısı) eklendi.
  - Tutarlar `Double` (V1 için yeterli; gerekirse Decimal'e geçilebilir).
- **İş mantığı:** `EarningsCalculator` (saf struct, SwiftData'dan bağımsız):
  - Net TL/saat = (brüt + bonus − giderler) / çalışma süresi; süre yoksa `nil` ("—").
  - Çalışma süresi, aralıkların **birleşimi** (aynı anda iki platformda çalışma iki kez sayılmaz).
  - Gider = manuel + km başına tahmin (yakıt+bakım). O gün manuel yakıt/bakım girildiyse tahmin uygulanmaz (çift sayım yok); lastik/amortisman/diğer her zaman eklenir.
  - Platform bazında toplam (`totalsByPlatform`).
- **Ana ekran (SwiftUI taslak):** `DashboardView` + `DashboardViewModel` (@Observable). Net kazanç kartı, Net TL/saat / çalışma süresi / mesafe kutuları, "Çalışmaya başla/bitir" düğmesi (durum kalıcı, konum henüz bağlı değil), bugünkü kayıtlar listesi, "+" menüsü (kazanç/gider ekleme şimdilik "yakında" sayfası).
- **Testler:** `EarningsCalculatorTests` (15 test), `ModelTests` (in-memory SwiftData), `DashboardUITests` (örnek veriyle 850 TL / 6 sa doğrulaması; `-ui-testing -sample-data` başlatma argümanları).
- **CI/CD:** `codemagic.yaml` — `ios-ci` (main/release dışı dallar + PR: build + unit + UI test, JUnit raporu) ve `ios-release` (main, release/*: testler + `use-profiles` + build no. arttırma + IPA + TestFlight). Simülatör adı sabitlenmedi (`scripts/ci/pick_simulator.sh`). TestFlight notu `TESTFLIGHT_NOTES.md`'den üretiliyor (`scripts/ci/make_release_notes.sh`).
- Geçici 1024×1024 uygulama ikonu (alfa kanalsız), AccentColor.

### Değişen/eklenen dosyalar
`project.yml`, `codemagic.yaml`, `.gitignore`, `.gitattributes` (LF zorunlu; CI scriptleri macOS'ta CRLF ile bozulmasın), `README.md`, `PROGRESS.md`, `TESTFLIGHT_NOTES.md`,
`scripts/ci/pick_simulator.sh`, `scripts/ci/make_release_notes.sh`,
`KuryeKazanc/App/{KuryeKazancApp,RootView,ModelContainerFactory,SampleData}.swift`,
`KuryeKazanc/Models/{Enums,Courier,Platform,EarningRecord,ExpenseRecord,AnonymousDeviceID}.swift`,
`KuryeKazanc/Services/{EarningsCalculator,AppPreferences,DataSeeder}.swift`,
`KuryeKazanc/ViewModels/DashboardViewModel.swift`, `KuryeKazanc/Views/Dashboard/DashboardView.swift`,
`KuryeKazanc/Utilities/Formatters.swift`, `KuryeKazanc/Supporting/Info.plist`, `KuryeKazanc/Resources/Assets.xcassets/*`,
`KuryeKazancTests/{EarningsCalculatorTests,ModelTests}.swift`, `KuryeKazancUITests/DashboardUITests.swift`

### Doğrulama durumu
- ⚠️ Kod **henüz derlenmedi/test edilmedi** (Windows'ta mümkün değil). İlk push'taki Codemagic `ios-ci` çalışması ilk gerçek doğrulama olacak; derleme hatası çıkarsa sonraki oturumun ilk işi bu.
- YAML dosyaları (codemagic.yaml, project.yml) sözdizimi olarak doğrulandı.

### Açık konular / kullanıcıdan beklenenler
- GitHub reposunu oluşturup Codemagic'e bağlamak; README'deki "Codemagic'te bir kez yapılacak ayarlar" tablosu.
- Bundle ID `com.kuryekazanc.app` geçici — App Store Connect'te kayıtlı ID ile değiştirilmeli (project.yml + codemagic.yaml).
- Km başına varsayılan maliyetler (`VehicleType.defaultCostPerKm`) kaba tahmin; kuryelerle doğrulanmalı.

### Sonraki adım
1. İlk CI çalışmasının sonucunu kontrol et, varsa derleme/test hatalarını düzelt.
2. Yol haritası #2 (Onboarding) ve #3 (manuel Kazanç ekle formu).

## Oturum 1 (devam) — 2026-10-05

**Commit:** `ci: Codemagic entegrasyon adını düzelt, build numarası için yedek`

### Yapılanlar
- İlk commit atıldı ve GitHub'a gönderildi: private repo `niinova22-blip/kurye-kazanc` (`main`).
- Codemagic hesabı incelendi: GitHub entegrasyonu ve Developer Portal (App Store Connect API) anahtarı zaten bağlı. Anahtarın adı `Codemagic`; `codemagic.yaml` buna göre güncellendi.
- `ios-release`: `APP_STORE_APPLE_ID` yoksa build numarası Codemagic `BUILD_NUMBER`'dan üretiliyor (adım çökmesin).

### Engel (kullanıcı yapmalı)
- Codemagic GitHub App'i yalnızca seçili repolara erişiyor; `kurye-kazanc` eklenmeli. GitHub bu ayar için kimlik doğrulaması (sudo mode) istiyor → github.com/settings/installations → Codemagic CI/CD → Configure → Repository access'e `kurye-kazanc` ekle.
- Ardından Codemagic → Add application → `kurye-kazanc` → iOS.
- TestFlight için: App Store Connect'te `com.kuryekazanc.app` bundle ID'li uygulama kaydı oluşturulmalı; sayısal Apple ID'si Codemagic'te `app_store_credentials` grubuna `APP_STORE_APPLE_ID` olarak eklenmeli.

### Sonraki adım
- Repo Codemagic'e bağlanınca ilk CI çalışmasının sonucunu kontrol et, derleme/test hatalarını düzelt.

## Oturum 1 (devam 2) — 2026-10-05

### Yapılanlar
- Codemagic GitHub App erişimine `kurye-kazanc` eklendi; Codemagic'te `kurye-kazanc` uygulaması (iOS) oluşturuldu.
- İlk CI çalışması (`ios-ci`, `main`, elle tetiklendi): **BAŞARILI** — XcodeGen 16 sn, derleme 47 sn, birim testleri **21/21** (EarningsCalculatorTests 15, ModelTests 6), UI testleri **3/3** (DashboardUITests).
  Build: https://codemagic.io/app/6ac40d8d93090394b5725bb9/build/6ac40d9f7394575b200b6a64
- Böylece Oturum 1 kodu derleniyor ve testleri geçiyor (önceki "henüz derlenmedi" uyarısı kapandı).

### Dikkat
- Repo bağlandığı için `main`/`release/*` push'ları artık `ios-release`'i (TestFlight) tetikler. App Store Connect'te `com.kuryekazanc.app` kaydı + `APP_STORE_APPLE_ID` tanımlanana kadar bu akış imzalamada düşer → o zamana kadar geliştirme `develop`/özellik dallarında yapılmalı ya da `main` commit'lerine `[skip ci]` eklenmeli.

### Sonraki adım
- Yol haritası #2 Onboarding ve #3 manuel Kazanç ekle formu (özellik dalında).
- Kullanıcı: App Store Connect'te uygulama kaydı → `APP_STORE_APPLE_ID` → ilk TestFlight.

## Oturum 2 — 2026-10-06

**Commitler:** `feat: V1 ekranları — onboarding, kazanç (manuel+OCR), gider, geçmiş/analiz, ayarlar, konum`, `test: Ayarlar UI testinde tembel yüklenen satır için kaydırma; sürüm 1.0.0 ve TestFlight notları`

### Tamamlanan (yol haritası #2–#9, V1 uygulama tarafı)
- **Onboarding** (`Views/Onboarding`, `OnboardingViewModel`): ad (isteğe bağlı) → araç tipi → platformlar (en az 1) → konum izni bilgisi. Bitince Courier oluşur, km başı maliyet araç tipine göre ayarlanır.
- **Kazanç formu** (`Views/Earnings/EarningFormView`, `EarningFormViewModel`): manuel giriş, düzenleme, "Çalışıyorum" oturumundan ön doldurma (süre, km, ilçe). Türkçe sayı girişi (`TurkishNumberParser`). Gece yarısını geçen vardiya desteği.
- **OCR** (`Services/OCR`): Vision `VNRecognizeTextRequest` (tr-TR, cihaz üstünde) + `EarningsScreenshotParser` + `TrendyolGoTemplate`/`GetirTemplate` (regex: tarih, paket/sipariş sayısı, toplam, bonus). Güvenilmeyen alan boş bırakılmaz: en iyi tahmin yazılır ve turuncu "Bu alanları kontrol et" ile işaretlenir; işaretli alan varken kaydetmede onay istenir. Çalışma saatleri ekran görüntüsünde olmadığından her OCR'da kontrol için işaretlenir.
- **Gider formu** (`Views/Expenses`, `ExpenseFormViewModel`): tür, tutar, tarih, not; yakıt/bakım girilince o günün km tahmini düşer.
- **Konum** (`LocationService`, `WorkSessionManager`): yalnızca "Çalışıyorum" modunda `startUpdatingLocation` + arka plan (UIBackgroundModes=location), 25 m filtre, gürültü/sıçrama eleme; bitince durur. Oturum uygulama kapanıp açılınca devam eder. CLGeocoder ile il/ilçe/semt; ham koordinat saklanmaz. UI testlerinde konum kapalı.
- **Geçmiş/Analiz** (`Views/History`): gün/hafta/ay (hafta Pazartesi başlar, `PeriodRange`), özet, günlük net grafiği (Swift Charts), platform bazında toplam, düzenle/sil. Gider tahmini kuralı gün bazında (`summarizeByDay`).
- **Ayarlar** (`Views/Settings`): profil/araç/platformlar, otomatik tahmin + km başı maliyet, konum izni durumu/yükseltme, anonim veri paylaşımı (varsayılan kapalı, açık onay ekranı, onay tarihi saklanır, V1'de gönderim yok), tüm kayıtları sil.
- **Ana yapı:** `MainTabView` (Bugün / Geçmiş / Ayarlar), gün değişiminde Bugün ekranı yenilenir. Bugün ekranında gider satırları, düzenle/sil.
- **App Store hazırlığı:** `SchemaV1` + `KuryeMigrationPlan` (sonraki model değişiklikleri veri kaybetmeden göç eder), `PrivacyInfo.xcprivacy` (UserDefaults CA92.1, izleme yok, veri toplama yok), sürüm 1.0.0, `TESTFLIGHT_NOTES.md` 1.0.0 bölümü (gerçek cihaz test listesi).
- **CI:** Codemagic webhook'u oluşturuldu (artık her push otomatik build+test tetikliyor).

### Testler
- Birim: 58/58 geçti (EarningsCalculator 17, EarningsScreenshotParser 11, FormViewModel 12, Model 6, PeriodRange 5, TurkishNumberParser 7).
- UI (build #2): 8/9 geçti; `testHistoryAndSettingsTabs` testteki bir eksik yüzünden düştü (tembel Form satırı ekran dışında) → test düzeltildi, build #3'te doğrulanacak.

### Açık konular
- OCR şablonları gerçek ekran görüntüleriyle kalibre edilmeli (TestFlight'tan örnek toplanacak).
- Uygulama ikonu geçici.
- TestFlight: App Store Connect'te `com.kuryekazanc.app` kaydı + Codemagic `APP_STORE_APPLE_ID` → `develop`'u `main`'e birleştir → `ios-release`.

## Oturum 2 (devam) — 2026-10-06

### Verimlilik / kalite
- **KuryeCore paketi:** saf mantık `KuryeKazanc/Core`'a taşındı; kökteki `Package.swift` aynı dosyaları derler. Windows'ta `swift test`: 40 test ~0,7 sn (Swift 6.4 + VS Build Tools kuruldu). Core'a SwiftData/UIKit/SwiftUI/Vision import eden dosya konmaz. Core testleri `#if canImport(KuryeCore)` ile hem SwiftPM hem Xcode'da çalışır.
- **pre-push kancası** (`.githooks/pre-push`, `git config core.hooksPath .githooks`): push öncesi `swift test`.
- **CI:** UI testleri sıradan push'ta atlanır; PR'larda ve `ios-release`'te (`RUN_UI_TESTS=true`) çalışır.
- **OCR testçi raporu:** TestFlight/DEBUG'da formdan Vision satırlarını teste hazır Swift dizisi olarak paylaşma (`BuildEnvironment`, `ocrDiagnosticReport`).
- **Dal koruması:** GitHub ücretsiz planda private repoda yok → kural: `main`'e yalnızca `develop`'tan PR ile, CI yeşilse.
- **Uygulama ikonu:** `scripts/design/make_app_icon.py` ile üretildi (₺ + hız çizgileri + artış oku).

### App Store / TestFlight kurulumu (tamam)
- Apple Developer: App ID `com.kuryekazanc.app` kaydedildi (ek yetenek yok).
- App Store Connect: "Kurye Kazanç" (iOS, Türkçe, SKU `kurye-kazanc-ios`), Apple ID **6819440649** → `codemagic.yaml` vars (gizli değil).
- Provisioning profile "Kurye Kazanc App Store" (sertifika: Distribution, 12.09.2027 — Codemagic'teki `selfwake-distribution`) → Codemagic'e `kurye-kazanc-appstore` adıyla çekildi.
- Build numarası adımı ilk yükleme (boş TestFlight) için sağlamlaştırıldı.

### CI
- develop: build #3 (UI dahil) ve #4 (Core taşıma sonrası) yeşil.

### Sonraki adım
- `develop → main` PR → CI (UI dahil) yeşil → birleştir → `ios-release` → TestFlight 1.0.0 (1).
- TestFlight'ta gerçek cihaz testleri (TESTFLIGHT_NOTES.md listesi), OCR raporlarıyla şablon kalibrasyonu.

## Oturum 2 (kapanış) — 2026-10-06

- PR #1 (develop → main) CI'dan geçti (UI dahil, 11 dk) ve birleştirildi (`09c1208`).
- `ios-release` başarılı → **TestFlight 1.0.0 (1) yüklendi** (App Store Connect'te Processing).
- Masaüstünde `KURYE_KALDIGIM_YER.txt`: kısa devam notu.

### Sonraki adım
1. Processing bitince TestFlight'ta dahili test grubu oluştur, kendini ekle → iPhone'a TestFlight uygulamasıyla kur.
2. Gönüllü kuryeler (App Store Connect kullanıcısı değillerse) için harici grup: ilk build Apple Beta App Review'dan geçer (~1 gün). Gerekirse `codemagic.yaml` → `beta_groups`.
3. Gerçek cihaz testleri (TESTFLIGHT_NOTES.md), OCR raporlarıyla şablon kalibrasyonu.

## Oturum 3 — 2026-10-07: Sürüm 1.1.0 (iOS tarzı arayüz ve cihaz üstü temel)

Tasarım: `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md` · Plan: `docs/superpowers/plans/2026-10-07-surum-1-1-arayuz-ve-cihaz-ustu.md`

- **Core:** JSON OCR şablon motoru (Trendyol GO, Getir, Yemeksepeti, Migros — hepsi `calibrating`), doğrulama seviyeleri (`manual` / `ocrEdited` / `ocrUnverified` / `verified`) ve ekran görüntüsü değerlendirmesi, analizler (gün×saat ısı haritası, en kârlı saatler, platform karşılaştırması, dönem değişimi), hedef ilerlemesi. Windows `swift test`: 62 test.
- **Model:** SchemaV2 (doğrulama seviyesi + `ScreenshotEvidence`), dondurulmuş SchemaV1 ve V1→V2 göçü (OCR kaynaklı eski kayıtlar `ocrUnverified`).
- **Arayüz:** Bugün / Analiz / Topluluk (iskelet) / Profil; yeşil tek vurgu, ana rakam + metrik şeridi, hedef halkası, doğrulama rozetleri; 4 adımlı onboarding.
- **Ekran görüntüsü:** kanıt (OCR satırları + kutular; görsel saklanmaz), son 48 saat otomatik öneri (izin yalnızca kullanıcı açınca), paylaş menüsü eklentisi + App Group gelen kutusu.

### Açık konular
- Paylaş eklentisi için Apple Developer önkoşulları (README → İmzalama) yapılmadan `ios-release` imzalamada düşer.
- Şablonlar gerçek ekran örnekleriyle kalibre edilene kadar hiçbir kayıt "Doğrulandı" olmaz (beklenen).
- Sonraki: 1.2 planı (Live Activity, widget, hareket algılama, PDF/CSV, Siri).

## Oturum 4 — 2026-10-08: Sürüm 1.2 (derlenmedi)

Tasarım: `docs/superpowers/specs/2026-10-08-surum-1-2-otomatik-vardiya-design.md`

### Yapılanlar
- **Core (`KuryeKazanc/Core/Shift/`, saf):** `AutoShiftPolicy` (başlatma/bitirme/iptal kuralları), `WorkHours` (çalışma saatleri penceresi, gece yarısını aşabilir; varsayılan 09:00–01:00, "Her saatte" seçeneği), `MotionSample` (CoreMotion örneği; yalnızca orta/yüksek güvenli araç veya bisiklet hareket sayılır), `PendingShift` + `PendingShiftList` (en fazla 5, 24 saat), `LiveActivityThrottle` (güncelleme sıklığı).
- **Servisler:** `CoreMotionActivityProvider` (CMMotionActivityManager geçmiş sorgusu), `ShiftNotifications` ("Vardiya başladı" + "Bu bir vardiya değil" eylemi, "Vardiya bitti" → kazanç formu), `LiveActivityController` (ActivityKit aç/güncelle/bitir/kapat), `AutoShiftCoordinator` (uyanma → hareket geçmişi → politika → başlat/bitir/iptal; bekleyen vardiyalar; tüm başlatma/bitirme buradan geçer). `LocationService`: önemli konum değişikliği izleme, son hareket zamanı (≥ 50 m), konum olayı bildirimi; `WorkSessionManager`: vardiya kaynağı (elle/otomatik), geri tarihli başlangıç, iptal.
- **Otomatik km:** vardiya boyunca GPS ile biriken mesafe (mevcut "Çalışıyorum" takibi; otomatik vardiyada iOS duraklatmaz). Koordinat saklanmaz, yalnızca il/ilçe/semt metni.
- **Uygulama:** `AppEnvironment` (tek nesne grafiği: SwiftUI sahnesi, AppDelegate ve Canlı Etkinlik Intent'i aynı örnekleri kullanır) + `AppDelegate` (konum olayıyla arka planda yeniden başlatmada izlemeyi kurar, bildirim eylemlerini işler).
- **`KuryeLiveActivity` eklentisi:** kilit ekranı + Dynamic Island; süre, km, bugünkü net, ~₺/saat ve "Vardiyayı bitir" düğmesi (`EndShiftIntent`, `Shared/`). Canlı Etkinlikten bitirilen vardiya bekleyen vardiya olur, "Vardiya bitti" bildirimi kazanç formuna götürür.
- **Arayüz:** Profil "Otomatik vardiya" bölümü (anahtar + çalışma saatleri, izin uyarısı); Bugün'de "Bu bir vardiya değil" satırı ve "Biten vardiyalar" bölümü; onboarding'de isteğe bağlı açma.
- **Kurallar:** çalışma saatleri içinde son 10 dakikada 3 dakika kesintisiz hareket → başlar (başlangıç hareketin ilk görüldüğü an); "Bu bir vardiya değil" sonrası 30 dk yeniden başlamaz; 20 dk hareketsizlikte biter, bitiş = son hareket anı (süreç ölüyken geçen uzun duraklama da aynı şekilde kesilir); 5 dakikadan kısa ve 1 km'den az otomatik vardiya sessizce atılır; biten vardiya kazancı kaydedilene kadar bekler. Elle vardiya yalnızca kullanıcı bitirince biter.
- **1.1 arayüz düzeltmeleri (bugün):** formlarda klavye kaydırınca ve "Bitti" ile kapanır; kazanç paylaşımı onayı konum yoğunluğunu da açar.
- **Son inceleme düzeltmeleri:** Canlı Etkinlik "Vardiyayı bitir" artık süre/km'yi kaybetmez; arka planda başlayan vardiyanın Canlı Etkinliği ön plana dönüşte açılır; her GPS olayında hareket geçmişi sorgulanmaz; elle vardiya başlığı "Vardiya · elle".

### Testler
- Core (Windows `swift test`): **90 test, 0 hata** (89 + saat geri alınınca Canlı Etkinlik güncellemesi).
- Uygulama XCTest'leri (`AutoShiftCoordinatorTests` vb.) Windows'ta çalıştırılamadı; elle izlendi.

### Derleme ve TestFlight durumu
- **Sürüm 1.2 derlenmedi, push edilmedi, TestFlight'a gönderilmedi** — kullanıcı kararı.
- **1.3 TestFlight öncesi önkoşul:** Apple Developer'da Canlı Etkinlik eklentisi App ID'si `com.kuryekazanc.app.liveactivity` ve App Store profili oluşturulmalı; yoksa `ios-release` imzalamada düşer. Kullanıcıya sorulacak.

### Sonraki adım
- 1.3 ile birlikte ilk CI derlemesi (uygulama + eklenti) ve uygulama testleri; gerçek cihazda otomatik vardiya ve Canlı Etkinlik denemesi.

## Oturum 5 — 2026-10-09: Sürüm 1.3.0 (sunucu; derlenmedi)

Tasarım: `docs/superpowers/specs/2026-10-09-surum-1-3-sunucu-design.md` · Plan: `docs/superpowers/plans/2026-10-09-surum-1-3-sunucu.md`

### Yapılanlar
- **Core (saf):** saf Swift SHA-256 ve ekran metni özeti (`TextHash`), vardiya yükü (`ShiftPayload`: il/ilçe, hafta günü, 15 dk dilim, 0,5 km'ye yuvarlı mesafe; yalnızca `verified`/`ocrUnverified`), `OutboxPolicy` (üstel bekleme 1 dk → 6 sa, günlük sınırda ertesi gün), `CalibrationMasker` (IBAN, telefon, TC kimlik, e-posta), `TemplateMerger` (gömülü + uzak şablon).
- **Sunucu (`supabase/`):** şema, RLS, `submit_shift` / `submit_calibration` / `delete_my_data` fonksiyonları, günlük hız sınırları, pgTAP testleri; `scripts/server/` betikleri (apply, seed_templates, test, e2e). Kurulum: `supabase/README.md`.
- **Servisler (`Services/Sync/`):** `SupabaseClient` (elle yazılmış REST; anonim oturum, Apple id_token, Keychain'de oturum, yalnızca HTTPS), `OutboxQueue` (Application Support/outbox.json, dosya korumalı), `SyncCoordinator` (rıza + kayıt → kuyruk, boşaltma, kalibrasyon, 12 saatte bir şablon çekimi; rıza yoksa ağ yok), `BackupService` + `AccountService` (Apple ile Giriş, yedekle/geri yükle, 24 saatte bir otomatik yedek, "Verilerimi sil").
- **Arayüz:** Profil > "Hesap ve yedek", "Kalibrasyon" (ayrı açık rıza), "Gizlilik ve KVKK"; formda "Kalibrasyona gönder". KVKK aydınlatma ve açık rıza **taslakları** `docs/legal/`.
- **Bağlantılar (Görev 8):** `AppEnvironment` istemciyi yalnızca Info.plist ayarı varsa kurar (UI testlerinde `nil`); `SyncCoordinator` + `AccountService` sahneye `.environment` ile verilir. Açılışta ve ön plana dönüşte şablon yenileme + kuyruk boşaltma. Kayıt sonrası kuyruğa ekleme + girişliyse yedek. Kayıt silinince bekleyen gönderimi düşer (`recordDeleted`, "Tüm kayıtları sil" → `allRecordsDeleted`). Paylaşım kapatılınca kuyruk temizlenir. Tüm ekran görüntüsü okumaları (form, paylaş gelen kutusu, çoklu seçim, otomatik tarama) birleşik şablonları kullanır. 1.2 öncesi "veri gönderilmez / yalnızca bu cihazda" metinleri 1.3'e göre düzeltildi.
- Sürüm **1.3.0**; `TESTFLIGHT_NOTES.md` 1.3.0 bölümü (1.2 + 1.3 yenilikleri, cihaz test listesi).

### Testler
- Core (Windows `swift test`): **98 test, 0 hata**.
- Uygulama XCTest'leri (`SupabaseClientTests`, `SyncCoordinatorTests`, `BackupServiceTests` vb.) Windows'ta çalıştırılamadı; ilk CI derlemesinde çalışacak.

### Derleme ve TestFlight durumu
- **1.2 + 1.3 henüz derlenmedi**, push edilmedi, TestFlight'a gönderilmedi.
- Info.plist'te `SupabaseURL` / `SupabaseAnonKey` yok → sunucu kapalı (Profil'de "Sunucu bu sürümde kapalı").

### Sonraki adım (kullanıcı onaylı sıra)
1. Supabase projesi (eu-central-1), Auth ayarları; betikler: apply → seed_templates → test → e2e; URL + anon anahtarı Info.plist'e.
2. Apple Developer: `com.kuryekazanc.app`'te Sign in with Apple (profil yeniden üretilir → Codemagic referansı); Canlı Etkinlik App ID + profil — kullanıcıya sorarak.
3. develop push → Codemagic `ios-ci`; derleme/test hatalarını düzelt.
4. TestFlight'tan önce kullanıcıya sor.
