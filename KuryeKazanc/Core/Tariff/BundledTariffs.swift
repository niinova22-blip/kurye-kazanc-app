import Foundation

/// Baslangic / ORNEK tarife kayitlari. Dogrulanmis guncel tarife DEGILDIR: tum kalemler "doğrulama gerekli",
/// surumler "doğrulanmamış" etiketlidir. Amaci sunucuya ulasilamadiginda hesaplamanin calismasidir;
/// sunucu ayni platform icin surum yayimladiginda bu kayitlar kullanilmaz (TariffCatalog.merged).
///
/// Ayni JSON `scripts/server/seed_tariffs.mjs` ile sunucuya tohumlanir (tek kaynak).
/// 1.9: yalnizca iki firma — Yemeksepeti Express ve Paket Taxi (Restoran, Migros, Migros Hemen). Eski surumler gecmis
/// kayitlarin kendi surumuyle gosterimi icin durur.
enum BundledTariffs {
    /// Bir kez cozulur (her erisimde JSON cozmek gorunum govdelerinde pahaliydi).
    static let all: [TariffVersion] = {
        guard let data = json.data(using: .utf8),
              let versions = try? JSONDecoder().decode([TariffVersion].self, from: data) else { return [] }
        return versions.map { version in
            var copy = version
            copy.origin = .bundled
            return copy
        }
    }()

