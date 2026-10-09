import Foundation

/// Planda bir platformdaki calisma blogu.
struct PlanBlock: Codable, Equatable {
    var platformCode: String
    var start: Date
    var end: Date

    var hours: Double { end.timeIntervalSince(start) / 3600 }
}

/// Plani gecersiz kilan sorun.
enum PlanIssue: Equatable {
    case platformInactive(String)
    case outsideAvailability(String)
    case overlap(String, String)
    case switchTooShort(from: String, to: String, minutes: Int)
    case exceedsMaxHours(Double, max: Double)
    case needsReservation(String)
    case outsideShift(String)
    case offGranularity(String, minutes: Int)
    case exclusiveConflict(String)
    case belowMinDaily(String, hours: Double)
    case reservedNotPlanned(String, cancelNoticeHours: Double?)
    case reservedOverlap

    func message(name: (String) -> String) -> String {
        switch self {
        case .platformInactive(let p): "\(name(p)): hesabın aktif değil."
        case .outsideAvailability(let p): "\(name(p)): uygun olduğun saatlerin dışında."
        case .overlap(let a, let b): "\(name(a)) ve \(name(b)) aynı anda — iki platformda birden teslimat yapılamaz."
        case .switchTooShort(let a, let b, let m): "\(name(a)) → \(name(b)) geçişi için en az \(m) dk gerekli."
        case .exceedsMaxHours(let h, let max): "Toplam \(Self.hours(h)) sa, günlük en fazla \(Self.hours(max)) sa."
        case .needsReservation(let p): "\(name(p)): yalnızca aldığın slotlarda çalışılabilir; bu saatte slotun yok."
        case .outsideShift(let p): "\(name(p)): vardiyan dışında."
        case .offGranularity(let p, let m): "\(name(p)): bloklar \(m) dakikalık slot sınırlarına oturmalı."
        case .exclusiveConflict(let p): "\(name(p)): aynı gün başka platformda çalışılamıyor."
        case .belowMinDaily(let p, let h): "\(name(p)): günlük en az \(Self.hours(h)) sa çalışma gerekli."
        case .reservedNotPlanned(let p, let notice):
            if let notice { "\(name(p)): aldığın slot planda yok. Bırakacaksan en az \(Self.hours(notice)) sa önce iptal et." }
            else { "\(name(p)): aldığın slot planda yok. İptal kuralını bilmiyoruz — slotu bırakmadan önce uygulamadan kontrol et." }
        case .reservedOverlap: "Aldığın slotlar/vardiyalar birbiriyle çakışıyor."
        }
    }

    private static func hours(_ h: Double) -> String {
        h == h.rounded() ? String(Int(h)) : String(format: "%.1f", h).replacingOccurrences(of: ".", with: ",")
    }
}

/// Kesin oneriye engel belirsizlik (kullanici kendi sozlesmesine gore onaylayabilir).
struct PlanUncertainty: Equatable, Identifiable {
    var ruleID: String
    var platformCode: String
    var category: RuleCategory
    var status: RuleStatus
    var isUnknownTerm: Bool
    var description: String
    var sourceURL: String?

    var id: String { "\(platformCode):\(ruleID)" }
}

/// Plan kurallarini denetler. Kisit olarak yalnizca dogrulanmis / kullanici onayli kurallar uygulanir;
/// digerleri belirsizlik olarak raporlanir.
struct PlanValidator {
    var calendar: Calendar
    var rules: RuleSet
    var profile: WorkProfile

    func today(_ day: Date) -> String { RuleDay.string(day, calendar: calendar) }

    func weekday(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    func effectiveRules(platform: String, day: Date) -> [EffectiveRule] {
        rules.effectiveRules(
            platform: platform,
            model: profile.platform(platform)?.courierModel ?? .any,
            region: profile.region,
            today: today(day),
            confirmations: profile.ruleConfirmations
        )
    }

    func enforced(_ kind: RuleKind, platform: String, day: Date) -> EffectiveRule? {
        effectiveRules(platform: platform, day: day).first { $0.rule.kind == kind && $0.isEnforced }
    }

    /// Gun basindan dakika.
    func minute(_ date: Date, day: Date) -> Int {
        Int((date.timeIntervalSince(calendar.startOfDay(for: day)) / 60).rounded())
    }

    /// Plan gunune dusen (kirpilmis) rezerve bloklar.
    func reservations(day: Date) -> [ReservedBlock] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return profile.reserved
            .filter { $0.end > start && $0.start < end && $0.end > $0.start }
            .map { ReservedBlock(id: $0.id, platformCode: $0.platformCode, start: max($0.start, start), end: min($0.end, end)) }
            .sorted { $0.start < $1.start }
    }

    /// [start, end) araligi ayni platformun rezervasyonlarinin birlesimiyle tamamen kapsaniyor mu.
    func isCovered(platform: String, start: Date, end: Date, by blocks: [(start: Date, end: Date, code: String)]) -> Bool {
        var cursor = start
        for b in blocks.filter({ $0.code == platform }).sorted(by: { $0.start < $1.start }) {
            if b.start > cursor { break }
            if b.end > cursor { cursor = b.end }
            if cursor >= end { return true }
        }
        return cursor >= end
    }

