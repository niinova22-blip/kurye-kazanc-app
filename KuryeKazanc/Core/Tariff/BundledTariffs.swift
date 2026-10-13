import Foundation

/// Baslangic / ORNEK tarife kayitlari. Dogrulanmis guncel tarife DEGILDIR: tum kalemler "doğrulama gerekli",
/// surumler "doğrulanmamış" etiketlidir. Amaci sunucuya ulasilamadiginda hesaplamanin calismasidir;
/// sunucu ayni platform icin surum yayimladiginda bu kayitlar kullanilmaz (TariffCatalog.merged).
///
/// Ayni JSON `scripts/server/seed_tariffs.mjs` ile sunucuya tohumlanir (tek kaynak).
/// Eksik ara kademeler uydurulmadi: Trendyol GO 3–6 km araligi tanimsiz, Yemeksepeti haftalik bonus kademesi yok,
/// Getir ekipman destegi / saglik sigortasi tutari yok.
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
        "tariff_version_id": "trendyol_go-esnaf-v1",
        "platform_id": "trendyol_go",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": null,
        "version_number": 1,
        "revision": 0,
        "effective_from": "2026-01-01",
        "effective_until": null,
        "created_at": "2026-10-11",
        "source_type": "seed",
        "verification_status": "unverified",
        "approval_status": "published",
        "approved_at": "2026-10-11",
        "approved_by": "seed",
        "change_summary": "Başlangıç / örnek tarife. Değerler doğrulanmadı.",
        "settings": {
          "km_method": "slab",
          "bonus_stacking": "highest_only",
          "confidence": {}
        },
        "items": [
          {
            "tariff_item_id": "tgo-v1-package-day",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "package.day",
            "item_type": "single_package",
            "label": "Gündüz tekli paket",
            "amount": "64.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "time_band": "day"
            },
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Gündüz/gece saat aralıkları doğrulanmadı."
          },
          {
            "tariff_item_id": "tgo-v1-package-night",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "package.night",
            "item_type": "single_package",
            "label": "Gece tekli paket",
            "amount": "92.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "eligibility_conditions": {
              "time_band": "night"
            },
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "tgo-v1-package-combined",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "package.combined",
            "item_type": "combined_package",
            "label": "Birleşen ikinci paket",
            "amount": "27.00",
            "amount_upper": "41.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "27–41,50 TL aralığı; kesin kural doğrulanmadı."
          },
          {
            "tariff_item_id": "tgo-v1-km-0-3",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "km.band.0",
            "item_type": "per_km",
            "label": "Km primi 0–3 km",
            "amount": "6.50",
            "unit": "km",
            "lower_threshold": "0",
            "upper_threshold": "3",
            "calculation_method": "distance_band",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "tgo-v1-km-6",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "km.band.6",
            "item_type": "per_km",
            "label": "Km primi 6 km ve üzeri",
            "amount": "7.80",
            "unit": "km",
            "lower_threshold": "6",
            "calculation_method": "distance_band",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "3–6 km arası kademe bilinmiyor; uydurulmadı."
          },
          {
            "tariff_item_id": "tgo-v1-bonus-42",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "bonus.daily.42",
            "item_type": "daily_bonus",
            "label": "Günlük 42 paket bonusu",
            "amount": "1610.00",
            "unit": "day",
            "lower_threshold": "42",
            "calculation_method": "tier",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "tgo-v1-bonus-82",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "bonus.daily.82",
            "item_type": "daily_bonus",
            "label": "Günlük 82 paket bonusu",
            "amount": "4400.00",
            "unit": "day",
            "lower_threshold": "82",
            "calculation_method": "tier",
            "stacking_rule": "exclusive_group",
            "item_group": "daily_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "42 paket bonusuna eklenip eklenmediği doğrulanmadı."
          },
          {
            "tariff_item_id": "tgo-v1-surge",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "surge",
            "item_type": "surge_multiplier",
            "label": "Yoğunluk çarpanı",
            "amount": "1.5",
            "amount_upper": "2.0",
            "unit": "multiplier",
            "calculation_method": "multiplier",
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Yalnızca kullanıcı girişiyle uygulanır; otomatik çarpan yok."
          },
          {
            "tariff_item_id": "tgo-v1-weekly-performance",
            "tariff_version_id": "trendyol_go-esnaf-v1",
            "item_key": "bonus.weekly.performance",
            "item_type": "weekly_bonus",
            "label": "Haftalık performans bonusu",
            "amount": "500.00",
            "amount_upper": "1000.00",
            "unit": "week",
            "calculation_method": "flat",
            "eligibility_conditions": {
              "requires_flag": "weekly_performance"
            },
            "stacking_rule": "additive",
            "confidence_status": "needs_verification",
            "is_cash": true,
            "note": "Örnek aralık."
          }
        ]
      },
      {
        "tariff_version_id": "getir-esnaf-motorcycle-v1",
        "platform_id": "getir",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": "motorcycle",
        "version_number": 1,
        "revision": 0,
        "effective_from": "2026-01-01",
        "created_at": "2026-10-11",
        "source_type": "seed",
        "verification_status": "unverified",
        "approval_status": "published",
        "approved_at": "2026-10-11",
        "approved_by": "seed",
        "change_summary": "Başlangıç / örnek tarife (motorlu). Değerler doğrulanmadı.",
        "settings": {
          "bonus_stacking": "highest_only",
          "confidence": {}
        },
        "items": [
          {
            "tariff_item_id": "getir-m-v1-hourly",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "hourly",
            "item_type": "hourly",
            "label": "Saatlik ücret",
            "amount": "50.00",
            "unit": "hour",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-package-first",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "package.first",
            "item_type": "single_package",
            "label": "İlk paket",
            "amount": "110.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-package-combined",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "package.combined",
            "item_type": "combined_package",
            "label": "Birleşen paket",
            "amount": "72.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-km",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "km",
            "item_type": "per_km",
            "label": "Km ücreti",
            "amount": "5.75",
            "unit": "km",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-weekend-40",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "bonus.weekend.40",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 40–60 paket",
            "amount": "800.00",
            "unit": "week",
            "lower_threshold": "40",
            "upper_threshold": "60",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-weekend-61",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "bonus.weekend.61",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 61–70 paket",
            "amount": "900.00",
            "unit": "week",
            "lower_threshold": "61",
            "upper_threshold": "70",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-weekend-71",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "bonus.weekend.71",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 71–80 paket",
            "amount": "1050.00",
            "unit": "week",
            "lower_threshold": "71",
            "upper_threshold": "80",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-weekend-81",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "bonus.weekend.81",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 81–100 paket",
            "amount": "1300.00",
            "unit": "week",
            "lower_threshold": "81",
            "upper_threshold": "100",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-weekend-101",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "bonus.weekend.101",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 101+ paket",
            "amount": "1700.00",
            "unit": "week",
            "lower_threshold": "101",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-m-v1-p1",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "side.p1",
            "item_type": "in_kind_support",
            "label": "P1 belgesi desteği",
            "amount": "11014.00",
            "unit": "flat",
            "calculation_method": "flat",
            "confidence_status": "needs_verification",
            "is_cash": false,
            "note": "Doğrulanmamış; nakit hakedişe eklenmez."
          },
          {
            "tariff_item_id": "getir-m-v1-equipment",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "side.equipment",
            "item_type": "fuel_equipment_support",
            "label": "Ekipman desteği",
            "amount": "0",
            "unit": "flat",
            "calculation_method": "flat",
            "confidence_status": "needs_verification",
            "is_cash": false,
            "note": "Tutar bilinmiyor; doğrulanmamış."
          },
          {
            "tariff_item_id": "getir-m-v1-health",
            "tariff_version_id": "getir-esnaf-motorcycle-v1",
            "item_key": "side.health",
            "item_type": "in_kind_support",
            "label": "Sağlık sigortası",
            "amount": "0",
            "unit": "flat",
            "calculation_method": "flat",
            "confidence_status": "needs_verification",
            "is_cash": false,
            "note": "Kapsam ve tutar doğrulanmadı."
          }
        ]
      },
      {
        "tariff_version_id": "getir-esnaf-car-v1",
        "platform_id": "getir",
        "work_model": "esnaf",
        "region_id": null,
        "vehicle_type": "car",
        "version_number": 1,
        "revision": 0,
        "effective_from": "2026-01-01",
        "created_at": "2026-10-11",
        "source_type": "seed",
        "verification_status": "unverified",
        "approval_status": "published",
        "approved_at": "2026-10-11",
        "approved_by": "seed",
        "change_summary": "Başlangıç / örnek tarife (araçlı). Değerler doğrulanmadı.",
        "settings": {
          "bonus_stacking": "highest_only",
          "confidence": {}
        },
        "items": [
          {
            "tariff_item_id": "getir-c-v1-hourly",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "hourly",
            "item_type": "hourly",
            "label": "Saatlik ücret",
            "amount": "120.00",
            "unit": "hour",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-package-first",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "package.first",
            "item_type": "single_package",
            "label": "İlk paket",
            "amount": "115.00",
            "unit": "package",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-package-combined",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "package.combined",
            "item_type": "combined_package",
            "label": "Birleşen paket",
            "amount": "92.50",
            "unit": "package",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-km",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "km",
            "item_type": "per_km",
            "label": "Km ücreti",
            "amount": "5.75",
            "unit": "km",
            "calculation_method": "per_unit",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-weekend-40",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "bonus.weekend.40",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 40–60 paket",
            "amount": "800.00",
            "unit": "week",
            "lower_threshold": "40",
            "upper_threshold": "60",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-weekend-61",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "bonus.weekend.61",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 61–70 paket",
            "amount": "900.00",
            "unit": "week",
            "lower_threshold": "61",
            "upper_threshold": "70",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-weekend-71",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "bonus.weekend.71",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 71–80 paket",
            "amount": "1050.00",
            "unit": "week",
            "lower_threshold": "71",
            "upper_threshold": "80",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-weekend-81",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "bonus.weekend.81",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 81–100 paket",
            "amount": "1300.00",
            "unit": "week",
            "lower_threshold": "81",
            "upper_threshold": "100",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-weekend-101",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "bonus.weekend.101",
            "item_type": "weekly_bonus",
            "label": "Hafta sonu 101+ paket",
            "amount": "1700.00",
            "unit": "week",
            "lower_threshold": "101",
            "calculation_method": "tier",
            "eligibility_conditions": {
              "weekdays": [
                6,
                7,
                1
              ]
            },
            "stacking_rule": "exclusive_group",
            "item_group": "weekend_bonus",
            "confidence_status": "needs_verification",
            "is_cash": true
          },
          {
            "tariff_item_id": "getir-c-v1-p1",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "side.p1",
            "item_type": "in_kind_support",
            "label": "P1 belgesi desteği",
            "amount": "11014.00",
            "unit": "flat",
            "calculation_method": "flat",
            "confidence_status": "needs_verification",
            "is_cash": false,
            "note": "Doğrulanmamış; nakit hakedişe eklenmez."
          },
          {
            "tariff_item_id": "getir-c-v1-health",
            "tariff_version_id": "getir-esnaf-car-v1",
            "item_key": "side.health",
            "item_type": "in_kind_support",
            "label": "Sağlık sigortası",
            "amount": "0",
            "unit": "flat",
            "calculation_method": "flat",
            "confidence_status": "needs_verification",
            "is_cash": false,
            "note": "Kapsam ve tutar doğrulanmadı."
          }
        ]
      },
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
      }
    ]
    """#
}
