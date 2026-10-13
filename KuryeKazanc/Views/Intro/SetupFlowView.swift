import SwiftUI

enum SetupStep: Int, CaseIterable {
    case firm, questions, fuel, goal
}

/// Kurulum: calisilan firma, firmaya ozel sorular, yakit ve hedef.
/// `firmOnly` (Profil > Calistigim firma): yalnizca firma ve sorulari.
struct SetupFlowView: View {
    @Environment(PayrollModel.self) private var payroll
    var firmOnly: Bool = false
    /// Karsilama ekraninda secilen firma: kurulum firma adimini atlayarak sorularla baslar (Geri ile degistirilebilir).
    var initialFirm: String? = nil
    let onFinish: () -> Void

    @State private var step: SetupStep = .firm
    @State private var firm: String?
    @State private var regionTier: String?
    @State private var seniority: Int = 0
    @State private var contractHours: Int = 10
    @State private var vehicle: String = "motorcycle"
    @State private var flags: Set<String> = []
    @State private var fuelPrice: Decimal?
    @State private var fuelType: FuelType = .gasoline
    @State private var consumption: Decimal = 3
    @State private var goalAmount: Decimal?
    @State private var goalPeriod: GoalPeriod = .month
    @State private var weekdays: Set<Int> = Set(GoalSpec.defaultWeekdays(count: 6))
    @State private var maxHours = 10
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form { content }
                .dismissesKeyboard()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    footer
                        .padding()
                        .background(.bar)
                }
                .animation(.snappy, value: step)
        }
        .onAppear(perform: load)
    }

    private var questions: TariffQuestions {
        guard let firm else { return TariffQuestions() }
        return payroll.questions(for: firm)
    }

    private var title: String {
        switch step {
        case .firm: "Firman"
        case .questions: "Tarife bilgilerin"
        case .fuel: "Araç ve yakıt"
        case .goal: "Hedefin"
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .firm: firmSection
        case .questions:
            TariffQuestionSections(questions: questions, regionTier: $regionTier, seniority: $seniority,
                                   contractHours: $contractHours, vehicle: $vehicle, flags: $flags)
        case .fuel: fuelSection
        case .goal: goalSection
        }
    }

    private var firmSection: some View {
        Section {
            FirmPicker(selection: $firm)
        } header: {
            Text("Hangi firmayla çalışıyorsun?")
                .font(.title3.bold())
                .textCase(nil)
                .foregroundStyle(.primary)
        } footer: {
            Text("Tüm hesaplar bu firmanın tarifesine göre yapılır. Profil > Çalıştığım firma'dan değiştirebilirsin.")
        }
    }

    private var fuelSection: some View {
        Section {
            if questions.vehicleTypes.isEmpty {
                Picker("Araç", selection: $vehicle) {
                    Text("Motosiklet").tag("motorcycle")
                    Text("Otomobil").tag("car")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("fuel.vehicle")
                .onChange(of: vehicle) { _, value in
                    consumption = FuelCostModel.defaultConsumption(vehicleType: value)
                }
            }
            Picker("Yakıt", selection: $fuelType) {
                ForEach(FuelType.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            HeroAmountField(title: "Güncel fiyat (\(fuelType.unitName) başına)", value: $fuelPrice, identifier: "fuel.price")
            DecimalStepper(title: "Tüketim", value: $consumption, range: 1...20, step: Decimal(string: "0.5")!,
                           unit: "\(fuelType.unitName)/100 km", identifier: "fuel.consumption")
        } footer: {
            Text("Pompadaki fiyatı gir; km başı yakıt gideri bununla hesaplanır. Şimdilik elle giriliyor.")
        }
    }

    private var goalSection: some View {
        Section {
            Picker("Dönem", selection: $goalPeriod.animation(.snappy)) {
                ForEach(GoalPeriod.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            HeroAmountField(title: "Cebine kalmasını istediğin tutar (yakıt düşülmüş)", value: $goalAmount,
                            identifier: "goal.amount")
            if goalPeriod != .day {
                WeekdayPicker(selection: $weekdays, identifier: "goal.days")
            }
            CountStepper(title: "Günde en fazla", value: $maxHours, range: 2...16, unit: "saat", identifier: "goal.hours")
        } footer: {
            Text("İstersen boş bırak; hedefini sonra Plan ekranından da koyabilirsin.")
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .firm {
                Button("Geri", action: goBack)
                    .buttonStyle(.pressable)
                    .frame(width: 80)
                    .accessibilityIdentifier("setup.back")
            }
            if isLast {
                Button("Bitir", action: finish)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.5)
                    .accessibilityIdentifier("setup.finish")
            } else {
                Button("Devam", action: goNext)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.5)
                    .accessibilityIdentifier("setup.next")
            }
        }
    }

    private var isLast: Bool {
        if firmOnly {
            return step == .questions || (step == .firm && questions.isEmpty)
        }
        return step == .goal
    }

    private var canContinue: Bool {
        switch step {
        case .firm: firm != nil
        case .questions: questions.regionTiers.isEmpty || regionTier != nil
        case .fuel, .goal: true
        }
    }

    private func goNext() {
        Haptics.selection()
        var next: SetupStep = SetupStep(rawValue: step.rawValue + 1) ?? .goal
        if next == .questions, questions.isEmpty { next = .fuel }
        step = next
    }

    private func goBack() {
        var previous: SetupStep = SetupStep(rawValue: step.rawValue - 1) ?? .firm
        if previous == .questions, questions.isEmpty { previous = .firm }
        step = previous
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let profile: CourierTariffProfile? = payroll.tariffProfile
        firm = profile?.platformCode ?? initialFirm
        if profile == nil, initialFirm != nil, !firmOnly {
            step = questions.isEmpty ? .fuel : .questions
        }
        regionTier = profile?.regionTier
        seniority = profile?.seniorityYears ?? 0
        contractHours = profile?.contractHours ?? 10
        vehicle = profile?.vehicleType ?? "motorcycle"
        flags = Set(profile?.flags ?? [])
        if let goal = payroll.goal {
            goalAmount = goal.amount.value
            goalPeriod = goal.period
            weekdays = Set(goal.workWeekdays ?? GoalSpec.defaultWeekdays(count: goal.daysPerWeek))
            maxHours = NSDecimalNumber(decimal: goal.maxHoursPerDay).intValue
        }
        consumption = payroll.state.fuel.consumptionPer100Km ?? FuelCostModel.defaultConsumption(vehicleType: vehicle)
    }

    private func finish() {
        guard let firm else { return }
        let q: TariffQuestions = questions
        payroll.chooseFirm(firm,
                           regionTier: q.regionTiers.isEmpty ? nil : regionTier,
                           seniorityYears: q.asksSeniority ? seniority : nil,
                           vehicleType: vehicle,
                           flags: Array(flags.intersection(Set(q.flags))),
                           contractHours: q.contractHours.isEmpty ? nil : contractHours)
        if !firmOnly {
            payroll.setConsumption(consumption)
            if let fuelPrice, fuelPrice > 0 {
                payroll.addFuelPrice(Money(fuelPrice), type: fuelType, on: Date())
            }
            if let goalAmount, goalAmount > 0 {
                let days: [Int]? = goalPeriod == .day ? nil : weekdays.sorted()
                payroll.setGoal(GoalSpec(amount: Money(goalAmount), period: goalPeriod, daysPerWeek: days?.count ?? 6,
                                         maxHoursPerDay: Decimal(maxHours), workWeekdays: days))
            }
        }
        Haptics.success()
        onFinish()
    }
}

/// Iki firma; Paket Taxi secilince kollari (Restoran / Migros / Migros Hemen) acilir. Secim tarife kodudur.
struct FirmPicker: View {
    @Binding var selection: String?
    @State private var openBrand: String?

    var body: some View {
        ForEach(PayPlatform.brands) { firm in
            let isSelected: Bool = selection.flatMap { PayPlatform.brand(of: $0)?.id } == firm.id
            Button {
                withAnimation(.snappy) {
                    openBrand = firm.id
                    if firm.hasBranches {
                        if !isSelected { selection = nil }
                    } else {
                        selection = firm.branches.first?.code
                    }
                }
                Haptics.selection()
            } label: {
                FirmPickerRow(firm: firm, isSelected: isSelected || openBrand == firm.id)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("firm.\(firm.id)")
            if firm.hasBranches, openBrand == firm.id || isSelected {
                ForEach(firm.branches) { option in
                    BranchRow(option: option, isSelected: selection == option.code) {
                        withAnimation(.snappy) { selection = option.code }
                        Haptics.selection()
                    }
                    .padding(.leading, 12)
                }
            }
        }
    }
}

private struct FirmPickerRow: View {
    let firm: FirmBrand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(firm.monogram)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(Theme.accent.opacity(isSelected ? 0.25 : 0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(firm.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(firm.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .contentShape(Rectangle())
    }
}

/// Firmanin tarifesinin istedigi sorular (bolge kademesi, kidem, arac, isaretler).
struct TariffQuestionSections: View {
    let questions: TariffQuestions
    @Binding var regionTier: String?
    @Binding var seniority: Int
    @Binding var contractHours: Int
    @Binding var vehicle: String
    @Binding var flags: Set<String>

    var body: some View {
        if !questions.regionTiers.isEmpty { regionSection }
        if !questions.contractHours.isEmpty {
            Section {
                Picker("Günlük çalışma", selection: $contractHours) {
                    ForEach(questions.contractHours, id: \.self) { Text("\($0) saat").tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("question.hours")
            } header: {
                Text("Günde kaç saat çalışıyorsun?")
            } footer: {
                Text("Sabit ücret, kıdem primi ve paket primi eşikleri günlük saate göre değişir (26 gün fiyatı).")
            }
        }
        if questions.asksSeniority {
            Section("Kıdem") {
                CountStepper(title: "Bu firmada", value: $seniority, range: 0...30, unit: "yıl", identifier: "question.seniority")
            }
        }
        if !questions.vehicleTypes.isEmpty {
            Section("Araç") {
                Picker("Araç", selection: $vehicle) {
                    ForEach(questions.vehicleTypes, id: \.self) { Text(TariffQuestions.vehicleName($0)).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        if !questions.flags.isEmpty { flagsSection }
        if questions.isEmpty {
            Section { Text("Bu firmanın tarifesi için ek bilgi gerekmiyor.").foregroundStyle(.secondary) }
        }
    }

    private var regionSection: some View {
        Section {
            ForEach(questions.regionTiers, id: \.self) { tier in
                Button {
                    regionTier = tier
                    Haptics.selection()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TariffQuestions.regionName(tier)).foregroundStyle(.primary)
                            let detail: String = TariffQuestions.regionDetail(tier)
                            if !detail.isEmpty {
                                Text(detail).font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer()
                        if regionTier == tier {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
                .accessibilityIdentifier("question.region.\(tier)")
            }
        } header: {
            Text("Çalıştığın bölge")
        } footer: {
            Text("Vardiya başlayınca konumundan kendiliğinden bulunur; şimdilik çalıştığın yeri seç.")
        }
    }

    private var flagsSection: some View {
        Section("Ek destekler") {
            ForEach(questions.flags, id: \.self) { flag in
                Toggle(TariffQuestions.flagName(flag), isOn: binding(for: flag))
                    .accessibilityIdentifier("question.flag.\(flag)")
            }
        }
    }

    private func binding(for flag: String) -> Binding<Bool> {
        Binding(
            get: { flags.contains(flag) },
            set: { isOn in
                if isOn { flags.insert(flag) } else { flags.remove(flag) }
                Haptics.selection()
            }
        )
    }
}
