import Foundation
import SwiftData

/// Test surumu: secilen senaryonun verisini telefondaki veritabanina yazar; olusturulan kimlikleri saklar ki
/// "Senaryoyu sil" yalnizca onlari silsin. Senaryo oncesi firma/hedef/yakit ayarlari yedeklenir ve geri yuklenir.
@MainActor
struct DemoScenarioLoader {
    let payroll: PayrollModel
    let context: ModelContext
    var defaults: UserDefaults = .standard

    static let backupKey = "demoScenarioBackup"

    /// Senaryo disinda kayit var mi (yuklemeden once uyarmak icin).
    var hasRealData: Bool {
        let demo: Set<UUID> = Set(payroll.state.demoRecordIDs)
        let all: [EarningRecord] = (try? context.fetch(FetchDescriptor<EarningRecord>())) ?? []
        return all.contains { !demo.contains($0.id) }
    }

    func load(_ scenario: DemoScenario, today: Date = .now) {
        clear()
        backupSettings()
        let calendar: Calendar = .current
        let todayString: String = payroll.day(today)
        if let profile = scenario.profile {
            payroll.chooseFirm(profile.platformCode, regionTier: profile.regionTier, seniorityYears: profile.seniorityYears,
                               vehicleType: profile.vehicleType, flags: profile.flags)
        }
        payroll.setGoal(scenario.goal)
        payroll.store.replaceFuel(FuelSettings(entries: [], consumptionPer100Km: scenario.consumption))
        for price in scenario.fuelPrices {
            let date: Date = calendar.date(byAdding: .day, value: price.dayOffset, to: today) ?? today
            payroll.addFuelPrice(price.price, type: .gasoline, on: date)
        }
        for version in scenario.userTariffs(today: todayString) {
            _ = payroll.saveUserTariff(version, activate: true)
        }
        var recordIDs: [UUID] = []
        var logIDs: [UUID] = []
        if let profile = scenario.profile {
            for work in scenario.workDays {
                guard let log = save(work, profile: profile, today: today, calendar: calendar) else { continue }
                logIDs.append(log.id)
                if let recordID = log.earningRecordID { recordIDs.append(recordID) }
            }
        }
        payroll.store.setDemoIDs(records: recordIDs, logs: logIDs)
        payroll.reloadState()
        if scenario.resetsOnboarding {
            defaults.set(false, forKey: AppPreferences.hasSeenIntroV17Key)
            defaults.set(false, forKey: AppPreferences.hasSeenIntroV18Key)
            defaults.removeObject(forKey: AppPreferences.startFirmKey)
            defaults.set(false, forKey: AppPreferences.hasCompletedOnboardingKey)
        }
    }

    private func save(_ work: DemoWorkDay, profile: CourierTariffProfile, today: Date, calendar: Calendar) -> WorkLog? {
        let dayStart: Date = calendar.date(byAdding: .day, value: work.dayOffset, to: calendar.startOfDay(for: today)) ?? today
        let start: Date = calendar.date(byAdding: .hour, value: work.startHour, to: dayStart) ?? dayStart
        let end: Date = start.addingTimeInterval(NSDecimalNumber(decimal: work.hours).doubleValue * 3600)
        var input = PayInput(platformCode: profile.platformCode, startDay: payroll.day(dayStart))
        input.dayPackages = work.packages
        input.totalKm = work.km
        input.hours = work.hours
        input.regionTier = profile.regionTier
        input.seniorityYears = profile.seniorityYears
        input.vehicleType = profile.vehicleType
        input.flags = profile.flags
        return payroll.save(input, method: .quick, start: start, end: end, context: context)
    }

    /// Yalnizca senaryonun olusturdugu kayitlari ve tarifeleri siler; ayarlari senaryo oncesine dondurur.
    func clear() {
        let recordIDs: Set<UUID> = Set(payroll.state.demoRecordIDs)
        let logIDs: Set<UUID> = Set(payroll.state.demoLogIDs)
        if !recordIDs.isEmpty {
            let records: [EarningRecord] = (try? context.fetch(FetchDescriptor<EarningRecord>())) ?? []
            for record in records where recordIDs.contains(record.id) {
                try? context.deleteEarning(record)
            }
            try? context.save()
        }
        payroll.store.removeLogs(ids: logIDs)
        for version in payroll.state.userTariffs where version.id.hasPrefix("demo-") {
            payroll.deleteUserTariff(version)
        }
        payroll.store.setDemoIDs(records: [], logs: [])
        restoreSettings()
        payroll.reloadState()
    }

    private func backupSettings() {
        guard defaults.data(forKey: DemoScenarioLoader.backupKey) == nil else { return }
        let s: PayrollState = payroll.state
        let backup = DemoBackup(activePlatform: s.activePlatform, regionTier: s.regionTier, seniorityYears: s.seniorityYears,
                                vehicleType: s.vehicleType, flags: s.flags, goal: s.goal, fuel: s.fuel)
        defaults.set(try? JSONEncoder().encode(backup), forKey: DemoScenarioLoader.backupKey)
    }

    private func restoreSettings() {
        guard let data = defaults.data(forKey: DemoScenarioLoader.backupKey),
              let backup = try? JSONDecoder().decode(DemoBackup.self, from: data) else { return }
        if let platform = backup.activePlatform {
            payroll.chooseFirm(platform, regionTier: backup.regionTier, seniorityYears: backup.seniorityYears,
                               vehicleType: backup.vehicleType, flags: backup.flags)
        }
        payroll.setGoal(backup.goal)
        payroll.store.replaceFuel(backup.fuel)
        defaults.removeObject(forKey: DemoScenarioLoader.backupKey)
    }
}

/// Senaryo oncesi ayarlar.
struct DemoBackup: Codable {
    var activePlatform: String?
    var regionTier: String?
    var seniorityYears: Int?
    var vehicleType: String?
    var flags: [String]
    var goal: GoalSpec?
    var fuel: FuelSettings
}
