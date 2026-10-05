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
