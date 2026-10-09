# Sürüm 1.4a — Ekran tipleri, senaryo testleri ve kazanç taraması denemesi

Tarih: 2026-10-09 · Üst tasarım: `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md`. 1.4 iki parçaya bölündü: **1.4a** (bu belge: ekran okuma ve otomatik yakalama) ve **1.4b** (Topluluk, konum hücreleri, App Attest; ayrı tasarım, 1.3 verisi biriktikçe).

## 1. Amaç ve kapsam

**Kullanıcının istediği:** Kurye kazancını girmek için ekran görüntüsü alıp paylaşmakla uğraşmasın; ideali, platform uygulamasındaki kazanç panelini açıp kapatması ve gerisinin otomatik olması. Kısayollar otomasyonu mutlaka olsun. Veri kaynağı ekran görüntüsü olarak kalır.

**Kullanıcının reddettikleri / elenenler:**
- Platform hesabına giriş yapıp gizli API'den veri çekmek (kullanım şartları, kuryenin hesabının kapanma riski, şifre saklama ve KVKK, App Review riski).
- Ödeme/ekstre e-postası okumak (platformlar bu e-postaları göndermiyor).

**Kısıtlar:**
- iOS, bir uygulamanın başka uygulamanın ekranını habersiz görmesine izin vermez; en yakın yollar ReplayKit yayın eklentisi (kullanıcı başlatır, kırmızı kayıt göstergesi) ve Kısayollar otomasyonu (kullanıcı bir kez kurar).
- Kullanıcıda kurye platform uygulamaları ve hesapları yok; gerçek kazanç ekranı görüntüsü yok. Trendyol GO ve Getir'in kurye uygulamaları Türkiye App Store'unda listelenmiyor.
- Uber, Trendyol GO'yu (2025) ve Getir'in teslimat işini (2026) devraldı; kurye uygulamaları ileride Uber'in sürücü uygulamasında birleşebilir. Şablonlar sunucudan güncellenebilir (1.3) ve bu yüzden kritik.
- Windows'ta yalnızca Core (`swift test`) çalışır; uygulama kodu CI'da (GitHub Actions) doğrulanır.

**Bu belgenin kapsamı:**
1. Okuma motoru: ekran tipleri (`summary`, `list`, `orderCard`), parmak iziyle tanıma, çalışma süresi alanı, KDV bayrağı, yeni şablonlar.
2. Senaryo testleri: satır (Core) ve görüntü (CI simülatörü, Vision) katmanları; doğruluk raporu ve eşik.
3. Kazanç taraması denemesi (spike): yayın eklentisi + Kısayollar testi, telefonda taklit ekranlarla.

**Kapsam dışı (bu belge):** Kazanç taramasının üretim sürümü ve Kısayollar entegrasyonunun üretim tasarımı (deneme sonucuna göre ayrı bölüm/belge), Topluluk ve 1.4b maddeleri.

**Başarı ölçütleri:**
- Motor üç ekran tipini ve platform adı yazmayan Uber "Kazançlar" ekranını tanır; mevcut 1.1–1.3 testleri bozulmaz.
- Satır senaryoları Windows'ta, görüntü senaryoları CI'da çalışır; CI özetinde platform × alan doğruluk tablosu görünür ve doğruluk taban değerin altına düşerse CI kırmızı olur.
- Deneme sürümünde yayın eklentisi en yüksek 40 MB bellekle çalışır, ekranda 2 sn kalan her taklit kazanç ekranını yakalar, aynı ekranı iki kez kaydetmez, 5 dakikada çökmez.

## 2. Kaynaklar (2026-10-09 araştırması)

App Store Türkiye mağaza görselleri ve yardım/haber sayfaları; kurye kazanç ekranının kendisi hiçbir yerde birebir görülmedi.

| Uygulama | Görülen | Ekran tipi |
|---|---|---|
| Uber – Driver (`1131342792`) | "Earnings/Kazançlar": tarih aralığı (hafta), büyük toplam, günlük çubuk grafik, çevrimiçi süre ("23h 32m"), iş sayısı ("54 Trips"), puan, bakiye, sonraki ödeme | `summary` |
| Yemeksepeti Express Kurye (`1667283557`) | Sipariş teklifinde tutar + "Includes … extra", kabul oranı, vardiya kartı. Yardım sayfası: "Ödemeler" bölümünde sipariş tutarı, mesafe tutarı, ek kazanç, bahşiş; bahşiş dışı tutarlar KDV hariç | `orderCard` (+ ileride "Ödemeler" `summary`) |
| TheKurye / Paket Taxi (`6736919536`) | "Faturalar": satır başına "Taşıma Ücreti", iş no, tutar; sipariş kartında tutar | `list` |
| Banabikurye: Delivery Partner (`1480375006`, HEMENGETIR) | Sipariş kartında "Nakit kazanç" + tutar, "%15 fazla kazanç" bandı | `orderCard` |
| Trendyol GO / Getir kurye | Görsel yok; metin kaynakları: paket ücreti, mesafe, bonus, saatlik ücret (Getir), günlük/haftalık özet, haftalık hakediş | mevcut `summary` şablonları (tahmin) |

