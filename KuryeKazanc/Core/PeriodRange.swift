import Foundation

/// Gecmis/Analiz ekranindaki donem secimi.
enum PeriodKind: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Gün"
        case .week: "Hafta"
        case .month: "Ay"
        }
    }
}

/// Donem araliklari. Hafta Pazartesi baslar (Turkiye).
struct PeriodRange {
    var calendar: Calendar

    init(calendar: Calendar = PeriodRange.turkishCalendar()) {
        self.calendar = calendar
    }

    static func turkishCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = timeZone
        return calendar
    }

    func interval(of kind: PeriodKind, containing date: Date) -> DateInterval {
        let component: Calendar.Component = switch kind {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        return calendar.dateInterval(of: component, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    func shift(_ date: Date, kind: PeriodKind, by value: Int) -> Date {
        let component: Calendar.Component = switch kind {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }

    /// Aralik icindeki gunlerin baslangiclari.
    func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    func title(of kind: PeriodKind, containing date: Date) -> String {
        let locale = Formatters.locale
        switch kind {
        case .day:
            return date.formatted(Date.FormatStyle().locale(locale).day().month(.wide).year())
        case .week:
            let interval = interval(of: .week, containing: date)
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let start = interval.start.formatted(Date.FormatStyle().locale(locale).day().month(.abbreviated))
            let end = last.formatted(Date.FormatStyle().locale(locale).day().month(.abbreviated).year())
            return "\(start) – \(end)"
        case .month:
            return date.formatted(Date.FormatStyle().locale(locale).month(.wide).year())
        }
    }
}
