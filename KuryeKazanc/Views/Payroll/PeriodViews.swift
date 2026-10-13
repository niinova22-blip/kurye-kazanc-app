import SwiftUI
import SwiftData

// MARK: - Donem ozeti

/// Haftalik / aylik: ya gunluk kayitlardan toplanir ya da kullanici donem toplamlarini girer.
struct PeriodSummaryView: View {
    @Environment(PayrollModel.self) private var model
    @State private var span: PaySpan = .month
    @State private var date: Date = Date()
    @State private var useLogs: Bool = true

    var body: some View {
        let range: (start: String, end: String) = span == .week ? model.weekRange(containing: date) : model.monthRange(containing: date)
        Form {
            Section {
                Picker("Dönem", selection: $span) {
                    Text("Hafta").tag(PaySpan.week)
                    Text("Ay").tag(PaySpan.month)
                }
                .pickerStyle(.segmented)
                DatePicker("Tarih", selection: $date, displayedComponents: .date)
                LabeledContent("Aralık", value: "\(PayFormat.day(range.start)) – \(PayFormat.day(range.end))")
                Picker("Kaynak", selection: $useLogs) {
                    Text("Kayıtlarımdan").tag(true)
                    Text("Toplamları gir").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("period.mode")
            }
            if useLogs {
                LoggedPeriodSections(range: range)
            } else {
                ManualPeriodSections(span: span, range: range)
            }
        }
        .navigationTitle("Dönem özeti")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
    }
}

private struct LoggedPeriodSections: View {
    @Environment(PayrollModel.self) private var model
    let range: (start: String, end: String)

    var body: some View {
        let code: String = model.state.activePlatform ?? ""
        let result: PeriodResult = model.period(platform: code, start: range.start, end: range.end)
        PeriodResultSections(result: result)
    }
}

/// Donem sonucunun gosterimi (donem ozeti ve odeme karsilastirmasi ortak).
struct PeriodResultSections: View {
    let result: PeriodResult

    var body: some View {
        Section {
            LabeledContent("Tahmini brüt hakediş", value: PayFormat.range(result.gross, result.grossUpper))
                .font(.headline)
                .accessibilityIdentifier("period.gross")
            LabeledContent("Günlük kalemler", value: PayFormat.tl(result.dailyPart))
            if !result.weeklyPart.isZero { LabeledContent("Haftalık kalemler", value: PayFormat.tl(result.weeklyPart)) }
            if !result.monthlyPart.isZero { LabeledContent("Aylık kalemler", value: PayFormat.tl(result.monthlyPart)) }
            if !result.provisionalPart.isZero {
                LabeledContent(result.provisionalReplaced ? "Taban tahmin (aylık kademeyle değişti)" : "Taban tahmin (ay sonunda kesinleşir)",
                               value: PayFormat.tl(result.provisionalPart))
            }
            if !result.periodLogPart.isZero { LabeledContent("Dönem kayıtları", value: PayFormat.tl(result.periodLogPart)) }
            LabeledContent("Ödeme öncesi tutar", value: PayFormat.range(result.prePayment, result.prePaymentUpper))
        } header: {
            Text("Sonuç")
        } footer: {
            Text("\(result.logCount) kayıt, \(result.daysWithLogs) gün. Günlük kayıtlar kendi tarife sürümleriyle; haftalık ve aylık kalemler dönem toplamıyla hesaplandı.")
        }
        Section("Toplamlar") {
            LabeledContent("Paket", value: "\(result.packages)")
            LabeledContent("Süre", value: "\(PayFormat.number(result.hours)) sa")
            LabeledContent("Mesafe", value: Formatters.distance(result.km.doubleValue))
            LabeledContent("Saat başına brüt", value: result.grossPerHour.map { PayFormat.tl($0) } ?? "—")
        }
        if !result.progress.isEmpty {
            Section("Bonus hedeflerine yakınlık") {
                ForEach(Array(result.progress.enumerated()), id: \.offset) { _, progress in
                    BonusProgressRow(progress: progress)
                }
            }
        }
        if !result.notices.isEmpty {
            Section("Kontrol edilmesi gerekenler") {
                ForEach(Array(result.notices.enumerated()), id: \.offset) { _, notice in
                    NoticeRow(notice: notice)
                }
            }
        }
    }
}

private struct ManualPeriodSections: View {
    @Environment(PayrollModel.self) private var model
    let span: PaySpan
    let range: (start: String, end: String)
    @State private var packages: String = ""
    @State private var nightPackages: String = ""
    @State private var combined: String = ""
    @State private var hours: String = ""
    @State private var km: String = ""
    @State private var weekendPackages: String = ""
    @State private var tierDays: [String: String] = [:]
    @State private var weeklyPerformance: Bool = false
    @State private var saved: Bool = false

