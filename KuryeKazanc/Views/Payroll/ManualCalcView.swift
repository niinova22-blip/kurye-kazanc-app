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
            introSection
            whenSection
            whatSection
            if let input, input.totalPackages > 0 || input.hours > 0 {
                switch model.calculate(input) {
                case let .success(breakdown):
                    resultSection(breakdown, input: input)
                    saveSection(input)
                    detailSection(breakdown)
                    VerificationFootnote(items: UnverifiedItems.from(breakdown, platformName: PayrollModel.platformName(code)))
                case let .failure(error):
                    Section {
                        Label(error.message, systemImage: "xmark.octagon").foregroundStyle(Theme.negative)
                    }
                }
            } else {
                emptyResultSection
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

    // MARK: - Ust kart (1.11)

    /// Ekranin ne ise yaradigi ve uc adim: donemi sec, hatirladiklarini yaz, bitir ve kayda ekleyip eklemeyecegini sec.
    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.title2.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vardiyayı başlatmayı mı unuttun?")
                            .font(.headline)
                        Text("Hatırladığın kadarını yaz; \(PayrollModel.platformName(code)) tarifesi gerisini hesaplar.")
                            .font(.subheadline)
                            .opacity(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 8) {
                    stepChip(1, "Dönemi seç")
                    stepChip(2, "Paketleri yaz")
                    stepChip(3, "Bitir ve ekle")
                }
            }
            .brandCard()
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func stepChip(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.caption.weight(.heavy))
                .frame(width: 20, height: 20)
                .background(.white, in: Circle())
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.14), in: Capsule())
    }

    // MARK: - Girdiler

    private var whenSection: some View {
        Section {
            Picker("Dönem", selection: $span.animation(.snappy)) {
                Text("Günlük").tag(PaySpan.day)
                Text("Haftalık").tag(PaySpan.week)
                Text("Aylık").tag(PaySpan.month)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("manual.span")
            DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) {
                Label(span == .day ? "Hangi gün" : span == .week ? "Hangi hafta (bir günü)" : "Hangi ay (bir günü)",
                      systemImage: "calendar")
            }
            if span != .day {
                LabeledContent {
                    Text("\(PayFormat.day(range.start)) – \(PayFormat.day(range.end))")
                } label: {
                    Label("Aralık", systemImage: "arrow.left.and.right")
                }
            }
        } header: {
            Text("Ne zaman?")
        }
    }

    private var whatSection: some View {
        Section {
            ManualInputRow(symbol: "shippingbox.fill", title: hasNightBand ? dayTitle : "Paket sayısı",
                           hint: hasNightBand ? "18:00'den önce bıraktıkların" : "Teslim ettiğin toplam paket",
                           unit: "paket", text: $packages, identifier: "manual.packages")
            if hasNightBand {
                ManualInputRow(symbol: "moon.stars.fill", title: nightTitle, hint: "Akşam bandı daha yüksek ödenir",
                               unit: "paket", text: $nightPackages, identifier: "manual.night")
            }
            ManualInputRow(symbol: "road.lanes", title: "Toplam km", hint: "Biliyorsan; yakıt ve km ücreti için",
                           unit: "km", text: $km, decimal: true, identifier: "manual.km")
            ManualInputRow(symbol: "clock.fill", title: "Çalışma süresi", hint: "Saatlik net bununla hesaplanır",
                           unit: "saat", text: $hours, decimal: true, identifier: "manual.hours")
            if span != .day {
                ManualInputRow(symbol: "calendar.badge.clock", title: "Kaç gün çalıştın",
                               hint: "Boşsa planındaki gün sayısı", unit: "gün", text: $days, identifier: "manual.days")
            }
        } header: {
            Text("Ne yaptın?")
        } footer: {
            Text("Km boş kalırsa yakıt gideri ve km ücreti hesaba girmez. Sonuç yazdıkça güncellenir.")
        }
    }

    /// Paket yazilmadan once sonucun nerede gorunecegini anlatan bos durum.
    private var emptyResultSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("Paket sayısını yazınca firmadan alacağın, yakıt gideri ve cebine kalan burada görünür.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private let dayTitle: String = "Gündüz paketi"
    private let nightTitle: String = "Akşam paketi"

    private func resultSection(_ breakdown: PayBreakdown, input: PayInput) -> some View {
        let workDays: Int = span == .day ? 1 : entry.days
        let detail: PayDetail = model.detail(for: breakdown, days: workDays)
        let fuel: Money = model.fuelModel(fallbackCostPerKm: costPerKm).cost(km: input.totalKm ?? 0, on: input.startDay)
        return Group {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(span == .day ? "Bu gün cebine kalan" : span == .week ? "Bu hafta cebine kalan" : "Bu ay cebine kalan")
                        .font(.subheadline)
                        .opacity(0.85)
                    Text(PayFormat.tl(detail.periodTotal - fuel))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("manual.net")
                    VStack(spacing: 8) {
                        resultRow("arrow.down.circle.fill", "Firmadan alacağın", PayFormat.tl(detail.periodTotal),
                                  identifier: "manual.total")
                        resultRow("fuelpump.fill", "Yakıt gideri", fuel.value > 0 ? "−" + PayFormat.tl(fuel) : "km girilmedi")
                        if span != .day {
                            resultRow("calendar", "Günde ortalama", PayFormat.tl(detail.perDayTotal))
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if detail.hasEstimates {
                        Label("Aylık sabit ücretin çalıştığın günlere düşen payı dahil (ay sonunda ödenir).",
                              systemImage: "banknote")
                            .font(.caption)
                            .opacity(0.85)
                    }
                }
                .brandCard()
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// Kalem kalem dokum ("Hesabı bitir"in altinda; once sonuc ve karar, sonra ayrinti).
    private func detailSection(_ breakdown: PayBreakdown) -> some View {
        Section {
            PayDetailDisclosure(detail: model.detail(for: breakdown, days: span == .day ? 1 : entry.days),
                                periodTitle: periodTitle, identifier: "manual.detail")
        } header: {
            Text("Nereden geldi?")
        }
    }

    private func resultRow(_ symbol: String, _ title: String, _ value: String, identifier: String? = nil) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .accessibilityIdentifier(identifier ?? "")
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

/// Elle hesap girdisi: renkli simge, baslik + kisa ipucu ve birimli sayi alani (odakta vurgu).
private struct ManualInputRow: View {
    let symbol: String
    let title: String
    let hint: String
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
                Text(hint).font(.caption).foregroundStyle(.secondary).lineLimit(2)
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
