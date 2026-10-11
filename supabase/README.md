# Kurye Kazanc - Supabase sunucusu (surum 1.3)

## Kurulum

1. Supabase projesi olusturun (bolge: eu-central-1).
2. Authentication > Sign In / Providers:
   - Anonymous sign-ins: acik.
   - Apple saglayici: acik, Client IDs: `com.kuryekazanc.app`.
   - E-posta saglayici: kapali.
3. Ortam degiskenlerini ayarlayin (degerleri repoya ASLA eklemeyin):
   - `SUPABASE_ACCESS_TOKEN` (kisisel erisim anahtari)
   - `SUPABASE_PROJECT_REF`
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

## Calistirma sirasi (repo kokunden)

```
node scripts/server/apply.mjs           # gocleri sirayla, bir kez uygular
node scripts/server/seed_templates.mjs  # gomulu sablonlari ocr_templates'e yazar
node scripts/server/test.mjs            # pgTAP testleri (basarisizlikta cikis kodu 1)
node scripts/server/e2e.mjs             # anon anahtarla uctan uca kontrol
node scripts/server/seed_synthetic.mjs  # 1.4b: Sincan/Ankara sentetik test kuryeleri (10 kurye, 30 gun)
node scripts/server/purge_synthetic.mjs # sentetik vardiyalari ve kullanicilari siler
node scripts/server/seed_platform_rules.mjs # 1.5: gomulu planlama kurallarini platform_rules'a yazar (var olani ezmez)
node scripts/server/check_sources.mjs   # kural kaynaklarini indirir, degisenleri incelemeye alir (kurali DEGISTIRMEZ)
node scripts/server/approve_rule.mjs --list   # yonetici: bekleyen kontroller; --rule/--recheck/--ignore ile onay
```

Planlama kurallari: kaynak degisikligi otomatik kabul edilmez. `check_sources.mjs` (ayda bir onerilir) degisen
kaynagi `pending` yazar; yonetici kaynagi okuyup `approve_rule.mjs --rule <id> --set ...` ile yeni surum ekler.
90 gunden uzun suredir kontrol edilmeyen kural uygulamada "guncelligi bilinmiyor" sayilir ve plan kesin gosterilmez.

Sira: `apply` -> `test` -> `seed_synthetic`. `seed_synthetic.mjs` sentetik satir varsa durur.
`purge_synthetic.mjs` gercek yayindan (topluluk ozelligi herkese acilmadan) once calistirilmalidir.

## Notlar

- `shifts` ve `calibration_samples` tablolarina dogrudan erisim yoktur; yazma `submit_shift`
  ve `submit_calibration` fonksiyonlariyla yapilir.
- Gunluk hiz siniri (vardiya 40, kalibrasyon 20) gunu UTC'ye gore sayar.
- `e2e.mjs` her calistirmada bir anonim auth kullanicisi birakir (silinmez).
- `test.mjs` bitince `tests` semasini siler.
- Gizli degerler (erisim anahtari, anon anahtar, service role) yalnizca ortam degiskeninde tutulur.
- Ekran tipli sablonlar (`layout: list/orderCard`, 1.4a) 1.3 istemcisini bozar (`layout`'u tanimaz, ozet ekran gibi okur):
  `seed_templates.mjs` bunlari atlar ("atlandi: ..." yazar); 1.3 emekli olana kadar yalnizca uygulamaya gomulu kalirlar.
  `layout`'u olmayan / `summary` olan sablonlar (or. yemeksepeti.earnings v2) sunucuya yazilabilir.

## Topluluk (1.4b)

- `20261010000003_community.sql`: `shifts.is_synthetic` (varsayilan false; `submit_shift` yazmaz), `community_heatmap(province, district)`
  ve `community_summary(province, district)`. Ikisi de `jsonb` doner, yalnizca `authenticated` (anonim oturum dahil) calistirabilir.
- k-anonimlik: hucre / toplam / platform satiri, en az 5 FARKLI kurye yoksa donmez. Pencere: `created_at` son 56 gun.
- `community_heatmap`: `[{weekday (1=Pzt..7=Paz), hour (0-23), per_hour, couriers, shifts}]`, bos ise `[]`.
- `community_summary`: `{per_hour?, couriers?, platforms:[{code, per_hour, per_package, couriers}], best:[3 hucre]}`;
  `per_hour`/`couriers` yalnizca ilcede >= 5 kurye varsa bulunur.
- Il/ilce eslesmesi buyuk/kucuk harf duyarsizdir (`Ankara` / `Sincan` yazilir).
- Sentetik kuryeler gercek verilerle karisir (k-anonimlige katkida bulunurlar); gercek yayindan once `purge_synthetic.mjs`.

## Hakedis tarifeleri ve tarife takibi (1.6)

Goc: `20261011000005_tariffs.sql`. Ilke: kaynakta gorulen degisiklik tarifeyi kendiliginden degistirmez
(kontrol -> aday -> dogrulama/onay -> yayim). Istemci yalnizca yayindaki surumleri, kalemlerini ve `tariff_change_events`'i okur.

```
node --env-file=.env.supabase scripts/server/apply.mjs          # goc
node --env-file=.env.supabase scripts/server/test.mjs           # pgTAP (004_tariffs dahil)
node --env-file=.env.supabase scripts/server/seed_tariffs.mjs   # ORNEK tarifeler ("dogrulama gerekli") + izlenecek kaynaklar
node --env-file=.env.supabase scripts/server/tariff_check.mjs   # zamani gelen kaynaklar + gunluk bakim (--all, --platform, --source)
node --env-file=.env.supabase scripts/server/tariff_center.mjs --admin "Ad Soyad"   # Tarife Merkezi (yalnizca 127.0.0.1)
```

- Yerel testler (kimlik bilgisi gerekmez, gercek Postgres = PGlite): `cd scripts/server && npm install && npm test`.
- Demo panel (bellekte veritabani, ag istegi yok): `cd scripts/server && node tariff/demo_center.mjs`.
- Zamanlama: `.github/workflows/tariff-check.yml` her gun 07:30 (Ubuntu, ~1 dk). Gizli degerler: `SUPABASE_PROJECT_REF`,
  `SUPABASE_ACCESS_TOKEN`. Tanimli degilse calisma atlanir. Kaynak basina siklik `tariff_sources.check_interval_minutes`.
- Ayarlar `tariff_config`: `auto_publish_official` (varsayilan **false**), `min_ocr_confidence` 0.9, `large_change_pct` 25,
  `per_host_delay_ms` 5000, `candidate_expiry_days` 60. Otomatik yayim yalnizca ayar acikken, tek ve guvenilir resmi kaynak,
  kesin yururluk tarihi ve baska belirsizlik yokken olur.
- Kaynaklar robots.txt'ye uyularak, giris gerektirmeyen herkese acik sayfalardan okunur. Alan cikarim profili
  (`extraction_profile`) olmayan kaynak yalnizca "sayfa degisti, dogrulama gerekli" uretir.
- Yayim/geri cekme `publish_tariff_candidate` / `withdraw_tariff_candidate` / `withdraw_tariff_version` ile tek islemde;
  ayni aday iki kez yayimlanmaz. Her karar `tariff_audit_log`'a yonetici adiyla yazilir.