    var body: some View {
        let code: String = model.state.activePlatform ?? ""
        let dailyTiers: [TariffItem] = (model.currentVersion()?.items ?? []).filter { $0.method == .tier && $0.unit == .day && $0.isCash }
        Section("Dönem toplamları") {
            NumberField(title: code == "yemeksepeti" ? "Gündüz paket" : "Paket", text: $packages, identifier: "period.packages")
            if code == "yemeksepeti" {
                NumberField(title: "Akşam paket (18:00 sonrası)", text: $nightPackages, identifier: "period.night")
            }
            NumberField(title: "Birleşen paket", text: $combined, identifier: "period.combined")
            NumberField(title: "Süre (saat)", text: $hours, decimal: true, identifier: "period.hours")
            NumberField(title: "Toplam km", text: $km, decimal: true, identifier: "period.km")
        }
        if !dailyTiers.isEmpty {
            Section {
                ForEach(dailyTiers) { tier in
                    NumberField(title: "\(tier.label): gün", text: binding(for: tier.key), identifier: "period.tier.\(tier.key)")
                }
            } header: {
                Text("Günlük bonus")
            } footer: {
                Text("Her kademeye ulaştığın gün sayısını gir (üst kademe günleri alt kademeye de dahil).")
            }
        }
        if let input = buildInput(code: code) {
            CalculationSections(result: model.calculate(input))
            Section {
                Button(saved ? "Kaydedildi" : "Dönem kaydı olarak kaydet") {
                    saved = model.save(input, method: .period, context: nil) != nil
                }
                .disabled(saved || input.totalPackages == 0)
                .accessibilityIdentifier("period.save")
                if let error = model.lastError {
                    Text(error).font(.caption).foregroundStyle(Theme.negative)
                }
            } footer: {
                Text("Bu dönemde günlük kayıtların varsa dönem kaydı çift sayım olmasın diye kaydedilmez.")
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { tierDays[key] ?? "" }, set: { tierDays[key] = $0 })
    }

    private func buildInput(code: String) -> PayInput? {
        guard var input = model.baseInput(day: range.start, span: span, end: range.end) else { return nil }
        input.dayPackages = PayFormat.parseInt(packages)
        input.nightPackages = PayFormat.parseInt(nightPackages)
        input.combinedPackages = PayFormat.parseInt(combined)
        input.hours = PayFormat.parseDecimal(hours) ?? 0
        input.totalKm = PayFormat.parseDecimal(km)
        input.periodPackages = input.totalPackages
        var days: [String: Int] = [:]
        for (key, text) in tierDays {
            let value: Int = PayFormat.parseInt(text)
            if value > 0 { days[key] = value }
        }
        input.bonusTierDays = days
        if weeklyPerformance { input.flags = ["weekly_performance"] }
        return input
    }
}

// MARK: - Odeme karsilastirma

/// Beklenen hakedis ile platformdan gelen odemenin karsilastirmasi. Fark otomatik "hata" sayilmaz.
struct PaymentCheckView: View {
    @Environment(PayrollModel.self) private var model
    @State private var start: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var end: Date = Date()
    @State private var paidOn: Date = Date()
    @State private var actual: String = ""
    @State private var advances: String = ""
    @State private var deductions: String = ""
    @State private var note: String = ""
    @State private var saved: Bool = false

