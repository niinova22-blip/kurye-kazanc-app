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
- **Son inceleme düzeltmeleri (2026-10-08):** "Verilerimi sil" artık eski (emekli) anonim/Apple kimliklerindeki veriyi de siler (emekli yenileme belirteçleri Keychain'de, yalnızca bu cihaz); ilk "Şimdi yedekle" öncesi uyarı (sunucudaki yedeği ezmesin); otomatik yedek yalnızca bir yedek tabanı (elle yedek / geri yükleme) varken; boşluksuz/önneksiz cep telefonu maskelenir; haftalık ekranlar vardiya olarak gönderilmez; Profil'de "Son gönderim"; Apple giriş hataları gösterilir; silme sürmekte olan gönderimi bekler; günlük sınır UTC gününe göre.
- Ertelenen küçükler ve kararlar: `.superpowers/sdd/2026-10-09-surum-1-3-sunucu/progress.md` ("minor (deferred)", "parked", "Ruling:").
- Sürüm **1.3.0**; `TESTFLIGHT_NOTES.md` 1.3.0 bölümü (1.2 + 1.3 yenilikleri, cihaz test listesi).

### Testler
- Core (Windows `swift test`): **100 test, 0 hata**.
- Uygulama XCTest'leri (`SupabaseClientTests`, `SyncCoordinatorTests`, `BackupServiceTests` vb.) Windows'ta çalıştırılamadı; ilk CI derlemesinde çalışacak.

### Derleme ve TestFlight durumu
- **1.2 + 1.3 henüz derlenmedi**, push edilmedi, TestFlight'a gönderilmedi.
- Info.plist'te `SupabaseURL` / `SupabaseAnonKey` yok → sunucu kapalı (Profil'de "Sunucu bu sürümde kapalı").

### Sonraki adım (kullanıcı onaylı sıra)
1. Supabase projesi (eu-central-1), Auth ayarları; betikler: apply → seed_templates → test → e2e; URL + anon anahtarı Info.plist'e.
2. Apple Developer: `com.kuryekazanc.app`'te Sign in with Apple (profil yeniden üretilir → Codemagic referansı); Canlı Etkinlik App ID + profil — kullanıcıya sorarak.
3. develop push → Codemagic `ios-ci`; derleme/test hatalarını düzelt.
4. TestFlight'tan önce kullanıcıya sor.

## Oturum 6 — 2026-10-09: Supabase canlı kurulum

