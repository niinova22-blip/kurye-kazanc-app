import SwiftUI

/// Hedef sonucu: once tek cumlelik cevap (gunde kac paket, kac saat), sonra paketsiz gelen ucretler, para dokumu ve ipucu.
struct GoalResultCard: View {
    let plan: GoalPlan
    let platformName: String

    var body: some View {
        Section {
            hero
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            ReachabilityNote(plan: plan)
            if !plan.guaranteed.isEmpty { GuaranteedBlock(plan: plan) }
            MoneyBlock(plan: plan)
            if plan.reachability != .alreadyMet || !plan.breakdown.lines.isEmpty {
                // 1.12.2: dokum secili donemde (aylik: Ayda + Günde, haftalik: Haftada + Günde, gunluk: yalnizca gun)
                PayDetailDisclosure(detail: periodDetail, periodTitle: periodColumnTitle, identifier: "goal.detail")
            }
            if let hint = plan.nextTier { hintRow(hint) }
        } header: {
            Text("Planın")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal.result")
    }

    /// Aylik plan kalem kalem; her kalemin gune dusen payi (ayda is gunune bolunur).
    private var detail: PayDetail {
        var extra: [PayDetailRow] = []
        let hasWeekly: Bool = plan.breakdown.lines.contains { $0.type == .weeklyBonus && $0.included }
        if plan.weeklyBonusIncome.value > 0, !hasWeekly {
            let days: Int = max(1, plan.workDays)
            extra.append(PayDetailRow(id: "weekly.bonus", category: .bonus, label: "Haftalık bonuslar (aylık karşılığı)",
                                      quantityText: nil, periodAmount: plan.weeklyBonusIncome,
                                      perDay: Money(Money.round(plan.weeklyBonusIncome.value / Decimal(days)))))
        }
        return PayDetailBuilder.make(breakdown: plan.breakdown, days: plan.workDays, extraRows: extra)
    }

    private var periodColumnTitle: String? {
        switch plan.goal.period {
        case .month: "Ayda"
        case .week: "Haftada"
        case .day: nil
        }
    }

    /// Aylik dokum secili doneme cevrilir. Aylik carpanli etiketler ("× 30 gün", "× 4,29 hafta") ve aylik miktarlar
    /// (581 paket × 59) donem disinda yaniltici oldugundan kaldirilir.
    private var periodDetail: PayDetail {
        let monthly: PayDetail = detail
        let period: GoalPeriod = plan.goal.period
        guard period != .month else { return monthly }
        var scaled = monthly
        scaled.rows = monthly.rows.map { row in
            var copy = row
            copy.periodAmount = period == .day ? row.perDay : plan.scaled(row.periodAmount, to: period)
            copy.quantityText = nil
            copy.label = row.label.components(separatedBy: " × ").first ?? row.label
            return copy
        }
        scaled.days = period == .day ? 1 : min(7, max(1, plan.goal.daysPerWeek))
        return scaled
    }

    // MARK: - Ust kart

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(platformName.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .opacity(0.8)
                Spacer()
                Text(goalText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            if plan.reachability == .alreadyMet {
                Text("Paket yapmasan da hedefe ulaşıyorsun")
                    .font(.title2.bold())
            } else {
                Text("Hedefine ulaşmak için")
                    .font(.subheadline)
                    .opacity(0.85)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(plan.packagesPerDay)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(plan.packagesPerDay)))
                        .accessibilityIdentifier("goal.packages")
                    Text("paket / gün")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                }
                HStack(spacing: 16) {
                    stat("clock.fill", "\(Formatters.decimalText(plan.hoursPerDay)) saat / gün")
                        .accessibilityIdentifier("goal.hours")
                    stat("calendar", daysText)
                }
                Text(periodPackagesText)
                    .font(.footnote)
                    .opacity(0.85)
                if let tier = plan.regionTier {
                    stat("mappin.and.ellipse", TariffQuestions.regionName(tier))
                }
            }
        }
        .brandCard()
        .padding(.vertical, 6)
    }

    private func stat(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
    }

    private var goalText: String {
        let suffix: String
        switch plan.goal.period {
        case .day: suffix = "günde"
        case .week: suffix = "haftada"
        case .month: suffix = "ayda"
        }
        return "Hedef: \(suffix) \(PayFormat.tl(plan.goal.amount)) net"
    }

    private var daysText: String {
        if let days = plan.goal.workWeekdays, plan.goal.period != .day {
            return days.count == 7 ? "Her gün" : GoalSpec.weekdayOrder.filter { days.contains($0) }
                .map(GoalSpec.weekdayShortName).joined(separator: " ")
        }
        return "Haftada \(plan.goal.daysPerWeek) gün"
    }

    private var periodPackagesText: String {
        let pace: String = Formatters.decimalText(plan.pace.packagesPerHour)
        let source: String = plan.pace.isUserProvided ? "girdiğin hız" : (plan.pace.isAssumed ? "tahmini hız" : "kayıtlarındaki hızın")
        switch plan.goal.period {
        case .day:
            return "Saatte \(pace) paket (\(source)) ile hesaplandı."
        case .week:
            return "Haftada toplam \(Formatters.groupedInt(plan.periodPackages())) paket · saatte \(pace) paket (\(source))"
        case .month:
            return "Ayda toplam \(Formatters.groupedInt(plan.monthlyPackages)) paket, \(plan.workDays) iş günü · saatte \(pace) paket (\(source))"
        }
    }

    private func hintRow(_ hint: NextTierHint) -> some View {
        let reward: String = hint.isBonus
            ? "\(PayFormat.tl(hint.newRate)) bonus kazanırsın"
            : "paket başı ücretin \(PayFormat.tl(hint.newRate)) olur"
        return Label {
            Text("Ayda \(Formatters.groupedInt(hint.threshold)) pakete ulaşırsan \(reward). Bunun için \(Formatters.groupedInt(hint.extraPackages)) paket daha gerekir; ayda \(PayFormat.tl(hint.extraNet)) daha fazla net kalır.")
                .font(.subheadline)
        } icon: {
            Image(systemName: "lightbulb.fill").foregroundStyle(Theme.highlight)
        }
        .accessibilityIdentifier("goal.hint")
    }
}