    var body: some View {
        let code: String = model.state.activePlatform ?? ""
        Form {
            Section("Ödeme dönemi") {
                DatePicker("Başlangıç", selection: $start, displayedComponents: .date)
                DatePicker("Bitiş", selection: $end, in: start..., displayedComponents: .date)
                DatePicker("Ödeme tarihi", selection: $paidOn, displayedComponents: .date)
            }
            Section {
                NumberField(title: "Gerçekleşen ödeme", text: $actual, decimal: true, identifier: "payment.actual")
                NumberField(title: "Avans", text: $advances, decimal: true, identifier: "payment.advances")
                NumberField(title: "Kesinti", text: $deductions, decimal: true, identifier: "payment.deductions")
                TextField("Açıklama", text: $note)
            } header: {
                Text("Platformdan gelen")
            } footer: {
                Text("Ödeme dökümündeki tutarları gir. Dökümü ekrandan okutursan değerleri kendin onaylamadan kesin sayılmaz.")
            }
            if let amount = PayFormat.parseMoney(actual) {
                let pair = model.reconcile(platform: code, start: model.day(start), end: model.day(end), actual: amount,
                                           advances: PayFormat.parseMoney(advances) ?? .zero,
                                           deductions: PayFormat.parseMoney(deductions) ?? .zero)
                ReconciliationSection(reconciliation: pair.1)
                Section {
                    Button(saved ? "Kaydedildi" : "Ödeme kaydını sakla") {
                        model.savePayment(platform: code, start: model.day(start), end: model.day(end), paidOn: model.day(paidOn),
                                          actual: amount, advances: PayFormat.parseMoney(advances) ?? .zero,
                                          deductions: PayFormat.parseMoney(deductions) ?? .zero, note: note)
                        saved = true
                    }
                    .disabled(saved)
                    .accessibilityIdentifier("payment.save")
                }
                PeriodResultSections(result: pair.0)
            }
            PaymentHistorySection(platform: code)
        }
        .navigationTitle("Ödeme karşılaştırma")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
        .onChange(of: actual) { _, _ in saved = false }
    }
}

private struct ReconciliationSection: View {
    let reconciliation: Reconciliation

    var body: some View {
        Section {
            LabeledContent("Beklenen (avans/kesinti düşülmüş)", value: PayFormat.range(reconciliation.expected, reconciliation.expectedUpper))
            LabeledContent("Gerçekleşen", value: PayFormat.tl(reconciliation.actual))
            LabeledContent("Fark (gerçekleşen − beklenen)", value: PayFormat.tl(reconciliation.difference))
                .font(.headline)
                .accessibilityIdentifier("payment.difference")
            Label(reconciliation.status.displayName, systemImage: statusSymbol)
                .foregroundStyle(reconciliation.status == .matches || reconciliation.status == .withinRange ? Theme.accent : Color.orange)
            ForEach(Array(reconciliation.checks.enumerated()), id: \.offset) { _, check in
                Label(check, systemImage: "magnifyingglass").font(.caption)
            }
        } header: {
            Text("Karşılaştırma")
        } footer: {
            Text("Fark tek başına hata anlamına gelmez; işaretlenen kalemleri ödeme dökümünle karşılaştır.")
        }
    }

    private var statusSymbol: String {
        switch reconciliation.status {
        case .matches, .withinRange: "checkmark.circle"
        case .lower: "arrow.down.circle"
        case .higher: "arrow.up.circle"
        }
    }
}

private struct PaymentHistorySection: View {
    @Environment(PayrollModel.self) private var model
    let platform: String

