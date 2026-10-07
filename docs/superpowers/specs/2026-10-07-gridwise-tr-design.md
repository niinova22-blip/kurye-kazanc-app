# Kurye Kazanç 2.0 — Türkiye için Gridwise benzeri platform (tasarım)

Tarih: 2026-10-07 · Durum: Kullanıcı onayı bekliyor

## 1. Amaç ve kapsam

**Kullanıcının istediği:**
- TestFlight 1.0.0 arayüzü daha profesyonel ve sade olmalı; Apple'ın kendi uygulamaları gibi (iPhone tarzı).
- Uygulama Gridwise gibi çalışmalı; hedef Türkiye'deki Yemeksepeti, Getir, Trendyol Go, Migros vb. kuryeleri.
- Topluluk verisi kuryenin elle girdiği bilgilere değil, **ekran görüntüsüyle teyit edilen** verilere dayanmalı; uygulama büyük platformların kazanç ekranlarını tanıyıp doğrulamalı.
- Sunucuya **tarih, saat ve konum** da gitmeli ki ileride harita üzerinde yoğunluk özelliği yapılabilsin.

**Hedef kullanıcı:** tek başına çalışan (esnaf) kurye; birden fazla platformda çalışabilir.

**Başarı ölçütleri:**
- Kurye bir vardiyayı en fazla iki dokunuşla kaydedebilir (ekran görüntüsü paylaş → onayla).
- Uygulama internetsiz eksiksiz çalışır; sunucu kapalıyken hiçbir veri kaybolmaz.
- Topluluk istatistiklerinde hiçbir tekil kuryenin kazancı veya evi çıkarsanamaz.
- Topluluk istatistikleri yalnızca doğrulanmış (veya açıkça "önizleme" etiketli) veriden üretilir.

### Gridwise karşılaştırması

| Gridwise | Türkiye karşılığı |
|---|---|
| Platform hesabı bağlayarak otomatik kazanç senkronu | Türk platformlarında açık API yok → ekran görüntüsü + OCR, sürtünmesi en aza indirilmiş (paylaş eklentisi, yeni ekran görüntüsü taraması) |
| Otomatik kilometre | "Çalışıyorum" modu + hareketle vardiya önerisi + Canlı Etkinlik |
| Kazanç/saat, sipariş başı, platform karşılaştırması | Aynı + gün×saat ısı haritası, hedefler |
| Gider ve vergi dökümü | PDF/CSV dışa aktarma; vergi rejimi bilgi alanı |
| Şehir karşılaştırması (benchmark) | İlçe karşılaştırması (Supabase, k-anonimlik) |
| "When to Drive", havalimanı/etkinlik | Kazanç/yoğunluk haritası (H3 hücreleri, saat kaydırıcısı) |
| Gridwise Plus | Sonraki aşama (D) |

### Alt projeler

| Kod | Alt proje | Sürüm |
|---|---|---|
| A | Arayüz yenilemesi (tasarım sistemi + tüm ekranlar) | 1.1 |
| B | Cihaz üstü Gridwise özellikleri | 1.1–1.2 |
| C | Topluluk verisi (Supabase) | 1.3–1.4 |
| D | Gelir modeli (Plus, ortaklıklar) | Kapsam dışı; ayrı tasarım |

Her sürüm kendi uygulama planıyla (writing-plans) yürütülür; bu belge hepsinin ortak çerçevesidir.

## 2. Verilen kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Veri mimarisi | **Yerel öncelikli**: SwiftData asıl kaynak; sunucuya kuyrukla gönderim | Kuryeler sık sık bağlantısız kalır |
| Sunucu | **Supabase, AB (Frankfurt)** | Postgres + RLS + SQL ile toplu istatistik; ücretsiz katmanla başlar; taşınabilir |
| Hesap | **Varsayılan anonim** (Supabase anonymous auth) + **isteğe bağlı Apple ile Giriş** (yedekleme/yeni telefona taşıma) | E-posta/telefon toplanmaz; sürtünme yok |
| Topluluk erişimi | **Paylaşan görür** ("ver-al") | Katılımı artırır, adil |
| Topluluk verisinin kaynağı | Yalnızca **ekran görüntüsüyle doğrulanmış** kayıtlar | Elle girilen veriyle istatistik kirlenmesin |
| Şablon kalibrasyonu | Gerçek ekran örneği şu an yok → **uygulama içi kalibrasyon modu** + **uzaktan şablonlar** | Yeni şablon için App Store güncellemesi gerekmesin |
| Konum | **H3 çözünürlük 8 hücreleri** (~0,7 km²), 15 dk zaman dilimleri, haftalık takma kimlik | Harita mümkün, ev/kimlik çıkarımı değil |
| Görsel dil | Apple'ın kendi uygulamaları gibi; sistem renkleri + tek vurgu rengi | Kullanıcı isteği |

