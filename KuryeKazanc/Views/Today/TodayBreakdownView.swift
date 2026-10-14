import SwiftUI

/// Bugun kartina dokununca acilan tam ekran dokum (1.11). Vardiya sonu ozetiyle ayni gorunum:
/// once kazanc kalem kalem (paketler, km, bonus, sabit ucretin bugune dusen payi...), sonra toplam, giderler ve net;
/// en sonda bu tempoyla hedefin ilerisinde mi gerisinde mi kalinacagi.
struct TodayBreakdownView: View {
    struct Content {
        var breakdown: DayBreakdown
        var packages: Int
        var workDuration: TimeInterval
        var distanceKm: Double
        /// Km'den yakit tahmini (elle yakit girildiyse 0).
        var fuelEstimate: Double
        var manualExpenses: [(label: String, amount: Double)]
        var net: Double
        var dailyTarget: Money?
        var pace: GoalPace?
        var goal: GoalSpec?
    }

    let content: Content
    let onClose: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var totalExpenses: Double {
        content.fuelEstimate + content.manualExpenses.map(\.amount).reduce(0, +)
    }

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    tiles
                    earningsCard
                    expensesCard
                    netCard
                    paceCard
                    Button(action: onClose) {
                        Text("Kapat")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(Theme.accent)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("dayBreakdown.close")
                }
                .foregroundStyle(.white)
                .padding(20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Bolumler

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Bugünün dökümü", systemImage: "list.bullet.rectangle.portrait.fill")
                .font(.headline)
                .foregroundStyle(Theme.mintOnDark)
            Text(Formatters.longDay(.now))
                .font(.subheadline)
                .opacity(0.8)
            Text("Bugün cebine kalan")
                .font(.subheadline)
                .opacity(0.8)
                .padding(.top, 6)
            Text(Formatters.currency(content.net))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("dayBreakdown.net")
        }
    }

    private var tiles: some View {
        HStack(spacing: 10) {
            tile("shippingbox.fill", "\(content.packages)", "paket")
            tile("clock.fill", Formatters.duration(content.workDuration), "süre")
            tile("road.lanes", Formatters.distance(content.distanceKm), "mesafe")
        }
    }

    private var earningsCard: some View {
        card(title: "Kazandıkların", symbol: "arrow.down.circle.fill") {
            if content.breakdown.rows.isEmpty {
                Text("Bugün henüz kazanç yok. Vardiya başlat ya da “Elle hesapla” ile ekle.")
                    .font(.subheadline)
                    .opacity(0.85)
            }
            ForEach(content.breakdown.rows) { row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: row.category.symbol)
                        .font(.subheadline)
                        .frame(width: 22)
                        .opacity(0.9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label).font(.subheadline)
                        if let note = note(for: row) {
                            Text(note).font(.caption).opacity(0.7)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(PayFormat.tl(row.periodAmount))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            Divider().overlay(.white.opacity(0.3))
            amountRow("Toplam kazanç", PayFormat.tl(content.breakdown.gross), bold: true, identifier: "dayBreakdown.gross")
        }
    }

    private func note(for row: PayDetailRow) -> String? {
        if row.category == .fixed { return "Aylık sabit ücretin bugüne düşen payı · ay sonunda ödenir" }
        if row.isEstimate { return "Tahmini" }
        return row.quantityText
    }

    private var expensesCard: some View {
        card(title: "Giderler", symbol: "arrow.up.circle.fill") {
            if totalExpenses == 0 {
                Text("Bugün gider yok.").font(.subheadline).opacity(0.85)
            }
            if content.fuelEstimate > 0 {
                amountRow("Yakıt (km × tüketim × fiyat)", "−" + Formatters.currency(content.fuelEstimate))
            }
            ForEach(Array(content.manualExpenses.enumerated()), id: \.offset) { _, expense in
                amountRow(expense.label, "−" + Formatters.currency(expense.amount))
            }
            if totalExpenses > 0 {
                Divider().overlay(.white.opacity(0.3))
                amountRow("Toplam gider", "−" + Formatters.currency(totalExpenses), bold: true, identifier: "dayBreakdown.expenses")
            }
        }
    }

    private var netCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            amountRow("Toplam kazanç", PayFormat.tl(content.breakdown.gross))
            amountRow("Giderler", "−" + Formatters.currency(totalExpenses))
            Divider().overlay(.white.opacity(0.4))
            HStack {
                Text("Bugün kazandığın (net)").font(.headline)
                Spacer()
                Text(Formatters.currency(content.net))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(content.net >= 0 ? Theme.mintOnDark : Color.red)
            }
        }
        .padding(16)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder private var paceCard: some View {
        card(title: "Hedefe göre", symbol: "target") {
            if let goal = content.goal {
                if let target = content.dailyTarget, target.value > 0 {
                    amountRow("Bugünkü hedefin (net)", PayFormat.tl(target))
                    let difference: Double = content.net - target.doubleValue
                    Label(difference >= 0
                          ? "Bugünkü hedefin \(Formatters.currency(difference)) ilerisindesin."
                          : "Bugünkü hedefe \(Formatters.currency(-difference)) kaldı.",
                          systemImage: difference >= 0 ? "checkmark.circle.fill" : "hourglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(difference >= 0 ? Theme.mintOnDark : Theme.amberOnDark)
                }
                if let pace = content.pace, goal.period != .day {
                    Divider().overlay(.white.opacity(0.3))
                    Text(paceText(pace, goal: goal))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("dayBreakdown.pace")
                    Label(pace.isAhead
                          ? "\(periodName(goal.period)) hedefinin \(PayFormat.tl(pace.difference)) ilerisinde kalırsın"
                          : "\(periodName(goal.period)) hedefinin \(PayFormat.tl(Money(-pace.difference.value))) gerisinde kalırsın",
                          systemImage: pace.isAhead ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(pace.isAhead ? Theme.mintOnDark : Theme.amberOnDark)
                    if !pace.isAhead, let needed = neededPerDay(pace, goal: goal) {
                        Text("Yetişmek için kalan günlerde günde ortalama \(PayFormat.tl(needed)) net gerekiyor.")
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
            } else {
                Text("Henüz hedefin yok. Bugün ekranındaki “Plan oluştur” ile hedef koyarsan burada hedefinin ilerisinde mi gerisinde mi olduğunu görürsün.")
                    .font(.subheadline)
                    .opacity(0.85)
            }
        }
    }

    private func periodName(_ period: GoalPeriod) -> String {
        switch period {
        case .day: "Günlük"
        case .week: "Haftalık"
        case .month: "Aylık"
        }
    }

    private func paceText(_ pace: GoalPace, goal: GoalSpec) -> String {
        let span: String = goal.period == .week ? "Bu hafta" : "Bu ay"
        let average: Double = pace.workedDays > 0 ? pace.projected.doubleValue / Double(goal.periodWorkDays()) : 0
        return "\(span) çalıştığın \(pace.workedDays) günün ortalaması günde \(Formatters.currency(average.rounded())) net. "
            + "Böyle devam edersen dönem sonunda yaklaşık \(PayFormat.tl(pace.projected)) net kazanırsın "
            + "(hedef \(PayFormat.tl(pace.goal)))."
    }

    /// Kalan is gunlerinde hedefe yetismek icin gereken gunluk net.
    private func neededPerDay(_ pace: GoalPace, goal: GoalSpec) -> Money? {
        let remainingDays: Int = goal.periodWorkDays() - pace.workedDays
        guard remainingDays > 0 else { return nil }
        let average: Decimal = pace.projected.value / Decimal(goal.periodWorkDays())
        let earned: Decimal = average * Decimal(pace.workedDays)
        let needed: Decimal = (pace.goal.value - earned) / Decimal(remainingDays)
        guard needed > 0 else { return nil }
        return Money(Money.round(needed, scale: 0))
    }

    // MARK: - Parcalar

    private func card<C: View>(title: String, symbol: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tile(_ symbol: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title3)
            Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
            Text(unit).font(.caption).opacity(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func amountRow(_ title: String, _ value: String, bold: Bool = false, identifier: String? = nil) -> some View {
        HStack {
            Text(title).font(bold ? .subheadline.weight(.semibold) : .subheadline).opacity(bold ? 1 : 0.9)
            Spacer()
            Text(value)
                .font(bold ? .headline.monospacedDigit() : .subheadline.monospacedDigit())
                .accessibilityIdentifier(identifier ?? "")
        }
    }
}
