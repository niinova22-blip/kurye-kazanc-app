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
```

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