## 3. Mimari

```
KuryeKazanc/
  Core/            Saf mantık (Windows'ta swift test). EKLENİR: Analytics/, Verification/, Anonymizer/, Goals
  Models/          SwiftData. SchemaV2: doğrulama seviyesi, ekran görüntüsü kanıtı, hedefler
  Services/
    OCR/           Vision + şablon motoru (JSON şablonları okur)
    Sync/          (1.3) OutboxQueue, SupabaseClient, AccountManager, AppAttestService
    Motion/        (1.2) Hareket algılama, vardiya önerisi
    Screenshots/   Fotoğraf kitaplığında yeni ekran görüntüsü taraması
  Views/
    Design/        Tasarım sistemi (renk, tipografi, bileşenler)
    Today/ Analysis/ Community/ Profile/ Onboarding/ Earnings/ Expenses/
KuryeShareExtension/   Paylaş menüsü eklentisi (1.1)
KuryeWidgets/          Widget'lar + Canlı Etkinlik (1.2)
supabase/migrations/   Sunucu şeması, RLS, fonksiyonlar (1.3)
supabase/tests/        pgTAP testleri
```

- Uygulama, eklenti ve widget'lar **App Group** üzerinden aynı SwiftData deposunu kullanır.
- `Core` hiçbir zaman SwiftData/UIKit/SwiftUI/Vision import etmez (mevcut kural).
- Sunucu kapalı veya paylaşım kapalıyken `Sync` katmanı hiçbir şey yapmaz; uygulamanın geri kalanı ondan bağımsızdır.

## 4. Doğrulama (verification)

### 4.1 Seviyeler

| Seviye | Anlamı | Topluluğa girer mi? |
|---|---|---|
| `manual` | Elle girildi | Hayır |
| `ocrEdited` | Ekran görüntüsünden okundu, kullanıcı tutar/tarih değiştirdi | Hayır |
| `ocrUnverified` | Ekran görüntüsünden okundu, değiştirilmedi; platform şablonu henüz kalibre değil | Yalnızca "önizleme" istatistiklerine |
| `verified` | Aşağıdaki tüm kontrollerden geçti | Evet |

Kişisel analizlerde (Bugün, Analiz) tüm seviyeler kullanılır; seviye yalnızca bir rozet olarak görünür.

### 4.2 Cihaz üstü kontroller

1. **Gerçek ekran görüntüsü:** PHAsset `mediaSubtypes` içinde `.photoScreenshot` olmalı; paylaş eklentisinden gelen görselde boyut bilinen bir iPhone ekran çözünürlüğüyle eşleşmeli ve kamera EXIF'i olmamalı. Kamerayla çekilmiş veya düzenlenmiş görsel `ocrUnverified`'ın üstüne çıkamaz.
2. **Platform parmak izi:** Şablon, o platformun kazanç ekranına özgü sabit metinleri ve göreli yerleşim kurallarını (ör. "etiket solda, tutar aynı satırda sağda") içerir. Vision'ın döndürdüğü metin ve sınır kutularıyla en az `minFingerprintMatches` eşleşme gerekir.
3. **İç tutarlılık:** tarih son 14 gün içinde; alt kalemlerin toplamı ana toplama eşit (±1 TL); paket sayısı × şablondaki paket ücreti aralığı toplamı açıklıyor.
4. **Gün düzeyinde mutabakat:** Ekran görüntüleri çoğunlukla günlük/haftalık toplam gösterir. Bir (gün, platform) için o günün vardiya kayıtlarının toplamı ekran görüntüsü toplamıyla ±%2 içinde örtüşürse o kayıtlar `verified` olur. Haftalık ekranlarda mutabakat hafta düzeyinde yapılır.

### 4.3 Kanıt ve tekrar kullanım

- Görsel **sunucuya gönderilmez** (isim, kurye no, IBAN içerebilir).
- Cihazda saklanan kanıt: OCR satırları + sınır kutuları (`ScreenshotEvidence` modeli), görüntünün kendisi saklanmaz. Böylece şablon güncellenince geriye dönük yeniden doğrulama yapılabilir.
- Sunucuya giden kanıt: normalize OCR metninin SHA-256 özeti (`text_hash`), şablon kimliği ve sürümü, tutarlılık puanı. `text_hash` sunucuda tekildir → aynı ekran görüntüsü ikinci kez (kim gönderirse göndersin) kabul edilmez.
- Tüm sunucu istekleri **App Attest** ile doğrulanır; cihaz başına günlük gönderim sınırı vardır.

