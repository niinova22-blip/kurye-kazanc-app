# Sürüm 1.4b — Topluluk: ilçe ısı haritası ve karşılaştırma

Tarih: 2026-10-10 · Üst tasarım: `docs/superpowers/specs/2026-10-07-gridwise-tr-design.md` (Topluluk). Kullanıcı kararları (sohbet): test için sentetik kuryeler (seçenek a), ilçe **Sincan / Ankara**; her şey ücretsiz (premium daha sonra, yeterli kullanıcı ve veri toplanınca).

## 1. Kapsam
1. Sunucu: `shifts.is_synthetic`; `community_heatmap(province, district)` ve `community_summary(province, district)` fonksiyonları; **k-anonimlik: farklı kurye sayısı ≥ 5 olmayan hücre/özet satırı döndürülmez**. pgTAP testleri.
2. Sentetik test verisi: `scripts/server/seed_synthetic.mjs` (8 anonim kurye, son 30 gün, Sincan/Ankara, `is_synthetic = true`) ve `purge_synthetic.mjs` (hepsini siler). Kullanıcı çalıştırır.
3. Uygulama: Topluluk sekmesi — ilçe seçimi (varsayılan: son kaydın ilçesi), "İlçende ₺/saat" + kendi ₺/saat karşılaştırması, gün × saat ısı haritası, platform karşılaştırması, en iyi 3 saat; paylaşım kapalıysa tek ekranlık davet (veri paylaşan görür); veri yetersizse açık mesaj.

**Kapsam dışı:** konum hücreleri (~500 m) ve harita (MapKit), App Attest, premium.

## 2. Sunucu kuralları
- Saat kovası: vardiya `weekday` (1 = Pazartesi), `start_slot` (15 dk), `duration_min` ile kapsadığı yerel saatlere dağıtılır (gece yarısını aşan kısım ertesi güne). Hücre değeri = Σ(gross+bonus) payı / Σ saat (dakika ağırlıklı ₺/saat); `couriers = count(distinct user_id)`, `shifts`.
- Özet: ilçe ortalaması ₺/saat (≥ 5 kurye), platform bazında ₺/saat ve ₺/paket (her platform ≥ 5 kurye), en iyi 3 hücre.
- Pencere: son 8 hafta (`created_at` yerine vardiyanın kendisi bilinmediği için `created_at >= now() - 56 gün`).
- `security definer`, `search_path = public`; `authenticated` (anonim oturum dahil) çalıştırabilir; `anon` rolü çalıştıramaz. `submit_shift` istemcinin `is_synthetic` göndermesine izin vermez (her zaman false).
- `delete_my_data` değişmez (sentetik kullanıcılar purge betiğiyle silinir).

## 3. Uygulama
- `SupabaseClient`: `communityHeatmap(province:district:)`, `communitySummary(province:district:)` (RPC, oturum gerekir; hata → nil).
- Core: `CommunityCell {weekday, hour, perHour, couriers, shifts}`, `CommunitySummary {perHour, couriers, platforms:[{code, perHour, perPackage, couriers}], best:[CommunityCell]}` Codable (snake_case).
- `CommunityViewModel`: paylaşım kapalıysa ağ yok; ilçe seçenekleri = kayıtlardaki (il, ilçe) çiftleri; yükleme/boş/hata durumları; kendi ₺/saat (son 8 hafta, mevcut analitik) karşılaştırması.

## 4. Testler
- pgTAP: k<5 hücre dönmez; ≥5 döner; saat dağıtımı (ör. 18:00 başlayıp 150 dk → 18, 19, 20 saatleri); anon çalıştıramaz; `submit_shift` is_synthetic=false.
- Core: Codable çözme; uygulama: VM paylaşım kapalı → istemci çağrılmaz; boş özet mesajı.
