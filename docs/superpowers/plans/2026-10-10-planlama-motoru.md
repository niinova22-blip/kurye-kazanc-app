# Planlama motoru — uygulama planı

**Spec:** `docs/superpowers/specs/2026-10-10-planlama-motoru-design.md` · Araştırma: `docs/research/2026-10-10-platform-kurallari.md`
**Yürütme:** yerel (native), her görev ayrı commit, PUSH YOK (kullanıcı: tek derleme sonda). Son adımda bütün dal için tek inceleme.

## Global kısıtlar
- Core saf Swift, `KuryeKazanc/Core/Planner/`; testler `KuryeKazancTests/Core/`, `swift test` (Windows).
- Tarihler kurallarda `yyyy-MM-dd` metni (Postgres `date`); hafta günü 1 = Pazartesi … 7 = Pazar (mevcut `HourSlot` ile aynı).
- Tarife uydurulmaz: tahmin yalnızca kullanıcı kayıtlarından veya kullanıcının girdiği platform ücretinden.
- Doğrulanmamış / tartışmalı / eski (son kontrol > 90 gün, geçerlilik bitmiş) kural plana etkiliyorsa plan **kesin değil** (`isConfirmed = false`) ve belirsizlik yazılır. Kısıt olarak yalnızca doğrulanmış veya kullanıcının "sözleşmemde var" dediği kurallar uygulanır.
- Sunucu göçü ve betikler yazılır, ÇALIŞTIRILMAZ (canlı veritabanı: kullanıcı `!` ile).
- Arayüz metinleri Türkçe.

## Review focus
1. Kural seti boş / sunucuya hiç ulaşılamadı → gömülü yedek; yedek de eskiyse plan kesin değil.
2. Hiç kaydı olmayan kullanıcı → "veri yetersiz", sayı uydurulmaz.
3. Gece yarısını aşan uygunluk aralığı → gün içinde 24:00'te kesilir, çökmez.
4. Rezerve slotlar azami saati aşıyor / çakışıyor → geçersiz plan gerekçesi.
5. Kurallar değişince kayıtlı plan yeniden doğrulanır ve kullanıcıya gösterilir.

## Görevler
1. **Kural modeli** — `PlatformRule.swift`: `RuleCategory, RuleKind, RuleSourceKind, RuleStatus, CourierModel, RuleParams, PlatformRule` (Codable, snake_case anahtarlar), `effectiveStatus(today:)`, `applies(model:region:today:)`, `RuleSet` (sürüm özeti, platform için geçerli kurallar, kullanıcı onayları). Testler: stale (90 gün), validTo geçmiş, bölge/model eşleşmesi, kullanıcı reddi, sürüm özeti değişimi, JSON çözme.
2. **Çalışma profili** — `WorkProfile.swift`: `TimeRange, PlatformProfile, ReservedBlock, WorkProfile` (Codable, varsayılanlar). Test: JSON gidiş-dönüş, uygunluk sorgusu.
3. **Tahmin** — `EarningsForecaster.swift`: hafta günü+saat → saat → platform → kullanıcı ücreti; ≥3 örnek, 8 hafta; p25/p50/p75; km/saat, paket/saat. Testler: kademeler, örnek yetersizliği, eski kayıtlar dışarıda, yüzdelikler.
4. **Kısıt denetimi** — `PlanValidator.swift`: `PlanBlock, PlanIssue` (+ Türkçe mesaj), `validate`, `uncertainties`. Testler: çakışma, yetkisiz platform, uygunluk dışı, geçiş süresi, azami saat, slot gereken platformda rezerv yok, vardiya dışı, adım uyumsuzluğu, münhasırlık, rezerve slot planda yok (iptal kuralı notu), doğrulanmamış kural belirsizliği, haftalık yükümlülük notu.
5. **Öneri ve tahmini sonuç** — `PlanEngine.swift`: dinamik programlama, üç öneri, `PlanEstimate` (brüt düşük/orta/yüksek, km gideri, vergi, sabit gider, net, vergi sonrası, net/saat, km, paket, güven), gerekçe/belirsizlik, `SavedPlan` ve `revalidate`. Testler: en kârlı platform seçimi, geçiş süresi düşümü, düşük riskli/az saatli farkları, veri yok → öneri yok, gider/vergi ayrımı, kural değişince yeniden doğrulama, eski kural → kesin değil.
6. **Sunucu** — göç `20261010000004_platform_rules.sql` (`platform_rules`, `rule_source_checks`, RLS: herkes okur, yazma yalnızca service role), pgTAP testi, `scripts/server/seed_platform_rules.mjs` (araştırmadaki başlangıç kuralları), `check_sources.mjs`, `approve_rule.mjs`, README.
7. **Uygulama** — `SupabaseClient.fetchPlatformRules`, `RuleStore` (12 sa yenileme, dosya önbelleği, gömülü yedek `BundledRules`), `WorkProfileStore`, `PlannerViewModel`, `PlannerView` (Bugün'de "Plan öner"), `WorkProfileView` (Profil > Çalışma profili). CI testleri: `PlannerViewModelTests`, `RuleStoreTests`.
8. **Sürüm 1.5.0**, notlar, PROGRESS; son inceleme; tek push → Codemagic.
