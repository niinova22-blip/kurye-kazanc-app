# Sürüm 1.7.0 — Tek firma odaklı hedef planı, Firmalar karşılaştırması, yakıt, tanıtım

Tarih: 2026-10-13 · Dal: `feature/surum-1-7` (`feature/hakedis-tarife` = main 1.6.0 üzerinden)

## 1. Amaç ve ilkeler

Kullanıcının sözleri (özet):
- "Doğrulanmamış" uyarısı her yerde değil, sayfanın en altında tek bilgi notu olsun.
- Topluluk yerine firmaların kazanç karşılaştırması gelsin.
- "Vardiyayı başlat" düğmesi kalksın.
- Plan öner anlaşılır ve güzel olsun; kullanıcı günlük/haftalık/aylık TL hedefi girsin
  (ör. aylık 100.000 TL), uygulama "en az şu kadar saat, şu kadar paket, şu bölgede" desin.
- Test senaryoları telefondaki veritabanına yüklensin, değerler ekranda görülsün.
- Elle giriş ekranları, düğmeler ve yazma alanları premium hissettirsin.
- Animasyonlu, görselli, tekrar izlenebilir tanıtım.
- Derleme GitHub Actions'ta.

Bağlayıcı ürün ilkeleri (kullanıcı kararı, 2026-10-13):
1. **Bir kurye aynı anda yalnızca bir firmada çalışır.** Tüm plan ve hedef en başta seçilen
   tek firmanın tarifesine göre kurulur. Çoklu firma günlük planı kaldırılır.
2. **Ücret = firmanın yayımladığı güncel tarife, kampanya ve bonuslar.** Kurye ortalaması /
   topluluk verisi ücret hesabında kullanılmaz.
3. **Gider = km × tüketim × güncel yakıt fiyatı.** Yakıt fiyatı şimdilik elle girilir; ileride
   sunucudan gelecek (kaynak alanı hazır).
4. Hedef **net, yakıt düşülmüş** tutardır.
5. Tarife değerleri uydurulmaz; doğrulanmamış kalemler kullanılır ama sayfa altındaki tek notta
   listelenir.

## 2. Bilgi mimarisi

Sekmeler (5 → 4):

| Sekme | İçerik |
|---|---|
| Bugün | Günlük hedef kartı (aylık hedeften günlük pay: paket, saat, şu ana kadar), bugünkü net, + menüsü (ekran görüntüsü / elle kazanç / gider), son kayıtlar, öneri varken tarama önerileri, Plan kartı |
| Kazanç | Hakediş + Analiz birleşimi: dönem seçici (gün/hafta/ay), brüt–yakıt–net kartları, grafikler, hakediş kayıtları ve dönem özeti, ödeme mutabakatı |
| Firmalar | Tarife karşılaştırması (bölüm 5) |
| Profil | Firmam ve tarife soruları, araç ve yakıt, hedef, otomatik vardiya, hesap/gizlilik, "Tanıtımı izle", **Gelişmiş** (platform kuralları ve kaynakları, tarife sürümleri, kaynak/onay, kendi tarifem), Test araçları (yalnızca test sürümü) |

Kaldırılanlar:
- Topluluk sekmesi ve uygulama tarafı kodu (`CommunityView`, `CommunityViewModel`, ısı haritası
  çağrıları). Sunucu fonksiyonlarına dokunulmaz. Paylaşım rızaları (Profil) olduğu gibi kalır.
- "Vardiyayı başlat/bitir" düğmesi (Bugün). Süre/km otomatik vardiyadan (açıksa) ya da formdaki
  km alanından gelir. Otomatik vardiyanın bildirimi ve Canlı Etkinlikteki "Vardiyayı bitir"
  korunur.
- `KuryeBroadcast` yayın eklentisi: hedef `project.yml`'den, imza adımları workflow'lardan,
  bağlı kod uygulamadan çıkarılır.
- Çoklu firma plan önerisi ekranı (`PlannerView` öneri listesi, zaman dilimi DP'si kullanıcıya
  gösterilmez). `PlanEngine` Core'da kalır (testleri var), arayüz kullanmaz. Kural ekranları
  Gelişmiş'e taşınır.

