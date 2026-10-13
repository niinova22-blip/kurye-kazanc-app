import SwiftUI

/// Hedef sonucu: zaten alacaklarin, bolge, paket, sure, brut-yakit-net ve kademe ipucu. Tek firma.
struct GoalResultCard: View {
    let plan: GoalPlan
    let platformName: String

    var body: some View {
        Section {
            header
            if !plan.guaranteed.isEmpty { GuaranteedBlock(plan: plan) }
            if plan.reachability != .alreadyMet { requirementBlock }
            totalsBlock
            if let hint = plan.nextTier { hintRow(hint) }
            ReachabilityNote(plan: plan)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal.result")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(platformName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text("\(plan.goal.period.displayName) \(PayFormat.tl(plan.goal.amount)) net hedef")
                .font(.title3.bold())
        }
    }

    private var requirementBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tier = plan.regionTier {
                GoalRequirementRow(symbol: "mappin.and.ellipse", title: "Bölge",
                                   value: TariffQuestions.regionName(tier) + tierDeltaText)
            }
            GoalRequirementRow(symbol: "shippingbox.fill", title: "Paket", value: packageText)
                .accessibilityIdentifier("goal.packages")
            GoalRequirementRow(symbol: "clock.fill", title: "Süre", value: hoursText)
                .accessibilityIdentifier("goal.hours")
        }
        .padding(.vertical, 4)
    }

    private var totalsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("Brüt \(PayFormat.tl(plan.gross + plan.sideIncome)) − yakıt \(PayFormat.tl(plan.fuel))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "banknote.fill").foregroundStyle(Theme.accent)
            }
            Text(netText)
                .font(.title2.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityIdentifier("goal.net")
        }
    }

    private var netText: String {
        switch plan.goal.period {
        case .month: "Net \(PayFormat.tl(plan.net)) / ay"
        case .week: "Net ≈ \(PayFormat.tl(plan.periodNet())) / hafta (\(PayFormat.tl(plan.net)) / ay)"
        case .day: "Net ≈ \(PayFormat.tl(plan.periodNet())) / gün (\(PayFormat.tl(plan.net)) / ay)"
        }
    }

    private func hintRow(_ hint: NextTierHint) -> some View {
        Label("\(hint.threshold) pakete ulaşırsan paket başı \(PayFormat.tl(hint.newRate)): +\(hint.extraPackages) paketle +\(PayFormat.tl(hint.extraNet)) net.",
              systemImage: "lightbulb.fill")
            .font(.subheadline)
            .foregroundStyle(.orange)
    }

    private var packageText: String {
        let period: String
        switch plan.goal.period {
        case .day: period = "Bugün"
        case .week: period = "Haftada"
        case .month: period = "Ayda"
        }
        return "\(period) \(plan.periodPackages()) → günde \(plan.packagesPerDay) paket (\(plan.goal.periodWorkDays()) iş günü)"
    }

    private var hoursText: String {
        let pace: String = Formatters.decimalText(plan.pace.packagesPerHour)
        let assumed: String = plan.pace.isAssumed ? ", varsayım" : ""
        return "Günde en az \(Formatters.decimalText(plan.hoursPerDay)) saat (hızın: \(pace) paket/saat\(assumed))"
    }

    private var tierDeltaText: String {
        guard let delta = plan.otherTierDelta, delta.value != 0 else { return "" }
        let word: String = delta.value > 0 ? "fazla" : "az"
        return " — diğer kademeye göre \(PayFormat.tl(Money(abs(delta.value)))) \(word) sabit ücret"
    }
}

private struct GuaranteedBlock: View {
    let plan: GoalPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zaten alacakların")
                .font(.subheadline.weight(.semibold))
            ForEach(plan.guaranteed) { line in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text(line.label).font(.subheadline)
                    Spacer()
                    Text((line.isSideBenefit ? "+" : "") + PayFormat.tl(line.amount))
                        .font(.subheadline.monospacedDigit())
                }
            }
            HStack {
                Text("Toplam").font(.subheadline.weight(.semibold))
                Spacer()
                Text(PayFormat.tl(plan.guaranteedTotal)).font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct GoalRequirementRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.medium))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReachabilityNote: View {
    let plan: GoalPlan

    var body: some View {
        switch plan.reachability {
        case .alreadyMet:
            Label("Sabit ücretin ve desteklerin hedefi zaten karşılıyor.", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Theme.accent)
        case .reachable:
            EmptyView()
        case let .needsMoreDays(days):
            Label("Günde \(Formatters.decimalText(plan.goal.maxHoursPerDay)) saatle bu hedefe yetmiyor; haftada \(days) gün çalışırsan ulaşırsın.",
                  systemImage: "calendar.badge.plus")
                .foregroundStyle(.orange)
        case let .unreachable(maxNet):
            Label("Bu saat ve gün sınırıyla en fazla \(PayFormat.tl(maxNet)) net/ay. Hedefi ya da süreyi değiştir.",
                  systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
