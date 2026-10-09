import Foundation

enum PlanKind: String, Codable, CaseIterable {
    case mostProfitable, lowRisk, fewerHours

    var title: String {
        switch self {
        case .mostProfitable: "En kârlı"
        case .lowRisk: "Düşük riskli"
        case .fewerHours: "Daha az saat"
        }
    }
}

enum PlanConfidence: String, Comparable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low: "Düşük"
        case .medium: "Orta"
        case .high: "Yüksek"
        }
    }

    private var rank: Int { self == .low ? 0 : self == .medium ? 1 : 2 }
    static func < (a: PlanConfidence, b: PlanConfidence) -> Bool { a.rank < b.rank }
    var lowered: PlanConfidence { self == .high ? .medium : .low }
}

/// Planin tahmini sonucu. Brut = platformdan gelen (bonus dahil); net = brut - km gideri - gunluk sabit gider; vergi ayrica.
struct PlanEstimate: Equatable {
    var grossLow: Double
    var grossMid: Double
    var grossHigh: Double
    /// Yakit + bakim (km x km basi maliyet).
    var vehicleCost: Double
    /// Bag-Kur / SGK + diger aylik sabitlerin gunluk payi.
    var fixedCost: Double
    /// Orta senaryo brut x vergi orani.
    var tax: Double
    var hours: Double
    var km: Double
    var packages: Double?
    var taxRate: Double

    var netLow: Double { grossLow - vehicleCost - fixedCost }
    var netMid: Double { grossMid - vehicleCost - fixedCost }
    var netHigh: Double { grossHigh - vehicleCost - fixedCost }
    var afterTaxLow: Double { netLow - grossLow * taxRate }
    var afterTaxMid: Double { netMid - tax }
    var afterTaxHigh: Double { netHigh - grossHigh * taxRate }
    var netPerHour: Double? { hours > 0 ? netMid / hours : nil }
}

struct PlanProposal: Equatable, Identifiable {
    var kind: PlanKind
    var blocks: [PlanBlock]
    var estimate: PlanEstimate
    var confidence: PlanConfidence
    var issues: [PlanIssue]
    var uncertainties: [PlanUncertainty]
    var reasons: [String]
    var notes: [String]
    var ruleSetVersion: String

    var id: PlanKind { kind }
    /// Kurallara uygun ve tum etkili kurallar dogrulanmis / onayli. Aksi halde "kesin degil" gosterilir.
    var isConfirmed: Bool { issues.isEmpty && uncertainties.isEmpty }
    var isValid: Bool { issues.isEmpty }
}

struct PlannerResult: Equatable {
    var proposals: [PlanProposal]
    /// Plana alinamayan platformlar ve nedeni.
    var excluded: [String: String]
    /// Oneri yoksa kullaniciya aciklama.
    var message: String?
}

/// Kaydedilen plan; kurallar degisince yeniden dogrulanir.
struct SavedPlan: Codable, Equatable {
    var day: String
    var kind: PlanKind
    var blocks: [PlanBlock]
    var ruleSetVersion: String
}

struct PlanCheck: Equatable {
    var issues: [PlanIssue]
    var uncertainties: [PlanUncertainty]
    var rulesChanged: Bool
    var isConfirmed: Bool { issues.isEmpty && uncertainties.isEmpty }
}

/// Gunluk plan onerisi: yarim saatlik dilimler uzerinde dinamik programlama.
struct PlanEngine {
    var calendar: Calendar
    var rules: RuleSet
    var profile: WorkProfile
    var entries: [EarningEntry]
    /// Ilce yogunlugu: yalnizca siralamada kucuk agirlik; tahmine girmez.
    var community: [CommunityCell] = []
    var platformName: (String) -> String = { $0 }
    /// Az saatli plan azami saatin bu orani kadar.
    var fewerHoursRatio: Double = 0.6
    var communityWeight: Double = 0.03

    var validator: PlanValidator { PlanValidator(calendar: calendar, rules: rules, profile: profile) }
    var forecaster: EarningsForecaster { EarningsForecaster(calendar: calendar) }

    // MARK: - Oneri