## 3. Okuma motoru (Core, saf Swift)

### 3.1 Şablon alanları (geriye uyumlu)

`OCRTemplate`'e eklenen alanlar; JSON'da yoksa varsayılan kullanılır (eski sunucu şablonları ve 1.3 uygulaması bozulmaz — 1.3 tanımadığı alanları yok sayar):

| Alan | Tür / varsayılan | Anlam |
|---|---|---|
| `layout` | `summary` \| `list` \| `orderCard`, varsayılan `summary` | Ekran tipi |
| `durationLabels` | `[String]`, varsayılan `[]` | "cevrimici", "calisma suresi", "online" |
| `rowLabels` | `[String]`, varsayılan `[]` | `list` tipinde toplanacak satırların etiketi ("tasima ucreti") |
| `amountsExcludeVAT` | `Bool`, varsayılan `false` | Ekrandaki tutarlar KDV hariç (bilgi amaçlı) |

`detectionKeywords` boş olabilir; bu durumda şablon yalnızca parmak iziyle seçilir.

### 3.2 Şablon seçimi

1. Platform adı (`detectionKeywords`) eşleşen şablonlar arasından en yüksek puanlı (bugünkü davranış).
2. Ad eşleşmesi yoksa: `fingerprintMatches >= minFingerprintMatches` olan şablonlardan en çok eşleşeni (eşitlikte daha özgül olan — daha çok parmak izi metni olan). Parmak izi eşiği ad eşleşmesinden yüksek tutulur (en az 3) ki genel ekranlar yanlış şablona düşmesin.
3. Hiçbiri yoksa `generic` (bugünkü davranış).

### 3.3 Ekran tipine göre çözümleme

- **`summary`:** bugünkü akış + çalışma süresi.
- **`list`:** `rowLabels` içeren her satırda (yoksa komşu satırda) tutar okunur; toplam = satır tutarlarının toplamı, iş sayısı = satır sayısı. Ekranda ayrıca bir toplam etiketi varsa ve satır toplamıyla ±%1 içinde tutmuyorsa toplam alanı kontrol için işaretlenir. Tarih bulunamazsa bugünkü kural.
- **`orderCard`:** tek sipariş: toplam = kart tutarı, iş sayısı = 1, "ek/extra" tutarı bonus. Sonuç `period = .order` olarak işaretlenir. 1.4a'da formda tek siparişlik kayıt olarak açılır ve "Bu tek bir sipariş" kontrol uyarısı gösterilir; kartların gün bazında birleştirilmesi üretim tasarımına kalır (§5.4). Denemede (§5) kartlar yalnızca günlüğe yazılır, kayıt oluşturulmaz. `.order` dönemli kayıtlar haftalık ekranlar gibi sunucuya vardiya olarak **gönderilmez** (1.3'teki `period == .day || nil` koşulu korunur).

`ParsedEarning`'e eklenenler: `workDuration: TimeInterval?` (süre okunamazsa `nil`, kontrol alanı değildir), `layout`, `amountsExcludeVAT`. `OCRTemplate.Period`'a `order` eklenir.

### 3.4 Çalışma süresi

`TextPatterns.duration(in:)`: "23 sa 32 dk", "23s 32dk", "23h 32m", "5 saat", "45 dk", "02:15 saat" biçimleri; normalize metin üzerinde. Etiketin olduğu satırda, yoksa komşu satırlarda aranır (`findAmount` ile aynı komşuluk kuralı). Kazanç formu, süre varsa ve kullanıcı vardiya süresi girmemişse süreyi doldurur.

### 3.5 Yeni / güncellenen şablonlar

Hepsi `status: calibrating`, `version` +1 (değişenler):

