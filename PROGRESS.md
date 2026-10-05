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