### Yapılanlar
- Supabase projesi `kurye-kazanc` (ref `pgvdefkweclutfwgbxbh`, ücretsiz plan) oluşturuldu.
- Betikler (kullanıcı çalıştırdı; otomatik mod canlı veritabanına yazmayı engelliyor):
  - `apply`: 2 göç uygulandı.
  - `seed_templates`: 4 şablon (Trendyol GO, Getir, Yemeksepeti, Migros Hemen) v1.
  - `test`: pgTAP 9 grup / 22 kontrol, **hepsi geçti** (Görev 3'ün bekleyen canlı doğrulaması kapandı).
  - `e2e`: anonim oturum, gönderim/tekrar, shifts 403, şablon okuma, verilerimi sil 204 — **hepsi OK**.
- `Info.plist`: `SupabaseURL` + `SupabaseAnonKey` dolduruldu → uygulamada sunucu açık (UI testlerinde yine `nil`).
- Yerel gizli ayarlar `.env.supabase` dosyasında (`.gitignore` → `.env.*`); betikler `node --env-file=.env.supabase scripts/server/<betik>.mjs` ile çalışır. Erişim anahtarı yalnızca bu projeye kapsamlı, 7 gün geçerli.

### Açık konular
- Authentication: anonim + Apple (`com.kuryekazanc.app`) açık, Email kapalı (kullanıcı teyit etti).
- Oturumda eski (legacy) service_role anahtarı yanlışlıkla sohbet kaydına düştü → uygulama ve betikler yeni **publishable** anahtara (`sb_publishable_...`, `apikey` başlığında) geçirildi, e2e yeniden geçti. Eski JWT tabanlı anahtarlar kapatıldı.

- **İlk 1.2 + 1.3 CI derlemesi (#19, `a1f1f6a`) başarılı:** derleme + birim testleri **234/234** (UI testleri yalnızca PR'da).

- **Apple Developer:** `com.kuryekazanc.app`'te Sign in with Apple açıldı; "Kurye Kazanc App Store" yeniden üretildi; App ID `com.kuryekazanc.app.liveactivity` + "Kurye Kazanc Live Activity App Store" profili oluşturuldu. Codemagic'e `kurye-kazanc-appstore-v3` ve `kurye-kazanc-liveactivity-appstore` olarak çekildi; `codemagic.yaml` v3'e geçti.

### Sonraki adım
1. develop → main PR (UI testleri burada çalışır) → birleştirme → `ios-release` → TestFlight 1.3.0 — kullanıcıya sorarak.

## Oturum 6 (devam) — 2026-10-09: 1.4a okuma motoru ve senaryo testleri

### Yapılanlar
- **Okuma motoru:** şablona `layout` (summary/list/orderCard), `durationLabels`, `rowLabels`, `amountsExcludeVAT` alanları eklendi (geriye uyumlu; bilinmeyen layout = summary).
  - Şablon seçimi: platform adı; yoksa en az 3 parmak izi.
  - Tarih aralığı = haftalık ekran.
  - Liste ekranı: satır toplamı (iş numaraları atlanır).
  - Sipariş kartı: period `.order`, vardiya sayılmaz, sunucuya gönderilmez.
  - Çalışma süresi okuma: formda vardiya saatini doldurur; haftalık ve >16 sa yok sayılır.
  - KDV notu.
- **Yeni şablonlar (hepsi calibrating):** uber.earnings, thekurye.invoices, yemeksepeti.order, banabikurye.order; yemeksepeti.earnings v2 (KDV hariç). Kaynak: App Store mağaza görselleri (gerçek ekran yok).
- **Senaryo testleri:** 144 satır senaryosu (Windows `swift test`, hepsi geçiyor). Görüntü katmanı CI'da 72 örneklenmiş taklit ekran (SwiftUI + Vision); GitHub Actions özetinde platform × alan tablosu; taban `KuryeKazancTests/Fixtures/scenario-baseline.json` (5 puandan fazla düşüş CI'ı kırmızı yapar).
  - Ölçülen: tüm hücreler %100, yalnızca yemeksepeti/total %94,4.
  - Birim test adımı ~81 sn → ~163 sn.
- Core testleri: 135. CI yeşil.
- **Yan iş:** TestFlight 1.3.0 Codemagic #3 bir UI testinde düştü. Kök neden: UI testlerinin `-dataSharingOptIn NO` başlatma argümanı (UserDefaults argüman katmanı uygulamanın yazdığı değeri gölgeliyordu). PR #4 ile `-reset-defaults`'a geçildi ve main'e birleşti; Codemagic #4 yeniden denendi.

### Açık konular
- Gerçek kurye ekran görüntüleri (`Fixtures/RealScreens`) yok.
- Sunucu şablon tohumlama 1.4a TestFlight'ında yapılacak (`supabase/README.md` notu).
- yemeksepeti/total %94,4.

### Sonraki adım
- Kazanç taraması denemesi (plan Görev 10–12), her adımda kullanıcıya sorarak.

### 1.4a son inceleme düzeltmeleri (2026-10-09)
- Ekrandaki çalışma süresi yalnızca günlük ekranda, yeni formda (oturumdan açılmamış / düzenleme değil) ve gece yarısını aşmıyorsa başlangıç saatini doldurur; "Çalışma saatleri" yine kontrol ister.
- İngilizce ("feb 4 - feb 10") ve kısa ("4-10 şub") tarih aralıkları ile 16 saati aşan süre haftalık sayılır (gönderilmez).
- Sipariş kartları ekran görüntüsü önerilerinde çıkmaz.
- `seed_templates.mjs` liste / sipariş kartı şablonlarını sunucuya yazmaz (1.3 bunları özet ekran gibi okurdu).
- "Bugün" yazmayan liste ekranı (TheKurye faturaları) haftalık sayılır: birden çok günün toplamı vardiya olarak gönderilmez.
- Görüntü senaryoları artık şablon bazında raporlanır; taban yoksa test başarısız olur. Ölçüm: tüm hücreler %100, `yemeksepeti.order/total` %88,9 (9 örnekte 1). Core: 143 test.
- Ertelenen küçükler ve kararlar: `.superpowers/sdd/2026-10-09-surum-1-4a-ekran-okuma/progress.md`.

### Kazanç taraması denemesi — sonuç (2026-10-09, TestFlight 1.3.0 (4), iPhone)
- Yayın eklentisi (`spike/broadcast-capture`, birleştirilmedi) ~1,5 dk: 86 kare işlendi, **en yüksek bellek 20,6 MB** (hedef < 40, iOS sınırı ~50), okuma ort. 0,46 sn / en uzun 1,18 sn, çökme yok, pil %75 → %74.
- 38 yakalama / 24 tanınmayan / 24 tekrar. 24 farklı deneme ekranına karşı 38 yakalama: metin özetiyle tekrar kontrolü yetmiyor (durum çubuğundaki saat, kaydırma sırasındaki yarım kareler metni değiştiriyor).
- Kısayollar otomasyonu testi kullanıcı tarafından yapılamadı.
- **Karar:** kazanç taraması uygulanabilir → üretim tasarımına geçilir (spec §5.4). Üretimde: tekrar kontrolü okunan değerlerle (şablon + tutar + tarih), durum çubuğu okumadan hariç, bir ekran ancak art arda 2 karede aynı okunursa kaydedilir; sipariş kartları gün bazında birleştirilir; onay ekranı. Kısayollar ikinci yol (basit hazır kısayol).
- 8 şablonun hepsi yakalandı (getir, migros_hemen, thekurye, trendyol_go, uber, yemeksepeti.earnings, yemeksepeti.order, banabikurye). Her platformun 3 deneme ekranına karşı Uber/TheKurye/Banabikurye 2'şer yakalandı: bir ekran kaçmış olabilir (liste sonunda hızlı geçiş) — üretimde kısa kalan / onaylanmayan kareler ayrıca sayılacak.

## Oturum 6 (devam 2) — 2026-10-09: Kazanç taraması (üretim) ve Kısayollar
- Core: CaptureKey, StableCaptureFilter, ScanResultBuilder + sipariş kartı birleştirme (gün + platform).
- Yayın eklentisi (üretim): ekranın üst %6'sı (durum çubuğu) okumadan hariç, iki kare doğrulama, değer tabanlı tekrar kontrolü, BroadcastCaptureStore, lastFrameAt.
- ScanResultsViewModel / ScanResultsView: atlanan kalemler silinmez, canlı yayında sonuç ekranı açılmaz.
- Bugün'de ScanButton + tanıtım.
- SendScreenshotIntent + KuryeShortcuts (Kısayollar eylemi).
- TestFlight artık GitHub Actions ile (ios-release.yml, sertifika GT35S8T4WB, profiller --create).
- Bilinen sınır: aynı tutarlı iki farklı sipariş kartı tek sayılır (gerçek ekranla sipariş no eklenecek).
- Sürüm 1.4.0.
- Sonraki adım: develop→main PR → TestFlight 1.4.0 → cihaz testi.

## Oturum 7 — 2026-10-10: 1.4.1 fotoğraflardan kazanç taraması

- Cihaz testi (1.4.0) sonrası kullanıcı kararı: ekran kaydı yerine rehber + son 24 saatin ekran görüntülerini okuma (spec §6, plan `docs/superpowers/plans/2026-10-09-surum-1-4b-fotograf-taramasi.md`).
- Test hataları: Uber/TheKurye/Banabikurye platform listesinde; haftalık özet kaydedilmez; platform adları; mesaj.
- Core: `ScanWindow` (24 sa / test 30 gün); 4 platform şablonuna çalışma süresi etiketleri (sürümler +1).
- `PhotoScanService` (300 getir → bilinenleri ele → en fazla 60 oku, `didTruncate`, oturumluk red listesi); `ScanResultsViewModel` fotoğraf kaynağı (ilçe, tüm görüntü kimlikleri, kaydedilenler yeniden gelmez).
- `ScanGuideView`: her basışta rehber, dönüşte otomatik tarama, izin/Ayarlar, test anahtarı (Profil > Test araçları). Yayın düğmesi Bugün'den kaldırıldı (eklenti kodu duruyor).
- 30 günlük test görselleri: masaüstü `Kurye-Test-30-Gun` (112 JPEG, EXIF tarihli).
- **CI/CD tekrar Codemagic'te**: GitHub Actions kotası %90 (özel repo, macOS ×10). `.github/workflows` yalnızca elle; Codemagic `ios-ci` push/PR, `ios-release` main/release; yayın eklentisi profili `kurye-kazanc-broadcast-appstore`; `submit_to_testflight: false`.
- Sürüm 1.4.1. Sıradaki: 1.4b Topluluk (sunucu ısı haritası + test kuryeleri, seçenek a), sonra akıllı çalışma planlama modülü.

### 1.4b Topluluk (2026-10-10)
- Sunucu (canlı): `shifts.is_synthetic`, `community_heatmap` / `community_summary` (k ≥ 5 farklı kurye; 56 gün; dakika ağırlıklı ₺/saat, gece yarısı devri); pgTAP 19/19. Sentetik test verisi: 10 kurye, 338 vardiya, Ankara/Sincan (`seed_synthetic.mjs`; gerçek lansmandan önce `purge_synthetic.mjs`).
- Uygulama: `SupabaseClient` RPC'leri, Core `CommunityModels`, `CommunityViewModel` (paylaşım kapalıyken ağ yok), Topluluk sekmesi (ilçe seçici, ₺/saat + kendi karşılaştırma, ortak `HeatmapChart`, platformlar, en iyi saatler).
- Not (lansman öncesi): anonim kayıt sınırsız olduğundan k=5 hücresi sahte hesaplarla çözülebilir — App Attest / hız sınırı lansmandan önce.
- Sıradaki: 1.4.1 TestFlight (fotoğraf taraması + Topluluk), sonra akıllı çalışma planlama motoru (hafıza: next-planner-module).

## Oturum 7 (devam) — 2026-10-10: 1.5.0 akıllı çalışma planlama motoru

### Yapılanlar
- Araştırma `docs/research/2026-10-10-platform-kurallari.md` (kullanıcının 8 başlıklı belge listesi dahil), tasarım `docs/superpowers/specs/2026-10-10-planlama-motoru-design.md`, plan `docs/superpowers/plans/2026-10-10-planlama-motoru.md`.
- Core `KuryeKazanc/Core/Planner/`: `PlatformRule`/`RuleSet` (kaynaklı, sürümlü, 90 gün stale, kullanıcı onayı), `BundledRules` (44 kural, bulunamayanlar `unknownTerm`), `WorkProfile`, `EarningsForecaster` (p25/p50/p75, ≥3 örnek, 8 hafta), `PlanValidator`, `PlanEngine` (30 dk dilimli DP; en kârlı / düşük riskli / az saat; brüt-gider-vergi; kayıtlı plan yeniden doğrulama). 208 Core testi geçiyor.
- Sunucu: göç `20261010000004_platform_rules.sql`, pgTAP `003_platform_rules.sql`, `seed_platform_rules.mjs`, `check_sources.mjs`, `approve_rule.mjs`. **Canlıya uygulanmadı.**
- Uygulama: `SyncCoordinator.refreshRulesIfNeeded/ruleSet`, `SupabaseClient.fetchPlatformRules`, `PlannerViewModel`, `PlannerView`, `WorkProfileView`, `PlatformRulesView`; Bugün > Plan öner, Profil > Çalışma profili ve plan. Sürüm 1.5.0.

### Kullanıcının çalıştıracakları (canlı veritabanı)
```
node --env-file=.env.supabase scripts/server/apply.mjs
node --env-file=.env.supabase scripts/server/test.mjs
node --env-file=.env.supabase scripts/server/seed_platform_rules.mjs
node --env-file=.env.supabase scripts/server/check_sources.mjs --dry-run
```

### Açık konular
- Uygulama kodu (fotoğraf taraması + Topluluk + planlayıcı) henüz derlenmedi: tek push → Codemagic.
- Sözleşme/slot/hakediş/askı/itiraz/çoklu platform belgelerinin çoğu kamuya açık değil; kurye belgeleri gelince kurallar güncellenmeli.
- Kural kaynakları ayda bir `check_sources.mjs` ile kontrol edilmeli (90 günü geçen kural "güncelliği bilinmiyor" olur).

### 1.5.0 yayın durumu (2026-10-10)
- PR #7 (develop → main) birleşti; Codemagic `ios-release` #6 (67b829c) başarılı: derleme, birim + UI testleri yeşil, **1.5.0 (6) App Store Connect'e yüklendi** (TestFlight işleme sonrası "İç Test").
- Develop'taki ara CI derlemeleri (#23–#32) `cancel_previous_builds` nedeniyle iptal; doğrulama main yayın derlemesinde yapıldı.
- Sıradaki: cihazda 1.5.0 testi (fotoğraf taraması, Topluluk, Plan öner); canlı veritabanına `platform_rules` göçü + tohum (yukarıdaki komutlar) uygulanmadıysa uygulanmalı — uygulanmazsa uygulama gömülü kurallarla çalışır.