/// Paketten bagimsiz gelirler (sabit ucret, destekler).
private struct GuaranteedBlock: View {
    let plan: GoalPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.goal.period == .month ? "Paket yapmasan da alacakların"
                 : "Paket yapmasan da alacakların (\(plan.goal.period == .week ? "haftaya" : "güne") düşen payı)")
                .font(.subheadline.weight(.semibold))
            ForEach(plan.guaranteed) { line in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.positive)
                    Text(line.label).font(.subheadline)
                    Spacer()
                    Text((line.isSideBenefit ? "+" : "") + PayFormat.tl(plan.scaled(line.amount, to: plan.goal.period)))
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Firmadan alinacak (brut) − yakit = cebe kalan (net).
private struct MoneyBlock: View {
    let plan: GoalPlan

    var body: some View {
        VStack(spacing: 8) {
            row("Firmadan alacağın", PayFormat.tl(plan.scaled(plan.gross + plan.sideIncome, to: period)), color: .primary)
            row("Yakıt gideri", "−" + PayFormat.tl(plan.scaled(plan.fuel, to: period)), color: Theme.negative)
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text("Cebine kalan").font(.headline)
                Spacer()
                Text(netText)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(Theme.positive)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("goal.net")
            }
            Text(projectionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier("goal.projection")
        }
        .padding(.vertical, 4)
    }

    private var period: GoalPeriod { plan.goal.period }

    /// Secili donem disindakiler: "Bu şekilde çalışmaya devam edersen günde …, ayda … net".
    private var projectionText: String {
        let others: [GoalPeriod] = GoalPeriod.allCases.filter { $0 != period }
        let parts: [String] = others.map { other in
            let word: String = other == .day ? "günde" : (other == .week ? "haftada" : "ayda")
            return "\(word) \(PayFormat.tl(plan.scaled(plan.net, to: other)))"
        }
        return "Bu şekilde çalışmaya devam edersen " + parts.joined(separator: ", ") + " net kalır."
    }

    private func row(_ title: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(color)
        }
    }

    private var netText: String {
        switch plan.goal.period {
        case .month: "\(PayFormat.tl(plan.net)) / ay"
        case .week: "≈ \(PayFormat.tl(plan.scaled(plan.net, to: .week))) / hafta"
        case .day: "≈ \(PayFormat.tl(plan.scaled(plan.net, to: .day))) / gün"
        }
    }
}

private struct ReachabilityNote: View {
    let plan: GoalPlan

    var body: some View {
        switch plan.reachability {
        case .alreadyMet:
            Label("Sabit ücretin ve desteklerin hedefini zaten karşılıyor.", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Theme.positive)
        case .reachable:
            EmptyView()
        case let .needsMoreDays(days):
            Label("Günde en fazla \(Formatters.decimalText(plan.goal.maxHoursPerDay)) saatle bu hedefe yetişmiyor. Haftada \(days) gün çalışırsan ulaşırsın.",
                  systemImage: "calendar.badge.plus")
                .foregroundStyle(Theme.highlight)
        case let .unreachable(maxNet):
            Label("Bu gün ve saat sınırıyla en fazla ayda \(PayFormat.tl(maxNet)) net kalıyor. Hedefi düşür ya da aşağıdaki yollara bak.",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.highlight)
        }
    }
}
