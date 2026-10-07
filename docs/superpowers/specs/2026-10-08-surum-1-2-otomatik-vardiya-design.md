# Sürüm 1.2 — Otomatik vardiya, otomatik kilometre ve Canlı Etkinlik

Tarih: 2026-10-08 · Üst tasarım: `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md` (bu belge oradaki §8 ve §12'nin 1.2 kısmını daraltır ve günceller)

## 1. Amaç ve kapsam

**Kullanıcının istediği:** Gridwise'daki otomatik kilometre gibi, kurye "Vardiyayı başlat"a basmayı unutsa da km ve çalışma süresi kaybolmasın; vardiya sırasında kilit ekranında ve Dynamic Island'da canlı bilgi görünsün.

**Kapsam (1.2):**
1. Hareketle otomatik vardiya algılama (otomatik başlatma ve bitirme)
2. Otomatik kilometre (otomatik vardiyada GPS)
3. Canlı Etkinlik + Dynamic Island

**Kapsam dışı (sonraya):** widget'lar, PDF/CSV dışa aktarma, Siri kısayolları. Sunucu yok (1.3).

**Teslim kuralı (kullanıcı kararı):** 1.2 tek başına derlenmez ve TestFlight'a gönderilmez. 1.2 bitince doğrudan 1.3'e geçilir; TestFlight yüklemesinden önce kullanıcıya sorulur.

**Başarı ölçütleri:**
- Otomatik mod açıkken motorla ≥3 dk yol alan kuryenin vardiyası kendiliğinden başlar; km, algılama anından itibaren sayılır.
- Yanlış başlayan vardiya tek dokunuşla iz bırakmadan iptal edilir.
- Otomatik mod kapalıyken davranış 1.1 ile birebir aynıdır.
- Gün boyu ek pil tüketimi önemsizdir (yalnızca önemli konum değişikliği izlenir).

## 2. Verilen kararlar

| Konu | Karar |
|---|---|
| Hareket algılanınca | Uygulama vardiyayı **kendisi başlatır** ve bildirim gönderir ("Vardiya başladı — yanlışsa dokun, iptal et"). Üst tasarım §8'deki "asla kendiliğinden başlatmaz" kuralı bununla değişir. |
| Yanlış alarm | Çalışma saatleri sınırı (Profil) + kolay iptal ("Bu bir vardiya değil") + iptal sonrası 30 dk bekleme |
| Canlı Etkinlik içeriği | Süre, km, bugünkü net, ~₺/saat tahmini + "Vardiyayı bitir" düğmesi |
| Teknik yaklaşım | Önemli konum değişikliği (uyandırma) + CoreMotion geçmişi (karar); tam GPS yalnızca vardiyada |

## 3. Mimari

| Bileşen | Yer | Görevi |
|---|---|---|
| `AutoShiftPolicy`, `MotionSample`, `WorkHours`, `PendingShift` kuralları | `KuryeKazanc/Core/Shift/` (yalnızca Foundation) | Saf kurallar; Windows'ta TDD |
| `LiveActivityThrottle` | `KuryeKazanc/Core/Shift/` | Canlı Etkinlik güncelleme sıklığı kuralı |
| `MotionActivityProviding` + `CoreMotionActivityProvider` | `Services/Motion/` | CMMotionActivityManager sarmalayıcısı; `[MotionSample]` döndürür |
| `LocationService` (değişir) | `Services/` | + önemli konum değişikliği izleme, "Her zaman" izni, son anlamlı hareket zamanı, uyanma olayı |
| `WorkSessionManager` (değişir) | `Services/` | `start(at:origin:)` (`manual`/`auto`), `cancel()`, oturum kaynağı kalıcı |
| `AutoShiftCoordinator` (`@MainActor`, yeni) | `Services/Shift/` | Uyanma → hareket geçmişi → politika → başlat/bitir/iptal; bekleyen vardiyalar |
| `ShiftNotifications` | `Services/Shift/` | Bildirim kategorileri ve eylemleri ("Bu bir vardiya değil", "Kazancını ekle") |
| `ShiftActivityAttributes`, `EndShiftIntent` | `Shared/` (uygulama + eklenti) | Canlı Etkinlik verisi; bitir düğmesi (LiveActivityIntent) |
| `KuryeLiveActivity` (yeni WidgetKit eklentisi) | `KuryeLiveActivity/` | Kilit ekranı + Dynamic Island görünümleri |
| `LiveActivityController` | `Services/Shift/` | Etkinliği aç/güncelle/kapat |
| `AppDelegate` (`UIApplicationDelegateAdaptor`) | `App/` | Konumla arka planda yeniden başlatmada izlemeyi ve koordinatörü kurar; bildirim eylemlerini yönlendirir |
| Profil + Onboarding + Bugün | `Views/` | Otomatik vardiya anahtarı, çalışma saatleri, izin akışı, "Biten vardiyan var" satırı |

Veri modeli (SchemaV2) değişmez. Otomatik vardiya, kazanç kaydedilene kadar yalnızca oturum durumu ve "bekleyen vardiya" olarak UserDefaults'ta tutulur.

`project.yml`: yeni `app-extension` hedefi `KuryeLiveActivity` (bundle `com.kuryekazanc.app.liveactivity`), uygulamaya gömülür; `INFOPLIST_KEY_NSSupportsLiveActivities: YES`; `NSMotionUsageDescription`; `NSLocationAlwaysAndWhenInUseUsageDescription` metni güncellenir. Eklenti App ID'si ve profili 1.3 TestFlight'ından önce açılır (imzalama önkoşulu, kullanıcıya sorulur).

## 4. Durum makinesi ve kurallar

```
boşta ──(başlatma kuralı)──▶ otomatik vardiya ──(20 dk durağan)──▶ bitti → bekleyen vardiya + bildirim
  │                               ├─("Bu bir vardiya değil")─▶ iptal (kayıt yok)
  │                               └─("Vardiyayı bitir")──────▶ bitti → kazanç formu
  └─(elle başlat)─▶ elle vardiya ──(yalnızca elle / Canlı Etkinlik "Bitir")─▶ bitti
```

**Başlatma kuralı:**
- Otomatik mod açık, vardiya yok ve şu an çalışma saatlerinin içinde olmalı.
- Son 10 dakikada en az 3 dakikalık kesintisiz hareket gerekir. Yalnızca güveni orta veya yüksek olan "otomobil" ya da "bisiklet" örnekleri sayılır.
- 60 saniyeden kısa "duruyor" kesintileri hareketi bölmez.
- Vardiyanın başlangıcı, bu hareketin ilk örneğinin zamanıdır.
- İptal edilen bir otomatik vardiyadan sonra 30 dakika yeniden başlatma yapılmaz.

**Bitirme kuralı (yalnızca otomatik vardiya):**
- Son anlamlı hareketten (≥50 m konum değişimi ya da hareket örneği) bu yana ≥20 dakika geçince vardiya biter.
- Bitiş zamanı, son hareket anıdır.
- Çalışma saatinin bitmesi vardiyayı bitirmez.
- Elle başlatılan vardiya asla kendiliğinden bitmez.

**Kısa vardiya filtresi:** <5 dk ve <1 km süren otomatik vardiya sessizce atılır.

**Bekleyen vardiyalar:**
- Biten otomatik vardiya listeye eklenir ve "Vardiya bitti — kazancını ekle" bildirimi gönderilir.
- Bugün ekranında "Biten vardiyan var" satırı görünür. Dokununca form süre, km ve ilçeyle dolu açılır.
- Liste en fazla 5 kayıt tutar; kayıtlar 24 saat sonra silinir.

## 5. İzinler ve Profil

"Otomatik vardiya" anahtarı açılınca önce bir açıklama ekranı gösterilir. Ardından izinler sırayla istenir: Hareket ve Fitness → konum "Her zaman" (önce "Kullanırken", sonra yükseltme) → Bildirimler.

- **Hareket veya "Her zaman" izni reddedilirse:** anahtar kapalı kalır ve "Ayarlar'dan aç" satırı gösterilir.
- **Bildirim izni reddedilirse:** otomatik mod yine çalışır. İptal, Canlı Etkinlik ve uygulama üzerinden yapılır.

Çalışma saatleri iki seçeneklidir: "Her zaman" ya da başlangıç–bitiş saati. Varsayılan 09:00–01:00'dır; aralık gece yarısını geçebilir.

Onboarding'in konum adımında isteğe bağlı bir "Otomatik vardiyayı aç" düğmesi bulunur.

## 6. Canlı Etkinlik

Elle ya da otomatik, her vardiyada açılır.

**Kilit ekranı:**
- Üstte "Vardiya" ve vardiyanın otomatik mi elle mi başladığı.
- Canlı sayan süre (`Text(timerInterval:)`; bunun için güncelleme gerekmez).
- Km, bugünkü net ve ~₺/saat tahmini.
- "Vardiyayı bitir" düğmesi (`EndShiftIntent`).

**Dynamic Island:**
- Kompakt: solda süre, sağda km.
- Genişletilmiş: kilit ekranındakinin aynısı.
- Minimal: simge.

**Güncelleme ve kapanış:**
- Güncelleme en fazla dakikada bir ya da 100 metrede bir yapılır; düşük güç modunda 3 dakikada bir.
- Vardiya bitince etkinlik 5 dakika boyunca özet gösterir, sonra kapanır.
- Canlı Etkinlikler kullanıcı tarafından kapatılmışsa sessizce atlanır.

## 7. Hata durumları

| Durum | Davranış |
|---|---|
| "Her zaman" izni sonradan düşürüldü / reddedildi | Otomatik mod askıda; Bugün'de "Ayarlar" satırı; elle vardiya çalışır |
| Hareket izni yok / desteklenmiyor | Otomatik mod açılamaz |
| Uygulama kaydırılarak kapatıldı / telefon yeniden başladı | Önemli konum değişikliği uygulamayı uyandırır; AppDelegate izlemeyi kurar; süren vardiya UserDefaults'tan devam eder |
| Vardiya sırasında iOS uygulamayı sonlandırdı | Km UserDefaults'ta; uyanınca devam; Canlı Etkinlik ilk güncellemede düzelir |
| Düşük güç modu | Başlatma çalışır; Canlı Etkinlik güncellemesi 3 dk |
| GPS sıçraması | Mevcut filtre korunur (≤50 m doğruluk, ≤160 km/sa, ≥10 m) |
| Elle vardiya sürerken hareket kuralı tetiklenir | Hiçbir şey yapılmaz |
| Gece yarısını geçen vardiya | Kayıt başlangıç gününe yazılır |
| Saat dilimi / yaz saati | Kurallar `Calendar` ile; çalışma saatleri yerel saattir |

**Gizlilik:** Hiçbir konum cihazdan çıkmaz. Önemli konum değişikliği koordinatları saklanmaz, yalnızca karar için kullanılır.

## 8. Test stratejisi

- **Core (`swift test`, Windows, TDD):**
  - `AutoShiftPolicy`: başlatma, bitirme, iptal sonrası bekleme, başlangıç zamanının geri alınması, güven filtresi, kısa durma toleransı.
  - `WorkHours`: gece yarısını geçen aralık ve kodlama.
  - Kısa vardiya filtresi.
  - Bekleyen vardiya listesi: en fazla 5 kayıt, 24 saatte silinme.
  - `LiveActivityThrottle`.
- **XCTest (1.3 ile birlikte CI'da):**
  - Sahte sağlayıcılarla `AutoShiftCoordinator`.
  - `WorkSessionManager` için `start(at:origin:)` ve `cancel()`.
  - Profil'de otomatik vardiya UI testi.
- **Derleme yerine:** Her görevden sonra bağımsız bir derleme odaklı kod incelemesi yapılır, çünkü 1.2 tek başına derlenmez.
- **Cihazda (1.3 TestFlight'ında):** Gerçek sürüş, kilit ekranı, uygulama kapalıyken uyanma, izin reddi.
