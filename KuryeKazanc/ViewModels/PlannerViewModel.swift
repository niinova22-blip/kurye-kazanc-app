import Foundation
import Observation

/// Calisma profili ve kayitli planin kalici deposu (UserDefaults, JSON). Kullanici verisidir; kurallardan ayridir.
enum WorkProfileStore {
    static func load(_ defaults: UserDefaults = .standard) -> WorkProfile? {
        guard let data = defaults.data(forKey: AppPreferences.workProfileKey) else { return nil }
        return try? JSONDecoder().decode(WorkProfile.self, from: data)
    }

    static func save(_ profile: WorkProfile, _ defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: AppPreferences.workProfileKey)
    }

    static func loadPlan(_ defaults: UserDefaults = .standard) -> SavedPlan? {
        guard let data = defaults.data(forKey: AppPreferences.savedPlanKey) else { return nil }
        return try? JSONDecoder().decode(SavedPlan.self, from: data)
    }

    static func savePlan(_ plan: SavedPlan?, _ defaults: UserDefaults = .standard) {
        guard let plan, let data = try? JSONEncoder().encode(plan) else {
            defaults.removeObject(forKey: AppPreferences.savedPlanKey)
            return
        }
        defaults.set(data, forKey: AppPreferences.savedPlanKey)
    }

    /// Ilk profil: son 8 haftada kaydi olan platformlar aktif, gider ve hedef mevcut ayarlardan, her gun 10:00-23:00 uygun.
    static func initialProfile(entries: [EarningEntry], defaults: UserDefaults = .standard, now: Date = .now, calendar: Calendar = .current) -> WorkProfile {
        var profile = WorkProfile()
        let cutoff: Date = calendar.date(byAdding: .day, value: -56, to: now) ?? .distantPast
        let used: Set<String> = Set(entries.filter { $0.start >= cutoff }.compactMap(\.platformCode))
        profile.platforms = Platform.defaults
            .filter { $0.code != "other" }
            .map { PlatformProfile(code: $0.code, isActive: used.contains($0.code), courierModel: .esnaf, offeredHourlyRate: nil) }
        var availability: [Int: [TimeRange]] = [:]
        for weekday in 1...7 { availability[weekday] = [TimeRange(startMinute: 10 * 60, endMinute: 23 * 60)] }
        profile.availability = availability
        let cost: Double = defaults.object(forKey: AppPreferences.costPerKmKey) as? Double ?? AppPreferences.defaultCostPerKm
        profile.costPerKm = cost
        let daily: Double = defaults.double(forKey: AppPreferences.dailyGoalKey)
        profile.dailyNetTarget = daily > 0 ? daily : nil
        return profile
    }
}

/// Plan oner ekrani: profil, kural kumesi ve kayitlarla oneri uretir; kullanici kural onaylarini ve secilen plani saklar.
@MainActor
@Observable
final class PlannerViewModel {
    private(set) var profile: WorkProfile
    private(set) var result: PlannerResult?
    private(set) var savedPlan: SavedPlan?
    private(set) var savedPlanCheck: PlanCheck?
    var day: Date

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var rules: RuleSet
    private var entries: [EarningEntry] = []
    private var community: [CommunityCell] = []
    private var names: [String: String] = [:]

    init(rules: RuleSet, entries: [EarningEntry], defaults: UserDefaults = .standard, calendar: Calendar = .current, day: Date = .now) {
        self.rules = rules
        self.entries = entries
        self.defaults = defaults
        self.calendar = calendar
        self.day = calendar.startOfDay(for: day)
        self.profile = WorkProfileStore.load(defaults)
            ?? WorkProfileStore.initialProfile(entries: entries, defaults: defaults, now: day, calendar: calendar)
        self.savedPlan = WorkProfileStore.loadPlan(defaults)
    }

    var ruleSet: RuleSet { rules }
    var hasActivePlatform: Bool { !profile.activePlatformCodes.isEmpty }

    func name(_ code: String) -> String {
        Self.displayName(code, names: names)
    }

    static func displayName(_ code: String, names: [String: String]) -> String {
        if let name = names[code] { return name }
        if let item = Platform.defaults.first(where: { $0.code == code }) { return item.name }
        return code
    }

    func update(rules: RuleSet? = nil, entries: [EarningEntry]? = nil, community: [CommunityCell]? = nil, names: [String: String]? = nil) {
        if let rules { self.rules = rules }
        if let entries { self.entries = entries }
        if let community { self.community = community }
        if let names { self.names = names }
    }

    var engine: PlanEngine {
        var e = PlanEngine(calendar: calendar, rules: rules, profile: profile, entries: entries, community: community)
        let lookup: [String: String] = names
        e.platformName = { code in PlannerViewModel.displayName(code, names: lookup) }
        return e
    }

    func plan() {
        result = engine.propose(day: day)
        checkSavedPlan()
    }

    func checkSavedPlan() {
        guard let savedPlan else {
            savedPlanCheck = nil
            return
        }
        savedPlanCheck = engine.check(savedPlan)
    }

    func choose(_ proposal: PlanProposal) {
        let plan: SavedPlan = engine.save(proposal, day: day)
        savedPlan = plan
        WorkProfileStore.savePlan(plan, defaults)
        checkSavedPlan()
    }

    func clearSavedPlan() {
        savedPlan = nil
        savedPlanCheck = nil
        WorkProfileStore.savePlan(nil, defaults)
    }

    /// Kullanici bir kosulu kendi sozlesmesine gore onaylar ya da reddeder (nil: karari geri al). Plan yeniden hesaplanir.
    func setConfirmation(_ decision: RuleConfirmation?, ruleID: String) {
        profile.ruleConfirmations[ruleID] = decision
        saveProfile(profile)
    }

    func saveProfile(_ newProfile: WorkProfile) {
        profile = newProfile
        WorkProfileStore.save(newProfile, defaults)
        if result != nil { plan() } else { checkSavedPlan() }
    }

    /// Kayitli plan bugun icin mi.
    var savedPlanIsForDay: Bool {
        savedPlan?.day == RuleDay.string(day, calendar: calendar)
    }
}
