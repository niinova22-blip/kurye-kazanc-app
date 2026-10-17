import SwiftUI
import SwiftData

/// Elle ekle: vardiyayi baslatmayi unuttugun gun icin paket, saat ve harcadigin yakit (TL). Ayni motor ve ayni tarife;
/// "Kaydet" o gunun kazancina ekler.
/// 1.15 sade: yalnizca gunluk (haftalik / aylik kalkti), adim kartlari ve "eklensin mi" sorusu kalkti. Yakit varsayilan
/// olarak harcanan tutardir; km yalnizca firma km basina oduyorsa ya da Araç ve yakıt'ta km'den hesap acildiysa sorulur.
struct ManualCalcView: View {
    @Environment(PayrollModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.fuelFromKmKey) private var fuelFromKm = false

    @State private var date: Date = Date()
    @State private var packages: String = ""
    @State private var nightPackages: String = ""
    @State private var km: String = ""
    @State private var hours: String = ""
    @State private var fuelSpent: String = ""
    @State private var saved = false

    private var code: String { model.state.activePlatform ?? "" }

    private var version: TariffVersion? { model.currentVersion() }

    /// Tarifede aksam / gece paket ucreti var mi (Yemeksepeti: saat bantli ucret).
    private var hasNightBand: Bool {
        (version?.items ?? []).contains { item in
            item.type == .singlePackage && (item.conditions.timeBand == .night || (item.conditions.hourFrom ?? 0) >= 18)
        }
    }

    /// Firma km basina ya da mesafe bandiyla oduyor mu (o zaman km ucret icin gerekli).
    private var paysPerKm: Bool {
        (version?.items ?? []).contains { $0.type == .perKm }
    }

    private var asksKm: Bool { fuelFromKm || paysPerKm }

    var body: some View {
        Form {
            inputSection
            if let input, input.totalPackages > 0 || input.hours > 0 {
                switch model.dayShare(input) {
                case let .success(breakdown):
                    resultSection(breakdown, input: input)
                    saveSection(input)
                    Section {
                        PayDetailDisclosure(detail: model.detail(for: breakdown, days: 1), periodTitle: nil,
                                            identifier: "manual.detail")
                    }
                case let .failure(error):
                    Section {
                        Label(error.message, systemImage: "xmark.octagon").foregroundStyle(Theme.negative)
                    }
                }
            }
        }
        .navigationTitle("Elle ekle")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
        .saveConfirmation(isPresented: $saved)
    }

    // MARK: - Girdiler

    private var inputSection: some View {
        Section {
            DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) {
                Label("Gün", systemImage: "calendar")
            }
            ManualInputRow(symbol: "shippingbox.fill", title: hasNightBand ? "Gündüz paketi" : "Paket sayısı",
                           hint: hasNightBand ? "18:00'den önce" : nil,
                           unit: "paket", text: $packages, identifier: "manual.packages")
            if hasNightBand {
                ManualInputRow(symbol: "moon.stars.fill", title: "Akşam paketi", hint: "18:00'den sonra",
                               unit: "paket", text: $nightPackages, identifier: "manual.night")
            }
            ManualInputRow(symbol: "clock.fill", title: "Kaç saat çalıştın", hint: nil,
                           unit: "saat", text: $hours, decimal: true, identifier: "manual.hours")
            if asksKm {
                ManualInputRow(symbol: "road.lanes", title: "Toplam km", hint: nil,
                               unit: "km", text: $km, decimal: true, identifier: "manual.km")
            }
            if !fuelFromKm {
                ManualInputRow(symbol: "fuelpump.fill", title: "Yakıta ne harcadın", hint: nil,
                               unit: "₺", text: $fuelSpent, decimal: true, identifier: "manual.fuel")
            }
        }
    }

    /// Yakit gideri: varsayilan olarak yazilan tutar; km'den hesap acildiysa km × tuketim × fiyat.
    private func fuelCost(_ input: PayInput) -> Money {
        if fuelFromKm {
            return model.fuelModel(fallbackCostPerKm: costPerKm).cost(km: input.totalKm ?? 0, on: input.startDay)
        }
        return Money(Money.round(PayFormat.parseDecimal(fuelSpent) ?? 0))
    }

    private func resultSection(_ breakdown: PayBreakdown, input: PayInput) -> some View {
        let total: Money = model.detail(for: breakdown, days: 1).periodTotal
        let fuel: Money = fuelCost(input)
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cebine kalan")
                    .font(.subheadline)
                    .opacity(0.85)
                Text(PayFormat.tl(total - fuel))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("manual.net")
                Text("Firmadan \(PayFormat.tl(total)) · Yakıt −\(PayFormat.tl(fuel))")
                    .font(.footnote)
                    .opacity(0.85)
                    .monospacedDigit()
                    .accessibilityIdentifier("manual.total")
            }
            .brandCard()
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func saveSection(_ input: PayInput) -> some View {
        Section {
            Button {
                save(input)
            } label: {
                Label("Kaydet", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(input.totalPackages == 0 || saved)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .accessibilityIdentifier("manual.save")
            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(Theme.negative)
            }
        }
    }

    // MARK: - Girdi

    private var entry: ManualEntry {
        ManualEntry(packages: PayFormat.parseInt(packages), nightPackages: hasNightBand ? PayFormat.parseInt(nightPackages) : 0,
                    km: asksKm ? PayFormat.parseDecimal(km) : nil, hours: PayFormat.parseDecimal(hours) ?? 0, days: 1)
    }

    private var input: PayInput? {
        let day: String = model.day(date)
        guard let base = model.baseInput(day: day, span: .day, end: nil) else { return nil }
        return entry.input(base: base, version: version)
    }

    private func save(_ input: PayInput) {
        // Baslangic verilmez: kayit o gunun son kaydindan sonra baslar (saatler ust uste binmesin)
        guard model.save(input, method: .manual, context: context) != nil else { return }
        // Harcanan yakit gun gideri olarak kaydedilir (o gun km'den yakit tahmini dusulmez)
        if !fuelFromKm, let spent = PayFormat.parseDecimal(fuelSpent), spent > 0 {
            context.insert(ExpenseRecord(date: date, type: .fuel, amount: NSDecimalNumber(decimal: spent).doubleValue))
            try? context.save()
        }
        Haptics.success()
        withAnimation { saved = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        }
    }
}

/// Elle giris satiri: renkli simge, baslik (+ istege bagli kisa ipucu) ve birimli sayi alani (odakta vurgu).
private struct ManualInputRow: View {
    let symbol: String
    let title: String
    let hint: String?
    let unit: String
    @Binding var text: String
    var decimal: Bool = false
    let identifier: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                if let hint {
                    Text(hint).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .keyboardType(decimal ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .focused($focused)
                    .frame(minWidth: 44, maxWidth: 80)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(identifier)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(focused ? Theme.accent.opacity(0.08) : Theme.groupedBackground))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Theme.accent : Color.clear, lineWidth: 1.5))
            .animation(.easeOut(duration: 0.18), value: focused)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onChange(of: focused) { _, isFocused in
            if isFocused { Haptics.selection() }
        }
    }
}
