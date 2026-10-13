import Foundation

/// UserDefaults / @AppStorage anahtarlari. Tek yerde toplanir ki yazim hatasi olmasin.
enum AppPreferences {
    /// Km basina yakit + bakim maliyeti (TL). Kullanici ayarlardan gunceller.
    static let costPerKmKey = "costPerKm"
    /// Otomatik gider tahmini acik mi?
    static let autoEstimateExpensesKey = "autoEstimateExpenses"
    /// "Calisiyorum" modu (arka plan konum takibi yalnizca bu acikken calisir).
    static let isWorkingKey = "isWorking"
    static let workSessionStartKey = "workSessionStart"
    /// Anonim istatistik havuzuna katilim. Varsayilan KAPALI (opt-in, acik onay gerekir).
    static let dataSharingOptInKey = "dataSharingOptIn"
    /// Kullanicinin acik onay verdigi an (Unix zaman damgasi). Onay geri alininca silinir.
    static let dataSharingConsentDateKey = "dataSharingConsentDate"
    /// Konum yogunlugu paylasimi (kazanc paylasimindan AYRI acik riza). Varsayilan KAPALI.
    static let locationSharingOptInKey = "locationSharingOptIn"
    static let locationSharingConsentDateKey = "locationSharingConsentDate"
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    /// 1.7 tanitimi bir kez gosterildi (1.6'dan gelenler de bir kez gorur).
    static let hasSeenIntroV17Key = "hasSeenIntroV17"
    /// Haftalik / gunluk net kazanc hedefi (TL). 0 = ayarlanmadi.
    static let weeklyGoalKey = "weeklyNetGoal"
    static let dailyGoalKey = "dailyNetGoal"
    /// Son 48 saatin ekran goruntulerini otomatik tara (kullanici acar; izin o an istenir).
    static let screenshotScanEnabledKey = "screenshotScanEnabled"
    static let dismissedScreenshotIDsKey = "dismissedScreenshotIDs"
    /// Vardiya elle mi otomatik mi basladi ("manual" / "auto").
    static let workSessionOriginKey = "workSessionOrigin"
    /// Hareketle otomatik vardiya (kullanici acar; izinler o an istenir).
    static let autoShiftEnabledKey = "autoShiftEnabled"
    static let workHoursKey = "autoShiftWorkHours"
    static let lastAutoCancelKey = "autoShiftLastCancel"
    static let pendingShiftsKey = "autoShiftPending"
    /// Son anlamli hareketin zamani (otomatik vardiyanin bitisi icin).
    static let lastMovementKey = "lastMovementDate"
    /// Kalibrasyon ornegi gonderimi (paylasimdan AYRI acik riza). Varsayilan KAPALI.
    static let calibrationOptInKey = "calibrationOptIn"
    /// Son basarili sunucu gonderimi (Unix zaman damgasi).
    static let lastSyncDateKey = "lastSyncDate"
    /// Uzak sablonlarin son cekildigi an (Unix zaman damgasi).
    static let templatesFetchedAtKey = "templatesFetchedAt"
    static let rulesFetchedAtKey = "platformRulesFetchedAt"
    /// Planlama motoru calisma profili (JSON).
    static let workProfileKey = "workProfile"
    /// Kullanicinin sectigi plan (yeniden dogrulama icin kural surumuyle).
    static let savedPlanKey = "savedWorkPlan"
    /// Sunucuya ulasmis (ok/duplicate) kayit id'leri; tekrar kuyruga girmez.
    static let sentRecordIDsKey = "sentRecordIDs"
    /// Son basarili yedekleme (Unix zaman damgasi). Cikista silinir.
    static let lastBackupDateKey = "lastBackupDate"

    /// 1.6: yayimlanan hakedis tarifelerini indir (herkese acik tablo; cihazdan veri gonderilmez). Varsayilan ACIK.
    static let tariffUpdatesEnabledKey = "tariffUpdatesEnabled"
    static let tariffsFetchedAtKey = "tariffsFetchedAt"

    static let defaultCostPerKm = VehicleType.motorcycle.defaultCostPerKm
}
