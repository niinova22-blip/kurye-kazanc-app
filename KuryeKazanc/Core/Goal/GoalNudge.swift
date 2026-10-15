import Foundation

/// 1.12: hedef kaydedildikten sonra ara ara gelen "hedefe su kadar kaldi" bildirimi.
/// Icerik planlandigi andaki ilerlemeyle yazilir; uygulama her paket / kayitta yeniden planlar.
struct GoalNudge: Equatable {
    var id: String
    var fireDate: Date
    var title: String
    var body: String
}

enum GoalNudgePlanner {
    /// Gun ici hatirlatma saatleri.
    static let slotHours: [Int] = [12, 16, 19]
    /// Kalan sure bu saate gore soylenir.
    static let dayEndHour: Int = 23
    /// Ertesi gun donem ozeti saati.
    static let periodHour: Int = 10
    /// Simdiye bundan yakin hatirlatma planlanmaz.
    static let minimumLead: TimeInterval = 15 * 60
    static let idPrefix = "reminder.goalNudge."
    static var allIDs: [String] { slotHours.indices.map { idPrefix + "\($0)" } + [idPrefix + "period"] }

    // MARK: - Gun ici

    /// Bugunun kalan saatlerine dusen hatirlatmalar. Hedef tamamsa, bugun calisma gunu degilse ya da gunluk paket hedefi
    /// yoksa bos.
    static func today(progress: DailyGoalProgress, packagesPerHour: Decimal, now: Date, calendar: Calendar,
                      isWorkDay: Bool) -> [GoalNudge] {
        guard isWorkDay, progress.targetPackages > 0 else { return [] }
        let remaining: Int = progress.remainingPackages
        guard remaining > 0 else { return [] }
        let remainingNet: Decimal = max(0, (progress.targetNet - progress.net).value)
        let rate: Double = max(0.5, NSDecimalNumber(decimal: packagesPerHour).doubleValue)
        let neededHours: Double = Double(remaining) / rate
        var result: [GoalNudge] = []
        for (index, hour) in slotHours.enumerated() {
            guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now),
                  fire.timeIntervalSince(now) >= minimumLead else { continue }
            let text = message(slot: index, remaining: remaining, remainingNet: remainingNet, rate: rate,
                               neededHours: neededHours, hoursLeft: dayEndHour - hour)
            result.append(GoalNudge(id: idPrefix + "\(index)", fireDate: fire, title: text.title, body: text.body))
        }
        return result
    }

    static func message(slot: Int, remaining: Int, remainingNet: Decimal, rate: Double, neededHours: Double,
                        hoursLeft: Int) -> (title: String, body: String) {
        let money: String = remainingNet > 0 ? "\(Formatters.currency(NSDecimalNumber(decimal: remainingNet).doubleValue.rounded())) daha kazanalım: " : ""
        let hours: String = hoursText(neededHours)
        let rateText: String = Formatters.decimalText(Decimal(rate))
        switch slot {
        case 0:
            return ("Bugünkü hedefe \(remaining) paket var",
                    "\(money)\(remaining) paket daha at. Saatte \(rateText) paketle \(hours) sürer.")
        case 1:
            if neededHours > Double(hoursLeft) {
                let perHour: Int = Int((Double(remaining) / Double(max(1, hoursLeft))).rounded(.up))
                return ("Hedefe geç kalıyorsun",
                        "Günün bitmesine \(hoursLeft) saat var, hedef için \(remaining) paket gerekiyor: saatte \(perHour) paket atman lazım.")
            }
            return ("Hedefe \(remaining) paket kaldı",
                    "\(money)günün bitmesine \(hoursLeft) saat var; \(hours) çalışırsan tamam.")
        default:
            return ("Son düzlük: \(remaining) paket",
                    "\(money)\(remaining) paket daha at. Günün bitmesine \(hoursLeft) saat kaldı.")
        }
    }

    /// "yaklaşık 3,5 saat" / "yaklaşık 30 dakika" (yarim saate yukari).
    static func hoursText(_ hours: Double) -> String {
        guard hours.isFinite, hours > 0 else { return "kısa bir süre" }
        if hours <= 0.5 { return "yaklaşık \(max(5, Int((hours * 60).rounded(.up)))) dakika" }
        let half: Double = (min(hours, 48) * 2).rounded(.up) / 2
        return "yaklaşık \(Formatters.decimalText(Decimal(half))) saat"
    }

    // MARK: - Donem

    /// Bugun hedefin calisma gunu mu (gunluk hedefte ve gun secilmemisse her gun).
    static func isWorkDay(goal: GoalSpec, now: Date, calendar: Calendar) -> Bool {
        guard goal.period != .day, let days = goal.workWeekdays, !days.isEmpty else { return true }
        return days.contains(calendar.component(.weekday, from: now))
    }

    /// Donemde (hafta / ay) yarindan itibaren kalan calisma gunu. Gun secilmemisse haftadaki gun sayisiyla orantilanir.
    static func remainingWorkDays(goal: GoalSpec, now: Date, calendar: Calendar) -> Int {
        guard goal.period != .day,
              let interval = calendar.dateInterval(of: goal.period == .week ? .weekOfYear : .month, for: now),
              var day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return 0 }
        var total = 0
        var working = 0
        while day < interval.end {
            total += 1
            if goal.workWeekdays?.contains(calendar.component(.weekday, from: day)) == true { working += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        if let days = goal.workWeekdays, !days.isEmpty { return working }
        return Int((Double(total) * Double(goal.daysPerWeek) / 7).rounded())
    }

    /// Haftalik / aylik hedefte ertesi sabah donem temposu: geride ise gunde kac paket fazla gerektigi, ilerideyse tebrik.
    /// - Parameters:
    ///   - netPerPackage: Gunluk plandaki paket basi net (gunluk net hedef / gunluk paket).
    ///   - daysLeft: Donemde kalan calisma gunu (bugun haric).
    static func period(pace: GoalPace?, netPerPackage: Decimal, daysLeft: Int, now: Date, calendar: Calendar) -> GoalNudge? {
        guard let pace, pace.period != .day, daysLeft > 0,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
              let fire = calendar.date(bySettingHour: periodHour, minute: 0, second: 0, of: tomorrow) else { return nil }
        let periodName: String = pace.period == .week ? "hafta" : "ay"
        let projected: String = Formatters.currency(pace.projected.doubleValue)
        let id: String = idPrefix + "period"
        if pace.isAhead {
            return GoalNudge(id: id, fireDate: fire, title: "Hedefin önündesin 👏",
                             body: "Bu tempoyla \(periodName) sonunda \(projected) net kalıyor. Böyle devam!")
        }
        let shortfall: Decimal = -pace.difference.value
        var body: String = "Bu tempoyla \(periodName) sonunda \(projected) kalıyor; hedefe \(Formatters.currency(NSDecimalNumber(decimal: shortfall).doubleValue.rounded())) eksik."
        if netPerPackage > 0 {
            let perDay: Double = NSDecimalNumber(decimal: shortfall / netPerPackage / Decimal(daysLeft)).doubleValue
            if perDay.isFinite, perDay > 0 {
                body += " Kalan \(daysLeft) günde günde \(Int(min(perDay, 999).rounded(.up))) paket fazla at."
            }
        }
        return GoalNudge(id: id, fireDate: fire, title: "\(periodName.capitalized(with: Locale(identifier: "tr_TR"))) sonuna \(daysLeft) iş günü kaldı",
                         body: body)
    }
}