    static let json: String = #"""
    [
      {
        "tariff_version_id": "yemeksepeti-esnaf-v1",
        "platform_id": "yemeksepeti",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 1,
        "revision": 0,
        "effective_from": "2026-01-01",
        "created_at": "2026-10-11",
        "source_type": "seed",
        "verification_status": "unverified",
        "approval_status": "published",
        "approved_at": "2026-10-11",
        "approved_by": "seed",
        "change_summary": "Başlangıç / örnek tarife. Değerler bölgeye göre değişir, doğrulanmadı.",
        "settings": {
          "confidence": {}
        },
        "items": [
          {
            "tariff_item_id": "ys-v1-package-single",
            "tariff_version_id": "yemeksepeti-esnaf-v1",
            "item_key": "package.single",
            "item_type": "single_package",
            "label": "Tekli paket",
            "amount": "75.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Yaklaşık (~75 TL)."
          },
          {
            "tariff_item_id": "ys-v1-package-combined",
            "tariff_version_id": "yemeksepeti-esnaf-v1",
            "item_key": "package.combined",
            "item_type": "combined_package",
            "label": "Birleşen ikinci paket",
            "amount": "30.00",
            "amount_upper": "40.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Bölgeye göre 30–40 TL."
          },
          {
            "tariff_item_id": "ys-v1-guarantee",
            "tariff_version_id": "yemeksepeti-esnaf-v1",
            "item_key": "guarantee.hourly",
            "item_type": "hourly",
            "label": "Saatlik garanti",
            "amount": "300.00",
            "unit": "hour",
            "calculation_method": "guarantee_top_up",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Kural doğrulanmadı: doğrulanana kadar fark ödemesi hesaba katılmaz."
          },
          {
            "tariff_item_id": "ys-v1-referral",
            "tariff_version_id": "yemeksepeti-esnaf-v1",
            "item_key": "referral",
            "item_type": "referral_bonus",
            "label": "Referans bonusu",
            "amount": "0",
            "unit": "flat",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "requires_flag": "referral"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Tutar ve koşullar kampanyaya göre; kullanıcı girer."
          }
        ]
      },
      {
        "tariff_version_id": "migros_hemen-esnaf-v1",
        "platform_id": "migros_hemen",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 1,
        "revision": 0,
        "effective_from": "2026-01-01",
        "created_at": "2026-10-11",
        "source_type": "seed",
        "verification_status": "unverified",
        "approval_status": "published",
        "approved_at": "2026-10-11",
        "approved_by": "seed",
        "change_summary": "Başlangıç / örnek tarife. Bölge ve kıdem tarifesinin ilişkisi doğrulanmadı.",
        "settings": {
          "fixed_pay_basis": "region",
          "threshold_application": "all_units",
          "fixed_covers_packages": null,
          "confidence": {}
        },
        "items": [
          {
            "tariff_item_id": "pt-v1-fixed-plus",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "fixed.region.plus",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (İstanbul Plus / Ankara Plus)",
            "amount": "65223.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "plus"
            },
            "stacking_rule": "exclusive_group",
            "item_group": "fixed_region",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Örnek, doğrulanmamış."
          },
          {
            "tariff_item_id": "pt-v1-fixed-standard",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "fixed.region.standard",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (standart bölge)",
            "amount": "53223.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "standard"
            },
            "stacking_rule": "exclusive_group",
            "item_group": "fixed_region",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Örnek, doğrulanmamış."
          },
          {
            "tariff_item_id": "pt-v1-seniority-0",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "fixed.seniority.0",
            "item_type": "fixed",
            "label": "Kıdem tarifesi: yeni başlayan",
            "amount": "36500.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "min_seniority_years": 0,
              "max_seniority_years": 2
            },
            "stacking_rule": "exclusive_group",
            "item_group": "fixed_seniority",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-seniority-2",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "fixed.seniority.2",
            "item_type": "fixed",
            "label": "Kıdem tarifesi: 2 yıl",
            "amount": "38000.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "min_seniority_years": 2,
              "max_seniority_years": 3
            },
            "stacking_rule": "exclusive_group",
            "item_group": "fixed_seniority",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-seniority-3",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "fixed.seniority.3",
            "item_type": "fixed",
            "label": "Kıdem tarifesi: 3 yıl",
            "amount": "38500.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "min_seniority_years": 3
            },
            "stacking_rule": "exclusive_group",
            "item_group": "fixed_seniority",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-perf-0",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "package.performance.0",
            "item_type": "single_package",
            "label": "Paket başı performans ücreti",
            "amount": "38.00",
            "unit": "package",
            "lower_threshold": "0",
            "calculation_method": "tier_rate",
            "stacking_rule": "exclusive_group",
            "item_group": "performance",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-perf-1100",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "package.performance.1100",
            "item_type": "single_package",
            "label": "Paket başı 1.100+",
            "amount": "40.00",
            "unit": "package",
            "lower_threshold": "1100",
            "calculation_method": "tier_rate",
            "stacking_rule": "exclusive_group",
            "item_group": "performance",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-perf-1300",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "package.performance.1300",
            "item_type": "single_package",
            "label": "Paket başı 1.300+",
            "amount": "42.00",
            "unit": "package",
            "lower_threshold": "1300",
            "calculation_method": "tier_rate",
            "stacking_rule": "exclusive_group",
            "item_group": "performance",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-perf-1500",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "package.performance.1500",
            "item_type": "single_package",
            "label": "Paket başı 1.500+",
            "amount": "44.00",
            "unit": "package",
            "lower_threshold": "1500",
            "calculation_method": "tier_rate",
            "stacking_rule": "exclusive_group",
            "item_group": "performance",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-perf-1700",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "package.performance.1700",
            "item_type": "single_package",
            "label": "Paket başı 1.700+",
            "amount": "46.00",
            "unit": "package",
            "lower_threshold": "1700",
            "calculation_method": "tier_rate",
            "stacking_rule": "exclusive_group",
            "item_group": "performance",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v1-shopping-card",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "side.shopping_card",
            "item_type": "in_kind_support",
            "label": "Alışveriş kartı",
            "amount": "500.00",
            "unit": "month",
            "calculation_method": "flat",
            "confidence_status": "needs_verification",
            "is_cash": false,
            "note": "Ayni destek; nakit hakedişe eklenmez."
          },
          {
            "tariff_item_id": "pt-v1-woman-support",
            "tariff_version_id": "migros_hemen-esnaf-v1",
            "item_key": "side.woman_employment",
            "item_type": "in_kind_support",
            "label": "Kadın istihdam desteği",
            "amount": "2000.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "requires_flag": "woman_employment"
            },
            "confidence_status": "needs_verification",
            "is_cash": false,
            "note": "Ayrı gösterilir; toplam hakedişe eklenmez."
          }
        ]
      },
      {
        "tariff_version_id": "yemeksepeti-esnaf-v2",
        "platform_id": "yemeksepeti",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 2,
        "revision": 0,
        "effective_from": "2026-01-12",
        "effective_until": null,
        "created_at": "2026-10-13",
        "source_type": "news",
        "verification_status": "unverified",
        "approval_status": "published",
        "approved_at": "2026-10-13",
        "approved_by": "seed",
        "change_summary": "2026 tarifesi (12 Ocak zammı sonrası). Kaynak: eleman.net, 13.01.2026. Paket ücreti saate ve güne göre değişir; tablo Ankara/İzmir içindir. Pazar 17:00–23:59 paket başı +15 TL ve özel gün ekleri hesaba katılmaz.",
        "settings": {
          "bonus_stacking": "highest_only",
          "confidence": {}
        },
        "items": [
          {
            "tariff_item_id": "ys-v2-package-day",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "package.day",
            "item_type": "single_package",
            "label": "Paket ücreti (08:00–17:59)",
            "amount": "59.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "amount_upper": "73.00",
            "eligibility_conditions": {
              "time_band": "day"
            },
            "note": "Ankara/İzmir tablosu: hafta içi 59, Cuma 61,5, Cumartesi 56–63, Pazar 64,5–73 TL. 00:00–07:59 arası 55–60,5 TL.",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "ys-v2-package-evening",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "package.night",
            "item_type": "single_package",
            "label": "Paket ücreti (18:00–23:59)",
            "amount": "67.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "amount_upper": "78.50",
            "eligibility_conditions": {
              "time_band": "night"
            },
            "note": "Hafta içi 67,5–70,5, Cuma 67,5–73,5, Cumartesi 67,5–73,5, Pazar 74,5–78,5 TL. Kilit paket (21:00–23:59) 33,5 TL.",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "ys-v2-km",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "km",
            "item_type": "per_km",
            "label": "Km ücreti",
            "amount": "3.70",
            "unit": "km",
            "calculation_method": "per_unit",
            "note": "3,2 TL'den 3,7 TL'ye güncellendi.",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "ys-v2-daily-17",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.17",
            "item_type": "daily_bonus",
            "label": "Günlük 17–19 paket bonusu",
            "amount": "120.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "17",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "19"
          },
          {
            "tariff_item_id": "ys-v2-daily-20",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–22 paket bonusu",
            "amount": "150.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "22"
          },
          {
            "tariff_item_id": "ys-v2-daily-23",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.23",
            "item_type": "daily_bonus",
            "label": "Günlük 23–25 paket bonusu",
            "amount": "200.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "23",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "25"
          },
          {
            "tariff_item_id": "ys-v2-daily-26",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.26",
            "item_type": "daily_bonus",
            "label": "Günlük 26–28 paket bonusu",
            "amount": "250.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "26",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "28"
          },
          {
            "tariff_item_id": "ys-v2-daily-29",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.29",
            "item_type": "daily_bonus",
            "label": "Günlük 29–31 paket bonusu",
            "amount": "350.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "29",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "31"
          },
          {
            "tariff_item_id": "ys-v2-daily-32",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.32",
            "item_type": "daily_bonus",
            "label": "Günlük 32–34 paket bonusu",
            "amount": "500.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "32",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "34"
          },
          {
            "tariff_item_id": "ys-v2-daily-35",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.35",
            "item_type": "daily_bonus",
            "label": "Günlük 35–39 paket bonusu",
            "amount": "550.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "35",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "39"
          },
          {
            "tariff_item_id": "ys-v2-daily-40",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.40",
            "item_type": "daily_bonus",
            "label": "Günlük 40–44 paket bonusu",
            "amount": "600.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "40",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "44"
          },
          {
            "tariff_item_id": "ys-v2-daily-45",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.45",
            "item_type": "daily_bonus",
            "label": "Günlük 45–49 paket bonusu",
            "amount": "700.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "45",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "49"
          },
          {
            "tariff_item_id": "ys-v2-daily-50",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.50",
            "item_type": "daily_bonus",
            "label": "Günlük 50–54 paket bonusu",
            "amount": "800.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "50",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "54"
          },
          {
            "tariff_item_id": "ys-v2-daily-55",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–59 paket bonusu",
            "amount": "900.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "59"
          },
          {
            "tariff_item_id": "ys-v2-daily-60",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.daily.60",
            "item_type": "daily_bonus",
            "label": "Günlük 60+ paket bonusu",
            "amount": "1000.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "60",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "ys-v2-weekly-160",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.160",
            "item_type": "weekly_bonus",
            "label": "Haftalık 160–179 paket bonusu",
            "amount": "1500.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "160",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "179",
            "note": "Yalnızca Ankara ve İzmir. Kaynakta 180–189 paket aralığı yok; uydurulmadı."
          },
          {
            "tariff_item_id": "ys-v2-weekly-190",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.190",
            "item_type": "weekly_bonus",
            "label": "Haftalık 190–199 paket bonusu",
            "amount": "2000.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "190",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "199"
          },
          {
            "tariff_item_id": "ys-v2-weekly-200",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.200",
            "item_type": "weekly_bonus",
            "label": "Haftalık 200–219 paket bonusu",
            "amount": "2750.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "200",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "219"
          },
          {
            "tariff_item_id": "ys-v2-weekly-220",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.220",
            "item_type": "weekly_bonus",
            "label": "Haftalık 220–259 paket bonusu",
            "amount": "3500.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "220",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "259"
          },
          {
            "tariff_item_id": "ys-v2-weekly-260",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.260",
            "item_type": "weekly_bonus",
            "label": "Haftalık 260–299 paket bonusu",
            "amount": "4000.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "260",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "299"
          },
          {
            "tariff_item_id": "ys-v2-weekly-300",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.300",
            "item_type": "weekly_bonus",
            "label": "Haftalık 300–339 paket bonusu",
            "amount": "5000.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "300",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "339"
          },
          {
            "tariff_item_id": "ys-v2-weekly-340",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.340",
            "item_type": "weekly_bonus",
            "label": "Haftalık 340–379 paket bonusu",
            "amount": "5700.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "340",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "379"
          },
          {
            "tariff_item_id": "ys-v2-weekly-380",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.380",
            "item_type": "weekly_bonus",
            "label": "Haftalık 380–419 paket bonusu",
            "amount": "6700.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "380",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true,
            "upper_threshold": "419"
          },
          {
            "tariff_item_id": "ys-v2-weekly-420",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "bonus.weekly.420",
            "item_type": "weekly_bonus",
            "label": "Haftalık 420+ paket bonusu",
            "amount": "8000.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "420",
            "stacking_rule": "exclusive_group",
            "item_group": "weekly_bonus",
            "eligibility_conditions": {
              "requires_flag": "ys_ankara_izmir"
            },
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "ys-v2-referral",
            "tariff_version_id": "yemeksepeti-esnaf-v2",
            "item_key": "referral",
            "item_type": "referral_bonus",
            "label": "Arkadaşını öner bonusu",
            "amount": "0",
            "unit": "flat",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "requires_flag": "referral"
            },
            "note": "Önerdiğin kurye 100 paket: 500 TL, 500 paket: 2.500 TL, 1.000 paket: 4.000 TL (İstanbul, Ankara, İzmir, Muğla). Tutarı sen gir.",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true
          }
        ]
      },
      {
        "tariff_version_id": "migros_hemen-esnaf-v2",
        "platform_id": "migros_hemen",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 2,
        "revision": 0,
        "effective_from": "2026-01-01",
        "effective_until": null,
        "created_at": "2026-10-13",
        "source_type": "official_announcement",
        "verification_status": "partial",
        "approval_status": "published",
        "approved_at": "2026-10-13",
        "approved_by": "seed",
        "change_summary": "Paket Taxi'nin kendi sitesindeki 2026 ücretleri (%34,69 artış): bölgeye göre sabit ücret, aylık paket bonusu, teslimat başı mesafe ek ödemesi. Ayrı paket başı ücret yok. Ara bonus kademeleri yayımlanmadı.",
        "settings": {
          "fixed_pay_basis": "region",
          "bonus_stacking": "highest_only",
          "confidence": {
            "fixed_pay_basis": "verified",
            "bonus_stacking": "verified"
          }
        },
        "items": [
          {
            "tariff_item_id": "pt-v2-fixed-plus",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "fixed.region.plus",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (İstanbul Plus / Ankara Plus)",
            "amount": "65223.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "plus"
            },
            "stacking_rule": "exclusive_group",
            "item_group": "fixed_region",
            "confidence_status": "verified",
            "note": "Paket Taxi'nin kendi sitesinde yayımlanan tutar.",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v2-fixed-standard",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "fixed.region.standard",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (diğer bölgeler)",
            "amount": "53223.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "standard"
            },
            "stacking_rule": "exclusive_group",
            "item_group": "fixed_region",
            "confidence_status": "verified",
            "note": "Paket Taxi'nin kendi sitesinde yayımlanan tutar.",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v2-bonus-700",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "bonus.monthly.700",
            "item_type": "monthly_bonus",
            "label": "Aylık 700 paket bonusu",
            "amount": "12000.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "700",
            "upper_threshold": "1699",
            "stacking_rule": "exclusive_group",
            "item_group": "monthly_bonus",
            "note": "701–1.699 arasındaki ara kademeler yayımlanmadı; bu aralıkta en az 12.000 TL sayılır, gerçek bonusun daha yüksek olabilir.",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v2-bonus-1700",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "bonus.monthly.1700",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.700 paket bonusu",
            "amount": "55600.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1700",
            "upper_threshold": "1799",
            "stacking_rule": "exclusive_group",
            "item_group": "monthly_bonus",
            "confidence_status": "verified",
            "note": "Paket Taxi'nin kendi sitesinde yayımlanan tutar.",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v2-bonus-1800",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "bonus.monthly.1800",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.800+ paket bonusu",
            "amount": "66870.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1800",
            "stacking_rule": "exclusive_group",
            "item_group": "monthly_bonus",
            "confidence_status": "verified",
            "note": "Paket Taxi'nin kendi sitesinde yayımlanan tutar.",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v2-distance-4",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "distance.4_6",
            "item_type": "other_payment",
            "label": "Mesafe ek ödemesi (4–6 km)",
            "amount": "25.00",
            "unit": "package",
            "calculation_method": "delivery_band",
            "lower_threshold": "4",
            "upper_threshold": "6",
            "confidence_status": "verified",
            "note": "Teslimat başına. Paket Taxi'nin kendi sitesinde yayımlanan tutar.",
            "stacking_rule": "additive",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v2-distance-6",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "distance.6_plus",
            "item_type": "other_payment",
            "label": "Mesafe ek ödemesi (6 km üzeri)",
            "amount": "35.00",
            "unit": "package",
            "calculation_method": "delivery_band",
            "lower_threshold": "6",
            "confidence_status": "verified",
            "note": "Teslimat başına. Paket Taxi'nin kendi sitesinde yayımlanan tutar.",
            "stacking_rule": "additive",
            "is_cash": true
          },
          {
            "tariff_item_id": "pt-v2-meal",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "side.meal",
            "item_type": "in_kind_support",
            "label": "Öğle yemeği desteği",
            "amount": "0",
            "unit": "flat",
            "calculation_method": "flat",
            "is_cash": false,
            "note": "Tutar yayımlanmadı.",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification"
          },
          {
            "tariff_item_id": "pt-v2-replacement",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "side.replacement_motor",
            "item_type": "in_kind_support",
            "label": "İkame motor desteği",
            "amount": "0",
            "unit": "flat",
            "calculation_method": "flat",
            "is_cash": false,
            "note": "Motorun arızalanınca yedek motor; tutar yok.",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification"
          },
          {
            "tariff_item_id": "pt-v2-woman-support",
            "tariff_version_id": "migros_hemen-esnaf-v2",
            "item_key": "side.woman_employment",
            "item_type": "in_kind_support",
            "label": "Kadın istihdam desteği",
            "amount": "2000.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "requires_flag": "woman_employment"
            },
            "is_cash": false,
            "note": "Kaynak: eleman.net, 26.01.2026. Ayrı gösterilir; firmadan alınan hakedişe eklenmez.",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification"
          }
        ]
      },
      {
        "tariff_version_id": "yemeksepeti-esnaf-v3",
        "platform_id": "yemeksepeti",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 3,
        "revision": 0,
        "effective_from": "2026-01-13",
        "effective_until": null,
        "created_at": "2026-10-14",
        "source_type": "news",
        "verification_status": "partial",
        "approval_status": "published",
        "approved_at": "2026-10-14T00:00:00Z",
        "approved_by": "tarife-ekibi",
        "change_summary": "Gün ve saat bandına göre paket ücreti (Pzt–Per, Cuma, Cumartesi, Pazar), Pazar akşam ve gece +15 TL, km 3,70 TL, günlük bonus; haftalık bonus şehir grubuna göre (resmî site).",
        "settings": {
          "bonus_stacking": "highest_only",
          "confidence": {
            "bonus_stacking": "verified"
          }
        },
        "items": [
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-mon_thu-00",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.mon_thu.00",
            "item_type": "single_package",
            "label": "Paket ücreti (Pzt–Per 00:00–07:59)",
            "amount": "55.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                2,
                3,
                4,
                5
              ],
              "hour_from": 0,
              "hour_to": 8
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-fri-00",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.fri.00",
            "item_type": "single_package",
            "label": "Paket ücreti (Cuma 00:00–07:59)",
            "amount": "55.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                6
              ],
              "hour_from": 0,
              "hour_to": 8
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sat-00",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sat.00",
            "item_type": "single_package",
            "label": "Paket ücreti (Cumartesi 00:00–07:59)",
            "amount": "56.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                7
              ],
              "hour_from": 0,
              "hour_to": 8
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sun-00",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sun.00",
            "item_type": "single_package",
            "label": "Paket ücreti (Pazar 00:00–07:59)",
            "amount": "60.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                1
              ],
              "hour_from": 0,
              "hour_to": 8
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-mon_thu-08",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.mon_thu.08",
            "item_type": "single_package",
            "label": "Paket ücreti (Pzt–Per 08:00–11:59)",
            "amount": "59.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                2,
                3,
                4,
                5
              ],
              "hour_from": 8,
              "hour_to": 12
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-fri-08",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.fri.08",
            "item_type": "single_package",
            "label": "Paket ücreti (Cuma 08:00–11:59)",
            "amount": "61.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                6
              ],
              "hour_from": 8,
              "hour_to": 12
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sat-08",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sat.08",
            "item_type": "single_package",
            "label": "Paket ücreti (Cumartesi 08:00–11:59)",
            "amount": "56.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                7
              ],
              "hour_from": 8,
              "hour_to": 12
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sun-08",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sun.08",
            "item_type": "single_package",
            "label": "Paket ücreti (Pazar 08:00–11:59)",
            "amount": "65.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                1
              ],
              "hour_from": 8,
              "hour_to": 12
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-mon_thu-12",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.mon_thu.12",
            "item_type": "single_package",
            "label": "Paket ücreti (Pzt–Per 12:00–14:59)",
            "amount": "59.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                2,
                3,
                4,
                5
              ],
              "hour_from": 12,
              "hour_to": 15
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-fri-12",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.fri.12",
            "item_type": "single_package",
            "label": "Paket ücreti (Cuma 12:00–14:59)",
            "amount": "61.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                6
              ],
              "hour_from": 12,
              "hour_to": 15
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sat-12",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sat.12",
            "item_type": "single_package",
            "label": "Paket ücreti (Cumartesi 12:00–14:59)",
            "amount": "63.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                7
              ],
              "hour_from": 12,
              "hour_to": 15
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sun-12",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sun.12",
            "item_type": "single_package",
            "label": "Paket ücreti (Pazar 12:00–14:59)",
            "amount": "64.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                1
              ],
              "hour_from": 12,
              "hour_to": 15
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-mon_thu-15",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.mon_thu.15",
            "item_type": "single_package",
            "label": "Paket ücreti (Pzt–Per 15:00–17:59)",
            "amount": "59.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                2,
                3,
                4,
                5
              ],
              "hour_from": 15,
              "hour_to": 18
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-fri-15",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.fri.15",
            "item_type": "single_package",
            "label": "Paket ücreti (Cuma 15:00–17:59)",
            "amount": "61.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                6
              ],
              "hour_from": 15,
              "hour_to": 18
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sat-15",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sat.15",
            "item_type": "single_package",
            "label": "Paket ücreti (Cumartesi 15:00–17:59)",
            "amount": "63.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                7
              ],
              "hour_from": 15,
              "hour_to": 18
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sun-15",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sun.15",
            "item_type": "single_package",
            "label": "Paket ücreti (Pazar 15:00–17:59)",
            "amount": "73.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                1
              ],
              "hour_from": 15,
              "hour_to": 18
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-mon_thu-18",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.mon_thu.18",
            "item_type": "single_package",
            "label": "Paket ücreti (Pzt–Per 18:00–20:59)",
            "amount": "70.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                2,
                3,
                4,
                5
              ],
              "hour_from": 18,
              "hour_to": 21
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-fri-18",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.fri.18",
            "item_type": "single_package",
            "label": "Paket ücreti (Cuma 18:00–20:59)",
            "amount": "73.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                6
              ],
              "hour_from": 18,
              "hour_to": 21
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sat-18",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sat.18",
            "item_type": "single_package",
            "label": "Paket ücreti (Cumartesi 18:00–20:59)",
            "amount": "73.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                7
              ],
              "hour_from": 18,
              "hour_to": 21
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sun-18",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sun.18",
            "item_type": "single_package",
            "label": "Paket ücreti (Pazar 18:00–20:59)",
            "amount": "78.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                1
              ],
              "hour_from": 18,
              "hour_to": 21
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-mon_thu-21",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.mon_thu.21",
            "item_type": "single_package",
            "label": "Paket ücreti (Pzt–Per 21:00–23:59)",
            "amount": "67.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                2,
                3,
                4,
                5
              ],
              "hour_from": 21,
              "hour_to": 24
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-fri-21",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.fri.21",
            "item_type": "single_package",
            "label": "Paket ücreti (Cuma 21:00–23:59)",
            "amount": "67.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                6
              ],
              "hour_from": 21,
              "hour_to": 24
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sat-21",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sat.21",
            "item_type": "single_package",
            "label": "Paket ücreti (Cumartesi 21:00–23:59)",
            "amount": "67.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                7
              ],
              "hour_from": 21,
              "hour_to": 24
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-sun-21",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.sun.21",
            "item_type": "single_package",
            "label": "Paket ücreti (Pazar 21:00–23:59)",
            "amount": "74.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                1
              ],
              "hour_from": 21,
              "hour_to": 24
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: eleman.net, 13.01.2026 (tablo Ankara ve İzmir için yayımlandı; diğer şehirlerde aynı sayılır)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-extra-sunday_evening",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "extra.sunday_evening",
            "item_type": "other_payment",
            "label": "Pazar akşam ek ödemesi (17:00–23:59)",
            "amount": "15.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "weekdays": [
                1
              ],
              "hour_from": 17,
              "hour_to": 24
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Pazar 17:00–23:59 arası her paket +15 TL. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-extra-night",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "extra.night",
            "item_type": "other_payment",
            "label": "Gece ek ödemesi (01:00 sonrası)",
            "amount": "15.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "hour_from": 1,
              "hour_to": 8
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "01:00 sonrası her teslimat +15 TL (08:00'e kadar sayılır). Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-package-lock",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "package.lock",
            "item_type": "other_payment",
            "label": "Kilit paket ücreti (21:00–23:59)",
            "amount": "33.50",
            "unit": "package",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "requires_flag": "ys_kilit_paket"
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kilit paket başına 33,50 TL; kilit paket sayısı ayrı girilmediği için hesaba otomatik eklenmez."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-km",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "km",
            "item_type": "per_km",
            "label": "Km ücreti",
            "amount": "3.70",
            "unit": "km",
            "calculation_method": "per_unit",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Çalışma saati içinde gidilen her km için ödenir. Kaynak: eleman.net, 13.01.2026 (3,20 → 3,70 TL)."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-17",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.17",
            "item_type": "daily_bonus",
            "label": "Günlük 17–19 paket bonusu",
            "amount": "120.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "17",
            "upper_threshold": "19",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-20",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–22 paket bonusu",
            "amount": "150.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "upper_threshold": "22",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-23",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.23",
            "item_type": "daily_bonus",
            "label": "Günlük 23–25 paket bonusu",
            "amount": "200.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "23",
            "upper_threshold": "25",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-26",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.26",
            "item_type": "daily_bonus",
            "label": "Günlük 26–28 paket bonusu",
            "amount": "250.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "26",
            "upper_threshold": "28",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-29",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.29",
            "item_type": "daily_bonus",
            "label": "Günlük 29–31 paket bonusu",
            "amount": "350.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "29",
            "upper_threshold": "31",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-32",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.32",
            "item_type": "daily_bonus",
            "label": "Günlük 32–34 paket bonusu",
            "amount": "500.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "32",
            "upper_threshold": "34",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-35",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.35",
            "item_type": "daily_bonus",
            "label": "Günlük 35–39 paket bonusu",
            "amount": "550.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "35",
            "upper_threshold": "39",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-40",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.40",
            "item_type": "daily_bonus",
            "label": "Günlük 40–44 paket bonusu",
            "amount": "600.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "40",
            "upper_threshold": "44",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-45",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.45",
            "item_type": "daily_bonus",
            "label": "Günlük 45–49 paket bonusu",
            "amount": "700.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "45",
            "upper_threshold": "49",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-50",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.50",
            "item_type": "daily_bonus",
            "label": "Günlük 50–54 paket bonusu",
            "amount": "800.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "50",
            "upper_threshold": "54",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-55",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–59 paket bonusu",
            "amount": "900.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "upper_threshold": "59",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-daily-60",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.daily.60",
            "item_type": "daily_bonus",
            "label": "Günlük 60+ paket bonusu",
            "amount": "1000.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "60",
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm Türkiye. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-160",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.160",
            "item_type": "weekly_bonus",
            "label": "Haftalık 160–179 paket bonusu (İstanbul)",
            "amount": "2250.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "160",
            "upper_threshold": "179",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-180",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.180",
            "item_type": "weekly_bonus",
            "label": "Haftalık 180–199 paket bonusu (İstanbul)",
            "amount": "2850.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "180",
            "upper_threshold": "199",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-200",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.200",
            "item_type": "weekly_bonus",
            "label": "Haftalık 200–219 paket bonusu (İstanbul)",
            "amount": "5250.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "200",
            "upper_threshold": "219",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-220",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.220",
            "item_type": "weekly_bonus",
            "label": "Haftalık 220–254 paket bonusu (İstanbul)",
            "amount": "6570.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "220",
            "upper_threshold": "254",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-255",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.255",
            "item_type": "weekly_bonus",
            "label": "Haftalık 255–289 paket bonusu (İstanbul)",
            "amount": "7775.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "255",
            "upper_threshold": "289",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-290",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.290",
            "item_type": "weekly_bonus",
            "label": "Haftalık 290–324 paket bonusu (İstanbul)",
            "amount": "9000.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "290",
            "upper_threshold": "324",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-325",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.325",
            "item_type": "weekly_bonus",
            "label": "Haftalık 325–359 paket bonusu (İstanbul)",
            "amount": "10150.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "325",
            "upper_threshold": "359",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-360",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.360",
            "item_type": "weekly_bonus",
            "label": "Haftalık 360–399 paket bonusu (İstanbul)",
            "amount": "11500.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "360",
            "upper_threshold": "399",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_istanbul-400",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_istanbul.400",
            "item_type": "weekly_bonus",
            "label": "Haftalık 400+ paket bonusu (İstanbul)",
            "amount": "13200.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "400",
            "eligibility_conditions": {
              "region_tier": "ys_istanbul"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "İstanbul. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-160",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.160",
            "item_type": "weekly_bonus",
            "label": "Haftalık 160–179 paket bonusu (Ankara/İzmir)",
            "amount": "1690.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "160",
            "upper_threshold": "179",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-180",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.180",
            "item_type": "weekly_bonus",
            "label": "Haftalık 180–199 paket bonusu (Ankara/İzmir)",
            "amount": "2275.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "180",
            "upper_threshold": "199",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-200",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.200",
            "item_type": "weekly_bonus",
            "label": "Haftalık 200–219 paket bonusu (Ankara/İzmir)",
            "amount": "3600.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "200",
            "upper_threshold": "219",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-220",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.220",
            "item_type": "weekly_bonus",
            "label": "Haftalık 220–254 paket bonusu (Ankara/İzmir)",
            "amount": "4575.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "220",
            "upper_threshold": "254",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-255",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.255",
            "item_type": "weekly_bonus",
            "label": "Haftalık 255–289 paket bonusu (Ankara/İzmir)",
            "amount": "5220.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "255",
            "upper_threshold": "289",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-290",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.290",
            "item_type": "weekly_bonus",
            "label": "Haftalık 290–324 paket bonusu (Ankara/İzmir)",
            "amount": "6330.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "290",
            "upper_threshold": "324",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-325",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.325",
            "item_type": "weekly_bonus",
            "label": "Haftalık 325–359 paket bonusu (Ankara/İzmir)",
            "amount": "7420.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "325",
            "upper_threshold": "359",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-360",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.360",
            "item_type": "weekly_bonus",
            "label": "Haftalık 360–399 paket bonusu (Ankara/İzmir)",
            "amount": "8700.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "360",
            "upper_threshold": "399",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_ankara_izmir-400",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_ankara_izmir.400",
            "item_type": "weekly_bonus",
            "label": "Haftalık 400+ paket bonusu (Ankara/İzmir)",
            "amount": "10800.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "400",
            "eligibility_conditions": {
              "region_tier": "ys_ankara_izmir"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Ankara/İzmir. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-160",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.160",
            "item_type": "weekly_bonus",
            "label": "Haftalık 160–179 paket bonusu (3. grup iller)",
            "amount": "1130.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "160",
            "upper_threshold": "179",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-180",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.180",
            "item_type": "weekly_bonus",
            "label": "Haftalık 180–199 paket bonusu (3. grup iller)",
            "amount": "1600.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "180",
            "upper_threshold": "199",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-200",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.200",
            "item_type": "weekly_bonus",
            "label": "Haftalık 200–219 paket bonusu (3. grup iller)",
            "amount": "3100.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "200",
            "upper_threshold": "219",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-220",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.220",
            "item_type": "weekly_bonus",
            "label": "Haftalık 220–254 paket bonusu (3. grup iller)",
            "amount": "3850.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "220",
            "upper_threshold": "254",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-255",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.255",
            "item_type": "weekly_bonus",
            "label": "Haftalık 255–289 paket bonusu (3. grup iller)",
            "amount": "4370.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "255",
            "upper_threshold": "289",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-290",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.290",
            "item_type": "weekly_bonus",
            "label": "Haftalık 290–324 paket bonusu (3. grup iller)",
            "amount": "5475.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "290",
            "upper_threshold": "324",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-325",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.325",
            "item_type": "weekly_bonus",
            "label": "Haftalık 325–359 paket bonusu (3. grup iller)",
            "amount": "6350.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "325",
            "upper_threshold": "359",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-360",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.360",
            "item_type": "weekly_bonus",
            "label": "Haftalık 360–399 paket bonusu (3. grup iller)",
            "amount": "6660.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "360",
            "upper_threshold": "399",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_group3-400",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_group3.400",
            "item_type": "weekly_bonus",
            "label": "Haftalık 400+ paket bonusu (3. grup iller)",
            "amount": "8000.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "400",
            "eligibility_conditions": {
              "region_tier": "ys_group3"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kocaeli, Sakarya, Diyarbakır, Malatya, Van, Elazığ, Mardin, Kahramanmaraş, Erzurum. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-160",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.160",
            "item_type": "weekly_bonus",
            "label": "Haftalık 160–179 paket bonusu (diğer iller)",
            "amount": "1125.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "160",
            "upper_threshold": "179",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-180",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.180",
            "item_type": "weekly_bonus",
            "label": "Haftalık 180–199 paket bonusu (diğer iller)",
            "amount": "1590.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "180",
            "upper_threshold": "199",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-200",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.200",
            "item_type": "weekly_bonus",
            "label": "Haftalık 200–219 paket bonusu (diğer iller)",
            "amount": "3085.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "200",
            "upper_threshold": "219",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-220",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.220",
            "item_type": "weekly_bonus",
            "label": "Haftalık 220–254 paket bonusu (diğer iller)",
            "amount": "3820.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "220",
            "upper_threshold": "254",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-255",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.255",
            "item_type": "weekly_bonus",
            "label": "Haftalık 255–289 paket bonusu (diğer iller)",
            "amount": "4350.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "255",
            "upper_threshold": "289",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-290",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.290",
            "item_type": "weekly_bonus",
            "label": "Haftalık 290–324 paket bonusu (diğer iller)",
            "amount": "5640.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "290",
            "upper_threshold": "324",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-325",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.325",
            "item_type": "weekly_bonus",
            "label": "Haftalık 325–359 paket bonusu (diğer iller)",
            "amount": "6250.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "325",
            "upper_threshold": "359",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-360",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.360",
            "item_type": "weekly_bonus",
            "label": "Haftalık 360–399 paket bonusu (diğer iller)",
            "amount": "7220.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "360",
            "upper_threshold": "399",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-bonus-weekly-ys_other-400",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "bonus.weekly.ys_other.400",
            "item_type": "weekly_bonus",
            "label": "Haftalık 400+ paket bonusu (diğer iller)",
            "amount": "9000.00",
            "unit": "week",
            "calculation_method": "tier",
            "lower_threshold": "400",
            "eligibility_conditions": {
              "region_tier": "ys_other"
            },
            "item_group": "weekly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Diğer iller. KDV dahil. Kaynak: Yemeksepeti kurye sitesi (Haftalık Bonus Baremleri), 2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-referral",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "referral",
            "item_type": "referral_bonus",
            "label": "Arkadaşını öner bonusu",
            "amount": "500.00",
            "unit": "flat",
            "calculation_method": "flat",
            "amount_upper": "4000.00",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Önerdiğin kurye 100 paket: 500 TL, 500 paket: 2.500 TL, 1.000 paket: 4.000 TL. İstanbul, Ankara, İzmir, Muğla. Kaynak: eleman.net, 13.01.2026."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-side-tips",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "side.tips",
            "item_type": "tip",
            "label": "Online bahşiş",
            "amount": "0.00",
            "unit": "flat",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": false,
            "note": "Müşterinin uygulamadan verdiği bahşiş ayrıca kazancındır; tutarı değişir."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-side-accounting",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "side.accounting",
            "item_type": "in_kind_support",
            "label": "Muhasebe desteği (Bimasraf)",
            "amount": "0.00",
            "unit": "flat",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": false,
            "note": "Şirket kuruluşu ve fatura işlemlerinde Bimasraf uygulamasından destek. Kaynak: Yemeksepeti kurye sitesi."
          },
          {
            "tariff_item_id": "yemeksepeti-esnaf-v3-side-schedule",
            "tariff_version_id": "yemeksepeti-esnaf-v3",
            "item_key": "side.schedule",
            "item_type": "in_kind_support",
            "label": "Çalışma saati zorunluluğu yok",
            "amount": "0.00",
            "unit": "flat",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": false,
            "note": "Takvimini sen belirlersin; araç (otomobil, motosiklet, bisiklet, yürüyerek) serbest. Çoklu sipariş imkânı var."
          }
        ]
      },
      {
        "tariff_version_id": "pt_migros-esnaf-v1",
        "platform_id": "pt_migros",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 1,
        "revision": 0,
        "effective_from": "2026-01-01",
        "effective_until": null,
        "created_at": "2026-10-14",
        "source_type": "official_channel",
        "verification_status": "verified",
        "approval_status": "published",
        "approved_at": "2026-10-14T00:00:00Z",
        "approved_by": "tarife-ekibi",
        "change_summary": "Migros hızlı kurye 2026: sabit 55.223 TL, bölgeye göre günlük paket primi, aylık paket bonusu.",
        "settings": {
          "bonus_stacking": "highest_only",
          "fixed_pay_basis": "region",
          "confidence": {
            "bonus_stacking": "verified",
            "fixed_pay_basis": "verified"
          }
        },
        "items": [
          {
            "tariff_item_id": "pt_migros-esnaf-v1-fixed-month",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "fixed.month",
            "item_type": "fixed",
            "label": "Aylık sabit ücret",
            "amount": "55223.00",
            "unit": "month",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde 55.223 TL (%34,69 artış). 26 gün × 12 saat = 312 saat; saatlik karşılığı 177 TL. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-16",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.16",
            "item_type": "daily_bonus",
            "label": "Günlük 16–19 paket primi (1. bölge)",
            "amount": "262.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "16",
            "upper_threshold": "19",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-20",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–23 paket primi (1. bölge)",
            "amount": "665.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "upper_threshold": "23",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-24",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.24",
            "item_type": "daily_bonus",
            "label": "Günlük 24–27 paket primi (1. bölge)",
            "amount": "1000.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "24",
            "upper_threshold": "27",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-28",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.28",
            "item_type": "daily_bonus",
            "label": "Günlük 28–33 paket primi (1. bölge)",
            "amount": "1325.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "28",
            "upper_threshold": "33",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-34",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.34",
            "item_type": "daily_bonus",
            "label": "Günlük 34–37 paket primi (1. bölge)",
            "amount": "1855.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "34",
            "upper_threshold": "37",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-38",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.38",
            "item_type": "daily_bonus",
            "label": "Günlük 38–42 paket primi (1. bölge)",
            "amount": "2360.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "38",
            "upper_threshold": "42",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-43",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.43",
            "item_type": "daily_bonus",
            "label": "Günlük 43–48 paket primi (1. bölge)",
            "amount": "2910.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "43",
            "upper_threshold": "48",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-49",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.49",
            "item_type": "daily_bonus",
            "label": "Günlük 49–54 paket primi (1. bölge)",
            "amount": "3530.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "49",
            "upper_threshold": "54",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-55",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–58 paket primi (1. bölge)",
            "amount": "4150.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "upper_threshold": "58",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-59",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.59",
            "item_type": "daily_bonus",
            "label": "Günlük 59–63 paket primi (1. bölge)",
            "amount": "4560.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "59",
            "upper_threshold": "63",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-64",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.64",
            "item_type": "daily_bonus",
            "label": "Günlük 64–69 paket primi (1. bölge)",
            "amount": "5075.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "64",
            "upper_threshold": "69",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-70",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.70",
            "item_type": "daily_bonus",
            "label": "Günlük 70–75 paket primi (1. bölge)",
            "amount": "5690.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "70",
            "upper_threshold": "75",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r1-76",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r1.76",
            "item_type": "daily_bonus",
            "label": "Günlük 76+ paket primi (1. bölge)",
            "amount": "6310.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "76",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-16",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.16",
            "item_type": "daily_bonus",
            "label": "Günlük 16–19 paket primi (2. ve 3. bölge)",
            "amount": "200.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "16",
            "upper_threshold": "19",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-20",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–23 paket primi (2. ve 3. bölge)",
            "amount": "510.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "upper_threshold": "23",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-24",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.24",
            "item_type": "daily_bonus",
            "label": "Günlük 24–27 paket primi (2. ve 3. bölge)",
            "amount": "760.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "24",
            "upper_threshold": "27",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-28",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.28",
            "item_type": "daily_bonus",
            "label": "Günlük 28–33 paket primi (2. ve 3. bölge)",
            "amount": "1005.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "28",
            "upper_threshold": "33",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-34",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.34",
            "item_type": "daily_bonus",
            "label": "Günlük 34–37 paket primi (2. ve 3. bölge)",
            "amount": "1440.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "34",
            "upper_threshold": "37",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-38",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.38",
            "item_type": "daily_bonus",
            "label": "Günlük 38–42 paket primi (2. ve 3. bölge)",
            "amount": "1855.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "38",
            "upper_threshold": "42",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-43",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.43",
            "item_type": "daily_bonus",
            "label": "Günlük 43–48 paket primi (2. ve 3. bölge)",
            "amount": "2305.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "43",
            "upper_threshold": "48",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-49",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.49",
            "item_type": "daily_bonus",
            "label": "Günlük 49–54 paket primi (2. ve 3. bölge)",
            "amount": "2810.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "49",
            "upper_threshold": "54",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-55",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–58 paket primi (2. ve 3. bölge)",
            "amount": "3320.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "upper_threshold": "58",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-59",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.59",
            "item_type": "daily_bonus",
            "label": "Günlük 59–63 paket primi (2. ve 3. bölge)",
            "amount": "3655.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "59",
            "upper_threshold": "63",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-64",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.64",
            "item_type": "daily_bonus",
            "label": "Günlük 64–69 paket primi (2. ve 3. bölge)",
            "amount": "4080.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "64",
            "upper_threshold": "69",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-70",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.70",
            "item_type": "daily_bonus",
            "label": "Günlük 70–75 paket primi (2. ve 3. bölge)",
            "amount": "4585.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "70",
            "upper_threshold": "75",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r23-76",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r23.76",
            "item_type": "daily_bonus",
            "label": "Günlük 76+ paket primi (2. ve 3. bölge)",
            "amount": "5090.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "76",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-16",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.16",
            "item_type": "daily_bonus",
            "label": "Günlük 16–19 paket primi (4. bölge)",
            "amount": "172.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "16",
            "upper_threshold": "19",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-20",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–23 paket primi (4. bölge)",
            "amount": "440.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "upper_threshold": "23",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-24",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.24",
            "item_type": "daily_bonus",
            "label": "Günlük 24–27 paket primi (4. bölge)",
            "amount": "655.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "24",
            "upper_threshold": "27",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-28",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.28",
            "item_type": "daily_bonus",
            "label": "Günlük 28–33 paket primi (4. bölge)",
            "amount": "860.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "28",
            "upper_threshold": "33",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-34",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.34",
            "item_type": "daily_bonus",
            "label": "Günlük 34–37 paket primi (4. bölge)",
            "amount": "1255.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "34",
            "upper_threshold": "37",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-38",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.38",
            "item_type": "daily_bonus",
            "label": "Günlük 38–42 paket primi (4. bölge)",
            "amount": "1630.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "38",
            "upper_threshold": "42",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-43",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.43",
            "item_type": "daily_bonus",
            "label": "Günlük 43–48 paket primi (4. bölge)",
            "amount": "2035.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "43",
            "upper_threshold": "48",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-49",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.49",
            "item_type": "daily_bonus",
            "label": "Günlük 49–54 paket primi (4. bölge)",
            "amount": "2495.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "49",
            "upper_threshold": "54",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-55",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–58 paket primi (4. bölge)",
            "amount": "2955.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "upper_threshold": "58",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-59",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.59",
            "item_type": "daily_bonus",
            "label": "Günlük 59–63 paket primi (4. bölge)",
            "amount": "3260.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "59",
            "upper_threshold": "63",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-64",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.64",
            "item_type": "daily_bonus",
            "label": "Günlük 64–69 paket primi (4. bölge)",
            "amount": "3645.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "64",
            "upper_threshold": "69",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-70",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.70",
            "item_type": "daily_bonus",
            "label": "Günlük 70–75 paket primi (4. bölge)",
            "amount": "4105.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "70",
            "upper_threshold": "75",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-daily-r4-76",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.daily.r4.76",
            "item_type": "daily_bonus",
            "label": "Günlük 76+ paket primi (4. bölge)",
            "amount": "4565.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "76",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-700",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.700",
            "item_type": "monthly_bonus",
            "label": "Aylık 700–799 paket bonusu",
            "amount": "12800.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "700",
            "upper_threshold": "799",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-800",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.800",
            "item_type": "monthly_bonus",
            "label": "Aylık 800–899 paket bonusu",
            "amount": "20224.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "800",
            "upper_threshold": "899",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-900",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.900",
            "item_type": "monthly_bonus",
            "label": "Aylık 900–999 paket bonusu",
            "amount": "27520.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "900",
            "upper_threshold": "999",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-1000",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.1000",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.000–1.199 paket bonusu",
            "amount": "33408.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1000",
            "upper_threshold": "1199",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-1200",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.1200",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.200–1.399 paket bonusu",
            "amount": "40300.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1200",
            "upper_threshold": "1399",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-1400",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.1400",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.400–1.599 paket bonusu",
            "amount": "47970.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1400",
            "upper_threshold": "1599",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-1600",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.1600",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.600–1.799 paket bonusu",
            "amount": "55698.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1600",
            "upper_threshold": "1799",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-bonus-monthly-1800",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "bonus.monthly.1800",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.800+ paket bonusu",
            "amount": "68575.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1800",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-side-lunch",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "side.lunch",
            "item_type": "in_kind_support",
            "label": "Öğle yemeği",
            "amount": "0.00",
            "unit": "flat",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": false,
            "note": "Öğle yemeği verilir. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_migros-esnaf-v1-side-break",
            "tariff_version_id": "pt_migros-esnaf-v1",
            "item_key": "side.break",
            "item_type": "in_kind_support",
            "label": "1,5 saat yemek molası",
            "amount": "0.00",
            "unit": "flat",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": false,
            "note": "Günlük 1,5 saat yemek molası. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          }
        ]
      },
      {
        "tariff_version_id": "migros_hemen-esnaf-v3",
        "platform_id": "migros_hemen",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 3,
        "revision": 0,
        "effective_from": "2026-01-01",
        "effective_until": null,
        "created_at": "2026-10-14",
        "source_type": "official_channel",
        "verification_status": "verified",
        "approval_status": "published",
        "approved_at": "2026-10-14T00:00:00Z",
        "approved_by": "tarife-ekibi",
        "change_summary": "Migros Hemen 2026: sabit 55.223 TL, bölgeye göre günlük paket primi (20+), aylık bonus, yemek paketlerine km desteği.",
        "settings": {
          "bonus_stacking": "highest_only",
          "fixed_pay_basis": "region",
          "confidence": {
            "bonus_stacking": "verified",
            "fixed_pay_basis": "verified"
          }
        },
        "items": [
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-fixed-month",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "fixed.month",
            "item_type": "fixed",
            "label": "Aylık sabit ücret",
            "amount": "55223.00",
            "unit": "month",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde 55.223 TL (%34,69 artış). 26 gün × 12 saat = 312 saat; saatlik karşılığı 177 TL. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-20",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–23 paket primi (1. bölge)",
            "amount": "335.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "upper_threshold": "23",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-24",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.24",
            "item_type": "daily_bonus",
            "label": "Günlük 24–27 paket primi (1. bölge)",
            "amount": "665.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "24",
            "upper_threshold": "27",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-28",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.28",
            "item_type": "daily_bonus",
            "label": "Günlük 28–33 paket primi (1. bölge)",
            "amount": "1005.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "28",
            "upper_threshold": "33",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-34",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.34",
            "item_type": "daily_bonus",
            "label": "Günlük 34–37 paket primi (1. bölge)",
            "amount": "1515.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "34",
            "upper_threshold": "37",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-38",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.38",
            "item_type": "daily_bonus",
            "label": "Günlük 38–42 paket primi (1. bölge)",
            "amount": "2020.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "38",
            "upper_threshold": "42",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-43",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.43",
            "item_type": "daily_bonus",
            "label": "Günlük 43–48 paket primi (1. bölge)",
            "amount": "2565.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "43",
            "upper_threshold": "48",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-49",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.49",
            "item_type": "daily_bonus",
            "label": "Günlük 49–54 paket primi (1. bölge)",
            "amount": "3185.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "49",
            "upper_threshold": "54",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-55",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–58 paket primi (1. bölge)",
            "amount": "3800.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "upper_threshold": "58",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-59",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.59",
            "item_type": "daily_bonus",
            "label": "Günlük 59–63 paket primi (1. bölge)",
            "amount": "4215.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "59",
            "upper_threshold": "63",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-64",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.64",
            "item_type": "daily_bonus",
            "label": "Günlük 64–69 paket primi (1. bölge)",
            "amount": "4730.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "64",
            "upper_threshold": "69",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-70",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.70",
            "item_type": "daily_bonus",
            "label": "Günlük 70–75 paket primi (1. bölge)",
            "amount": "5345.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "70",
            "upper_threshold": "75",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r1-76",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r1.76",
            "item_type": "daily_bonus",
            "label": "Günlük 76+ paket primi (1. bölge)",
            "amount": "5965.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "76",
            "eligibility_conditions": {
              "region_tier": "r1"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-20",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–23 paket primi (2. ve 3. bölge)",
            "amount": "255.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "upper_threshold": "23",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-24",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.24",
            "item_type": "daily_bonus",
            "label": "Günlük 24–27 paket primi (2. ve 3. bölge)",
            "amount": "505.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "24",
            "upper_threshold": "27",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-28",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.28",
            "item_type": "daily_bonus",
            "label": "Günlük 28–33 paket primi (2. ve 3. bölge)",
            "amount": "770.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "28",
            "upper_threshold": "33",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-34",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.34",
            "item_type": "daily_bonus",
            "label": "Günlük 34–37 paket primi (2. ve 3. bölge)",
            "amount": "1180.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "34",
            "upper_threshold": "37",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-38",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.38",
            "item_type": "daily_bonus",
            "label": "Günlük 38–42 paket primi (2. ve 3. bölge)",
            "amount": "1595.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "38",
            "upper_threshold": "42",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-43",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.43",
            "item_type": "daily_bonus",
            "label": "Günlük 43–48 paket primi (2. ve 3. bölge)",
            "amount": "2040.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "43",
            "upper_threshold": "48",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-49",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.49",
            "item_type": "daily_bonus",
            "label": "Günlük 49–54 paket primi (2. ve 3. bölge)",
            "amount": "2550.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "49",
            "upper_threshold": "54",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-55",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–58 paket primi (2. ve 3. bölge)",
            "amount": "3055.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "upper_threshold": "58",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-59",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.59",
            "item_type": "daily_bonus",
            "label": "Günlük 59–63 paket primi (2. ve 3. bölge)",
            "amount": "3390.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "59",
            "upper_threshold": "63",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-64",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.64",
            "item_type": "daily_bonus",
            "label": "Günlük 64–69 paket primi (2. ve 3. bölge)",
            "amount": "3815.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "64",
            "upper_threshold": "69",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-70",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.70",
            "item_type": "daily_bonus",
            "label": "Günlük 70–75 paket primi (2. ve 3. bölge)",
            "amount": "4320.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "70",
            "upper_threshold": "75",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r23-76",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r23.76",
            "item_type": "daily_bonus",
            "label": "Günlük 76+ paket primi (2. ve 3. bölge)",
            "amount": "4830.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "76",
            "eligibility_conditions": {
              "region_tier": "r23"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-20",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.20",
            "item_type": "daily_bonus",
            "label": "Günlük 20–23 paket primi (4. bölge)",
            "amount": "220.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "20",
            "upper_threshold": "23",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-24",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.24",
            "item_type": "daily_bonus",
            "label": "Günlük 24–27 paket primi (4. bölge)",
            "amount": "440.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "24",
            "upper_threshold": "27",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-28",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.28",
            "item_type": "daily_bonus",
            "label": "Günlük 28–33 paket primi (4. bölge)",
            "amount": "660.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "28",
            "upper_threshold": "33",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-34",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.34",
            "item_type": "daily_bonus",
            "label": "Günlük 34–37 paket primi (4. bölge)",
            "amount": "1030.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "34",
            "upper_threshold": "37",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-38",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.38",
            "item_type": "daily_bonus",
            "label": "Günlük 38–42 paket primi (4. bölge)",
            "amount": "1405.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "38",
            "upper_threshold": "42",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-43",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.43",
            "item_type": "daily_bonus",
            "label": "Günlük 43–48 paket primi (4. bölge)",
            "amount": "1810.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "43",
            "upper_threshold": "48",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-49",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.49",
            "item_type": "daily_bonus",
            "label": "Günlük 49–54 paket primi (4. bölge)",
            "amount": "2270.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "49",
            "upper_threshold": "54",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-55",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.55",
            "item_type": "daily_bonus",
            "label": "Günlük 55–58 paket primi (4. bölge)",
            "amount": "2730.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "55",
            "upper_threshold": "58",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-59",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.59",
            "item_type": "daily_bonus",
            "label": "Günlük 59–63 paket primi (4. bölge)",
            "amount": "3035.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "59",
            "upper_threshold": "63",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-64",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.64",
            "item_type": "daily_bonus",
            "label": "Günlük 64–69 paket primi (4. bölge)",
            "amount": "3415.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "64",
            "upper_threshold": "69",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-70",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.70",
            "item_type": "daily_bonus",
            "label": "Günlük 70–75 paket primi (4. bölge)",
            "amount": "3875.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "70",
            "upper_threshold": "75",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-daily-r4-76",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.daily.r4.76",
            "item_type": "daily_bonus",
            "label": "Günlük 76+ paket primi (4. bölge)",
            "amount": "4335.00",
            "unit": "day",
            "calculation_method": "tier",
            "lower_threshold": "76",
            "eligibility_conditions": {
              "region_tier": "r4"
            },
            "item_group": "daily_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-700",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.700",
            "item_type": "monthly_bonus",
            "label": "Aylık 700–799 paket bonusu",
            "amount": "12800.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "700",
            "upper_threshold": "799",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-800",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.800",
            "item_type": "monthly_bonus",
            "label": "Aylık 800–899 paket bonusu",
            "amount": "20224.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "800",
            "upper_threshold": "899",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-900",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.900",
            "item_type": "monthly_bonus",
            "label": "Aylık 900–999 paket bonusu",
            "amount": "27520.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "900",
            "upper_threshold": "999",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-1000",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.1000",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.000–1.199 paket bonusu",
            "amount": "33408.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1000",
            "upper_threshold": "1199",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-1200",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.1200",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.200–1.399 paket bonusu",
            "amount": "40300.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1200",
            "upper_threshold": "1399",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-1400",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.1400",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.400–1.599 paket bonusu",
            "amount": "47970.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1400",
            "upper_threshold": "1599",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-1600",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.1600",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.600–1.799 paket bonusu",
            "amount": "55698.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1600",
            "upper_threshold": "1799",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-bonus-monthly-1800",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "bonus.monthly.1800",
            "item_type": "monthly_bonus",
            "label": "Aylık 1.800+ paket bonusu",
            "amount": "68575.00",
            "unit": "month",
            "calculation_method": "tier",
            "lower_threshold": "1800",
            "item_group": "monthly_bonus",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Tüm bölgelerde aynı. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-distance-4_6",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "distance.4_6",
            "item_type": "other_payment",
            "label": "Km desteği (4–6 km)",
            "amount": "25.00",
            "unit": "package",
            "calculation_method": "delivery_band",
            "lower_threshold": "4",
            "upper_threshold": "6",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Migros yemek paketlerinde 4–6 km teslimata +25 TL. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-distance-6",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "distance.6",
            "item_type": "other_payment",
            "label": "Km desteği (6 km üstü)",
            "amount": "35.00",
            "unit": "package",
            "calculation_method": "delivery_band",
            "lower_threshold": "6",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Migros yemek paketlerinde 6 km üstü teslimata +35 TL. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-side-lunch",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "side.lunch",
            "item_type": "in_kind_support",
            "label": "Öğle yemeği",
            "amount": "0.00",
            "unit": "flat",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": false,
            "note": "Öğle yemeği verilir. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "migros_hemen-esnaf-v3-side-break",
            "tariff_version_id": "migros_hemen-esnaf-v3",
            "item_key": "side.break",
            "item_type": "in_kind_support",
            "label": "1,5 saat yemek molası",
            "amount": "0.00",
            "unit": "flat",
            "calculation_method": "flat",
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": false,
            "note": "Günlük 1,5 saat yemek molası. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          }
        ]
      },
      {
        "tariff_version_id": "pt_restoran-esnaf-v1",
        "platform_id": "pt_restoran",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 1,
        "revision": 0,
        "effective_from": "2026-01-01",
        "effective_until": null,
        "created_at": "2026-10-14",
        "source_type": "official_channel",
        "verification_status": "verified",
        "approval_status": "published",
        "approved_at": "2026-10-14T00:00:00Z",
        "approved_by": "tarife-ekibi",
        "change_summary": "Restoran moto kurye 2026: bölge ve günlük çalışma saatine (9–12) göre sabit ücret, kıdem primi, günlük paket primi (%28–30 zam).",
        "settings": {
          "bonus_stacking": "highest_only",
          "fixed_pay_basis": "both",
          "confidence": {
            "bonus_stacking": "verified",
            "fixed_pay_basis": "verified"
          }
        },
        "items": [
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r1-9",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r1.9",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (1. bölge, günde 9 saat)",
            "amount": "69630.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                9
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r1-10",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r1.10",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (1. bölge, günde 10 saat)",
            "amount": "77370.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                10
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r1-11",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r1.11",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (1. bölge, günde 11 saat)",
            "amount": "85100.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                11
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r1-12",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r1.12",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (1. bölge, günde 12 saat)",
            "amount": "92840.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                12
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r23-9",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r23.9",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (2. ve 3. bölge, günde 9 saat)",
            "amount": "67220.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                9
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r23-10",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r23.10",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (2. ve 3. bölge, günde 10 saat)",
            "amount": "74680.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                10
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r23-11",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r23.11",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (2. ve 3. bölge, günde 11 saat)",
            "amount": "82150.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                11
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r23-12",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r23.12",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (2. ve 3. bölge, günde 12 saat)",
            "amount": "89620.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                12
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r4-9",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r4.9",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (4. bölge, günde 9 saat)",
            "amount": "63320.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                9
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r4-10",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r4.10",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (4. bölge, günde 10 saat)",
            "amount": "70360.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                10
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r4-11",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r4.11",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (4. bölge, günde 11 saat)",
            "amount": "77400.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                11
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-fixed-r4-12",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "fixed.r4.12",
            "item_type": "fixed",
            "label": "Aylık sabit ücret (4. bölge, günde 12 saat)",
            "amount": "84430.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                12
              ]
            },
            "item_group": "fixed_region",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "26 gün fiyatı, KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-2-9",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.2.9",
            "item_type": "fixed",
            "label": "Kıdem primi (2 yıl, günde 9 saat)",
            "amount": "2025.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                9
              ],
              "min_seniority_years": 2,
              "max_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-3-9",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.3.9",
            "item_type": "fixed",
            "label": "Kıdem primi (3 yıl ve üzeri, günde 9 saat)",
            "amount": "2700.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                9
              ],
              "min_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-2-10",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.2.10",
            "item_type": "fixed",
            "label": "Kıdem primi (2 yıl, günde 10 saat)",
            "amount": "2250.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                10
              ],
              "min_seniority_years": 2,
              "max_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-3-10",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.3.10",
            "item_type": "fixed",
            "label": "Kıdem primi (3 yıl ve üzeri, günde 10 saat)",
            "amount": "3000.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                10
              ],
              "min_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-2-11",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.2.11",
            "item_type": "fixed",
            "label": "Kıdem primi (2 yıl, günde 11 saat)",
            "amount": "2475.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                11
              ],
              "min_seniority_years": 2,
              "max_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-3-11",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.3.11",
            "item_type": "fixed",
            "label": "Kıdem primi (3 yıl ve üzeri, günde 11 saat)",
            "amount": "3300.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                11
              ],
              "min_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-2-12",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.2.12",
            "item_type": "fixed",
            "label": "Kıdem primi (2 yıl, günde 12 saat)",
            "amount": "2700.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                12
              ],
              "min_seniority_years": 2,
              "max_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-seniority-3-12",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "seniority.3.12",
            "item_type": "fixed",
            "label": "Kıdem primi (3 yıl ve üzeri, günde 12 saat)",
            "amount": "3600.00",
            "unit": "month",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "contract_hours": [
                12
              ],
              "min_seniority_years": 3
            },
            "item_group": "seniority",
            "stacking_rule": "exclusive_group",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r1-9-a",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r1.9.a",
            "item_type": "single_package",
            "label": "Paket primi 21–35. paket (1. bölge, 9–10 saat)",
            "amount": "34.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "21",
            "upper_threshold": "35",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                9,
                10
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Günde 21. pakete kadar sabit ücrete dahil; 21–35. paketler için paket başı. KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r1-9-b",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r1.9.b",
            "item_type": "single_package",
            "label": "Paket primi 36. paketten itibaren (1. bölge, 9–10 saat)",
            "amount": "43.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "36",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                9,
                10
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r1-11-a",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r1.11.a",
            "item_type": "single_package",
            "label": "Paket primi 26–40. paket (1. bölge, 11–12 saat)",
            "amount": "34.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "26",
            "upper_threshold": "40",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                11,
                12
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Günde 26. pakete kadar sabit ücrete dahil; 26–40. paketler için paket başı. KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r1-11-b",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r1.11.b",
            "item_type": "single_package",
            "label": "Paket primi 41. paketten itibaren (1. bölge, 11–12 saat)",
            "amount": "43.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "41",
            "eligibility_conditions": {
              "region_tier": "r1",
              "contract_hours": [
                11,
                12
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r23-9-a",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r23.9.a",
            "item_type": "single_package",
            "label": "Paket primi 21–35. paket (2. ve 3. bölge, 9–10 saat)",
            "amount": "25.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "21",
            "upper_threshold": "35",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                9,
                10
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Günde 21. pakete kadar sabit ücrete dahil; 21–35. paketler için paket başı. KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r23-9-b",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r23.9.b",
            "item_type": "single_package",
            "label": "Paket primi 36. paketten itibaren (2. ve 3. bölge, 9–10 saat)",
            "amount": "34.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "36",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                9,
                10
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r23-11-a",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r23.11.a",
            "item_type": "single_package",
            "label": "Paket primi 26–40. paket (2. ve 3. bölge, 11–12 saat)",
            "amount": "25.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "26",
            "upper_threshold": "40",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                11,
                12
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Günde 26. pakete kadar sabit ücrete dahil; 26–40. paketler için paket başı. KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r23-11-b",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r23.11.b",
            "item_type": "single_package",
            "label": "Paket primi 41. paketten itibaren (2. ve 3. bölge, 11–12 saat)",
            "amount": "34.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "41",
            "eligibility_conditions": {
              "region_tier": "r23",
              "contract_hours": [
                11,
                12
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r4-9-a",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r4.9.a",
            "item_type": "single_package",
            "label": "Paket primi 21–35. paket (4. bölge, 9–10 saat)",
            "amount": "17.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "21",
            "upper_threshold": "35",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                9,
                10
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Günde 21. pakete kadar sabit ücrete dahil; 21–35. paketler için paket başı. KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r4-9-b",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r4.9.b",
            "item_type": "single_package",
            "label": "Paket primi 36. paketten itibaren (4. bölge, 9–10 saat)",
            "amount": "26.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "36",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                9,
                10
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r4-11-a",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r4.11.a",
            "item_type": "single_package",
            "label": "Paket primi 26–40. paket (4. bölge, 11–12 saat)",
            "amount": "17.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "26",
            "upper_threshold": "40",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                11,
                12
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "Günde 26. pakete kadar sabit ücrete dahil; 26–40. paketler için paket başı. KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          },
          {
            "tariff_item_id": "pt_restoran-esnaf-v1-package-r4-11-b",
            "tariff_version_id": "pt_restoran-esnaf-v1",
            "item_key": "package.r4.11.b",
            "item_type": "single_package",
            "label": "Paket primi 41. paketten itibaren (4. bölge, 11–12 saat)",
            "amount": "26.00",
            "unit": "package",
            "calculation_method": "daily_package_rate",
            "lower_threshold": "41",
            "eligibility_conditions": {
              "region_tier": "r4",
              "contract_hours": [
                11,
                12
              ]
            },
            "stacking_rule": "additive",
            "confidence_status": "verified",
            "is_cash": true,
            "note": "KDV dahil. Kaynak: Paket Taxi resmî 2026 tarife paylaşımı."
          }
        ]
      }
    ]
    """#
}