    var body: some View {
        let payments: [PaymentRecord] = model.state.payments.filter { $0.platformCode == platform }.sorted { $0.periodEnd > $1.periodEnd }
        if !payments.isEmpty {
            Section("Önceki ödemeler") {
                ForEach(payments) { payment in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(PayFormat.day(payment.periodStart)) – \(PayFormat.day(payment.periodEnd))").font(.subheadline)
                        Text("Ödenen \(PayFormat.tl(payment.actualAmount)) · beklenen \(PayFormat.tl(payment.expected)) · fark \(PayFormat.tl(payment.difference))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { model.deletePayment(payments[index]) }
                }
            }
        }
    }
}

// MARK: - Kayit ayrintisi

/// Kaydin dondurulmus sonucu, tarife surumu, elle duzeltme ve acik yeniden hesaplama gecmisi.
struct WorkLogDetailView: View {
    @Environment(PayrollModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let logID: UUID
    @State private var reason: String = ""
    @State private var adjustment: String = ""
    @State private var adjustmentNote: String = ""
    @State private var message: String?

    var body: some View {
        if let log = model.state.logs.first(where: { $0.id == logID }) {
            List {
                Section("Kayıt") {
                    LabeledContent("Platform", value: PayPlatform.named(log.platformCode)?.name ?? log.platformCode)
                    LabeledContent("Yöntem", value: log.method.displayName)
                    LabeledContent("Tarih", value: log.isDaily ? PayFormat.day(log.startDay) : "\(PayFormat.day(log.startDay)) – \(PayFormat.day(log.endDay))")
                    LabeledContent("Tarife sürümü", value: "\(log.result.tariffVersionLabel) (\(log.tariffVersionID))")
                    LabeledContent("Hesaplama zamanı", value: log.result.computedAt.formatted(date: .abbreviated, time: .shortened))
                }
                BreakdownSections(breakdown: log.result)
                AdjustmentSection(log: log, amount: $adjustment, note: $adjustmentNote)
                RecalculationSection(log: log, reason: $reason, message: $message)
                Section {
                    Button("Kaydı sil", role: .destructive) {
                        model.delete(log, context: context)
                        dismiss()
                    }
                }
                VerificationFootnote(items: UnverifiedItems.from(log.result, platformName: PayrollModel.platformName(log.platformCode)))
            }
            .navigationTitle("Kayıt")
            .navigationBarTitleDisplayMode(.inline)
            .dismissesKeyboard()
        } else {
            ContentUnavailableView("Kayıt bulunamadı", systemImage: "doc.questionmark")
        }
    }
}

private struct AdjustmentSection: View {
    @Environment(PayrollModel.self) private var model
    let log: WorkLog
    @Binding var amount: String
    @Binding var note: String

    var body: some View {
        Section {
            if let current = log.manualAdjustment {
                LabeledContent("Elle düzeltme", value: PayFormat.tl(current))
                if let text = log.adjustmentNote { Text(text).font(.caption).foregroundStyle(.secondary) }
            }
            NumberField(title: "Düzeltme tutarı (± TL)", text: $amount, decimal: true, identifier: "log.adjustment")
            TextField("Neden", text: $note)
            Button("Düzeltmeyi kaydet") {
                model.setAdjustment(PayFormat.parseMoney(amount), note: note.isEmpty ? nil : note, log: log)
                amount = ""
                note = ""
            }
            .disabled(PayFormat.parseMoney(amount) == nil)
        } header: {
            Text("Elle düzeltme")
        } footer: {
            Text("Hesaplama sonucu değişmez; düzeltme ayrıca gösterilir ve toplamlara eklenir.")
        }
    }
}

private struct RecalculationSection: View {
    @Environment(PayrollModel.self) private var model
    let log: WorkLog
    @Binding var reason: String
    @Binding var message: String?