### 2.1 Tek bilgi notu

`VerificationFootnote` bileşeni: sayfa kendi kullandığı doğrulanmamış kalemleri
(`[UnverifiedItem(label, platform, reason)]`) toplar; liste boş değilse sayfanın en altında
"ⓘ Bu sayfadaki bazı tarife değerleri henüz firmanın resmi kaynağıyla doğrulanmadı; sonuçlar
tahminidir." görünür, dokununca kalem listesi sayfası açılır. Satır içi "Doğrulama gerekli",
"Doğrulanmamış kalem içerir", "Kesin değil" etiketleri ve turuncu uyarılar kaldırılır. Tarife
sürümü ayrıntı ekranındaki (Gelişmiş) "Doğrulama durumu" alanı veri olarak kalır.

## 3. Firma seçimi ve profil

- Kurulumun ilk sorusu (tanıtımdan hemen sonra): **"Hangi firmayla çalışıyorsun?"** — dört
  firmadan biri seçilir: Getir, Trendyol GO, Yemeksepeti, Paket Taxi / Migros Hemen. Seçim
  kaydedilir; Bugün, Kazanç, Plan ve hedef hesapları yalnızca bu firmaya göre yapılır. `PayrollModel.select(platform:)` ve mevcut hakediş platformu tercihi
  bu seçimdir (tek kaynak).
