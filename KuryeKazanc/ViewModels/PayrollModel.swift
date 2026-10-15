import Foundation
import Observation
import SwiftData

/// Hakedis ekranlarinin ortak modeli. Dort giris yontemi (hizli, detayli, donem, odeme karsilastirma) ayni motoru
/// (`PayEngine`) ve ayni tarife katalogunu kullanir; kayitlar `PayrollStore`'da dondurulmus sonuclariyla saklanir.
@MainActor
@Observable
final class PayrollModel {
    /// Deponun gozlenebilir kopyasi (her degisiklikten sonra yenilenir).
    private(set) var state: PayrollState
    private(set) var lastError: String?

    let store: PayrollStore
    let tariffs: TariffSyncService
    private let calendar: Calendar
    private let clock: () -> Date

    init(store: PayrollStore, tariffs: TariffSyncService, calendar: Calendar = .current, clock: @escaping () -> Date = { Date() }) {
        self.store = store
        self.tariffs = tariffs
        self.calendar = calendar
        self.clock = clock
        self.state = store.state
    }

    nonisolated static func defaultFileURL() -> URL {
        let base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("payroll.json")
    }

    private func reload() {
        state = store.state
    }

    // MARK: - Katalog ve motor

    /// Katalog yalnizca uzak / kullanici surumleri degisince yeniden kurulur (gorunum govdeleri sik okur).
    var catalog: TariffCatalog {
        let key: String = catalogKey
        if let cached = catalogCache, cached.key == key { return cached.catalog }
        let merged = TariffCatalog.merged(bundled: BundledTariffs.all, remote: tariffs.remoteVersions, user: state.userTariffs)
        catalogCache = (key, merged)
        return merged
    }

    @ObservationIgnored private var catalogCache: (key: String, catalog: TariffCatalog)?
    @ObservationIgnored private var planCache: (key: PlanCacheKey, result: Result<GoalPlan, PayError>)?
    @ObservationIgnored private var comparisonCache: (key: PlanCacheKey, rows: [FirmComparisonRow])?
    @ObservationIgnored private var alternativesCache: (key: PlanCacheKey, items: [GoalAlternative])?

    private var catalogKey: String {
        let versions: [TariffVersion] = tariffs.remoteVersions + state.userTariffs
        return versions.map { v in
            "\(v.id).\(v.revision).\(v.approvalStatus.rawValue).\(v.effectiveFrom).\(v.effectiveUntil ?? "").\(v.items.count)"
        }.joined(separator: ",")
    }

    /// Plan ve karsilastirma onbellek anahtari: girdilerden biri degismedikce motor yeniden calismaz.
    private struct PlanCacheKey: Equatable {
        var catalog: String
        var profile: CourierTariffProfile?
        var goal: GoalSpec?
        var fuel: FuelSettings
        var pace: PaceEstimate?
        var workload: WorkloadSpec?
        var day: String
        var fallback: Double
    }

    var engine: PayEngine { PayEngine(catalog: catalog) }

    var aggregator: PeriodAggregator {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return PeriodAggregator(engine: engine, calendar: c)
    }

    var activePlatform: PayPlatform? { state.activePlatform.flatMap { PayPlatform.named($0) } }

    func day(_ date: Date) -> String { RuleDay.string(date, calendar: calendar) }
    var today: String { day(clock()) }

    /// Aktif platformun bugunku tarife surumu (gosterim icin).
    func currentVersion(platform: String? = nil) -> TariffVersion? {
        guard let code = platform ?? state.activePlatform else { return nil }
        return catalog.current(platform: code, day: today)
    }

    // MARK: - Platform ve tercihler

    func select(platform code: String) {
        store.select(platform: code, at: clock())
        reload()
    }

    func setPreferences(regionTier: String?, seniorityYears: Int?, vehicleType: String?) {
        store.setPreferences(regionTier: regionTier, seniorityYears: seniorityYears, vehicleType: vehicleType)
        reload()
    }