    func propose(day rawDay: Date) -> PlannerResult {
        let day = calendar.startOfDay(for: rawDay)
        let v = validator
        let reserved = v.reservations(day: day)
        var excluded: [String: String] = [:]
        var forecasts: [String: [Int: HourForecast]] = [:]

        let active = profile.activePlatformCodes
        guard !active.isEmpty else {
            return PlannerResult(proposals: [], excluded: [:], message: "Çalışma profilinde aktif platform yok. Profil > Çalışma profili'nden ekle.")
        }
        for p in active {
            var byHour: [Int: HourForecast] = [:]
            for h in 0..<24 {
                if let f = forecaster.forecast(entries: entries, platform: p, day: day, hour: h,
                                               offeredRate: profile.platform(p)?.offeredHourlyRate) {
                    byHour[h] = f
                }
            }
            let needsReservation = v.enforced(.slotRequired, platform: p, day: day) != nil
                || v.enforced(.shiftBased, platform: p, day: day) != nil
            if byHour.isEmpty {
                excluded[p] = "Son 8 haftada bu platformda en az 3 kaydın yok ve platform ücreti girilmemiş — tahmin uydurmuyoruz."
            } else if needsReservation && !reserved.contains(where: { $0.platformCode == p }) {
                excluded[p] = v.enforced(.shiftBased, platform: p, day: day) != nil
                    ? "Vardiya düzeninde çalışıyor; bu gün için vardiya girmedin."
                    : "Yalnızca aldığın slotlarda çalışılabiliyor; bu gün için slot girmedin."
            } else {
                forecasts[p] = byHour
            }
        }
        // Rezervasyonu olan platform tahminsiz olsa da planda yer alir (kullanici o saatte calisacak).
        let candidates = Array(Set(forecasts.keys).union(reserved.map(\.platformCode)).filter(active.contains)).sorted()
        guard !candidates.isEmpty else {
            return PlannerResult(proposals: [], excluded: excluded,
                                 message: "Plan önermek için yeterli veri yok. Birkaç gün kazanç kaydı ekle ya da çalışma profilinde platform ücretini gir.")
        }

        var proposals: [PlanProposal] = []
        for kind in PlanKind.allCases {
            guard let blocks = bestBlocks(kind: kind, day: day, candidates: candidates, forecasts: forecasts, reserved: reserved),
                  !blocks.isEmpty else { continue }
            if proposals.contains(where: { $0.blocks == blocks }) { continue }
            proposals.append(proposal(kind: kind, blocks: blocks, day: day, forecasts: forecasts))
        }
        let message: String? = proposals.isEmpty
            ? "Uygun saatlerinde kârlı bir plan bulunamadı. Uygunluk saatlerini ya da platformlarını kontrol et."
            : nil
        return PlannerResult(proposals: proposals, excluded: excluded, message: message)
    }

    // MARK: - Yeniden dogrulama

    func check(_ saved: SavedPlan) -> PlanCheck {
        let day = RuleDay.date(saved.day).flatMap { utc -> Date? in
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(identifier: "UTC")!
            let c = utcCal.dateComponents([.year, .month, .day], from: utc)
            return calendar.date(from: c)
        } ?? Date()
        let v = validator
        return PlanCheck(
            issues: v.validate(saved.blocks, day: day),
            uncertainties: v.uncertainties(saved.blocks, day: day),
            rulesChanged: saved.ruleSetVersion != rules.version
        )
    }

    func save(_ proposal: PlanProposal, day: Date) -> SavedPlan {
        SavedPlan(day: RuleDay.string(day, calendar: calendar), kind: proposal.kind, blocks: proposal.blocks, ruleSetVersion: rules.version)
    }

    // MARK: - Dinamik programlama

    private func slotMinutes(candidates: [String], day: Date) -> Int {
        let g = candidates.compactMap { validator.enforced(.slotGranularityMinutes, platform: $0, day: day)?.rule.params.minutes }.max() ?? 30
        return g >= 60 ? 60 : 30
    }

