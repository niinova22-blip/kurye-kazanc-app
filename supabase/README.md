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