    /// Kayitli tercihlerle doldurulmus girdi (aktif platform).
    func baseInput(day: String, span: PaySpan = .day, end: String? = nil) -> PayInput? {
        guard let code = state.activePlatform else { return nil }
        var input = PayInput(platformCode: code, span: span, startDay: day, endDay: end)
        input.regionTier = state.regionTier
        input.seniorityYears = state.seniorityYears
        input.flags = state.flags
        input.contractHours = state.contractHours
        return input
    }

    /// Kaydin tarife surumu (gecmis kayitta o gunku surum; bulunamazsa guncel).
    func version(id: String) -> TariffVersion? {
        catalog.versions.first { $0.id == id } ?? currentVersion()
    }

    /// Ayrintili dokum: kalem kalem, gune dusen paylariyla. Gunluk / haftalik hesapta aylik sabit ucretin payi tahmin olarak eklenir.
    func detail(for breakdown: PayBreakdown, days: Int) -> PayDetail {
        PayDetailBuilder.make(breakdown: breakdown, days: days, version: version(id: breakdown.tariffVersionID),
                              regionTier: state.regionTier, monthWorkDays: state.goal?.monthWorkDays ?? 26,
                              contractHours: state.contractHours, seniorityYears: state.seniorityYears)
    }

    /// Aylik sabit ucretin (ve kidem priminin) bugune dusen payi: Paket Taxi'de calisilan gun bir kez eklenir.
    func fixedShareToday() -> Money {
        fixedShareRowsToday().map(\.perDay).sum()
    }

    /// Sabit ucret kalemleri ve bugune dusen paylari (Bugun dokumu kalem kalem gosterir).
    func fixedShareRowsToday() -> [PayDetailRow] {
        guard let version = currentVersion() else { return [] }
        return PayDetailBuilder.fixedShares(version: version, day: today, regionTier: state.regionTier, days: 1,
                                            monthWorkDays: state.goal?.monthWorkDays ?? 26, contractHours: state.contractHours,
                                            seniorityYears: state.seniorityYears)
    }

    /// Konumdan gelen bolge onerisini profile yazar (yalnizca degisiklik varsa).
    func applyRegion(_ suggestion: RegionSuggestion) {
        guard suggestion.changed else { return }
        store.setPreferences(regionTier: suggestion.regionTier, seniorityYears: state.seniorityYears, vehicleType: state.vehicleType)
        store.setFlags(suggestion.flags)
        reload()
    }

    func setContractHours(_ hours: Int?) {
        store.setContractHours(hours)
        reload()
    }

    func setRegionTier(_ tier: String) {
        store.setPreferences(regionTier: tier, seniorityYears: state.seniorityYears, vehicleType: state.vehicleType)
        reload()
    }

    func calculate(_ input: PayInput) -> Result<PayBreakdown, PayError> {
        engine.calculate(input)
    }

    // MARK: - Kayitlar

    var logs: [WorkLog] {
        state.logs.sorted { (a: WorkLog, b: WorkLog) -> Bool in
            if a.startDay != b.startDay { return a.startDay > b.startDay }
            return a.createdAt > b.createdAt
        }
    }

    func logs(platform: String) -> [WorkLog] { logs.filter { $0.platformCode == platform } }

    /// Kaydeder. Gunluk kayit icin mevcut Bugun/Analiz ekranlarina yansiyan bir kazanc kaydi da olusturulur.
    @discardableResult
    /// - Parameter recordKm: Kazanc kaydina (yakit gideri) yazilacak yol; nil ise girdinin mesafesi.
    func save(_ input: PayInput, method: EntryMethod, start: Date? = nil, end: Date? = nil, recordKm: Double? = nil,
              context: ModelContext?) -> WorkLog? {
        lastError = nil
        let breakdown: PayBreakdown
        switch calculate(input) {
        case let .success(value): breakdown = value
        case let .failure(error):
            lastError = error.message
            return nil
        }
        let log = WorkLog(method: method, input: input, result: breakdown, createdAt: clock())
        do {
            try store.add(log)
        } catch let error as PayrollStoreError {
            lastError = error.message
            return nil
        } catch {
            lastError = error.localizedDescription
            return nil
        }
        if input.span == .day, let context {
            let recordID: UUID? = createEarningRecord(for: log, start: start, end: end, km: recordKm, context: context)
            if let recordID { store.linkEarningRecord(recordID, to: log.id) }
        }
        reload()
        return store.log(id: log.id)
    }

