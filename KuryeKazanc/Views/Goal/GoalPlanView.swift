import SwiftUI
import SwiftData

/// Plan: hedef girisi + secili firmanin tarifesine gore sonuc karti. Tek firma.
struct GoalPlanView: View {
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro
    @Query(sort: \EarningRecord.startTime, order: .reverse) private var records: [EarningRecord]
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm

    @State private var amount: Decimal?
    @State private var period: GoalPeriod = .month
    @State private var daysPerWeek = 6
    @State private var maxHours = 10
    @State private var showsHelp = false
    @State private var saved = false

    var body: some View {
        let result: Result<GoalPlan, PayError>? = payroll.goalPlan(entries: records.map(\.entry), fallbackCostPerKm: costPerKm)
        List {
            inputSection
            GoalResultSections(result: result)
            VerificationFootnote(items: unverified(result))
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

    private var inputSection: some View {
        Section {
            Picker("Dönem", selection: $period) {
                ForEach(GoalPeriod.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            AmountField(title: "Net hedef (yakıt düşülmüş)", value: $amount, identifier: "plan.amount")
            CountStepper(title: "Haftada", value: $daysPerWeek, range: 1...7, unit: "gün", identifier: "plan.days")
            CountStepper(title: "Günde en fazla", value: $maxHours, range: 2...16, unit: "saat", identifier: "plan.hours")
            Button("Hedefi kaydet", action: save)
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled((amount ?? 0) <= 0)
                .opacity((amount ?? 0) > 0 ? 1 : 0.5)
                .accessibilityIdentifier("plan.save")
        } header: {
            Text(PayrollModel.platformName(payroll.tariffProfile?.platformCode ?? ""))
        }
    }

    private func load() {
        guard let goal = payroll.goal else { return }
        amount = goal.amount.value
        period = goal.period
        daysPerWeek = goal.daysPerWeek
        maxHours = NSDecimalNumber(decimal: goal.maxHoursPerDay).intValue
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        payroll.setGoal(GoalSpec(amount: Money(amount), period: period, daysPerWeek: daysPerWeek,
                                 maxHoursPerDay: Decimal(maxHours)))
        withAnimation { saved = true }
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
                    Label("Yakıt fiyatı girilmedi; km başı tahmini maliyet kullanıldı. Profil > Araç ve yakıt.",
                          systemImage: "fuelpump")
                        .font(.footnote)
                }
            }
        case let .failure(error)?:
            Section { Text(error.message).foregroundStyle(.secondary) }
        case nil:
            Section {
                Text("Hedefini gir ve kaydet; gereken paket, saat ve bölge burada görünür.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
