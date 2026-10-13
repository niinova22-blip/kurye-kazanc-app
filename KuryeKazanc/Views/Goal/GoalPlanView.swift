import SwiftUI
import SwiftData
import UIKit

/// Plan: hedef girisi + secili firmanin tarifesine gore sonuc ve alternatif yollar. Tek firma.
struct GoalPlanView: View {
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro
    @Query(sort: \EarningRecord.startTime, order: .reverse) private var records: [EarningRecord]
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm

    @State private var amount: Decimal?
    @State private var period: GoalPeriod = .month
    @State private var weekdays: Set<Int> = Set(GoalSpec.defaultWeekdays(count: 6))
    @State private var maxHours = 10
    @State private var showsHelp = false
    @State private var saved = false

    var body: some View {
        let entries: [EarningEntry] = records.map(\.entry)
        let result: Result<GoalPlan, PayError>? = payroll.goalPlan(entries: entries, fallbackCostPerKm: costPerKm)
        ScrollViewReader { proxy in
            List {
                inputSection(proxy: proxy)
                GoalResultSections(result: result)
                    .id("result")
                if case .success? = result {
                    GoalAlternativesSection(alternatives: payroll.goalAlternatives(entries: entries, fallbackCostPerKm: costPerKm),
                                            apply: apply)
                }
                VerificationFootnote(items: unverified(result))
            }
            .dismissesKeyboard()
        }
        .navigationTitle("Plan")
        .toolbar { HelpBubble(screen: .plan, showsScreenHelp: $showsHelp, showIntro: showIntro) }
        .sheet(isPresented: $showsHelp) { ScreenHelpSheet(screen: .plan) }
        .saveConfirmation(isPresented: $saved)
        .onAppear(perform: load)
    }

    private func unverified(_ result: Result<GoalPlan, PayError>?) -> [UnverifiedItem] {
        guard case let .success(plan)? = result else { return [] }
        return UnverifiedItems.from(plan.breakdown, platformName: PayrollModel.platformName(plan.platformCode))
    }

    private func inputSection(proxy: ScrollViewProxy) -> some View {
        Section {
            Picker("Hedef dönemi", selection: $period.animation(.snappy)) {
                ForEach(GoalPeriod.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("plan.period")
            HeroAmountField(title: amountTitle, value: $amount, identifier: "plan.amount")
            if period != .day {
                WeekdayPicker(selection: $weekdays, identifier: "plan.days")
            }
            CountStepper(title: "Günde en fazla", value: $maxHours, range: 2...16, unit: "saat", identifier: "plan.hours")
            Button {
                save(proxy: proxy)
            } label: {
                Label("Planı oluştur", systemImage: "sparkles")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled((amount ?? 0) <= 0)
            .opacity((amount ?? 0) > 0 ? 1 : 0.5)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .accessibilityIdentifier("plan.save")
        } header: {
            Text(PayrollModel.platformName(payroll.tariffProfile?.platformCode ?? ""))
        } footer: {
            Text(periodFooter)
        }
    }

    private var amountTitle: String {
        switch period {
        case .day: "Bir günde cebine kalmasını istediğin tutar"
        case .week: "Bir haftada cebine kalmasını istediğin tutar"
        case .month: "Bir ayda cebine kalmasını istediğin tutar"
        }
    }

    private var periodFooter: String {
        switch period {
        case .day:
            "Yakıt düşüldükten sonra kalan tutar. Aylık sabit ücret ve aylık bonuslar, haftada 6 gün çalıştığın varsayılarak güne bölünür."
        case .week:
            "Yakıt düşüldükten sonra kalan tutar. Çalışacağın günleri seç; hafta sonu bonusu yalnızca seçtiğin hafta sonu günleriyle hesaplanır."
        case .month:
            "Yakıt düşüldükten sonra kalan tutar. Çalışacağın günleri seç; ay, seçtiğin gün sayısına göre hesaplanır."
        }
    }

    private func load() {
        guard let goal = payroll.goal else { return }
        amount = goal.amount.value
        period = goal.period
        weekdays = Set(goal.workWeekdays ?? GoalSpec.defaultWeekdays(count: goal.daysPerWeek))
        maxHours = NSDecimalNumber(decimal: goal.maxHoursPerDay).intValue
    }

    private func save(proxy: ScrollViewProxy) {
        guard let amount, amount > 0 else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let days: [Int]? = period == .day ? nil : weekdays.sorted()
        let previous: GoalSpec? = payroll.goal
        let dayCount: Int = period == .day ? (previous?.daysPerWeek ?? 6) : weekdays.count
        payroll.setGoal(GoalSpec(amount: Money(amount), period: period, daysPerWeek: dayCount,
                                 maxHoursPerDay: Decimal(maxHours), workWeekdays: days))
        withAnimation { saved = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.snappy) { proxy.scrollTo("result", anchor: .top) }
        }
    }

    /// Alternatifi hedefe uygular: gun sayisi, gunluk sure, kademe hedefi ya da aksam payi (GoalAlternatives.applied).
    private func apply(_ alternative: GoalAlternative) {
        guard let goal = payroll.goal else { return }
        payroll.setGoal(GoalAlternatives.applied(alternative, to: goal))
        load()
        Haptics.success()
        withAnimation { saved = true }
    }
}

/// Pzt–Paz gun cipleri; en az bir gun secili kalir.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Çalışacağın günler")
                Spacer()
                Text("Haftada \(selection.count) gün")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(value: Double(selection.count)))
                    .accessibilityIdentifier(identifier)
            }
            HStack(spacing: 6) {
                ForEach(GoalSpec.weekdayOrder, id: \.self) { day in
                    chip(day)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ day: Int) -> some View {
        let isOn: Bool = selection.contains(day)
        return Button {
            toggle(day)
        } label: {
            Text(GoalSpec.weekdayShortName(day))
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isOn ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Color.primary.opacity(0.06)))
                }
                .scaleEffect(isOn ? 1 : 0.96)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(GoalSpec.weekdayShortName(day))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("\(identifier).\(day)")
    }

    private func toggle(_ day: Int) {
        if selection.contains(day) {
            guard selection.count > 1 else {
                Haptics.warning()
                return
            }
            withAnimation(.snappy) { _ = selection.remove(day) }
        } else {
            withAnimation(.snappy) { _ = selection.insert(day) }
        }
        Haptics.selection()
    }
}

