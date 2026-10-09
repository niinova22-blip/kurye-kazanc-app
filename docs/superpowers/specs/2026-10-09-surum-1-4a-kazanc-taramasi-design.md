# Sürüm 1.4a (devam) — Kazanç taraması (üretim) ve Kısayollar

Tarih: 2026-10-09 · Önceki: `docs/superpowers/specs/2026-10-09-surum-1-4a-ekran-okuma-design.md` (§5 deneme). Deneme sonucu: `PROGRESS.md` "Kazanç taraması denemesi — sonuç".

## 1. Amaç ve kapsam

**Kullanıcının istediği:** Kurye taramayı başlatsın, platform uygulamalarındaki kazanç panellerini açıp kapatsın; tarama bitince uygulama bulduklarını göstersin ve onayla kayda çevirsin. Kısayollar ikinci yol olarak dursun. (Kullanıcı bu tasarımı sohbette onayladı.)

**Deneme verisi (iPhone, 1,5 dk):** en yüksek bellek 20,6 MB, okuma ort. 0,46 sn, çökme yok, 8 şablonun hepsi yakalandı; sorun: metin özetiyle tekrar kontrolü yetmedi (24 ekrana 38 yakalama — durum çubuğu saati ve kaydırma sırasındaki yarım kareler).

**Kapsam:**
1. Yayın eklentisi (`KuryeBroadcast`) üretim sürümü: üst şerit hariç okuma, iki kare kuralı, değer tabanlı tekrar kontrolü, yakalama dosyaları.
2. "Taramada bulunanlar" sonuç ekranı: liste, sipariş kartlarının gün+platform birleşimi, haftalık ekranlar bilgi, seçip kaydetme.
3. Giriş noktaları: Bugün'de "Kazanç taraması" düğmesi, Profil'de açıklama, ilk kullanım tanıtımı; deneme bölümü kaldırılır (tarama günlüğü yalnızca test araçlarında).
4. Kısayollar: "Kurye Kazanç'a ekran görüntüsü gönder" App Intent'i (görseli gelen kutusuna bırakır) + Profil'de kısa tarif.

**Kapsam dışı:** 1.4b (Topluluk, konum hücreleri, App Attest); gerçek platform ekranlarıyla kalibrasyon; otomatik (kurye başlatmadan) tarama — iOS izin vermez.

**Başarı ölçütleri:**
- Deneme ekranlarında 5 dk taramada her farklı ekran **bir kez** listelenir (saat değişimi, yarım kare tekrar üretmez); bellek < 40 MB.
- Sipariş kartları aynı gün + platformda tek satırda birleşir (toplam = kartların toplamı, paket = kart sayısı, bonus = ek tutarların toplamı).
- Kaydedilen kayıtlar mevcut form kurallarıyla aynı doğrulama seviyesini alır; daha önce kaydedilmiş ekran tekrar kaydedilmez.
- Görüntü hiçbir yerde saklanmaz; eklenti yalnızca okunan satırları yazar.

## 2. Kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Üst şerit | Karenin üst %6'sı okunmaz (Vision `regionOfInterest`) | Saat/pil metni tekrar kontrolünü bozuyordu |
| Kararlılık | Bir ekran art arda **2 karede aynı anahtarla** okunursa kabul | Kaydırma sırasındaki yarım kareler elenir |
| Tekrar anahtarı | `şablon + toplam (kuruş) + tarih (gün) + dönem`; tarama boyunca bir kez | Saat değişse de aynı ekran bir kez |
| Kaçan ekran sayısı | Tek karede görülüp onaylanmayan anahtarlar günlükte "kısa kaldı" olarak sayılır | Deneme: Uber/TheKurye/Banabikurye 2/3 — görünür olsun |
| Paylaşım dosyası | App Group `BroadcastCaptures/<ms>.json` = `BroadcastCapture {capturedAt, lines}` | Gelen kutusu (`Inbox/*.img`) görsel bekler; ayrı tutulur |
| Sipariş birleştirme | Aynı gün + platformdaki `.order` sonuçları tek kalem; dönem `.order` kalır (sunucuya vardiya olarak **gönderilmez**) | Tek sipariş kartları vardiya kanıtı değil |
| Haftalık | Listede "Haftalık özet — vardiya değil" etiketiyle, varsayılan seçili değil | Kurye isterse kaydeder (mevcut form kuralı: haftalık kontrol ister) |
| Kayıt | Her seçili kalem mevcut `EarningFormViewModel(imported:)` + `save` ile; `isGenuine = true` (sistem yayınından) | Tek doğrulama/kayıt yolu |
| Tekrar kayıt | Daha önce kaydedilmiş metin özeti (`knownTextHashes`) olan kalem listede "Zaten kayıtlı" ve seçilemez | Mevcut kural |
| Kısayollar | App Intent `SendScreenshotIntent(image: IntentFile)` → `ScreenshotInbox.add` | Paylaş menüsü olmadan otomasyonda kullanılabilir |