- Firmaya özel sorular, firmanın tarifesindeki koşullardan türetilir
  (`TariffQuestions.required(for: TariffVersion)`):
  - `eligibility_conditions.region_tier` varsa → bölge kademesi (Plus / standart).
  - `min/max_seniority_years` varsa → kıdem yılı.
  - `requires_flag` varsa → ilgili bayrak (ör. `woman_employment` "Kadın istihdam desteğinden
    yararlanıyorum").
  - tarife araç türüne göre ayrıysa → araç türü.
- Yanıtlar `CourierTariffProfile` (JSON, UserDefaults) olarak saklanır; `PayInput.regionTier`,
  `seniorityYears`, `vehicleType`, `flags` buradan doldurulur.
- Değiştirme: Profil > Ayarlar > **"Çalıştığım firma"** satırı (firma adı + logo yerine baş
  harf simgesi). Dokununca aynı seçim ekranı ve firmaya özel sorular açılır; onaydan sonra tüm
  ekranlar yeniden hesaplanır. Eski firmanın kayıtları silinmez (Kazanç'ta firma filtresiyle
  görülebilir).

## 4. Hedef planlayıcı (Plan ekranı)

### 4.1 Girdiler
`GoalSpec`: tutar (TL, net), dönem (gün/hafta/ay), haftada çalışma günü (1–7, varsayılan 6),
günde en fazla saat (varsayılan 10). Ay = takvim ayının iş günleri (haftalık gün sayısına göre;
ör. 6 gün → 26), hafta = haftalık gün, gün = 1.

Hız (`PaceEstimate`): son 8 haftanın seçili firmadaki kayıtlarından paket/saat ve km/paket;
en az 5 kayıt ve 10 saat yoksa Profil'deki varsayılanlar (2,5 paket/saat, 3,5 km/paket) ve
`isAssumed = true`.

Yakıt (`FuelCostModel`): son girilen fiyat (TL/L) × tüketim (L/100 km); fiyat yoksa eski
`costPerKm` (yakıt+bakım) yedeği ve not.

### 4.2 Hesap (yaklaşım A: motoru tersine çalıştırma)
Core `GoalPlanner` (saf, test edilir):
1. Dönem için `PayInput` kurar (span = dönem, `periodPackages`, saat, km = paket × km/paket,
   profil alanları), `PayEngine` ile brütü hesaplar.
2. Paket sayısı N için `net(N) = brüt(N) − yakıt(N)`; `net(N) ≥ hedef` olan **en küçük N**'i
   arar (monoton artan varsayımıyla ikili arama, 0…20.000; kademe sıçramaları motor tarafından
   doğru hesaplanır). Saatlik ücretli modellerde saat = N / hız, saat sınırıyla kırpılır.
3. Saat = N / hız; günlük saat > en fazla saat ise **ulaşılamaz**: o sınırla en yüksek net ve
   hedefe ulaşmak için gereken gün sayısı (haftada 7'ye kadar) önerilir; 7 günde de olmuyorsa
   yalnızca en yüksek net söylenir.
4. Çıktı `GoalPlan`:
   - `guaranteed`: paketten bağımsız kalemler (sabit ücret, saatlik ücret × saat, kullanıcıya
     uygun yan haklar — `requires_flag` sağlanıyorsa `is_cash` olmasa da **hedefe dahil**, ayrı
     satırda) — kalem listesi + toplam.
   - `packageIncome`: paket/km/bonus kalemleri.
   - `fuel`, `gross`, `net`, `packages` (dönem/gün), `hours` (gün), `workDays`.
   - `regionTier` + `otherTierDelta` (tarifede bölge kademesi varsa diğer kademeyle sabit ücret
     farkı).
   - `nextTierHint`: bir sonraki kademe eşiği N'den ≤ %20 uzaksa: eşik, ek paket, ek net.
   - `unverified`: kullanılan doğrulanmamış kalemler (sayfa altı not için).
   - `isPaceAssumed`, `reachability` (.reachable / .needsMoreDays(Int) / .unreachable(maxNet)).

### 4.3 Sonuç kartı (örnek, Paket Taxi, örnek tarife)
```
Paket Taxi · Aylık 100.000 TL net hedef
Zaten alacakların
  ✓ Aylık sabit ücret (Plus bölge)      65.223 TL
  ✓ Kadın istihdam desteği              +2.000 TL
Hedef için kalan: 32.777 TL + tahmini yakıt → paket geliri
📍 Bölge: Plus bölge (standarda göre +12.000 TL sabit ücret)
📦 Paket: ayda 966 → günde 38 paket (26 iş günü)
⏱ Süre: günde en az 9 saat (hızın: 4,2 paket/saat)
💰 Brüt − yakıt = net 100.000 TL
💡 1.100 pakete ulaşırsan tüm paketler 40 TL: +… TL
```
Kartın altında: hız "varsayım" ise kısa not; ulaşılamazsa açıklama + en yakın seçenek.
Bölgenin hangi ilçeleri kapsadığı uydurulmaz; kullanıcı kademesini kendi seçer.

### 4.4 Bugün kartı
`DailyGoalProgress`: dönem planından günlük pay (paket, saat, net) ve bugünkü kayıtlardan
gerçekleşen (paket, net). Hedef yoksa "Hedef koy" çağrısı.

Eski `weeklyNetGoal` / `dailyNetGoal` anahtarları `GoalSpec`'e taşınır (bir kerelik geçiş:
haftalık varsa haftalık hedef olur).

## 5. Firmalar sekmesi

- "Aynı iş" girdisi (`WorkloadSpec`): günlük paket, saat, km/paket, ayda gün. Başlangıç değeri
  kendi ortalamalarından, yoksa varsayılan; değiştirilebilir (premium sayı seçiciler).
- `TariffComparison` (Core): her firmanın **güncel** tarifesiyle ayın hakedişi (`PayEngine`,
  span = ay), yakıt, net, net/saat. Kendi firman üstte sabit "Şu anki firman"; diğer üçü
  net farkıyla ("+4.300 TL/ay") sıralı. Diğer firmalarda **en düşük kıdem** (yeni başlayan)
  kullanılır — kurye o firmaya geçerse zaten bu kademeden başlar (kullanıcı kararı). Bölge
  kademesi kullanıcının kendi seçtiği bölge kademesidir; o firmada karşılığı yoksa en düşük
  bölge kademesi. Satırda "yeni başlayan kademesiyle" yazar.
- Firma ayrıntısı: tarife tablosu (sabit, paket, km, kademeler, bonuslar), "Kampanyalar ve süreli
  bonuslar" (geçerlilik bitişi olan kalemler, bitiş tarihiyle), yürürlük ve son kontrol tarihi.
- **Tarife ↔ yakıt ilişkisi** (`TariffFuelCorrelation`): her firmanın son iki yayımlanmış
  sürümü arasındaki paket başı (yoksa sabit/saatlik) değişim yüzdesi ile aynı aralıkta
  kullanıcının yakıt geçmişindeki değişim yüzdesi; aynı yönde ve yakıt artışı ≥ %3 ise "✓ yakıt
  artışıyla uyumlu", ters yönde ise "kontrol et", yakıt verisi yoksa gösterilmez. Doğrulama
  durumunu değiştirmez.
- Tarife bildirimi: tarife eşitlemesi sonrası başka bir firma kullanıcının işi için kendi
  firmasından ≥ %5 daha fazla net veriyorsa ve bu durum yeni oluştuysa yerel bildirim + Firmalar
  rozetinde nokta ("Tarifeler değişti — Firmalar'a bak"). Aynı sürüm çifti için bir kez.

## 6. Yakıt

- `FuelPriceEntry { date, pricePerLiter (Money), fuelType (benzin/motorin/elektrik-kWh), source:
  manual|server, province? }`, `FuelStore` (JSON `fuel.json`, `PayrollStore` deseni).
  SwiftData şeması değişmez.
- Profil > Araç ve yakıt: fiyat girişi (tarih varsayılan bugün), tüketim (L/100 km; motosiklet
  varsayılan 3,0, otomobil 6,5), geçmiş listesi (silinebilir).
- Fiyat 7 günden eskiyse Bugün ve Firmalar'da "Yakıt fiyatını güncelle" satırı.
- `FuelCostModel.cost(km:on:)`: o tarihteki (≤ tarih en yeni) fiyatla hesap. Bugün / Kazanç
  ekranlarının tahmini gideri bu modelden gelir; fiyat hiç yoksa eski `costPerKm`.

## 7. Tanıtım

- `IntroView`: 6 sayfa (`TabView` .page), SwiftUI ile çizilmiş görseller (SF Symbols +
  şekiller; görüntü varlığı yok), sayfa göründüğünde oynayan animasyonlar (`PhaseAnimator`,
  `symbolEffect`, `contentTransition(.numericText())`), `accessibilityReduceMotion` açıkken sade.
  1. Ne kadar kazandığını ve ne kadar kaldığını bil — TL sayacı.
  2. Kazancını ekle — telefon çerçevesinde tarama çizgisi, rakamlar kartlara.
  3. Firmanın tarifesi — tarife satırları sırayla, ✓.
  4. Hedefini koy — halka dolar, paket/saat sayar.
  5. Yakıt ve km — gösterge iğnesi, damla.
  6. Firmalar ve gizlilik — kartlar yer değiştirir, kilit kapanır.
- İlk açılış: Tanıtım → Kurulum (firma, firma soruları, araç/yakıt, hedef) →
  `hasCompletedOnboarding`. Mevcut kullanıcılar (1.6'dan güncelleyen) tanıtımı bir kez görür
  (`hasSeenIntroV17`), kurulumu değil; firma seçili değilse kurulumun firma adımı açılır.
- Tekrar izleme: Bugün ekranının üst çubuğunda **soru balonu düğmesi**
  (`questionmark.bubble`) → kısa menü: "Uygulamayı tanı (tanıtımı izle)" ve "Bu ekran ne
  gösteriyor?" (ekrana özel 2–3 satırlık açıklama kartı). Aynı düğme Kazanç, Firmalar ve Plan
  ekranlarında da var (ekrana özel açıklamayla). Ayrıca Profil > "Tanıtımı izle". Tekrar
  izlemede yalnızca tanıtım açılır, "Başla" yerine "Kapat".

## 8. Premium giriş bileşenleri (`Views/Design/Input/`)

- `AmountField`: büyük TL rakamı, `numericText` geçişi, odakta vurgu rengi parlaması +
  `Haptics.selection`, geçersizde sallanma + uyarı titreşimi, Türkçe sayı ayrıştırma
  (`TurkishNumberParser`).
- `FloatingTextField`: yukarı kayan etiket, odak çerçevesi.
- `Stepper`-benzeri `CountStepper`: −/+ , basılı tutunca hızlanır, her adımda hafif titreşim.
- `PressableButtonStyle`: basılınca 0,97 ölçek + hafif titreşim; `PrimaryActionButtonStyle`
  bunu kullanır.
- `SaveConfirmation`: Kaydet sonrası ✓ çizim animasyonu + `Haptics.success`.
- Uygulandığı ekranlar: elle kazanç, gider, hakediş kaydı, hedef, yakıt, kurulum.

## 9. Test senaryoları ve Veritabanı ekranı

- Core `DemoScenario` (saf veri, `DemoScenarioCatalog`):
  1. `paketTaxi30` — Paket Taxi, Plus, kadın desteği, 30 gün kayıt (gün 30–45 paket), hedef aylık
     100.000 TL, yakıt geçmişi 4 giriş.
  2. `getirBehind` — Getir motorlu, 14 gün düşük hız, hedef aylık 100.000 TL (ulaşılamaz/ek gün).
  3. `tariffChanged` — iki tarife sürümü (kullanıcı tarifesi olarak; örnek), yakıt +%11, Firmalar
     bildirimi ve ✓.
  4. `fresh` — boş; tanıtım + kurulum baştan.
  Senaryolar deterministiktir (sabit tohum, bugüne göre göreli tarihler).
- `DemoScenarioLoader` (uygulama): kazanç/gider (SwiftData), hakediş kayıtları (`PayrollStore`),
  yakıt (`FuelStore`), profil ve hedef (UserDefaults) yazar; oluşturulan kimlikleri
  `demoRecordIDs` altında saklar. "Senaryoyu sil" yalnızca bunları ve senaryonun ayarlarını
  geri alır (yükleme öncesi ayarların yedeği). Gerçek kayıt varken yüklemede onay uyarısı.
- `DatabaseInspectorView` (salt okunur): sekmeler Kazançlar, Giderler, Hakediş, Yakıt, Ayarlar
  (hedef, firma profili, yakıt tüketimi), Aktif tarife; satır sayısı + satırlar, dokununca tüm
  alanlar. Yalnızca `BuildEnvironment.showsTesterTools`.

## 10. Testler

Core (`swift test`, Windows):
- `GoalPlannerTests`: Paket Taxi Plus + kadın desteği → beklenen paket/saat; kademe geçişi (1.100
  eşiği) ve `nextTierHint`; hız varsayımı bayrağı; ulaşılamaz → `needsMoreDays` /
  `unreachable`; Getir saatlik + paket + hafta sonu bonusu; günlük/haftalık dönem; hedef ≤
  garanti gelir → 0 paket.
- `FuelCostModelTests`: tarihe göre fiyat seçimi, fiyat yokken yedek, tüketim.
- `TariffComparisonTests`, `TariffFuelCorrelationTests`, `TariffQuestionsTests`,
  `DemoScenarioTests` (senaryo verisi tutarlı, planlayıcı beklenen sonucu verir).
Uygulama (CI): `IntroFlowUITests` (tanıtım → kurulum → hedef sonucu görünür),
`DemoScenarioUITests` (senaryo yükle → Veritabanı'nda satır sayısı), mevcut UI testlerinin
vardiya düğmesi / Topluluk / Hakediş sekmesi referanslarının güncellenmesi.

## 11. Derleme ve yayın

- Sürüm 1.7.0. Dal `feature/surum-1-7` push edilir; `ios-ci.yml` GitHub Actions'ta
  `workflow_dispatch` ile (UI testleri dahil) çalıştırılır.
- `KuryeBroadcast` kaldırıldığı için `ios-release.yml` ve `codemagic.yaml`'dan ilgili imza
  profili adımları çıkarılır.
- TestFlight yüklemesi (`ios-release.yml`) yalnızca kullanıcı onayıyla, kullanıcı başlatır.

## 12. Kapsam dışı

- Sunucudan otomatik yakıt fiyatı (sonraki sürüm; alanlar hazır).
- Topluluk sunucu fonksiyonlarının silinmesi, sentetik verinin temizlenmesi (lansman öncesi ayrı iş).
- Bölge kademesinin ilçe listesi (resmi kaynak yok).