    private func bestBlocks(
        kind: PlanKind, day: Date, candidates: [String], forecasts: [String: [Int: HourForecast]], reserved: [ReservedBlock]
    ) -> [PlanBlock]? {
        let v = validator
        // Ayni gun munhasir platformlar: her biri tek basina ve geri kalanlar birlikte denenir.
        let exclusive = candidates.filter { v.enforced(.exclusiveSameDay, platform: $0, day: day) != nil }
        var groups: [[String]] = exclusive.map { [$0] }
        let rest = candidates.filter { !exclusive.contains($0) }
        if !rest.isEmpty { groups.append(rest) }
        let reservedCodes = Set(reserved.map(\.platformCode))
        if reservedCodes.count > 0 {
            // Rezervasyonu olan platformlar her grupta bulunur (kullanici o slotu zaten almis); ihlal varsa denetim gosterir.
            groups = groups.map { Array(Set($0).union(reservedCodes)).sorted() }
        }
        var best: (value: Double, blocks: [PlanBlock])?
        for group in groups {
            guard let r = solve(kind: kind, day: day, platforms: group, forecasts: forecasts, reserved: reserved) else { continue }
            if best == nil || r.value > best!.value { best = r }
        }
        return best?.blocks
    }

    private func solve(
        kind: PlanKind, day: Date, platforms: [String], forecasts: [String: [Int: HourForecast]], reserved: [ReservedBlock]
    ) -> (value: Double, blocks: [PlanBlock])? {
        let v = validator
        let L = slotMinutes(candidates: platforms, day: day)
        let T = 1440 / L
        let P = platforms.count
        let wd = v.weekday(of: day)
        let buffer = max(0, profile.switchBufferMinutes)
        let idleCap = buffer / L + 1
        let slotHours = Double(L) / 60

        // Zorunlu dilimler (rezervasyon) ve izinli platformlar
        var forced = [Int?](repeating: nil, count: T)
        for r in reserved {
            guard let pi = platforms.firstIndex(of: r.platformCode) else { continue }
            let s = v.minute(r.start, day: day), e = v.minute(r.end, day: day)
            for t in 0..<T where t * L < e && t * L + L > s {
                if forced[t] == nil { forced[t] = pi }
            }
        }
        let forcedCount = forced.compactMap { $0 }.count
        var maxHours = profile.maxHoursPerDay
        if kind == .fewerHours { maxHours *= fewerHoursRatio }
        let maxSlots = max(forcedCount, Int((maxHours / slotHours).rounded(.down)))

        let maxCommunity = community.map(\.perHour).max() ?? 0
        func communityFactor(_ hour: Int) -> Double {
            guard maxCommunity > 0, let cell = community.first(where: { $0.weekday == wd && $0.hour == hour }) else { return 1 }
            return 1 + communityWeight * cell.perHour / maxCommunity
        }

        // value[t][p]: dilimin degeri (izinsizse nil)
        var value = [[Double?]](repeating: [Double?](repeating: nil, count: P), count: T)
        for t in 0..<T {
            let s = t * L, e = s + L
            let hour = s / 60
            for (pi, p) in platforms.enumerated() {
                let inRes = reserved.contains { $0.platformCode == p && v.minute($0.start, day: day) <= s && v.minute($0.end, day: day) >= e }
                if let f = forced[t] {
                    guard f == pi else { continue }
                } else {
                    let needsRes = v.enforced(.slotRequired, platform: p, day: day) != nil || v.enforced(.shiftBased, platform: p, day: day) != nil
                    if needsRes && !inRes { continue }
                    if !inRes && !profile.isAvailable(weekday: wd, start: s, end: e) { continue }
                }
                let f = forecasts[p]?[hour]
                if f == nil && forced[t] == nil { continue }
                if kind == .lowRisk, let f, forced[t] == nil, f.basis == .platform || f.basis == .offeredRate { continue }
                // Zayif dayanakli (platform geneli / kullanici ucreti) saatler siralamada temkinli (dusuk senaryo) degerle girer.
                let rate = f.map { kind == .lowRisk || $0.basis == .platform || $0.basis == .offeredRate ? $0.low : $0.mid } ?? 0
                let km = (f?.kmPerHour ?? 0) * slotHours * max(0, profile.costPerKm)
                value[t][pi] = (rate * slotHours - km) * communityFactor(hour)
            }
        }

        // Durum: son platform (0 = yok, 1...P), bosta gecen dilim (0...idleCap), kullanilan dilim
        let S1 = P + 1, S2 = idleCap + 1, S3 = maxSlots + 1
        func idx(_ last: Int, _ idle: Int, _ used: Int) -> Int { (last * S2 + idle) * S3 + used }
        let stateCount = S1 * S2 * S3
        let neg = -Double.infinity
        var dp = [Double](repeating: neg, count: stateCount)
        dp[idx(0, idleCap, 0)] = 0
        // geri izleme: [t][state] -> (onceki durum, secim: -1 bos, pi calis, penalti dk)
        var back = [[(Int, Int, Int)]](repeating: [(Int, Int, Int)](repeating: (-1, -1, 0), count: stateCount), count: T)

        for t in 0..<T {
            var next = [Double](repeating: neg, count: stateCount)
            for last in 0..<S1 {
                for idle in 0..<S2 {
                    for used in 0..<S3 {
                        let cur = dp[idx(last, idle, used)]
                        if cur == neg { continue }
                        let from = idx(last, idle, used)
                        // bos kal (zorunlu dilim degilse)
                        if forced[t] == nil {
                            let to = idx(last, min(idle + 1, idleCap), used)
                            if cur > next[to] { next[to] = cur; back[t][to] = (from, -1, 0) }
                        }
                        guard used < maxSlots else { continue }
                        for pi in 0..<P {
                            guard let val = value[t][pi] else { continue }
                            var gained = val
                            var penalty = 0
                            if last != 0 && last - 1 != pi {
                                penalty = max(0, buffer - idle * L)
                                if penalty > 0, let g = v.enforced(.slotGranularityMinutes, platform: platforms[pi], day: day)?.rule.params.minutes, g > 0 {
                                    penalty = Int((Double(penalty) / Double(g)).rounded(.up)) * g
                                }
                                if penalty >= L {
                                    // Zorunlu dilime gecis: sure yetmese de girilir, denetim "gecis suresi" sorununu gosterir.
                                    guard forced[t] == pi else { continue }
                                    penalty = 0
                                }
                                gained = val * Double(L - penalty) / Double(L)
                            }
                            // Kucuk bos dilimleri ayni platformda doldurmayi zorlamamak icin degersiz dilime girilmez
                            if gained <= 0 && forced[t] != pi { continue }
                            let to = idx(pi + 1, 0, used + 1)
                            if cur + gained > next[to] { next[to] = cur + gained; back[t][to] = (from, pi, penalty) }
                        }
                    }
                }
            }
            dp = next
        }
        guard let (bestState, bestValue) = dp.enumerated().max(by: { $0.element < $1.element }).map({ ($0.offset, $0.element) }),
              bestValue > neg else { return nil }

        // Secimleri geri izle
        var choices = [(pi: Int, penalty: Int)](repeating: (-1, 0), count: T)
        var state = bestState
        for t in stride(from: T - 1, through: 0, by: -1) {
            let (prev, choice, penalty) = back[t][state]
            choices[t] = (choice, penalty)
            state = prev
            if state < 0 { break }
        }

        let dayStart = calendar.startOfDay(for: day)
        func date(_ minute: Int) -> Date { calendar.date(byAdding: .minute, value: minute, to: dayStart) ?? dayStart }
        var blocks: [PlanBlock] = []
        var t = 0
        while t < T {
            let (pi, penalty) = choices[t]
            guard pi >= 0 else { t += 1; continue }
            var end = t + 1
            while end < T && choices[end].pi == pi && choices[end].penalty == 0 { end += 1 }
            blocks.append(PlanBlock(platformCode: platforms[pi], start: date(t * L + penalty), end: date(end * L)))
            t = end
        }
        return (bestValue, blocks)
    }