    var body: some View {
        Section {
            ForEach(Array(log.recalculations.enumerated()), id: \.offset) { _, entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(PayFormat.tl(entry.previous.gross)) → \(PayFormat.tl(entry.new.gross))").font(.subheadline)
                    Text("\(entry.reason) · \(entry.at.formatted(date: .abbreviated, time: .shortened)) · \(entry.previous.tariffVersionLabel) → \(entry.new.tariffVersionLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let previewText {
                Text(previewText).font(.caption)
            }
            TextField("Neden (zorunlu)", text: $reason)
            Button("Güncel tarifeyle yeniden hesapla") {
                let result: Recalculation? = model.recalculate(log, reason: reason)
                message = result == nil ? model.lastError : "Yeniden hesaplandı; önceki sonuç geçmişte saklandı."
                reason = ""
            }
            .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        } header: {
            Text("Geçmişe dönük düzeltme")
        } footer: {
            Text("Yeni tarife eski kayıtları kendiliğinden değiştirmez. Yeniden hesaplama ayrı bir işlem olarak (önceki sonuç, yeni sonuç, neden, zaman) saklanır.")
        }
    }

    /// Guncel tarifeyle sonuc farkliysa onizleme metni.
    private var previewText: String? {
        guard case let .success(preview) = model.calculate(log.input) else { return nil }
        guard preview.gross != log.result.gross || preview.tariffVersionID != log.tariffVersionID else { return nil }
        return "Güncel tarifeyle: \(PayFormat.tl(preview.gross)) (\(preview.tariffVersionLabel))"
    }
}

// MARK: - Gecmis ve karsilastirma

struct PayrollHistoryView: View {
    @Environment(PayrollModel.self) private var model

    private struct MonthGroup: Identifiable {
        let month: String
        let logs: [WorkLog]
        var id: String { month }
    }

    var body: some View {
        let logs: [WorkLog] = model.logs
        let comparison: [PlatformComparison] = PlatformComparison.build(logs)
        let groups: [MonthGroup] = monthGroups(logs)
        List {
            if comparison.count > 0 {
                Section {
                    ForEach(comparison) { item in
                        ComparisonRow(item: item)
                    }
                } header: {
                    Text("Platform karşılaştırma")
                } footer: {
                    Text("Her kayıt kendi platformu ve kendi tarife sürümüyle; yeniden hesaplanmaz.")
                }
            }
            ForEach(groups) { group in
                Section(group.month) {
                    ForEach(group.logs) { log in
                        NavigationLink { WorkLogDetailView(logID: log.id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(PayPlatform.named(log.platformCode)?.name ?? log.platformCode).font(.caption2).foregroundStyle(.secondary)
                                WorkLogRow(log: log)
                            }
                        }
                    }
                }
            }
            if logs.isEmpty {
                Text("Henüz hakediş kaydı yok.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Geçmiş")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func monthGroups(_ logs: [WorkLog]) -> [MonthGroup] {
        var order: [String] = []
        var map: [String: [WorkLog]] = [:]
        for log in logs {
            let key: String = String(log.startDay.prefix(7))
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(log)
        }
        var result: [MonthGroup] = []
        for key in order {
            result.append(MonthGroup(month: monthTitle(key), logs: map[key] ?? []))
        }
        return result
    }

    private func monthTitle(_ key: String) -> String {
        let text: String = TariffNotifier.longDate(key + "-01")
        return text.split(separator: " ").dropFirst().joined(separator: " ")
    }
}

private struct ComparisonRow: View {
    let item: PlatformComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PayPlatform.named(item.platformCode)?.name ?? item.platformCode).font(.headline)
            Text("\(item.months) ay · \(PayFormat.day(item.firstDay)) – \(PayFormat.day(item.lastDay))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                metric("Aylık ort.", PayFormat.tl(item.monthlyAverage))
                metric("Saat başı", item.perHour.map { PayFormat.tl($0) } ?? "—")
                metric("Paket başı", item.perPackage.map { PayFormat.tl($0) } ?? "—")
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
