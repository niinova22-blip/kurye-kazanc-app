import Foundation

/// Bir donemin (hafta / ay / odeme donemi) hakedis ozeti.
struct PeriodResult: Equatable {
    var platformCode: String
    var startDay: String
    var endDay: String
    /// Gunluk kayitlarin dondurulmus gunluk satirlari (kendi tarife surumleriyle).
    var dailyPart: Money
    var dailyPartUpper: Money
    /// Haftalik kalemler (hafta sonu bonusu, haftalik performans) — o haftanin toplamindan.
    var weeklyPart: Money
    /// Aylik kalemler (sabit ucret, aylik kademe) — ayin toplamindan.
    var monthlyPart: Money
    /// Ay sonunda kesinlesecek gunluk tahminler (aylik hesap yapildiysa toplama girmez).
    var provisionalPart: Money
    var provisionalReplaced: Bool
    /// Gunluk kaydi olmayan donem kayitlarinin brutu.
    var periodLogPart: Money
    var tips: Money
    var extraPayments: Money
    var deductions: Money
    var advances: Money
    var packages: Int
    var hours: Decimal
    var km: Decimal
    var logCount: Int
    var daysWithLogs: Int
    var notices: [PayNotice]
    var progress: [BonusProgress]
    var weakestConfidence: ConfidenceStatus
    var tariffVersionIDs: [String]

    var gross: Money {
        dailyPart + weeklyPart + monthlyPart + periodLogPart + (provisionalReplaced ? .zero : provisionalPart)
    }

    var grossUpper: Money {
        dailyPartUpper + weeklyPart + monthlyPart + periodLogPart + (provisionalReplaced ? .zero : provisionalPart)
    }

    var prePayment: Money { gross + tips + extraPayments - deductions - advances }
    var prePaymentUpper: Money { grossUpper + tips + extraPayments - deductions - advances }

    var grossPerHour: Money? {
        guard hours > 0 else { return nil }
        return Money(gross.value / hours)
    }

    var needsVerification: Bool { weakestConfidence == .needsVerification }

    static func empty(platform: String, start: String, end: String) -> PeriodResult {
        PeriodResult(platformCode: platform, startDay: start, endDay: end, dailyPart: .zero, dailyPartUpper: .zero,
                     weeklyPart: .zero, monthlyPart: .zero, provisionalPart: .zero, provisionalReplaced: false,
                     periodLogPart: .zero, tips: .zero, extraPayments: .zero, deductions: .zero, advances: .zero,
                     packages: 0, hours: 0, km: 0, logCount: 0, daysWithLogs: 0, notices: [], progress: [],
                     weakestConfidence: .verified, tariffVersionIDs: [])
    }
}

/// Gunluk kayitlardan donem toplami. Kural: gunluk satirlar kayitlarin dondurulmus sonucundan; haftalik ve aylik
/// kalemler o hafta / ayin toplam girdisiyle motordan. Ayni kalem iki kez sayilmaz.
struct PeriodAggregator {
    var engine: PayEngine
    var calendar: Calendar

    init(engine: PayEngine, calendar: Calendar = PeriodAggregator.utcCalendar) {
        self.engine = engine
        self.calendar = calendar
    }