    func validate(_ blocks: [PlanBlock], day: Date) -> [PlanIssue] {
        var issues: [PlanIssue] = []
        func add(_ issue: PlanIssue) { if !issues.contains(issue) { issues.append(issue) } }
        let sorted = blocks.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        let reserved = reservations(day: day)
        let reservedTuples = reserved.map { (start: $0.start, end: $0.end, code: $0.platformCode) }
        let wd = weekday(of: day)

        for block in sorted {
            let p = block.platformCode
            if profile.platform(p)?.isActive != true { add(.platformInactive(p)) }
            let s = minute(block.start, day: day), e = minute(block.end, day: day)
            let inReservation = isCovered(platform: p, start: block.start, end: block.end, by: reservedTuples)
            if !inReservation && !profile.isAvailable(weekday: wd, start: s, end: e) { add(.outsideAvailability(p)) }
            if enforced(.slotRequired, platform: p, day: day) != nil && !inReservation { add(.needsReservation(p)) }
            if enforced(.shiftBased, platform: p, day: day) != nil && !inReservation { add(.outsideShift(p)) }
            if let g = enforced(.slotGranularityMinutes, platform: p, day: day)?.rule.params.minutes, g > 0,
               s % g != 0 || e % g != 0 {
                add(.offGranularity(p, minutes: g))
            }
        }

        for (a, b) in zip(sorted, sorted.dropFirst()) {
            if b.start < a.end {
                add(.overlap(a.platformCode, b.platformCode))
            } else if a.platformCode != b.platformCode {
                let gap = Int((b.start.timeIntervalSince(a.end) / 60).rounded())
                if gap < profile.switchBufferMinutes {
                    add(.switchTooShort(from: a.platformCode, to: b.platformCode, minutes: profile.switchBufferMinutes))
                }
            }
        }

        let used = Set(sorted.map(\.platformCode))
        for p in used {
            if enforced(.exclusiveSameDay, platform: p, day: day) != nil && used.count > 1 { add(.exclusiveConflict(p)) }
            if let h = enforced(.minDailyHours, platform: p, day: day)?.rule.params.hours {
                let total = sorted.filter { $0.platformCode == p }.reduce(0) { $0 + $1.hours }
                if total + 0.001 < h { add(.belowMinDaily(p, hours: h)) }
            }
        }

        let total = sorted.reduce(0) { $0 + $1.hours }
        if total > profile.maxHoursPerDay + 0.001 { add(.exceedsMaxHours(total, max: profile.maxHoursPerDay)) }

        let planTuples = sorted.map { (start: $0.start, end: $0.end, code: $0.platformCode) }
        for r in reserved where !isCovered(platform: r.platformCode, start: r.start, end: r.end, by: planTuples) {
            let notice = effectiveRules(platform: r.platformCode, day: day)
                .first { $0.rule.kind == .slotCancelNoticeHours }?.rule.params.hours
            add(.reservedNotPlanned(r.platformCode, cancelNoticeHours: notice))
        }
        for (a, b) in zip(reserved, reserved.dropFirst()) where b.start < a.end && a.platformCode != b.platformCode {
            add(.reservedOverlap)
        }
        return issues
    }

    /// Plana etkili, dogrulanmamis / eski / bilinmeyen kosullar. Coklu platform kosulu yalnizca birden cok platform kullaniliyorsa.
    func uncertainties(_ blocks: [PlanBlock], day: Date) -> [PlanUncertainty] {
        let used = Array(Set(blocks.map(\.platformCode))).sorted()
        var result: [PlanUncertainty] = []
        for p in used {
            for eff in effectiveRules(platform: p, day: day) where eff.isUncertain {
                if eff.rule.category == .exclusivity && used.count < 2 { continue }
                let u = PlanUncertainty(
                    ruleID: eff.rule.id, platformCode: p, category: eff.rule.category, status: eff.status,
                    isUnknownTerm: eff.rule.kind == .unknownTerm, description: eff.rule.description, sourceURL: eff.rule.sourceURL
                )
                if !result.contains(where: { $0.ruleID == u.ruleID }) { result.append(u) }
            }
        }
        return result
    }

    /// Haftalik yogun saat yukumlulugu notlari (plani gecersiz kilmaz).
    func weeklyNotes(_ blocks: [PlanBlock], day: Date, name: (String) -> String) -> [String] {
        var notes: [String] = []
        let used = Set(blocks.map(\.platformCode))
        for p in used.sorted() {
            for eff in effectiveRules(platform: p, day: day) where eff.rule.kind == .peakWeeklyHours {
                guard let from = eff.rule.params.fromHour, let to = eff.rule.params.toHour, let h = eff.rule.params.hours else { continue }
                var inPeak = 0.0
                for b in blocks where b.platformCode == p {
                    let s = max(minute(b.start, day: day), from * 60)
                    let e = min(minute(b.end, day: day), to * 60)
                    if e > s { inPeak += Double(e - s) / 60 }
                }
                let status = eff.confirmedByUser ? "sözleşmende var" : eff.status.displayName.lowercased()
                notes.append(String(
                    format: "%@: haftalık %02d:00–%02d:00 arası %@ sa yükümlülük (%@). Bu planda %@ sa.",
                    name(p), from, to, Self.number(h), status, Self.number(inPeak)
                ))
            }
        }
        return notes
    }

    static func number(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}