| id | layout | Not |
|---|---|---|
| `uber.earnings` (yeni) | summary | Ad eşleşmesi yok; parmak izi: kazanclar/earnings, cevrimici/online, seyahat/teslimat/trips, bakiye/balance, sonraki odeme; TR ve EN etiketler |
| `thekurye.invoices` (yeni) | list | `rowLabels: ["tasima ucreti"]`; parmak izi: faturalar, tasima ucreti, fatura olustur |
| `yemeksepeti.order` (yeni) | orderCard | "includes … extra"/"… ek dahil"; `amountsExcludeVAT: true` |
| `banabikurye.order` (yeni) | orderCard | "nakit kazanc" |
| `yemeksepeti.earnings` (v2) | summary | `amountsExcludeVAT: true`; `totalIncludesBonus` değişmez (bilinmiyor, kontrol işareti korunur) |

Gömülü kopyalar `BundledTemplates`'e, sunucu kopyaları `seed_templates` betiğiyle Supabase'e yazılır. Sunucu şeması değişmez (şablon `jsonb`).

## 4. Senaryo testleri

### 4.1 Senaryo modeli (Core)

`ScreenScenario`: şablon kimliği, layout, satır listesi (`ScenarioRow`: etiket, değer metni, aynı satır mı alt satır mı), tema (açık/koyu), cihaz boyutu (SE / standart / Pro Max), metin biçimi (Türkçe karakterli / karaktersiz / büyük harf), gürültü satırları (saat çubuğu, menü, bant), beklenen sonuç (toplam, bonus, iş sayısı, süre, tarih, dönem).

`ScenarioGenerator`: her ekran tipi için 2–4 temel düzen × çeşitlemeler; sabit tohumlu üreteçle tutarlar (Türkçe sayı biçimleri: `1.245,50 ₺`, `₺1.245,50`, `1245,5 TL`). Hedef ≈ 120 senaryo. Üreteç Core'dadır (SwiftUI/Vision bağımlılığı yok).

### 4.2 Katman A — satır testleri (Windows + CI)

Senaryo → Vision'ın okuma sırasına benzer satır dizisi (yukarıdan aşağı; aynı satır seçeneğinde etiket ve değer birleşik) → `EarningsScreenshotParser` → beklenenle karşılaştırma. `KuryeKazancTests/Core/ScenarioParserTests.swift`; pre-push kancasında da çalışır. Tüm satır senaryoları geçmelidir (eşik %100; satır katmanında OCR gürültüsü yoktur).

### 4.3 Katman B — görüntü testleri (CI simülatörü)

`MockEarningsScreen` (SwiftUI, uygulama hedefinde, yalnızca DEBUG/TestFlight derlemesinde): senaryoyu platformun bilinen görsel diline yakın çizer (renk, kart, büyük toplam). Test, `ImageRenderer` ile görüntü üretir → `VisionTextRecognitionService` → çözümleyici → beklenen. `KuryeKazancTests/ScenarioImageTests.swift`.

- Rapor: alan bazında doğru/yanlış; platform × alan doğruluk tablosu `$GITHUB_STEP_SUMMARY`'ye yazılır (test, tabloyu `build/scenario-report.md`'ye yazar; iş akışı bu dosyayı özete ekler).
- Eşik: `KuryeKazancTests/Fixtures/scenario-baseline.json` içindeki platform × alan taban doğruluğu. İlk çalıştırmada ölçülen değerler taban olarak kaydedilir (bilerek commit edilir); sonraki çalıştırmada herhangi bir hücre tabandan 5 puandan fazla düşerse test başarısız. Taban yükseltmek elle ve commit'le yapılır.
- Süre hedefi: katman B CI'a en fazla 2 dakika ekler; aşarsa senaryo sayısı görüntü katmanında örneklenir.

### 4.4 Gerçek görüntüler

`KuryeKazancTests/Fixtures/RealScreens/<platform>/<ad>.png` + `<ad>.json` (beklenen değerler). Kişisel bilgiler (ad, telefon, IBAN, TC) görüntüde karartılmış olmalı. Aynı çalıştırıcı gerçek görüntüleri ayrı bir rapor satırında gösterir; gerçek görüntü eşiği, en az 3 örnek birikince tabana eklenir. Bir şablon `active` durumuna yalnızca gerçek görüntülerle geçer (taklit ekranlarla asla).

## 5. Kazanç taraması denemesi (spike)

Çıktısı bir karardır; kod atılabilir. Dal: `spike/broadcast-capture`.

### 5.1 Parçalar

