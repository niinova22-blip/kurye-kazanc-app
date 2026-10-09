# Akıllı çalışma planlama motoru — mimari analiz ve tasarım

Tarih: 2026-10-10. Kullanıcı isteği iki metin (hafıza `next-planner-module`); araştırma `docs/research/2026-10-10-platform-kurallari.md`. Kullanıcı: "bütün geliştirmeleri yap, en son build et" — iş yerelde, tek derleme sonda.

## 1. Mimari analiz (mevcut yapıya oturtma)
- **Core (saf Swift, Windows'ta test):** kural modeli, çalışma profili, kısıt denetimi, plan üretimi, tahmin.
- **Sunucu:** `platform_rules` (herkese okunur, sürümlü, kaynaklı), `rule_source_checks` (kaynak değişikliği kayıtları; kural otomatik değişmez). Betikler: `seed_platform_rules.mjs` (araştırmadaki başlangıç kuralları), `check_sources.mjs` (kaynakları indirir, içerik özetini karşılaştırır, değişikliği "beklemede" yazar), `approve_rule.mjs` (yönetici onayıyla yeni kural sürümü / durum değişikliği).
- **Uygulama:** `RuleStore` (sunucudan + gömülü yedek, şablon akışı gibi), `WorkProfile` (kullanıcı verisi, kurallardan ayrı; JSON, Application Support), `PlannerViewModel`; arayüz: Bugün'de "Plan öner", Profil > "Çalışma profili".
- **Veri:** kullanıcının kayıtları (platform × hafta günü × saat ₺/saat, km/saat, paket/saat), Topluluk ısı haritası (yalnızca yoğunluk sinyali), gider ayarları.

## 2. Kural modeli
`PlatformRule`: id, platformCode, category (`workModel, account, slotSystem, minHours, cancellation, region, pay, exclusivity, other`), kind (`slotRequired, slotGranularityMinutes, slotCancelNoticeHours, peakWeeklyHours (params: from,to,hours), minDailyHours, shiftBased, exclusiveSameTime, exclusiveSameDay, info`), params, description, sourceURL, sourceKind (`official, secondary, user`), publishedAt, lastCheckedAt, validFrom, validTo, status (`verified, unverified, disputed, stale`), confidence (0–1), courierModel (`esnaf, intermediary, payroll, any`), region (nil = her yer), version, previousID.
- Kullanıcı kendi sözleşmesinden kural ekleyebilir veya bir kuralı "benim sözleşmemde geçerli / geçersiz" diye işaretleyebilir (yerelde; `sourceKind = user`).
- `stale`: `lastCheckedAt` > 90 gün veya `validTo` geçmiş.

## 3. Çalışma profili
Platformlar: hesap aktif mi, kurye modeli; kendi motoru; şahıs şirketi; bölge (il/ilçe); hafta günü başına uygun aralıklar; rezerve slot/vardiyalar (tarih, başlangıç–bitiş, platform); platformun sunduğu ücret (opsiyonel, kullanıcı kaynağı); giderler: km başı maliyet (mevcut ayar), vergi oranı %, aylık Bağ-Kur/SGK, diğer aylık sabit; günlük net hedef; azami saat; platform değiştirme süresi (vars. 20 dk).

## 4. Kısıt motoru
- Plan = bloklar `[platform, başlangıç, bitiş]`.
- Kurallar: platform aktif; blok uygun saatte; toplam ≤ azami saat; çakışma yok; farklı platforma geçişte ≥ değiştirme süresi; rezerve slot/vardiyalar aynen planda; `slotRequired` doğrulanmış/kabul edilmişse o platformda yalnızca rezerve slotlarda çalışılır (rezerv yoksa platform o gün plana girmez, gerekçe); `shiftBased` → yalnızca girilen vardiya; `slotGranularityMinutes` blok sınırları; `exclusiveSameDay/Time` ihlali geçersiz.
- Haftalık kurallar (`peakWeeklyHours`) günlük planı geçersiz kılmaz: haftalık ilerleme uyarısı + ilgili saatlere öncelik notu.
- **Belirsizlik:** plana etkiyen kural `verified` değilse (ve kullanıcı onaylamadıysa) plan "uygunluk doğrulanmadı" işareti ve maddeler halinde gerekçe alır. `stale` da öyle.

## 5. Tahmin
- Geçmişten platform × hafta günü × saat saatlik brüt (son 8 hafta, ≥3 örnek) → yoksa platform × saat → platform geneli → yoksa "veri yetersiz" (tahmin yok).
- Senaryolar: p25/p50/p75; tek örnekte aralık geniş, güven düşük.
- Giderler: km (kullanıcı km/saat × saat) × km başı maliyet; vergi = brüt × oran; Bağ-Kur/sabit = aylık / 26. Brüt, giderler, net (vergi öncesi) ve vergi sonrası ayrı.
- Güven: veri miktarı + kural durumu (yüksek/orta/düşük) + açıklama.
- Topluluk yoğunluğu yalnızca sıralamada küçük ağırlık ve "ilçede yoğun saat" notu; ücret değil.

## 6. Öneri
- Saat dilimleri (1 sa; kural varsa slot adımı) üzerinde dinamik programlama: her dilim için platform veya boş; geçiş süresi ve azami saat kısıtı.
- Üç öneri: **en kârlı** (orta senaryo net), **düşük riskli** (düşük senaryo neti, yalnızca güveni yeterli dilimler), **daha az saat** (azami saatin %60'ı, en yüksek net/saat).
- Her öneride bloklar, toplam saat, brüt, giderler (yakıt/bakım, vergi, Bağ-Kur/sabit), net, net/saat, km, teslimat, düşük–yüksek aralık, güven, "neden", belirsizlikler.
- Plan, kural kümesi sürümünü saklar; kurallar değişince yeniden doğrulanır.

## 7. Testler
Kural çakışması, stale kaynak, eksik veri, rezerve slot çakışması, slot gereken platformda rezerv yokluğu, yetkisiz platform, geçiş süresi, azami saat, doğrulanmamış kural işareti, senaryo/gider/vergi ayrımı, geçersiz plan gerekçeleri, kural sürümü değişince yeniden doğrulama.

## 8. Kapsam dışı
Platform uygulamalarına bağlanma / otomatik slot rezervasyonu; yönetici web paneli (SQL/betik onayı); gerçek zamanlı yoğunluk.