    static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    func summarize(platform: String, logs allLogs: [WorkLog], start: String, end: String,
                   preferences: PayInput? = nil, includeMonthly: Bool = true) -> PeriodResult {
        var result = PeriodResult.empty(platform: platform, start: start, end: end)
        let logs: [WorkLog] = allLogs.filter { $0.platformCode == platform }
        let daily: [WorkLog] = logs.filter { $0.isDaily && $0.startDay >= start && $0.startDay <= end }
        let periodLogs: [WorkLog] = logs.filter { log in
            !log.isDaily && log.startDay >= start && log.endDay <= end
                && !logs.contains { $0.isDaily && $0.overlaps(start: log.startDay, end: log.endDay) }
        }
        var confidences: [ConfidenceStatus] = []
        var versions: Set<String> = []
        var days: Set<String> = []

        for log in daily {
            let lines: [PayLine] = log.result.lines.filter { $0.included && $0.isCash && $0.type != .tip && $0.type != .deduction }
            for line in lines where line.scope == .daily {
                if line.provisional {
                    result.provisionalPart += line.low
                } else {
                    result.dailyPart += line.low
                    result.dailyPartUpper += line.high
                }
            }
            if let adjustment = log.manualAdjustment {
                result.dailyPart += adjustment
                result.dailyPartUpper += adjustment
            }
            accumulate(log, into: &result)
            confidences.append(log.result.weakestConfidence)
            versions.insert(log.tariffVersionID)
            days.insert(log.startDay)
        }
        for log in periodLogs {
            result.periodLogPart += log.gross
            accumulate(log, into: &result)
            confidences.append(log.result.weakestConfidence)
            versions.insert(log.tariffVersionID)
            result.notices.append(contentsOf: log.result.notices)
        }

        // Haftalik kalemler: haftasi (Pazartesi–Pazar) bu donemde biten her hafta
        let allWeeks: [(start: String, end: String, counts: Bool)] = weeks(endingIn: start, end)
        for (index, week) in allWeeks.enumerated() {
            let weekLogs: [WorkLog] = logs.filter { $0.isDaily && $0.startDay >= week.start && $0.startDay <= week.end }
            guard !weekLogs.isEmpty else { continue }
            var input: PayInput = aggregateInput(platform: platform, logs: weekLogs, span: .week, start: week.start, end: week.end, preferences: preferences)
            input.weekendPackages = weekendPackages(weekLogs)
            guard case let .success(breakdown) = engine.calculate(input) else { continue }
            if week.counts {
                // Her hafta yalnizca Pazarinin dustugu donemde sayilir (aylar arasinda cift sayim yok)
                let weekly: [PayLine] = breakdown.lines.filter { $0.included && $0.isCash && $0.scope == .weekly }
                result.weeklyPart += weekly.map(\.low).sum()
                if !weekly.isEmpty { versions.insert(breakdown.tariffVersionID) }
            }
            if index == allWeeks.count - 1 {
                result.progress.append(contentsOf: breakdown.progress.filter { $0.unit == .week })
            }
            result.notices.append(contentsOf: breakdown.notices.filter { $0.kind == .ambiguity })
        }

        // Aylik kalemler: donem bir takvim ayi ise
        if includeMonthly, !daily.isEmpty {
            let input: PayInput = aggregateInput(platform: platform, logs: daily, span: .month, start: start, end: end, preferences: preferences)
            if case let .success(breakdown) = engine.calculate(input) {
                let monthly: [PayLine] = breakdown.lines.filter { $0.included && $0.isCash && $0.scope == .monthly }
                if !monthly.isEmpty {
                    result.monthlyPart = monthly.map(\.low).sum()
                    result.provisionalReplaced = breakdown.lines.contains { $0.scope == .monthly && $0.unit == .package }
                    versions.insert(breakdown.tariffVersionID)
                    result.notices.append(contentsOf: breakdown.notices.filter { $0.kind != .info })
                }
                result.progress.append(contentsOf: breakdown.progress.filter { $0.unit == .month })
            }
        }

        // Bugunun / son gunun gunluk bonus ilerlemesi
        if let last = daily.max(by: { $0.startDay < $1.startDay }) {
            result.progress.insert(contentsOf: last.result.progress.filter { $0.unit == .day }, at: 0)
        }
        for log in daily {
            for notice in log.result.notices where notice.kind == .needsVerification || notice.kind == .ambiguity {
                if !result.notices.contains(where: { $0.message == notice.message }) { result.notices.append(notice) }
            }
        }
        result.daysWithLogs = days.count
        result.weakestConfidence = confidences.min() ?? .verified
        result.tariffVersionIDs = versions.sorted()
        return result
    }

    private func accumulate(_ log: WorkLog, into result: inout PeriodResult) {
        result.tips += log.result.tips
        result.extraPayments += log.result.extraPayments
        result.deductions += log.result.totalDeductions
        result.advances += log.result.advances
        result.packages += log.input.periodPackages ?? log.input.totalPackages
        result.hours += log.input.hours
        result.km += log.input.distanceKm
        result.logCount += 1
    }

