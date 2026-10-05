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
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    static let defaultCostPerKm = VehicleType.motorcycle.defaultCostPerKm
}
