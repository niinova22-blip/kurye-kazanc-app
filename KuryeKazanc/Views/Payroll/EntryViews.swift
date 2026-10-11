import SwiftUI
import SwiftData

// MARK: - Hizli tahmin

/// "Bugun ne kadar kazandim": platform + paket + sure. Detay gerektirmez; ayni motor ve tarife.
struct QuickEstimateView: View {
    @Environment(PayrollModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date()
    @State private var packages: String = ""
    @State private var hours: String = ""

    var body: some View {
        Form {
            Section {
                DatePicker("Gün", selection: $date, in: ...Date(), displayedComponents: .date)
                NumberField(title: "Paket sayısı", text: $packages, identifier: "quick.packages")
                NumberField(title: "Çalışma süresi (saat)", text: $hours, decimal: true, identifier: "quick.hours")
            } footer: {
                Text("Paketler gündüz tekli paket sayılır. Gece, birleşen paket, km ve bonus ayrıntısı için detaylı kayıt kullan.")
            }
            if let input {
                CalculationSections(result: model.calculate(input))
                Section {
                    Button("Günlük kayıt olarak kaydet") { save(input) }
                        .disabled(PayFormat.parseInt(packages) == 0)
                        .accessibilityIdentifier("quick.save")
                    if let error = model.lastError {
                        Text(error).font(.caption).foregroundStyle(Theme.negative)
                    }
                }
            }
        }
        .navigationTitle("Hızlı tahmin")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
    }

    private var input: PayInput? {
        guard var value = model.baseInput(day: model.day(date)) else { return nil }
        value.dayPackages = PayFormat.parseInt(packages)
        value.hours = PayFormat.parseDecimal(hours) ?? 0
        return value
    }

    private func save(_ input: PayInput) {
        if model.save(input, method: .quick, context: context) != nil { dismiss() }
    }
}

/// Hesap sonucu ya da hata.
struct CalculationSections: View {
    let result: Result<PayBreakdown, PayError>