**Bilinen sınır:** Ustaca düzenlenmiş bir ekran görüntüsü kontrolleri geçebilir. Etkisi k-anonimlik (≥5 kurye), uç değer filtresi ve medyan tabanlı istatistiklerle sınırlanır.

### 4.4 Kalibrasyon modu ve uzaktan şablonlar

- Şablonlar Swift kodundan çıkarılıp **sürümlü JSON** olur (`ocr_templates` tablosu; uygulama içinde yedek olarak gömülü bir kopya). Mevcut `TrendyolGoTemplate`/`GetirTemplate` ilk JSON sürümlerine dönüştürülür; `EarningsScreenshotParser` JSON şablonu okuyan bir motora evrilir.
- Testçi kurye, Profil → Kalibrasyon'dan (ayrı açık rıza) bir ekran görüntüsünü "Kalibrasyona gönder" ile işaretler. Cihazda maskelenir: IBAN (TR + 24 hane), telefon, 11 haneli TC kimlik no, e-posta, şablonun "isim alanı" olarak işaretlediği satırlar. Yalnızca maskelenmiş satırlar + sınır kutuları gönderilir.
- Bir platform şablonu durum alanı: `calibrating` → `active`. `active` olma eşiği: en az 5 farklı kuryeden 15 örnekle elle doğrulanmış şablon. Şablonlar ve parmak izleri, gelen örneklerden geliştirici tarafından yazılır ve `KuryeCore` testlerine örnek olarak eklenir.
- Şablon `active` olunca uygulama yerel `ScreenshotEvidence` kayıtlarını yeniden doğrular.

### 4.5 Platformlar

Parmak izli şablon hedefi: Trendyol Go, Getir (GetirYemek dahil), Yemeksepeti Express, Migros Hemen / Migros Yemek. Diğerleri genel şablona düşer (`ocrUnverified` üstüne çıkamaz).

## 5. Konum, tarih ve saat (harita için)

