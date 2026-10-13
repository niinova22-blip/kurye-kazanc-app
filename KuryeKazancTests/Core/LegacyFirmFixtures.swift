import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

// 1.9'da uygulamadan kaldirilan Trendyol GO ve Getir tarifeleri ve hesaplayicilari. Uygulamada YOKTUR; yalnizca motorun
// genel kurallarini (mesafe bantli km, hafta sonu kademesi, saatlik ucret, yogunluk carpani, donem toplami) denemek icin
// test ortaminda tutulur.
enum LegacyFirms {
    static let calculators: [PayCalculator] = [TrendyolGoCalculator(), GetirCalculator()]

    static let versions: [TariffVersion] = {
        guard let data = json.data(using: .utf8),
              let versions = try? JSONDecoder().decode([TariffVersion].self, from: data) else { return [] }
        return versions.map { var copy = $0; copy.origin = .bundled; return copy }
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
      }
    ]
    """#
}

// MARK: - Trendyol GO

/// Gunduz/gece tekli paket, birlesen paket, mesafe bantli km primi, kullanici girisli yogunluk carpani.
/// Gunluk paket bonusu ve haftalik performans bonusu ortak kurallarla (kademe / isaret).
struct TrendyolGoCalculator: PayCalculator {
    let platformCode = "trendyol_go"

    func apply(_ b: inout PayBuilder) {
        PackagePay.singles(&b)
        PackagePay.combined(&b)
        PackagePay.bandedKm(&b)
        applySurge(&b)
    }

    /// Yogunluk carpani yalnizca kullanicinin girdigi carpan ve paket sayisiyla; hava/mac/tatil bazli otomatik carpan yok.
    private func applySurge(_ b: inout PayBuilder) {
        let items: [TariffItem] = b.items(.surgeMultiplier)
        b.consume(items)
        guard let multiplier = b.input.surgeMultiplier, multiplier > 1, b.input.surgePackages > 0 else { return }
        let base: TariffItem? = b.items(.singlePackage).first { $0.conditions.timeBand == .day }
            ?? b.items(.singlePackage).first
        guard let base else { return }
        let extraPerPackage: Money = base.amount * (multiplier - 1)
        let count: Int = b.input.surgePackages
        b.add(PayLine(id: "surge", itemID: items.first?.id, itemKey: items.first?.key ?? "surge", type: .surgeMultiplier,
                      label: "Yoğunluk ek ödemesi (\(multiplier)×)", quantity: Decimal(count), unit: .package, rate: extraPerPackage,
                      amount: extraPerPackage * count, confidence: .userEntered,
                      note: "Çarpanı ve paket sayısını sen girdin."))
        if let item = items.first {
            let low: Decimal = item.amount.value
            let high: Decimal = (item.amountUpper ?? item.amount).value
            if multiplier < low || multiplier > high {
                b.note(.info, "Girdiğin çarpan (\(multiplier)×) tarifedeki aralığın (\(low)–\(high)×) dışında.")
            }
        }
    }
}

// MARK: - Getir

/// Saatlik ucret + ilk paket + birlesen paket + km. Motorlu / aracli tarife surum kapsamiyla (vehicle_type) secilir.
/// Hafta sonu (Cuma-Cumartesi-Pazar) bonusu ortak kademe kuraliyla, hafta sonu paket toplamindan.
struct GetirCalculator: PayCalculator {
    let platformCode = "getir"

    func apply(_ b: inout PayBuilder) {
        let hourly: [TariffItem] = b.items(.hourly).filter { $0.method == .perUnit }
        b.consume(hourly)
        if let item = hourly.first {
            if b.input.hours > 0 {
                b.perUnit(item, quantity: b.input.hours)
            } else if b.input.totalPackages > 0 {
                b.note(.missing, "Saatlik ücret için çalışma süresi girilmedi.")
            }
        }
        PackagePay.singles(&b)
        PackagePay.combined(&b)
        PackagePay.flatKm(&b)
    }
}