    var body: some View {
        switch result {
        case let .success(breakdown):
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tahmini brüt hakediş").font(.subheadline).foregroundStyle(.secondary)
                    Text(PayFormat.range(breakdown.gross, breakdown.grossUpper))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .accessibilityIdentifier("estimate.gross")
                    if breakdown.needsVerification {
                        Label("Doğrulanmamış tarife kalemi içerir; sonuç tahminidir.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            BreakdownSections(breakdown: breakdown)
        case let .failure(error):
            Section {
                Label(error.message, systemImage: "xmark.octagon").foregroundStyle(Theme.negative)
            }
        }
    }
}

// MARK: - Detayli gunluk kayit

/// Detayli kayit formunun metin durumu.
struct DetailedForm {
    var start: Date
    var end: Date
    var dayPackages: String = ""
    var nightPackages: String = ""
    var combinedPackages: String = ""
    var totalKm: String = ""
    var deliveryKm: String = ""
    var tips: String = ""
    var surgeMultiplier: String = ""
    var surgePackages: String = ""
    var weeklyPerformance: Bool = false
    var weeklyPerformanceAmount: String = ""
    var referral: Bool = false
    var referralAmount: String = ""
    var womanEmployment: Bool = false
    var extraPayments: String = ""
    var deductions: String = ""
    var advances: String = ""

    init(now: Date = Date()) {
        end = now
        start = now.addingTimeInterval(-8 * 3600)
    }

    var hours: Decimal {
        let seconds: Double = max(0, end.timeIntervalSince(start))
        return Money.round(Decimal(seconds / 3600), scale: 2)
    }

    /// "2,5 7 4" -> [2.5, 7, 4]. Ayirac bosluk ya da noktali virgul (virgul Turkce ondalik).
    var distances: [Decimal] {
        deliveryKm.split(whereSeparator: { $0 == " " || $0 == ";" || $0 == "\n" })
            .compactMap { Decimal.parse(String($0)) }
            .filter { $0 > 0 }
    }

    func apply(to base: PayInput) -> PayInput {
        var input = base
        input.dayPackages = PayFormat.parseInt(dayPackages)
        input.nightPackages = PayFormat.parseInt(nightPackages)
        input.combinedPackages = PayFormat.parseInt(combinedPackages)
        input.totalKm = PayFormat.parseDecimal(totalKm)
        input.deliveryDistancesKm = distances
        input.hours = hours
        input.tips = PayFormat.parseMoney(tips) ?? .zero
        input.surgeMultiplier = PayFormat.parseDecimal(surgeMultiplier)
        input.surgePackages = PayFormat.parseInt(surgePackages)
        var flags: [String] = []
        if weeklyPerformance {
            flags.append("weekly_performance")
            if let amount = PayFormat.parseMoney(weeklyPerformanceAmount) { input.flagAmounts["weekly_performance"] = amount }
        }
        if womanEmployment { flags.append("woman_employment") }
        input.flags = flags
        input.referralConditionsMet = referral
        input.referralAmount = referral ? PayFormat.parseMoney(referralAmount) : nil
        input.extraPayments = PayFormat.parseMoney(extraPayments) ?? .zero
        input.deductions = PayFormat.parseMoney(deductions) ?? .zero
        input.advances = PayFormat.parseMoney(advances) ?? .zero
        return input
    }
}

/// Platforma ozgu tum alanlar, her kazanc kalemi ayri gosterilir.
struct DetailedLogView: View {
    @Environment(PayrollModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var form: DetailedForm = DetailedForm()

    var body: some View {
        let code: String = model.state.activePlatform ?? ""
        Form {
            Section("Vardiya") {
                DatePicker("Başlangıç", selection: $form.start, in: ...Date())
                DatePicker("Bitiş", selection: $form.end, in: form.start...)
                LabeledContent("Süre", value: "\(PayFormat.number(form.hours)) sa")
            }
            PackageFields(form: $form, platform: code)
            Section {
                NumberField(title: "Toplam km", text: $form.totalKm, decimal: true, identifier: "detail.km")
                TextField("Teslimat başına km (ör. 2,5 7 4)", text: $form.deliveryKm)
                    .keyboardType(.numbersAndPunctuation)
            } header: {
                Text("Mesafe")
            } footer: {
                Text("Mesafe bantlı km primi için teslimat başına km girersen daha doğru hesaplanır.")
            }
            PlatformExtraFields(form: $form, platform: code)
            Section("Ek ödeme, kesinti, avans") {
                NumberField(title: "Bahşiş", text: $form.tips, decimal: true, identifier: "detail.tips")
                NumberField(title: "Diğer ek ödeme", text: $form.extraPayments, decimal: true, identifier: "detail.extra")
                NumberField(title: "Kesinti", text: $form.deductions, decimal: true, identifier: "detail.deductions")
                NumberField(title: "Avans", text: $form.advances, decimal: true, identifier: "detail.advances")
            }
            if let input {
                CalculationSections(result: model.calculate(input))
                Section {
                    Button("Kaydet") { save(input) }
                        .accessibilityIdentifier("detail.save")
                    if let error = model.lastError {
                        Text(error).font(.caption).foregroundStyle(Theme.negative)
                    }
                }
            }
        }
        .navigationTitle("Detaylı kayıt")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
    }

    private var input: PayInput? {
        guard let base = model.baseInput(day: model.day(form.start)) else { return nil }
        return form.apply(to: base)
    }

    private func save(_ input: PayInput) {
        if model.save(input, method: .detailed, start: form.start, end: form.end, context: context) != nil { dismiss() }
    }
}

private struct PackageFields: View {
    @Binding var form: DetailedForm
    let platform: String

    var body: some View {
        Section("Paketler") {
            if platform == "trendyol_go" {
                NumberField(title: "Gündüz tekli paket", text: $form.dayPackages, identifier: "detail.day")
                NumberField(title: "Gece tekli paket", text: $form.nightPackages, identifier: "detail.night")
            } else if platform == "getir" {
                NumberField(title: "İlk paket (tekli)", text: $form.dayPackages, identifier: "detail.day")
            } else {
                NumberField(title: "Tekli paket", text: $form.dayPackages, identifier: "detail.day")
            }
            NumberField(title: "Birleşen paket", text: $form.combinedPackages, identifier: "detail.combined")
        }
    }
}

private struct PlatformExtraFields: View {
    @Environment(PayrollModel.self) private var model
    @Binding var form: DetailedForm
    let platform: String

    var body: some View {
        switch platform {
        case "trendyol_go":
            Section {
                NumberField(title: "Yoğunluk çarpanı (ör. 1,5)", text: $form.surgeMultiplier, decimal: true, identifier: "detail.surge")
                NumberField(title: "Çarpanlı paket sayısı", text: $form.surgePackages, identifier: "detail.surgePackages")
                Toggle("Haftalık performans bonusu hak edildi", isOn: $form.weeklyPerformance)
                if form.weeklyPerformance {
                    NumberField(title: "Bildirilen tutar (biliyorsan)", text: $form.weeklyPerformanceAmount, decimal: true,
                                identifier: "detail.weeklyAmount")
                }
            } header: {
                Text("Trendyol GO")
            } footer: {
                Text("Yoğunluk çarpanı yalnızca senin girdiğinle uygulanır; hava, maç ya da tatil için otomatik çarpan yoktur.")
            }
        case "getir":
            Section("Getir") {
                LabeledContent("Tarife", value: (model.state.vehicleType ?? "motorcycle") == "car" ? "Araçlı" : "Motorlu")
                Text("Araç tipini Hakediş ayarlarından değiştirebilirsin. Hafta sonu bonusu Cuma–Pazar toplamından dönem özetinde hesaplanır.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case "yemeksepeti":
            Section {
                Toggle("Referans bonusu koşulları sağlandı", isOn: $form.referral)
                if form.referral {
                    NumberField(title: "Referans tutarı", text: $form.referralAmount, decimal: true, identifier: "detail.referral")
                }
            } header: {
                Text("Yemeksepeti Express")
            } footer: {
                Text("Saatlik garanti yalnızca kural doğrulanmışsa (ya da kendi tarifende onayladıysan) fark ödemesi olarak eklenir.")
            }
        case "migros_hemen":
            Section("Paket Taxi / Migros Hemen") {
                LabeledContent("Bölge kademesi", value: model.state.regionTier == "plus" ? "Plus" : model.state.regionTier == "standard" ? "Standart" : "Seçilmedi")
                Toggle("Kadın istihdam desteği koşulları", isOn: $form.womanEmployment)
                Text("Aylık sabit ücret ve paket kademesi ay sonunda dönem özetinde kesinleşir; günlük kayıt taban ücretle tahmindir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }
}