- Kaynak: yalnızca "Çalışıyorum" modundaki konum güncellemeleri (mevcut `LocationService`).
- Cihazda **H3 çözünürlük 8** hücresine dönüştürülür; ham koordinat ne saklanır ne gönderilir. (H3 için saf Swift bir uygulama `Core`'a eklenir veya hafif bir paket kullanılır; plan aşamasında seçilir.)
- Hücre kaydı: hücre, tarih, 15 dk zaman dilimi, o hücrede geçen dakika, duraklı (hız < 5 km/s) dakika, doğrulanmış vardiyalarda zamana orantılı net kazanç payı.
- **Ev koruması:** her vardiyanın ilk ve son 10 dakikası ile başlangıç/bitiş noktasına 1 km'den yakın hücreler gönderilmez.
- **Bağlanamazlık:** hücre kayıtları hesap kimliği taşımaz; yalnızca `HMAC(sunucu tuzu, kullanıcı kimliği ‖ ISO hafta)` ile üretilen haftalık takma kimlik taşır (k-anonimlik sayımı için).
- Konum paylaşımı, kazanç paylaşımından **ayrı açık rıza** ile açılır.
- **Hukuki not:** Konum + zaman verisi ve yurt dışı (AB) sunucu nedeniyle, 1.4 yayınından önce KVKK aydınlatma metni ve açık rıza metinleri bir hukukçuya gözden geçirtilecek.

## 6. Sunucu (Supabase, Frankfurt)

| Nesne | İçerik | RLS / erişim |
|---|---|---|
| `shifts` | user_id, platform_code, il, ilçe, araç, hafta günü, başlangıç dilimi (15 dk), süre dk, brüt, bonus, paket, km (0,5'e yuvarlı), doğrulama seviyesi, template_id/ver, `text_hash` (unique), created_at | Kullanıcı yalnızca kendi satırını ekler/siler; SELECT yok |
| `location_cells` | week_pseudonym, h3_cell, tarih, dilim, dakika, duraklı dk, kazanç payı | Yalnızca INSERT (fonksiyon üzerinden) |
| `ocr_templates` | platform_code, sürüm, json, durum | Herkes okur |
| `calibration_samples` | platform_code, maskelenmiş satırlar (jsonb), created_at | Yalnızca INSERT |
| `backups` | user_id (Apple ile girişli), kayıt yükü (jsonb), updated_at | Yalnızca sahibi |
| `district_benchmark(il, ilçe, platform?)` | Medyan/çeyrekler net ₺/saat, ₺/sipariş; kullanıcının yüzdelik dilimi | ≥5 farklı kurye; çağıran son 30 günde ≥3 vardiya paylaşmış olmalı |
| `best_hours(il, ilçe)` | Hafta günü × saat medyan ₺/saat | Aynı kurallar |
| `heatmap(bbox, gün, dilim)` | Hücre başına aktif kurye yoğunluğu, duraklı dk, medyan ₺/saat | ≥5 farklı haftalık takma kimlik |
| Edge Function `attest` | App Attest anahtar kaydı ve doğrulaması, oran sınırı | — |

- Uç değer filtresi: net ₺/saat ve ₺/sipariş için şehir bazında IQR dışı kayıtlar istatistiklere girmez.
- "Verilerimi sil": kullanıcının `shifts` ve `backups` satırlarını siler; hesabı kapatır. `location_cells` hesaba bağlı olmadığı için silinemez; bu durum rıza metninde açıkça yazılır.
- Şema `supabase/migrations/` altında SQL olarak repoda; RLS ve fonksiyonlar `supabase/tests/` altında pgTAP ile test edilir.

## 7. Arayüz dili

**Görsel kurallar** (`Views/Design/`):
- Renk: sistem renkleri + tek vurgu (koyu yeşil). Kırmızı yalnızca gider ve "vardiyayı bitir". Gradyanlı kart yok; yüzeyler `secondarySystemGroupedBackground`. Karanlık mod tam destek.
- Tipografi: yalnızca Dynamic Type stilleri; büyük rakamlar SF Pro Rounded + `monospacedDigit`; her ekranda büyük başlık.
- Bileşenler: `insetGrouped` listeler, metrik satırları, hiyerarşik SF Symbols, dokunsal geri bildirim (kayıt, vardiya başlat/bitir). Kart yerine liste bölümü, çerçeve yerine boşluk.
- Erişilebilirlik: tüm etkileşimli öğelerde VoiceOver etiketi ve `accessibilityIdentifier`; en büyük erişilebilirlik yazı boyutunda düzen bozulmaz.

**Sekmeler:**
1. **Bugün** — büyük net rakamı; altında "brüt · gider · ₺/saat"; haftalık hedef halkası; tek büyük "Vardiyayı başlat" (aktifken canlı panel: süre, km, ₺/saat tahmini); bugünün kayıtları (doğrulama rozetiyle); sağ üstte + → "Ekran görüntüsü" (ilk), "Elle", "Gider". Yeni ekran görüntüsü bulunduysa üstte öneri satırı.
2. **Analiz** — gün/hafta/ay; net trend grafiği; platform karşılaştırması (₺/saat, ₺/sipariş, km başı net); gün×saat ısı haritası; "geçen döneme göre"; en kârlı 3 zaman dilimi; kayıt listesi; dışa aktar (1.2).
3. **Topluluk** — 1.1'de "yakında" iskeleti; 1.4'te ilçe karşılaştırması ve MapKit üzerinde hücre haritası (saat kaydırıcısı). Paylaşım kapalıysa tek ekranlık davet.
4. **Profil** — araç, platformlar, km maliyeti, hedefler; Apple ile Giriş ve yedekleme (1.3); kazanç paylaşımı ve konum paylaşımı ayrı rızalar; "Verilerimi sil"; kalibrasyon modu (1.3).

**Onboarding:** 4 adım (araç → platformlar → konum izni gerekçesiyle → isteğe bağlı paylaşım), alt kısımda tek elle ulaşılan düğmeler, ilerleme noktaları.

## 8. Cihaz üstü özellikler (B)

- **Ekran görüntüsü kazanımı (1.1):** paylaş menüsü eklentisi (App Group üzerinden kuyruğa yazar, uygulama açılınca işlenir); uygulama açılışında son 48 saatin ekran görüntüsü taraması (sınırlı fotoğraf erişimiyle de çalışır); çoklu seçim.
- **Analizler (1.1):** `Core/Analytics` — ısı haritası, platform karşılaştırması, dönem karşılaştırması, en kârlı dilimler.
- **Hedefler (1.1):** haftalık net hedef, isteğe bağlı günlük hedef.
- **Canlı Etkinlik + Dynamic Island (1.2):** vardiya süresi, km, ₺/saat tahmini; vardiyayı bitir düğmesi.
- **Widget'lar (1.2):** bugünkü net, haftalık hedef (ana ekran + kilit ekranı).
- **Hareketle vardiya önerisi (1.2):** CoreMotion "automotive/cycling" ≥3 dk → "Vardiyayı başlatalım mı?" bildirimi; 20 dk duraklama → "Bitirelim mi?". Uygulama kapalıyken yalnızca "Her zaman" konum izni ve belirgin konum değişikliği izlemesiyle; isteğe bağlı. Asla kendiliğinden başlatmaz.
- **Dışa aktarma (1.2):** aylık/yıllık PDF ve CSV (platform bazında kazanç, türe göre gider, km). Vergi rejimi alanı (basit usul / esnaf muafiyeti / diğer) yalnızca bilgi amaçlı; vergi hesaplanmaz.
- **Siri/Kısayollar (1.2):** "Vardiyamı başlat/bitir".

## 9. Veri modeli değişiklikleri (SchemaV2)

- `EarningRecord`: `verificationRaw: String` (varsayılan `manual`), `evidence: ScreenshotEvidence?`, `syncStateRaw: String` (`local`, `queued`, `uploaded`), `remoteID: UUID?`.
- Yeni `ScreenshotEvidence`: OCR satırları + kutular (Codable blob), platform kodu, şablon kimliği/sürümü, ekran görüntüsü tarihi, gerçek ekran görüntüsü bayrağı, text hash, ekrandaki toplam ve kapsadığı dönem (gün/hafta).
- Yeni `Goal`: dönem türü, hedef tutar.
- `KuryeMigrationPlan`'a V1 → V2 hafif göç (yeni alanlar varsayılanlı).
- Depo App Group konteynerine taşınır (eklenti ve widget erişimi için); ilk açılışta mevcut depo kopyalanır.

## 10. Hata durumları

- OCR başarısız / şablon tanınmadı → mevcut davranış korunur: alanlar en iyi tahminle doldurulur, "kontrol et" işaretlenir; kayıt `ocrUnverified` veya kullanıcı değiştirirse `ocrEdited`.
- Gönderim başarısız → kuyrukta kalır, üstel bekleme ile yeniden denenir; kullanıcıya hata gösterilmez (Profil'de "son eşitleme" bilgisi).
- `text_hash` çakışması (409) → kayıt yerelde `ocrEdited` gibi işaretlenir ("bu ekran görüntüsü daha önce kullanılmış"), topluluğa girmez.
- App Attest desteklenmeyen cihaz/simülatör → paylaşım devre dışı, uygulama çalışmaya devam eder.
- Rıza geri çekilince kuyruk boşaltılır, yeni gönderim yapılmaz.

## 11. Test stratejisi

- `Core` (doğrulama kuralları, mutabakat, analizler, H3 dönüşümü, anonimleştirme/ev koruması, maskeleme, şablon motoru): Windows'ta `swift test`, TDD.
- SwiftData göçü, ViewModel'ler: XCTest (CI).
- Ekran akışları (Bugün, + menüsü, Analiz, Profil, onboarding): XCUITest (PR ve release'te).
- Sunucu: pgTAP — RLS (başkasının satırını okuyamama/silememe), k-anonimlik eşiği, ver-al kuralı, `text_hash` tekilliği.

## 12. Teslim sırası

| Sürüm | İçerik |
|---|---|
| **1.1** | Tasarım sistemi; Bugün/Analiz/Topluluk iskeleti/Profil/Onboarding yenilemesi; SchemaV2 + App Group; doğrulama seviyeleri ve kanıt saklama; JSON şablon motoru (gömülü şablonlarla); paylaş eklentisi; ekran görüntüsü taraması; analizler; hedefler |
| **1.2** | Canlı Etkinlik/Dynamic Island, widget'lar, hareketle vardiya önerisi, PDF/CSV, Siri kısayolları |
| **1.3** | Supabase projesi + şema/RLS/pgTAP; anonim oturum; App Attest; kalibrasyon modu; uzaktan şablonlar; vardiya kuyruğu; Apple ile Giriş yedekleme; KVKK metinleri taslağı |
| **1.4** | Konum hücreleri; Topluluk sekmesi (ilçe karşılaştırması, harita, en iyi saatler); hukuki gözden geçirme sonrası yayın |
| Sonra | D: Plus ve ortaklıklar (ayrı tasarım) |

## 13. Kapsam dışı

- Platform hesaplarına giriş yapıp veri çekme (kazıma) — platform sözleşmelerine aykırı ve kırılgan.
- Vergi hesaplama/beyanname.
- Android.
- Ekip/filo yönetimi.