    private func createEarningRecord(for log: WorkLog, start: Date?, end: Date?, km: Double?, context: ModelContext) -> UUID? {
        let parts: [Int] = log.startDay.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let localDay: Date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 9)) ?? clock()
        let hours: Double = log.input.hours.doubleValue
        // Elle eklenen kayitlar ayni saate (09:00) yigilmasin: o gunun son kaydinin bitisinden baslar.
        // Ust uste binen araliklar calisma suresinde bir kez sayildigindan saat basi kazanc sisiyordu.
        let recordStart: Date = start ?? nextFreeStart(day: localDay, context: context)
        let recordEnd: Date = end ?? recordStart.addingTimeInterval(max(hours, 0) * 3600)
        let code: String = log.platformCode
        let platform: Platform? = try? context.fetch(FetchDescriptor<Platform>(predicate: #Predicate { $0.code == code })).first
        let bonus: Money = log.result.bonusTotal
        let gross: Money = log.result.gross - bonus + log.result.tips + log.result.extraPayments
        let record = EarningRecord(
            startTime: recordStart, endTime: recordEnd, platform: platform, grossEarning: gross.doubleValue,
            bonus: bonus.doubleValue, distanceKm: km ?? log.input.distanceKm.doubleValue,
            packageCount: log.input.totalPackages, source: .manual, verification: .manual
        )
        context.insert(record)
        try? context.save()
        return record.id
    }

    /// Gunun kayitlarinin en gec bitisi (09:00'dan once degil); kayit yoksa 09:00.
    private func nextFreeStart(day localDay: Date, context: ModelContext) -> Date {
        let dayStart: Date = calendar.startOfDay(for: localDay)
        let descriptor = FetchDescriptor<EarningRecord>(predicate: #Predicate { $0.date == dayStart })
        let records: [EarningRecord] = (try? context.fetch(descriptor)) ?? []
        let latestEnd: Date? = records.map(\.endTime).max()
        guard let latestEnd, latestEnd > localDay else { return localDay }
        return latestEnd
    }

    func delete(_ log: WorkLog, context: ModelContext?) {
        if let recordID = log.earningRecordID, let context {
            let id: UUID = recordID
            if let record = try? context.fetch(FetchDescriptor<EarningRecord>(predicate: #Predicate { $0.id == id })).first {
                context.delete(record)
                try? context.save()
            }
        }
        store.deleteLog(id: log.id)
        reload()
    }

    /// Acik yeniden hesaplama (kullanici istegiyle). Sonuc degismediyse nil.
    func recalculate(_ log: WorkLog, reason: String) -> Recalculation? {
        lastError = nil
        do {
            let result: Recalculation? = try store.recalculate(logID: log.id, engine: engine, reason: reason, at: clock())
            reload()
            if result == nil { lastError = "Güncel tarifeyle sonuç aynı; değişiklik kaydedilmedi." }
            return result
        } catch {
            lastError = PayrollStoreError.notFound.message
            return nil
        }
    }

    func setAdjustment(_ amount: Money?, note: String?, log: WorkLog) {
        store.setAdjustment(amount, note: note, logID: log.id)
        reload()
    }

    // MARK: - Donem ve pano

    func monthRange(containing date: Date) -> (start: String, end: String) {
        aggregator.monthRange(containing: day(date)) ?? (today, today)
    }

    func weekRange(containing date: Date) -> (start: String, end: String) {
        aggregator.weekRange(containing: day(date)) ?? (today, today)
    }

    func period(platform: String, start: String, end: String) -> PeriodResult {
        var preferences = PayInput(platformCode: platform, startDay: start, endDay: end)
        preferences.regionTier = state.regionTier
        preferences.seniorityYears = state.seniorityYears
        preferences.contractHours = state.contractHours
        preferences.flags = state.flags
        let isMonth: Bool = aggregator.monthRange(containing: start).map { $0.start == start && $0.end == end } ?? false
        return aggregator.summarize(platform: platform, logs: state.logs, start: start, end: end, preferences: preferences,
                                    includeMonthly: isMonth)
    }

    /// - Parameter fallbackCostPerKm: verilirse (otomatik gider tahmini acik) ve ayda elle yakit gideri yoksa km'den yakit dusulur.
    func dashboard(expenses: [DatedExpense], month date: Date = Date(), fallbackCostPerKm: Double? = nil) -> PayrollDashboard? {
        guard let code = state.activePlatform else { return nil }
        let range = monthRange(containing: date)
        let result: PeriodResult = period(platform: code, start: range.start, end: range.end)
        let inMonth: [DatedExpense] = expenses.filter { $0.day >= range.start && $0.day <= range.end }
        let monthExpenses: Money = inMonth.map(\.amount).sum()
        let lastPayment: PaymentRecord? = store.payments(platform: code).first { $0.periodEnd >= range.start }
        var fuel: Money = .zero
        if let fallbackCostPerKm, !inMonth.contains(where: { $0.category == .fuel }) {
            fuel = fuelModel(fallbackCostPerKm: fallbackCostPerKm).cost(km: result.km, on: today)
        }
        return PayrollDashboard(period: result, expenses: monthExpenses, paymentDifference: lastPayment?.difference,
                                fuel: fuel, monthWorkDays: state.goal?.monthWorkDays ?? 26)
    }

    // MARK: - Odeme kontrolu

    func reconcile(platform: String, start: String, end: String, actual: Money, advances: Money, deductions: Money) -> (PeriodResult, Reconciliation) {
        let result: PeriodResult = period(platform: platform, start: start, end: end)
        let days: Int = (RuleDay.days(from: start, to: end) ?? 0) + 1
        let reconciliation = PaymentReconciler.reconcile(period: result, actual: actual, advances: advances, deductions: deductions,
                                                         periodDays: days)
        return (result, reconciliation)
    }

    func savePayment(platform: String, start: String, end: String, paidOn: String, actual: Money, advances: Money,
                     deductions: Money, note: String) {
        let result: PeriodResult = period(platform: platform, start: start, end: end)
        let payment = PaymentRecord(platformCode: platform, periodStart: start, periodEnd: end, paidOn: paidOn, actualAmount: actual,
                                    advances: advances, deductions: deductions, note: note, expected: result.prePayment,
                                    expectedUpper: result.prePaymentUpper, createdAt: clock())
        store.add(payment)
        reload()
    }

    func deletePayment(_ payment: PaymentRecord) {
        store.deletePayment(id: payment.id)
        reload()
    }

    // MARK: - Kullanici tarifesi

    func saveUserTariff(_ version: TariffVersion, activate: Bool) -> Bool {
        lastError = nil
        do {
            try store.saveUserTariff(version, activate: activate)
            reload()
            return true
        } catch let error as PayrollStoreError {
            lastError = error.message
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func deleteUserTariff(_ version: TariffVersion) {
        store.deleteUserTariff(id: version.id)
        reload()
    }

    /// Aktif firmanin kullanici degerleriyle degistirilmis (onayli) tarifesi var mi.
    var hasEditedTariff: Bool {
        guard let code = state.activePlatform else { return false }
        return state.userTariffs.contains { $0.platformCode == code && $0.approvalStatus.isUsableForCalculation }
    }

    /// Firmanin yayimladigi (kullanici degeri karismamis) guncel tarife: kalem ekraninda "Firma: X" olarak gosterilir.
    func firmVersion() -> TariffVersion? {
        guard let code = state.activePlatform else { return nil }
        return TariffCatalog.merged(bundled: BundledTariffs.all, remote: tariffs.remoteVersions, user: [])
            .current(platform: code, day: today)
    }

    /// Kalem ekrani: degisen tutarlarla yeni kullanici tarifesi kaydedilir ve hemen kullanilir; onceki duzenleme yerini alir.
    /// Degisiklik yoksa (ya da hepsi firma degerine donduyse) firma tarifesine donulur.
    func applyTariffEdits(_ amounts: [String: Money]) -> Bool {
        guard let code = state.activePlatform, let base = firmVersion() else { return false }
        let id: String = "user-edit-\(code)-\(Int(clock().timeIntervalSince1970))"
        let edited: TariffVersion? = TariffImport.editedVersion(base: base, amounts: amounts, today: today, id: id)
        for version in state.userTariffs where version.platformCode == code {
            store.deleteUserTariff(id: version.id)
        }
        guard let edited else {
            reload()
            return true
        }
        return saveUserTariff(edited, activate: true)
    }

    /// Kullanici degerleri silinir; firmanin tarifesi kullanilir.
    func resetToFirmTariff() {
        guard let code = state.activePlatform else { return }
        for version in state.userTariffs where version.platformCode == code {
            store.deleteUserTariff(id: version.id)
        }
        reload()
    }

    // MARK: - 1.7 firma, hedef, yakit

    var tariffProfile: CourierTariffProfile? { state.tariffProfile }
    var goal: GoalSpec? { state.goal }

    nonisolated static func platformName(_ code: String) -> String { PayPlatform.named(code)?.name ?? code }

    func questions(for platform: String) -> TariffQuestions {
        TariffQuestions.required(platform: platform, catalog: catalog, day: today)
    }

    /// Calisilan tek firmayi ve tarifesinin istedigi kisisel bilgileri kaydeder.
    func chooseFirm(_ code: String, regionTier: String?, seniorityYears: Int?, vehicleType: String?, flags: [String],
                    contractHours: Int? = nil) {
        store.select(platform: code, at: clock())
        store.setPreferences(regionTier: regionTier, seniorityYears: seniorityYears, vehicleType: vehicleType)
        store.setFlags(flags)
        store.setContractHours(contractHours)
        reload()
    }

    /// 1.9 gecisi: Getir / Trendyol GO secen kullanici firmasini yeniden secer (eski kayitlar kalir);
    /// eski Paket Taxi "plus" bolgesi 1. bolge olur, Yemeksepeti Ankara/Izmir isareti sehir grubuna donusur.
    /// - Returns: Firma secimi sifirlandiysa true.
    @discardableResult
    func migrateTo19() -> Bool {
        if let code = state.activePlatform, PayPlatform.named(code) == nil {
            store.resetFirmChoice()
            reload()
            return true
        }
        var tier: String? = state.regionTier
        var flags: [String] = state.flags
        switch (state.activePlatform, tier) {
        case (_, "plus"?): tier = "r1"
        case (_, "standard"?): tier = nil
        default: break
        }
        if flags.contains("ys_ankara_izmir") {
            flags.removeAll { $0 == "ys_ankara_izmir" }
            if state.activePlatform == "yemeksepeti", tier == nil { tier = "ys_ankara_izmir" }
        }
        guard tier != state.regionTier || flags != state.flags else { return false }
        store.setPreferences(regionTier: tier, seniorityYears: state.seniorityYears, vehicleType: state.vehicleType)
        store.setFlags(flags)
        reload()
        return false
    }

    func setGoal(_ goal: GoalSpec?) {
        store.setGoal(goal)
        reload()
    }

    /// 1.6'daki haftalik/gunluk net hedef anahtarlarini bir kez yeni hedefe tasir.
    func migrateLegacyGoal(defaults: UserDefaults) {
        guard state.goal == nil else { return }
        let weekly: Double = defaults.double(forKey: AppPreferences.weeklyGoalKey)
        let daily: Double = defaults.double(forKey: AppPreferences.dailyGoalKey)
        if weekly > 0 {
            setGoal(GoalSpec(amount: Money(double: weekly), period: .week))
        } else if daily > 0 {
            setGoal(GoalSpec(amount: Money(double: daily), period: .day))
        }
        // Bir kerelik: eski anahtarlar silinir (hedef sonradan kaldirilirsa geri gelmesin)
        defaults.removeObject(forKey: AppPreferences.weeklyGoalKey)
        defaults.removeObject(forKey: AppPreferences.dailyGoalKey)
    }

    func addFuelPrice(_ price: Money, type: FuelType, on date: Date) {
        store.addFuelPrice(FuelPriceEntry(day: day(date), pricePerUnit: price, type: type))
        reload()
    }

    func deleteFuelPrice(_ id: UUID) {
        store.deleteFuelPrice(id: id)
        reload()
    }

    func setConsumption(_ value: Decimal?) {
        store.setConsumption(value)
        reload()
    }

    func fuelModel(fallbackCostPerKm: Double) -> FuelCostModel {
        FuelCostModel(settings: state.fuel, vehicleType: state.vehicleType, fallbackCostPerKm: Money(double: fallbackCostPerKm))
    }

    func pace(entries: [EarningEntry]) -> PaceEstimate {
        PaceEstimate.estimate(entries: entries, platform: state.activePlatform ?? "", now: clock(),
                              userPackagesPerHour: state.packagesPerHour)
    }

    /// Kayitlardan olculen hiz (kullanicinin girdigi deger yok sayilir): ayarlarda karsilastirma icin.
    func measuredPace(entries: [EarningEntry]) -> PaceEstimate {
        PaceEstimate.estimate(entries: entries, platform: state.activePlatform ?? "", now: clock(), userPackagesPerHour: nil)
    }

    /// Kullanicinin girdigi hiz; nil olcume / varsayilana doner.
    func setPackagesPerHour(_ value: Decimal?) {
        store.setPackagesPerHour(value)
        reload()
    }

    /// Secili firmanin tarifesiyle hedef plani; firma ya da hedef yoksa nil.
    func goalPlan(entries: [EarningEntry], fallbackCostPerKm: Double) -> Result<GoalPlan, PayError>? {
        guard let profile = tariffProfile, let goal = state.goal else { return nil }
        let currentPace: PaceEstimate = pace(entries: entries)
        let key = PlanCacheKey(catalog: catalogKey, profile: profile, goal: goal, fuel: state.fuel, pace: currentPace,
                               workload: nil, day: today, fallback: fallbackCostPerKm)
        if let cached = planCache, cached.key == key { return cached.result }
        let planner = GoalPlanner(engine: engine, fuel: fuelModel(fallbackCostPerKm: fallbackCostPerKm))
        let result: Result<GoalPlan, PayError> = planner.plan(goal: goal, profile: profile, pace: currentPace, day: today)
        planCache = (key, result)
        return result
    }

    /// Kayitli hedefe giden alternatif yollar (daha az saat / bonus esigi / sonraki kademe / aksam bandi).
    func goalAlternatives(entries: [EarningEntry], fallbackCostPerKm: Double) -> [GoalAlternative] {
        guard let profile = tariffProfile, let goal = state.goal,
              case let .success(plan)? = goalPlan(entries: entries, fallbackCostPerKm: fallbackCostPerKm) else { return [] }
        let currentPace: PaceEstimate = pace(entries: entries)
        let key = PlanCacheKey(catalog: catalogKey, profile: profile, goal: goal, fuel: state.fuel, pace: currentPace,
                               workload: nil, day: today, fallback: fallbackCostPerKm)
        if let cached = alternativesCache, cached.key == key { return cached.items }
        let planner = GoalPlanner(engine: engine, fuel: fuelModel(fallbackCostPerKm: fallbackCostPerKm))
        let items: [GoalAlternative] = GoalAlternatives.suggest(base: plan, planner: planner, profile: profile,
                                                                pace: currentPace, day: today)
        alternativesCache = (key, items)
        return items
    }

    func comparison(workload: WorkloadSpec, fallbackCostPerKm: Double) -> [FirmComparisonRow] {
        guard let profile = tariffProfile else { return [] }
        let key = PlanCacheKey(catalog: catalogKey, profile: profile, goal: nil, fuel: state.fuel, pace: nil,
                               workload: workload, day: today, fallback: fallbackCostPerKm)
        if let cached = comparisonCache, cached.key == key { return cached.rows }
        let rows: [FirmComparisonRow] = TariffComparison.rows(workload: workload, profile: profile, catalog: catalog,
                                                              fuel: fuelModel(fallbackCostPerKm: fallbackCostPerKm), day: today)
        comparisonCache = (key, rows)
        return rows
    }

    func correlation(platform: String, fallbackCostPerKm: Double) -> TariffFuelCorrelation? {
        TariffFuelCorrelation.evaluate(platform: platform, catalog: catalog,
                                       fuel: fuelModel(fallbackCostPerKm: fallbackCostPerKm), today: today)
    }

    /// Henuz gosterilmemis gecis onerisi (ayni surum cifti icin bir kez).
    func pendingSwitchSuggestion(workload: WorkloadSpec, fallbackCostPerKm: Double) -> SwitchSuggestion? {
        let rows: [FirmComparisonRow] = comparison(workload: workload, fallbackCostPerKm: fallbackCostPerKm)
        guard let suggestion = TariffComparison.switchSuggestion(rows: rows) else { return nil }
        return state.seenEventIDs.contains("switch:" + suggestion.key) ? nil : suggestion
    }

    func markSwitchSeen(_ suggestion: SwitchSuggestion) {
        store.markEventsSeen(["switch:" + suggestion.key])
        reload()
    }

    /// Tarife esitlemesinden sonra: yeni bir gecis onerisi varsa bir kez bildirilmek uzere dondurur
    /// (bildirim kaydi ayri tutulur; Firmalar ekranindaki serit "Anladim"a kadar kalir).
    func switchSuggestionToNotify(entries: [EarningEntry], fallbackCostPerKm: Double) -> SwitchSuggestion? {
        let workload = WorkloadSpec.from(pace: pace(entries: entries), goal: state.goal)
        // Yalnizca tarife surumleri degistiyse: ilk degerlendirme (kurulum / guncelleme) sessizce taban olur
        let rows: [FirmComparisonRow] = comparison(workload: workload, fallbackCostPerKm: fallbackCostPerKm)
        guard !rows.isEmpty else { return nil }
        let baseline: String = rows.map(\.versionID).sorted().joined(separator: "|")
        let previous: String? = state.switchBaseline
        if previous != baseline {
            store.setSwitchBaseline(baseline)
            reload()
        }
        guard let previous, previous != baseline else { return nil }
        guard let suggestion = pendingSwitchSuggestion(workload: workload, fallbackCostPerKm: fallbackCostPerKm) else { return nil }
        let key: String = "notified:" + suggestion.key
        guard !state.seenEventIDs.contains(key) else { return nil }
        store.markEventsSeen([key])
        reload()
        return suggestion
    }

    /// Senaryo yukleyici gibi depoya dogrudan yazanlar icin.
    func reloadState() { reload() }

    // MARK: - Bildirimler

    var unreadNoticeCount: Int {
        guard let code = state.activePlatform else { return 0 }
        return state.notices.filter { $0.platformCode == code && !$0.isRead }.count
    }

    /// Aktif platformun yeni tarife olaylarini bildirim yapar. Diger platformlarin olaylari istenmez bile.
    func refreshNotices() async {
        guard let code = state.activePlatform else { return }
        let events: [TariffChangeEvent] = await tariffs.events(platform: code)
        let notices: [TariffNotice] = TariffNotifier.notices(from: events, activePlatform: code, seen: store.seenEventIDs, now: clock())
        guard !notices.isEmpty else { return }
        store.addNotices(notices, eventIDs: events.map(\.id))
        reload()
    }

    func markNoticesRead() {
        guard let code = state.activePlatform else { return }
        store.markNoticesRead(platform: code)
        reload()
    }
}

extension ExpenseRecord {
    var datedExpense: DatedExpense {
        DatedExpense(day: RuleDay.string(date, calendar: .current), category: type, amount: Money(Decimal(amount)))
    }
}