    /// Donemin gunluk kayitlarindan toplu girdi (donem hesabi ve bonus ilerlemesi icin).
    func aggregateInput(platform: String, logs: [WorkLog], span: PaySpan, start: String, end: String, preferences: PayInput?) -> PayInput {
        var input = PayInput(platformCode: platform, span: span, startDay: start, endDay: end)
        let latest: WorkLog? = logs.max { $0.startDay < $1.startDay }
        input.vehicleType = preferences?.vehicleType ?? latest?.input.vehicleType
        input.regionID = preferences?.regionID ?? latest?.input.regionID
        input.regionTier = preferences?.regionTier ?? latest?.input.regionTier
        input.seniorityYears = preferences?.seniorityYears ?? latest?.input.seniorityYears
        input.workModel = latest?.input.workModel ?? "esnaf"
        var flags: Set<String> = Set(preferences?.flags ?? [])
        for log in logs {
            input.dayPackages += log.input.dayPackages
            input.nightPackages += log.input.nightPackages
            input.combinedPackages += log.input.combinedPackages
            input.hours += log.input.hours
            input.totalKm = (input.totalKm ?? 0) + log.input.distanceKm
            flags.formUnion(log.input.flags)
        }
        input.flags = flags.sorted()
        input.flagAmounts = preferences?.flagAmounts ?? [:]
        input.periodPackages = input.totalPackages
        return input
    }

    /// Cuma, Cumartesi, Pazar paketleri.
    func weekendPackages(_ logs: [WorkLog]) -> Int {
        logs.filter { log in
            guard let date = RuleDay.date(log.startDay) else { return false }
            let weekday: Int = calendar.component(.weekday, from: date)
            return weekday == 6 || weekday == 7 || weekday == 1
        }.map { $0.input.totalPackages }.reduce(0, +)
    }

    /// Pazari bu donemde olan haftalar (Pazartesi–Pazar, `counts` true) ve donem Pazar bitmiyorsa suren hafta
    /// (`counts` false: yalnizca ilerleme gosterilir, tutari Pazarinin dustugu donemde sayilir).
    func weeks(endingIn start: String, _ end: String) -> [(start: String, end: String, counts: Bool)] {
        guard var day = RuleDay.date(start), let last = RuleDay.date(end) else { return [] }
        var result: [(start: String, end: String, counts: Bool)] = []
        while day <= last {
            if calendar.component(.weekday, from: day) == 1 {
                let monday: Date = calendar.date(byAdding: .day, value: -6, to: day) ?? day
                result.append((RuleDay.string(monday, calendar: calendar), RuleDay.string(day, calendar: calendar), true))
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? last.addingTimeInterval(86_400)
        }
        // Donem sonu Pazar degilse suren hafta (ilerleme gosterimi) de eklenir
        if calendar.component(.weekday, from: last) != 1 {
            let weekday: Int = calendar.component(.weekday, from: last)
            let back: Int = (weekday + 5) % 7
            let monday: Date = calendar.date(byAdding: .day, value: -back, to: last) ?? last
            let sunday: Date = calendar.date(byAdding: .day, value: 6, to: monday) ?? last
            result.append((RuleDay.string(monday, calendar: calendar), RuleDay.string(sunday, calendar: calendar), false))
        }
        return result
    }

    /// Takvim ayinin ilk ve son gunu.
    func monthRange(containing day: String) -> (start: String, end: String)? {
        guard let date = RuleDay.date(day),
              let interval = calendar.dateInterval(of: .month, for: date) else { return nil }
        let last: Date = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return (RuleDay.string(interval.start, calendar: calendar), RuleDay.string(last, calendar: calendar))
    }

    func weekRange(containing day: String) -> (start: String, end: String)? {
        guard let date = RuleDay.date(day) else { return nil }
        let weekday: Int = calendar.component(.weekday, from: date)
        let back: Int = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -back, to: date),
              let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return nil }
        return (RuleDay.string(monday, calendar: calendar), RuleDay.string(sunday, calendar: calendar))
    }
}
