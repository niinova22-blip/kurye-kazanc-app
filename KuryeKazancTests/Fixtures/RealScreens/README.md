# Gercek ekran ornekleri

`<platform>/<ad>.png` + ayni adli `<ad>.json`. JSON, `ScenarioExpectation` bicimindedir:

    {"templateID": "getir.earnings", "total": 980, "bonus": 0, "packages": 11, "duration": null, "period": "day"}

Kisisel bilgiler (ad, telefon, IBAN, TC kimlik, adres) gorselde KARARTILMIS olmali; aksi halde repoya eklenmez.

## Taban yeniden olcumu

Taklit ekran tabani (`../scenario-baseline.json`, anahtar `<sablonID>/<alan>`) sablon / senaryo degisince yeniden olculur:
`.github/workflows/ios-ci.yml` "Birim testleri" adimina GECICI olarak `export TEST_RUNNER_SCENARIO_REMEASURE=1` ekle,
bir kosu yap, "Senaryo raporu" ozetindeki JSON'u `scenario-baseline.json` olarak kaydet, satiri geri kaldir.
Taban dosyasi eksik/bozuksa test (yeniden olcum disinda) basarisiz olur.