    // MARK: - Sonuc

    private func proposal(kind: PlanKind, blocks: [PlanBlock], day: Date, forecasts: [String: [Int: HourForecast]]) -> PlanProposal {
        let v = validator
        var grossLow = 0.0, grossMid = 0.0, grossHigh = 0.0, km = 0.0, packages = 0.0
        var hasPackages = false
        var minSamples = Int.max
        var bases: Set<ForecastBasis> = []
        var reasons: [String] = []

        for block in blocks {
            var cursor = block.start
            var blockBases: [HourForecast] = []
            while cursor < block.end {
                let hourStart = calendar.dateInterval(of: .hour, for: cursor)?.start ?? cursor
                let hourEnd = min(calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? block.end, block.end)
                let h = hourEnd.timeIntervalSince(cursor) / 3600
                if let f = forecasts[block.platformCode]?[calendar.component(.hour, from: cursor)] {
                    grossLow += f.low * h
                    grossMid += f.mid * h
                    grossHigh += f.high * h
                    km += f.kmPerHour * h
                    if let pph = f.packagesPerHour { packages += pph * h; hasPackages = true }
                    minSamples = min(minSamples, f.samples)
                    bases.insert(f.basis)
                    blockBases.append(f)
                } else {
                    minSamples = 0
                    bases.insert(.offeredRate)
                }
                cursor = hourEnd
            }
            reasons.append(reason(for: block, forecasts: blockBases))
        }
        let hours = blocks.reduce(0) { $0 + $1.hours }
        let vehicle = km * max(0, profile.costPerKm)
        let taxRate = min(max(profile.taxRate, 0), 1)
        let estimate = PlanEstimate(
            grossLow: grossLow, grossMid: grossMid, grossHigh: grossHigh, vehicleCost: vehicle,
            fixedCost: hours > 0 ? profile.dailyFixedCost : 0, tax: grossMid * taxRate, hours: hours, km: km,
            packages: hasPackages ? packages : nil, taxRate: taxRate
        )

        let issues = v.validate(blocks, day: day)
        let uncertainties = v.uncertainties(blocks, day: day)
        var confidence: PlanConfidence
        if bases.contains(.offeredRate) || bases.contains(.platform) || minSamples < 3 { confidence = .low }
        else if bases == [.weekdayHour] && minSamples >= 5 { confidence = .high }
        else { confidence = .medium }
        if !uncertainties.isEmpty { confidence = confidence.lowered }

        var notes = v.weeklyNotes(blocks, day: day, name: platformName)
        if zip(blocks, blocks.dropFirst()).contains(where: { $0.platformCode != $1.platformCode }) {
            notes.append("Platform değiştirirken \(profile.switchBufferMinutes) dk geçiş süresi ayrıldı.")
        }
        if let target = profile.dailyNetTarget, target > 0 {
            notes.append(estimate.netMid >= target
                ? "Günlük net hedefini (\(Int(target)) ₺) orta senaryoda karşılıyor."
                : "Günlük net hedefinin (\(Int(target)) ₺) altında kalıyor.")
        }
        if !uncertainties.isEmpty {
            notes.insert("Kesin öneri değil: bazı platform koşulları doğrulanmadı ya da güncel değil. Aşağıdakileri kendi sözleşmene göre onayla.", at: 0)
        }
        return PlanProposal(
            kind: kind, blocks: blocks, estimate: estimate, confidence: confidence, issues: issues,
            uncertainties: uncertainties, reasons: reasons, notes: notes, ruleSetVersion: rules.version
        )
    }

    private func reason(for block: PlanBlock, forecasts: [HourForecast]) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "HH:mm"
        let span = "\(f.string(from: block.start))–\(f.string(from: block.end)) \(platformName(block.platformCode))"
        guard !forecasts.isEmpty else { return "\(span): aldığın slot/vardiya (tahmin için kayıt yok)." }
        let mid = forecasts.map(\.mid).reduce(0, +) / Double(forecasts.count)
        let main = forecasts.max { $0.samples < $1.samples }!
        if main.basis == .offeredRate {
            return "\(span): kaydın yok; girdiğin \(Int(mid.rounded())) ₺/sa ücrete göre."
        }
        return "\(span): \(main.basis.displayName) ortası ~\(Int(mid.rounded())) ₺/sa (\(main.samples) kayıt, son 8 hafta)."
    }
}
