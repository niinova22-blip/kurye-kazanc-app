import SwiftUI
import SwiftData

/// Elle hesapla: vardiyayi baslatmayi unuttuysan ya da firmanin uygulamasinda kazanc ekrani yoksa, hatirladigin paket,
/// km ve sureyle gunluk / haftalik / aylik hesap. Ayni motor ve ayni tarife; istenirse kayit olarak eklenir.
struct ManualCalcView: View {
    @Environment(PayrollModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm

    @State private var span: PaySpan = .day
    @State private var date: Date = Date()
    @State private var packages: String = ""
    @State private var nightPackages: String = ""
    @State private var km: String = ""
    @State private var hours: String = ""
    @State private var days: String = ""
    @State private var weekendPackages: String = ""
    @State private var saved = false
    /// "Hesabı bitir" sorusu ve sorulan girdi.
    @State private var asksToAdd = false
    @State private var pendingInput: PayInput?

    private var code: String { model.state.activePlatform ?? "" }

    private var version: TariffVersion? { model.currentVersion() }

    /// Tarifede aksam / gece paket ucreti var mi (Yemeksepeti: saat bantli ucret).
    private var hasNightBand: Bool {
        (version?.items ?? []).contains { item in
            item.type == .singlePackage && (item.conditions.timeBand == .night || (item.conditions.hourFrom ?? 0) >= 18)
        }
    }

    var body: some View {
        Form {
            inputSection
            if let input, input.totalPackages > 0 || input.hours > 0 {
                switch model.calculate(input) {
                case let .success(breakdown):
                    resultSection(breakdown, input: input)
                    saveSection(input)
                    VerificationFootnote(items: UnverifiedItems.from(breakdown, platformName: PayrollModel.platformName(code)))
                case let .failure(error):
                    Section {
                        Label(error.message, systemImage: "xmark.octagon").foregroundStyle(Theme.negative)
                    }
                }
            }
        }
        .navigationTitle("Elle hesapla")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
        .saveConfirmation(isPresented: $saved)
        .alert(addQuestion, isPresented: $asksToAdd, presenting: pendingInput) { input in
            Button("Evet, ekle") { save(input) }
                .accessibilityIdentifier("manual.confirmAdd")
            Button("Hayır, yalnızca hesapladım") { dismiss() }
                .accessibilityIdentifier("manual.skipAdd")
            Button("Hesaba devam et", role: .cancel) {}
        } message: { _ in
            Text("Eklersen kazanç ekranları ve hedefin bu hesapla güncellenir.")
        }
    }

    private var inputSection: some View {
        Section {
            Picker("Dönem", selection: $span.animation(.snappy)) {
                Text("Günlük").tag(PaySpan.day)
                Text("Haftalık").tag(PaySpan.week)
                Text("Aylık").tag(PaySpan.month)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("manual.span")
            DatePicker(span == .day ? "Gün" : span == .week ? "Hafta (bir günü)" : "Ay (bir günü)",
                       selection: $date, in: ...Date(), displayedComponents: .date)
            if span != .day {
                LabeledContent("Aralık", value: "\(PayFormat.day(range.start)) – \(PayFormat.day(range.end))")
            }
            NumberField(title: hasNightBand ? dayTitle : "Paket sayısı", text: $packages, identifier: "manual.packages")
            if hasNightBand {
                NumberField(title: nightTitle, text: $nightPackages, identifier: "manual.night")
            }
            NumberField(title: "Toplam km (biliyorsan)", text: $km, decimal: true, identifier: "manual.km")
            NumberField(title: "Çalışma süresi (saat)", text: $hours, decimal: true, identifier: "manual.hours")
            if span != .day {
                NumberField(title: "Kaç gün çalıştın", text: $days, identifier: "manual.days")
            }

        } header: {
            Text(PayrollModel.platformName(code))
        } footer: {
            Text("Vardiya başlatmayı unuttuğun günler için. Hatırladığın kadarını gir; km boşsa yakıt ve km ücreti hesaba girmez.")
        }
    }

    private let dayTitle: String = "Gündüz paketi (18:00 öncesi)"
    private let nightTitle: String = "Akşam paketi (18:00 sonrası)"

    private func resultSection(_ breakdown: PayBreakdown, input: PayInput) -> some View {
        let workDays: Int = span == .day ? 1 : entry.days
        let detail: PayDetail = model.detail(for: breakdown, days: workDays)
        let fuel: Money = model.fuelModel(fallbackCostPerKm: costPerKm).cost(km: input.totalKm ?? 0, on: input.startDay)
        return Section {
            LabeledContent("Firmadan alacağın", value: PayFormat.tl(detail.periodTotal))
                .accessibilityIdentifier("manual.total")
            if fuel.value > 0 {
                LabeledContent("Yakıt gideri", value: "−" + PayFormat.tl(fuel))
            }
            LabeledContent("Cebine kalan") {
                Text(PayFormat.tl(detail.periodTotal - fuel))
                    .font(.headline)
                    .foregroundStyle(Theme.positive)
                    .accessibilityIdentifier("manual.net")
            }
            if span != .day {
                LabeledContent("Günde ortalama", value: PayFormat.tl(detail.perDayTotal))
            }
            PayDetailDisclosure(detail: detail, periodTitle: periodTitle, identifier: "manual.detail")
        } header: {
            Text("Sonuç")
        } footer: {
            if detail.hasEstimates {
                Text("Aylık sabit ücret, çalıştığın günlere bölünerek eklendi (ay sonunda tek seferde ödenir).")
            }
        }
    }

    private var periodTitle: String? {
        switch span {
        case .day: nil
        case .week: "Haftada"
        case .month: "Ayda"
        }
    }

    /// 1.10: hesap kendiliginden kayda donusmez; "Hesabı bitir" deyince gunluk kazanca eklensin mi diye sorulur.
    private func saveSection(_ input: PayInput) -> some View {
        Section {
            Button {
                pendingInput = input
                asksToAdd = true
            } label: {
                Label("Hesabı bitir", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(input.totalPackages == 0)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .accessibilityIdentifier("manual.save")
            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(Theme.negative)
            }
        } footer: {
            Text(span == .day
                 ? "Bitirince bu hesabın o günün kazancına eklenip eklenmeyeceğini sorarız. Eklemezsen hiçbir yere kaydedilmez."
                 : "Bitirince dönem kaydı olarak eklenip eklenmeyeceğini sorarız. Bu dönemde vardiya kayıtların varsa çift saymamak için ekleme.")
        }
    }

    private var addQuestion: String {
        switch span {
        case .day:
            Calendar.current.isDateInToday(date) ? "Bugünkü kazancına eklensin mi?" : "\(PayFormat.day(model.day(date))) kazancına eklensin mi?"
        case .week, .month:
            "Bu dönem hesabı kayıtlarına eklensin mi?"
        }
    }

    // MARK: - Girdi

    private var range: (start: String, end: String) {
        switch span {
        case .day: (model.day(date), model.day(date))
        case .week: model.weekRange(containing: date)
        case .month: model.monthRange(containing: date)
        }
    }

    private var entry: ManualEntry {
        let defaultDays: Int = span == .week ? (model.goal?.daysPerWeek ?? 6) : (model.goal?.monthWorkDays ?? 26)
        let typedDays: Int = PayFormat.parseInt(days)
        let weekend: Int = PayFormat.parseInt(weekendPackages)
        return ManualEntry(packages: PayFormat.parseInt(packages), nightPackages: hasNightBand ? PayFormat.parseInt(nightPackages) : 0,
                           km: PayFormat.parseDecimal(km), hours: PayFormat.parseDecimal(hours) ?? 0,
                           days: span == .day ? 1 : (typedDays > 0 ? typedDays : defaultDays),
                           weekendPackages: weekend > 0 ? weekend : nil)
    }

    private var input: PayInput? {
        let bounds = range
        guard let base = model.baseInput(day: bounds.start, span: span, end: span == .day ? nil : bounds.end) else { return nil }
        return entry.input(base: base, version: version)
    }

    private func save(_ input: PayInput) {
        let method: EntryMethod = span == .day ? .manual : .period
        // Baslangic verilmez: kayit o gunun son kaydindan sonra baslar (saatler ust uste binmesin)
        guard model.save(input, method: method, context: span == .day ? context : nil) != nil else { return }
        Haptics.success()
        withAnimation { saved = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        }
    }
}