private struct GoalResultSections: View {
    let result: Result<GoalPlan, PayError>?

    var body: some View {
        switch result {
        case let .success(plan)?:
            GoalResultCard(plan: plan, platformName: PayrollModel.platformName(plan.platformCode))
            if plan.usesFuelFallback {
                Section {
                    Label("Yakıt fiyatını girmedin; km başına tahmini gider kullanıldı. Profil > Araç ve yakıt'tan girebilirsin.",
                          systemImage: "fuelpump")
                        .font(.footnote)
                }
            }
        case let .failure(error)?:
            Section { Text(error.message).foregroundStyle(.secondary) }
        case nil:
            Section {
                Label("Hedefini yaz ve \"Planı oluştur\"a dokun; günde kaç paket ve kaç saat çalışman gerektiği burada görünür.",
                      systemImage: "target")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// "Daha iyi yollar": ayni hedefe daha az saatle ya da daha yuksek netle ulasma secenekleri.
private struct GoalAlternativesSection: View {
    let alternatives: [GoalAlternative]
    let apply: (GoalAlternative) -> Void

    var body: some View {
        if !alternatives.isEmpty {
            Section {
                ForEach(alternatives) { alternative in
                    GoalAlternativeRow(alternative: alternative, apply: apply)
                }
            } header: {
                Text("Daha iyi yollar")
            } footer: {
                Text("Aynı tarife ve senin çalışma hızınla hesaplandı. Bonus eşikleri firmanın tarifesinden gelir.")
            }
            .accessibilityIdentifier("plan.alternatives")
        }
    }
}

private struct GoalAlternativeRow: View {
    let alternative: GoalAlternative
    let apply: (GoalAlternative) -> Void

    var body: some View {
        Button { apply(alternative) } label: { content }
            .buttonStyle(.pressable)
            .accessibilityHint("Dokununca bu yol hedefine uygulanır")
            .accessibilityIdentifier("plan.alternative.\(alternative.id)")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(alternative.title).font(.headline)
                    Text(alternative.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { pills }
                VStack(alignment: .leading, spacing: 6) { pills }
            }
            Label(applyTitle, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("plan.alternative.apply.\(alternative.id)")
        }
        .padding(.vertical, 6)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }

    private var applyTitle: String {
        switch alternative.kind {
        case .nextTier: "Hedefimi buna yükselt"
        case .evening: "Akşam saatleriyle planla"
        case .days, .bonusPace: "Bu planı uygula"
        }
    }

    @ViewBuilder private var pills: some View {
        if alternative.hoursSaved >= 1 {
            pill("Ayda \(Formatters.decimalText(alternative.hoursSaved)) saat daha az", color: Theme.positive)
        }
        if alternative.extraNet.value >= 500 {
            pill("+\(PayFormat.tl(alternative.extraNet)) net", color: Theme.highlight)
        }
        pill("Saati \(PayFormat.tl(alternative.netPerHour)) net", color: Theme.accent)
    }

    private var symbol: String {
        switch alternative.kind {
        case .days: "calendar"
        case .bonusPace: "gift.fill"
        case .nextTier: "chart.line.uptrend.xyaxis"
        case .evening: "moon.stars.fill"
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}
