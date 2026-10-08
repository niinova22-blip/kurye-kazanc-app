# Sürüm 1.3 — Sunucu temeli (Supabase), veri gönderimi, Apple ile Giriş, kalibrasyon

Tarih: 2026-10-09 · Üst tasarım: `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md` (§2, §4.3, §4.4, §6, §12'nin 1.3 satırı). Bu belge 1.3'ü daraltır ve üst tasarımdan sapmaları kaydeder.

## 1. Amaç ve kapsam

**Kullanıcının istediği:** Topluluk özellikleri (1.4) için veri toplamaya başlamak; sunucu kurulumu dahil 1.3'ü bitirip test etmek. 1.2 ile 1.3 birlikte ilk kez derlenecek; TestFlight'a göndermeden önce kullanıcıya sorulacak.

**Kapsam (1.3):**
1. Supabase projesi (Frankfurt), şema, RLS, sunucu fonksiyonları, sunucu testleri
2. Anonim oturum (varsayılan) + isteğe bağlı **Apple ile Giriş** ve yedekleme/geri yükleme
3. Vardiya gönderim kuyruğu (outbox): paylaşım açıksa, uygun kayıtlar sunucuya
4. Uzaktan OCR şablonları (sunucudan sürümlü JSON; gömülü kopya yedek)
5. Kalibrasyon modu (ayrı rıza; maskelenmiş OCR satırları gönderilir)
6. "Verilerimi sil"
7. KVKK aydınlatma ve açık rıza metinleri **taslağı** (uygulama içi + `docs/legal/`)

**Kapsam dışı:** App Attest (kullanıcı kararı: 1.4'e), konum hücreleri gönderimi ve topluluk istatistik fonksiyonları/ekranı (1.4), widget, PDF/CSV.

**Başarı ölçütleri:**
- Paylaşım kapalıyken hiçbir istek atılmaz (ağ çağrısı yok); uygulama sunucusuz tam çalışır.
- Paylaşım açıkken uygun kayıt, internet gelince bir kez gönderilir; aynı ekran görüntüsü (aynı `text_hash`) sunucuda ikinci kez kabul edilmez.
- Başka kullanıcının satırı okunamaz/silinemez (RLS testleriyle kanıtlı).
- Apple ile giriş yapan kurye yeni telefonda kayıtlarını geri yükleyebilir.
- Sunucu testleri (SQL) ve uçtan uca betik (anonim oturum → gönderim → tekrar reddi → silme) Windows'tan gerçek projeye karşı geçer.

## 2. Kararlar

| Konu | Karar | Gerekçe / maliyet |
|---|---|---|
| App Attest | **1.4'e ertelendi** | 1.3 verisi henüz kimseye gösterilmez; yerine sunucu tarafı günlük gönderim sınırı + `text_hash` tekilliği |
| İstemci kütüphanesi | **Kendi küçük REST istemcimiz** (URLSession; GoTrue + PostgREST uçları) | Üçüncü taraf bağımlılık yok kuralı; ihtiyaç 6–7 uç |
| Gönderilen seviyeler | `verified` ve `ocrUnverified` (sunucuda `level` sütunu); `manual` ve `ocrEdited` **gönderilmez** | Üst tasarım §4.1: ocrUnverified yalnızca "önizleme" istatistiğine girer (1.4) |
| `text_hash` | Normalize OCR metninin **SHA-256**'sı (Core'da saf Swift); yerel tekrar kontrolündeki FNV özetinden ayrı | Üst tasarım §4.3 |
| Kimlik | Anonim Supabase kullanıcısı; Apple ile Giriş ayrı bir kullanıcıya geçer (anonim hesap bağlanmaz). Gönderilmiş vardiyalar anonim kimlikte kalır | Bağlama (linkIdentity) karmaşık; vardiyalarda SELECT zaten yok |
| Yedek | Apple ile girişli kullanıcı için tek satır `backups` (jsonb: tüm kazanç, gider, hedef, ayarlar); elle "Yedekle" + her kayıtta en geç 24 saatte bir otomatik | Basit; şifreleme 1.4 değerlendirmesi |
| Oran sınırı | Kullanıcı başına günde en fazla 40 vardiya ve 20 kalibrasyon örneği (sunucu fonksiyonunda) | App Attest yerine kaba koruma |
| Sunucu testleri | SQL testleri (pgTAP) Supabase Management API'nin SQL ucu üzerinden Node betiğiyle çalıştırılır; ayrıca anon anahtarla uçtan uca Node betiği | Bu makinede Docker yok |
| Proje | Supabase, bölge `eu-central-1` (Frankfurt), ad `kurye-kazanc`, ücretsiz katman | Üst tasarım §2 |

## 3. Sunucu

**Tablolar** (`supabase/migrations/`):

| Tablo | Sütunlar | Erişim |
|---|---|---|
| `shifts` | id, user_id (auth.uid()), platform_code, province, district, vehicle, weekday (1–7), start_slot (0–95, 15 dk), duration_min, gross, bonus, packages, distance_km (0,5'e yuvarlı), level (`verified`/`ocrUnverified`), template_id, template_version, text_hash (unique), client_record_id (uuid), created_at | Doğrudan erişim yok; yalnızca `submit_shift` (INSERT) ve `delete_my_data`. SELECT yok |
| `ocr_templates` | id (ör. `getir.earnings`), platform_code, version, status, body (jsonb), updated_at; birincil anahtar (id, version) | anon + authenticated SELECT |
| `calibration_samples` | id, user_id, platform_code, template_id, lines (jsonb: maskelenmiş metin + kutular), created_at | Yalnızca `submit_calibration` |
| `backups` | user_id (birincil anahtar), payload (jsonb), updated_at | Yalnızca sahibi (SELECT/INSERT/UPDATE/DELETE), anonim kullanıcı yazamaz |

**Fonksiyonlar** (SECURITY DEFINER, `search_path` sabit):
- `submit_shift(payload jsonb) returns text`: doğrular (level, aralıklar, platform kodu), günlük sınırı uygular, `text_hash` çakışırsa `'duplicate'`, başarılıysa `'ok'`, sınırda `'rate_limited'`.
- `submit_calibration(payload jsonb) returns text`: aynı mantık.
- `delete_my_data() returns void`: çağıranın `shifts`, `calibration_samples`, `backups` satırlarını siler.
- Anonim kullanıcı `backups`'a yazamaz (RLS: `auth.jwt()->>'is_anonymous' = 'false'`).

**Ayarlar:** Anonim oturum açık; Apple sağlayıcısı (Services ID + .p8 anahtar, Apple Developer'dan); e-posta oturumu kapalı.

## 4. İstemci

| Bileşen | Yer | Görevi |
|---|---|---|
| `SHA256`, `TextHash.sha256(_:)` | `Core/` | Saf Swift SHA-256 (test vektörleriyle) |
| `ShiftPayload` + kurallar | `Core/Sync/` | Kayıttan gönderim yüküne: 15 dk dilim, hafta günü, km 0,5 yuvarlama, seviye filtresi |
| `OutboxPolicy` | `Core/Sync/` | Yeniden deneme (üstel bekleme 1 dk → 6 sa), hangi sonuç kalıcı (duplicate/ok) |
| `CalibrationMasker` | `Core/Sync/` | IBAN (TR+24), telefon, 11 haneli TC, e-posta maskesi |
| `TemplateMerger` | `Core/OCR/` | Gömülü + uzak şablonları id'ye göre birleştirir (yüksek sürüm kazanır) |
| `SupabaseConfig` | `Services/Sync/` | URL + anon anahtar (Info.plist; anon anahtar gizli değildir) |
| `SupabaseClient` | `Services/Sync/` | Anonim kayıt, token yenileme, Apple id_token girişi, RPC çağrısı, tablo okuma/yazma; oturum Keychain'de |
| `OutboxQueue` | `Services/Sync/` | Bekleyen gönderimler (Application Support JSON), ağ/uygulama açılışında boşaltma |
| `SyncCoordinator` | `Services/Sync/` | Paylaşım rızası + kayıt değişince kuyruğa ekleme; şablon güncelleme; yedekleme |
| `AppleSignIn` | `Services/Sync/` | AuthenticationServices, nonce (SHA-256), id_token → Supabase |
| `BackupService` | `Services/Sync/` | Yedek yükü oluştur/yükle/geri yükle (SwiftData) |
| Profil | `Views/Profile/` | "Hesap ve yedek" (Apple ile Giriş, Yedekle, Geri yükle, Çıkış), "Kalibrasyon" (rıza + açıklama), "Verilerimi sil", "Gizlilik (KVKK)" |
| Kazanç formu | `Views/Earnings/` | Kalibrasyon açıksa OCR'lı kayıtta "Kalibrasyona gönder" |

**Kurallar:**
- Ağ yalnızca: paylaşım veya kalibrasyon rızası açıkken ya da Apple ile giriş yapılmışken. Rıza kapatılınca kuyruk boşaltılır (gönderilmeden silinir).
- Gönderim yalnızca yeni/düzenlenmiş uygun kayıt için; kayıt sonradan `ocrEdited` olursa gönderilmez.
- Uzak şablonlar uygulama açılışında en fazla 12 saatte bir çekilir; ağ yoksa gömülü kopya.
- Sunucu hatası kullanıcıya gösterilmez; Profil'de "Son eşitleme" bilgisi.

## 5. Hata durumları

| Durum | Davranış |
|---|---|
| İnternet yok / sunucu kapalı | Kuyrukta kalır, üstel bekleme |
| `duplicate` | Kayıt yerelde "daha önce gönderilmiş" işaretlenir, tekrar denenmez |
| `rate_limited` | Ertesi gün tekrar |
| Token süresi doldu | Yenileme; yenileme başarısızsa yeni anonim oturum |
| Apple girişi iptal/başarısız | Sessiz; anonim oturum sürer |
| Geri yükleme | Mevcut yerel kayıtlarla `id` üzerinden birleştirir (yinelenmez) |

## 6. Testler

- **Core (`swift test`):** SHA-256 vektörleri, ShiftPayload dönüşümü, OutboxPolicy, CalibrationMasker, TemplateMerger.
- **Sunucu:** `supabase/tests/*.sql` (pgTAP: RLS, tekillik, oran sınırı, yetkisiz okuma) + `scripts/server/e2e.mjs` (anon anahtarla uçtan uca). İkisi de gerçek projeye karşı Windows'tan çalışır.
- **XCTest (CI):** SupabaseClient istek biçimleri (sahte URLProtocol), OutboxQueue, BackupService birleştirme.
- **İlk derleme:** 1.2 + 1.3 birlikte develop'ta Codemagic `ios-ci`; hatalar düzeltilir. TestFlight'tan önce kullanıcıya sorulur (Canlı Etkinlik App ID/profili de o zaman).