## 3. Bileşenler

**Core (saf):**
- `BroadcastCapture` (Codable): `capturedAt: Date`, `lines: [RecognizedLine]`.
- `CaptureKey` (Hashable): `templateID`, `totalCents`, `day` (gün başı), `period`; `init?(parsed: ParsedEarning, calendar:)` — şablon yoksa nil.
- `StableCaptureFilter`: `mutating func offer(_ key: CaptureKey?) -> CaptureKey?` — önceki kareyle aynı anahtar gelirse ve daha önce kabul edilmediyse anahtarı döndürür; `unconfirmedCount` (tek karede kalıp kabul edilmeyen farklı anahtar sayısı).
- `ScanResultBuilder`: `[(ParsedEarning, lines, capturedAt)]` → `[ScanItem]`; tekrarları anahtara göre atar, `.order` kalemlerini gün+platform bazında birleştirir.
- `ScanItem`: `kind` (`.daily`, `.weekly`, `.orderGroup(count)`, `.unknown`), `parsed`, `lines` (sipariş grubunda kartların satırları art arda), `capturedAt`, `textHash`.

**Eklenti (`KuryeBroadcast`):** denemedeki `SampleHandler` + üst şerit hariç + `StableCaptureFilter` + `CaptureKey` tekrar kümesi; kabul edilen kare `BroadcastCaptureStore.save`. Günlük (`BroadcastLog`) korunur: işlenen, tanınmayan, tekrar, kısa kalan, kabul edilen, en yüksek bellek.

**Uygulama:**
- `BroadcastCaptureStore` (App Group klasörü; uygulama + eklenti): `save`, `pending() -> [URL]`, `load`, `remove`.
- `ScanResultsViewModel` (@MainActor @Observable): bekleyen yakalamaları okur, `SyncCoordinator.mergedTemplates()` ile çözer, `ScanResultBuilder` ile kalemler; seçim; `save(in:)` her seçili kalem için `ImportedScreenshot` kurup `EarningFormViewModel(imported:)` ile kaydeder; sonra dosyaları siler.
- `ScanResultsView`: liste (platform, tarih, toplam, tür etiketi, durum), "Kaydet (n)", "Vazgeç" (dosyaları siler).
- `ScanButton` (Bugün): `RPSystemBroadcastPickerView` + "Kazanç taraması" etiketi; ilk kullanımda 3 adımlı tanıtım sayfası.
- Açılış/ön plana dönüşte bekleyen yakalama varsa sonuç sayfası açılır (gelen kutusu işlemesiyle aynı yer).
- `SendScreenshotIntent` + Profil'de "Kısayollar ile" tarifi.
- Deneme bölümü (`SpikeSection`) kaldırılır; "Tarama günlüğü" Profil > test araçlarında (yalnızca TestFlight/DEBUG) kalır.

## 4. Hata durumları
- Eklenti bellek sınırında sonlandırılırsa: o ana kadar kabul edilenler dosyada; günlükte bitiş boş → sonuç ekranında "Tarama beklenmedik şekilde durdu" notu.
- Sonuç yokken: "Kazanç ekranı bulunamadı — platform uygulamasında kazanç panelini açtığından emin ol."
- Bozuk yakalama dosyası: atlanır ve silinir.

## 5. Testler
- Core (Windows): `CaptureKey` (yuvarlama, şablonsuz nil), `StableCaptureFilter` (iki kare kuralı, tekrar, kısa kalan sayımı, araya giren farklı kare), `ScanResultBuilder` (tekrar, sipariş birleştirme toplam/bonus/paket, haftalık türü, farklı gün/platform ayrımı), `BroadcastCapture` Codable.
- CI (uygulama): `ScanResultsViewModel` (sahte yakalamalarla liste, seçim, kaydetme → kayıt sayısı ve seviye, zaten kayıtlı kalemin seçilemezliği, dosyaların silinmesi); `SendScreenshotIntent` gelen kutusuna yazar (geçici klasörle).
- Cihaz: masaüstündeki `Kurye-Senaryo-Gorselleri` ile 5 dk tarama; ölçütler §1.
