# Kurye Kazanç (iOS)

Kuryeler için net kazanç takip uygulaması. Swift + SwiftUI + SwiftData, MVVM, iOS 17+.

## Geliştirme akışı (Windows, Xcode yok)

1. Swift kaynaklarını ve `project.yml` dosyasını VS Code'da düzenleyin.
2. `.xcodeproj` repoda **yoktur**; CI'da [XcodeGen](https://github.com/yonaskolb/XcodeGen) ile `project.yml`'den üretilir.
   Yeni bir `.swift` dosyası eklemek için projeye "eklemeniz" gerekmez — ilgili klasöre koymanız yeterli.
3. Push → Codemagic `ios-ci` akışı: proje üretimi, derleme, birim testleri, UI testleri (simülatör).
4. `main` veya `release/*` dalına push → `ios-release`: testler + imzalı IPA + otomatik TestFlight.
   Öncesinde `TESTFLIGHT_NOTES.md` en üstüne yeni sürüm notunu ekleyin.

Mac erişimi olursa: `brew install xcodegen && xcodegen generate && open KuryeKazanc.xcodeproj`

## Klasör yapısı

```
KuryeKazanc/
  App/           Uygulama girişi, ModelContainer, örnek veri
  Models/        SwiftData @Model sınıfları + enum'lar + anonim cihaz UUID'si
  Services/      Saf iş mantığı (EarningsCalculator), tercih anahtarları, seed
  ViewModels/    @Observable ViewModel'ler
  Views/         SwiftUI ekranları (ekran başına klasör)
  Utilities/     Biçimlendiriciler
  Resources/     Assets.xcassets
  Supporting/    Kısmi Info.plist (konum izin metinleri, arka plan modu)
KuryeKazancTests/    XCTest birim testleri
KuryeKazancUITests/  XCUITest
scripts/ci/          CI yardımcı scriptleri
```

## Codemagic'te bir kez yapılacak ayarlar

Gizli bilgiler koda yazılmaz; hepsi Codemagic arayüzünde tutulur:

| Ne | Nerede |
|---|---|
| App Store Connect API anahtarı (Issuer ID, Key ID, .p8) | Teams → Integrations → Developer Portal, adı: `KuryeKazanc ASC` |
| iOS Distribution sertifikası | Teams → Code signing identities (veya Codemagic'e ürettirin) |
| `APP_STORE_APPLE_ID` (uygulamanın sayısal Apple ID'si) | Environment variables, grup: `app_store_credentials` |

Bundle ID (`com.kuryekazanc.app`) gizli değildir; `project.yml` ve `codemagic.yaml`'da aynı olmalı ve App Store Connect'te kayıtlı olmalıdır.

## Gizlilik notu

Kazanç/gider kayıtları kişisel bilgi içermez; yalnızca cihazda üretilmiş rastgele bir UUID taşır.
Ham GPS koordinatı saklanmaz, yalnızca il/ilçe/semt. V1'de hiçbir veri cihaz dışına gönderilmez.

İlerleme kaydı: [PROGRESS.md](PROGRESS.md)