- **`KuryeBroadcast`** (Broadcast Upload Extension, `com.kuryekazanc.app.broadcast`, App Group `group.com.kuryekazanc.app`): `RPBroadcastSampleHandler`; saniyede en fazla 1 video karesi; kare küçültülür (uzun kenar ≈ 1280 px); `VNRecognizeTextRequest` (önce `.accurate`, bellek aşarsa `.fast` ölçümü de alınır); Core çözümleyici ile şablon seçimi; yalnızca kazanç ekranı sayılan karelerin `RecognizedLine` dizisi paylaş eklentisinin gelen kutusuna (`ScreenshotInbox`) yazılır; görüntü saklanmaz; `TextHash` ile son 50 ekran tekrarı atlanır.
- **Günlük:** App Group'ta `broadcast-log.json`: başlangıç/bitiş, en yüksek bellek (`phys_footprint`), okuma süresi (ortalama/en yüksek), işlenen/atlanan/yakalanan kare, yakalanan ekranların şablon kimliği.
- **Uygulama:** Profil > (yalnızca TestFlight/DEBUG) "Deneme" bölümü: "Kazanç taramasını başlat" (`RPSystemBroadcastPickerView`, `preferredExtension` = eklenti), "Deneme ekranları" (§4.3'teki taklit ekranlar arasında kaydırmalı gezinme), "Tarama günlüğü".

### 5.2 Kısayollar testi (kod yok)

Kullanıcıya verilecek tarif: Kısayollar > Otomasyon > Uygulama > Ayarlar "Açıldığında", "Hemen çalıştır" → "Bekle 3 sn" → "Ekran Görüntüsü Al" → "Paylaş" / "Kurye Kazanç'a gönder". Gözlenecek: otomasyon onaysız çalışıyor mu, görüntü ön plandaki uygulamayı mı içeriyor, paylaş eklentisine ulaşıyor mu.

### 5.3 Teslim ve önkoşullar

- Apple Developer: App ID `com.kuryekazanc.app.broadcast` (App Groups açık, aynı grup) + App Store profili; Codemagic referansı `kurye-kazanc-broadcast-appstore`; deneme dalının `codemagic.yaml`'ında `ios-release` profillerine eklenir.
- `release/spike-capture` dalı → Codemagic `ios-release` → TestFlight İç Test. **TestFlight 1.3.0 yüklemesi tamamlanmadan gönderilmez**; gönderimden önce kullanıcıya sorulur.
- Kullanıcı testi: taramayı başlat → Deneme ekranlarında hızlı gezin, araya Mesajlar/Ayarlar gir → 5 dk → durdur → Tarama günlüğünün ekran görüntüsünü paylaş; pil yüzdesini başta/sonda not et.

### 5.4 Karar

- Ölçütler (§1) sağlanırsa: 1.4a üretim tasarımı — kazanç taramasının kalıcı sürümü (orderCard'ların gün bazında birleştirilmesi, onay ekranı), Kısayollar entegrasyonu (App Intent ile "Kazanç ekranını oku").
- Bellek/kararlılık tutmazsa: `.fast` tanıma, daha seyrek kare; o da tutmazsa Kısayollar yolu ana yol olur.

## 6. Sıra

1. Okuma motoru (§3) + satır senaryoları (§4.1–4.2) — Windows'ta TDD.
2. Görüntü senaryoları ve CI raporu (§4.3) — GitHub Actions.
3. Kazanç taraması denemesi (§5) — TestFlight 1.3.0 sonrası, kullanıcıya sorarak.

## 7. Hata durumları

- Bilinmeyen ekran: bugünkü gibi `generic` + kontrol alanları; deneme eklentisinde kare atlanır (günlüğe "tanınmadı" sayısı).
- `list` ekranında satır okunamaması: toplam yine satırlardan; görünen toplamla uyuşmazlık kontrol işareti.
- Eklenti bellek sınırını aşarsa iOS yayını sonlandırır: günlüğe son durum yazılmış olur (her 10 karede bir kalıcı yazım); uygulama "Tarama beklenmedik şekilde durdu" gösterir.
- Görüntü testinde Vision'ın simülatörde farklı sonuç vermesi: taban değer CI ortamında ölçülür, cihazla karşılaştırma deneme sürümünde yapılır.

## 8. Testler

- Core (Windows): `TextPatterns.duration` birim testleri; şablon seçimi (ad, parmak izi, eşitlik, generic); `list` toplama ve uyuşmazlık; `orderCard`; eski JSON'un yeni alanlar olmadan çözülmesi (geriye uyum); satır senaryoları (~120).
- CI (simülatör): görüntü senaryoları + eşik; mevcut birim ve UI testleri.
- Deneme: §5.3 kullanıcı testi; sonuçlar `PROGRESS.md`'ye.
