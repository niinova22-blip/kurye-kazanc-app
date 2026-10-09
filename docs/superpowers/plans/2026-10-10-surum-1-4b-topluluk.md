# 1.4b Topluluk — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Spec:** `docs/superpowers/specs/2026-10-10-surum-1-4b-topluluk-design.md`

## Global Constraints
- Önceki kısıtlar (Core saf, ASCII yorum, Türkçe metin).
- k-anonimlik ≥ 5 farklı kurye — sunucuda uygulanır; istemci asla tek kişinin verisini göstermez.
- Canlı veritabanına yazan betikleri ajan ÇALIŞTIRMAZ (kullanıcı çalıştırır); yalnızca yazar ve `node --check` ile sözdizimini doğrular.
- CI Codemagic'te; macOS kuyruğu yavaş — düzeltmeleri toplayıp tek push.

### Task 1: Sunucu göçü, fonksiyonlar, pgTAP, betikler
- `supabase/migrations/20261010000003_community.sql`: `alter table shifts add column if not exists is_synthetic boolean not null default false`; `submit_shift` is_synthetic yazmaz (değişiklik gerekmiyorsa doğrula); `community_heatmap`, `community_summary` (spec §2); grant/revoke.
- `supabase/tests/002_community.sql` (pgTAP; mevcut 001 dosyasının yardımcı desenini izle).
- `scripts/server/seed_synthetic.mjs`: GoTrue `/auth/v1/signup` (anonim, `SUPABASE_ANON_KEY` publishable) ile 8 kullanıcı; her biri için son 30 günde gerçekçi vardiyalar (Sincan/Ankara; platformlar trendyol_go/getir/yemeksepeti/migros_hemen/uber; akşam ve hafta sonu daha yüksek ₺/saat; 3–6 sa); SQL ile `insert … is_synthetic = true`, rastgele 64-hex `text_hash`, `level = 'ocrUnverified'`. Tohumlu rastgele (tekrarlanabilir). `purge_synthetic.mjs`: `delete from shifts where is_synthetic` + bu kullanıcıları `auth.users`'tan siler (sentetik kullanıcıların kimlikleri `user_id in (select user_id from shifts where is_synthetic)` ile; önce kimlikleri topla).
- `supabase/README.md` güncelle.

### Task 2: İstemci + Core modeller + görünüm modeli
- Core `KuryeKazanc/Core/Community/CommunityModels.swift` + test.
- `SupabaseClient` RPC'leri (+ `SupabaseServing` protokolü ve test sahteleri).
- `CommunityViewModel` + testler.

### Task 3: Topluluk sekmesi arayüzü
- `CommunityView` yeniden: davet / ilçe seçici / kartlar / ısı haritası / platformlar / en iyi saatler / yetersiz veri mesajı. Mevcut kişisel ısı haritası görünümünü yeniden kullan (Analiz).

### Task 4: Notlar ve yayın
- `TESTFLIGHT_NOTES.md` 1.4.1 bölümüne Topluluk eklenir (sürüm 1.4.1 kalır, henüz yayınlanmadı), `PROGRESS.md`, PR develop→main (kullanıcı birleştirir), kullanıcıya betik komutları.
