import SwiftUI
import SwiftData
import UIKit
import PhotosUI
import PDFKit
import UniformTypeIdentifiers
import Charts

// MARK: - Tarife bilgisi

/// Aktif platformun tarifesi: kalemler (guven etiketiyle), belirsiz ayarlar, kaynak turu, kullanici tarifeleri.
struct TariffInfoView: View {
    @Environment(PayrollModel.self) private var model

    var body: some View {
        List {
            if model.hasEditedTariff {
                Section {
                    Label("Kendi değerlerin kullanılıyor. Değiştirmek ya da firma değerlerine dönmek için kaleme dokun.",
                          systemImage: "pencil.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.highlight)
                }
            }
            if let version = model.currentVersion() {
                VersionSummarySection(version: version)
                TariffItemsSection(version: version, today: model.today)
                SettingsConfidenceSection(settings: version.settings)
            } else {
                Section { Text("Bu platform için yayında tarife yok.").foregroundStyle(.secondary) }
            }
            UserTariffsSection()
            Section {
                if model.tariffs.lastAttemptFailed {
                    Label("Son güncelleme denemesi başarısız; son bilinen tarife kullanılıyor.", systemImage: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let fetched = model.tariffs.fetchedAt {
                    LabeledContent("Sunucudan son alınış", value: fetched.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text(model.tariffs.isServerAvailable ? "Sunucudan henüz tarife alınmadı; başlangıç / örnek tarife kullanılıyor." : "Sunucu kapalı; başlangıç / örnek tarife kullanılıyor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Güncellik")
            } footer: {
                Text("Tarifeler kaynaklardan takip edilir; değişiklikler doğrulama ve onaydan geçmeden yayımlanmaz. Bir haberde zam görülmesi tarifeyi tek başına değiştirmez.")
            }
        }
        .navigationTitle("Tarife")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { TariffEditButton() }
        }
    }
}

private struct VersionSummarySection: View {
    let version: TariffVersion

    var body: some View {
        Section("Sürüm") {
            LabeledContent("Sürüm", value: version.label)
            LabeledContent("Durum", value: version.approvalStatus.displayName)
            LabeledContent("Doğrulama", value: version.verificationStatus.displayName)
            LabeledContent("Kaynak türü", value: version.sourceType.displayName)
            LabeledContent("Yürürlük", value: PayFormat.day(version.effectiveFrom))
            if let vehicle = version.vehicleType {
                LabeledContent("Araç", value: vehicle == "car" ? "Araçlı" : "Motorlu")
            }
            if let summary = version.changeSummary { Text(summary).font(.caption).foregroundStyle(.secondary) }
            if let note = version.sourceNote { LabeledContent("Kaynağın", value: note) }
        }
    }
}

private struct TariffItemsSection: View {
    let version: TariffVersion
    let today: String

    var body: some View {
        let items: [TariffItem] = version.items.filter { !$0.withdrawn && ($0.effectiveUntil == nil || $0.effectiveUntil! > today) }
        Section("Kalemler") {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.label).font(.subheadline)
                        Spacer()
                        Text(amountText(item)).font(.subheadline).monospacedDigit()
                    }
                    HStack(spacing: 8) {
                        ConfidenceLabel(status: item.confidence, compact: true)
                        if !item.isCash { Text("Yan hak").font(.caption2).foregroundStyle(.secondary) }
                        if let from = item.effectiveFrom, from > today {
                            Text("\(PayFormat.day(from)) itibarıyla").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    if let note = item.note { Text(note).font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func amountText(_ item: TariffItem) -> String {
        if item.unit == .multiplier {
            let low: String = PayFormat.number(item.amount.value)
            let high: String = item.amountUpper.map { PayFormat.number($0.value) } ?? low
            return low == high ? "\(low)×" : "\(low)–\(high)×"
        }
        var text: String = PayFormat.range(item.amount, item.amountUpper ?? item.amount) + item.unit.suffix
        if let lower = item.lowerThreshold {
            text = "\(PayFormat.number(lower))\(item.upperThreshold.map { "–" + PayFormat.number($0) } ?? "+") · " + text
        }
        return text
    }
}

private struct SettingsConfidenceSection: View {
    let settings: TariffSettings

    var body: some View {
        let rows: [(String, String, String)] = describe()
        if !rows.isEmpty {
            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 2) {
                        LabeledContent(row.0, value: row.1)
                        ConfidenceLabel(status: settings.confidence(of: row.2), compact: true)
                    }
                }
            } header: {
                Text("Uygulama kuralları")
            } footer: {
                Text("Doğrulanmamış kurallarda diğer yorumun sonucu hesaplamada ayrıca gösterilir.")
            }
        }
    }

    private func describe() -> [(String, String, String)] {
        var rows: [(String, String, String)] = []
        if let km = settings.kmMethod {
            rows.append(("Km primi", km == .slab ? "Dilimli (her km kendi bandında)" : "Tüm mesafe tek bant", "km_method"))
        }
        if let stacking = settings.bonusStacking {
            rows.append(("Bonus kademeleri", stacking == .cumulative ? "Toplanır" : "Yalnızca en yüksek", "bonus_stacking"))
        }
        if let threshold = settings.thresholdApplication {
            rows.append(("Kademe ücreti", threshold == .allUnits ? "Eşik aşılınca tüm paketlere" : "Yalnızca eşik üstüne", "threshold_application"))
        }
        if let basis = settings.fixedPayBasis {
            let text: String
            switch basis {
            case .region: text = "Bölge ücreti (kıdem tarifesi alternatif)"
            case .seniority: text = "Kıdem tarifesi"
            case .both: text = "Bölge + kıdem"
            }
            rows.append(("Sabit ücret", text, "fixed_pay_basis"))
        }
        return rows
    }
}

private struct UserTariffsSection: View {
    @Environment(PayrollModel.self) private var model

    var body: some View {
        let code: String = model.state.activePlatform ?? ""
        let mine: [TariffVersion] = model.state.userTariffs.filter { $0.platformCode == code }
        Section {
            ForEach(mine) { version in
                VStack(alignment: .leading, spacing: 2) {
                    Text(version.sourceNote ?? "Kendi tarifem").font(.subheadline)
                    Text("\(version.approvalStatus == .published ? "Kullanımda" : "Taslak") · \(PayFormat.day(version.effectiveFrom)) · \(version.items.count) kalem")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("Sil", role: .destructive) { model.deleteUserTariff(version) }
                }
            }
            NavigationLink { UserTariffEditorView() } label: {
                Label("Kendi tarifemi ekle", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("tariff.addUser")
        } header: {
            Text("Kendi tarifem")
        } footer: {
            Text("Sözleşmen ya da platform ekranın farklıysa kendi tarifeni girebilirsin. Kullanıcı girişi \"Kullanıcı tarafından girildi\" etiketiyle ayrı gösterilir; onaylayana kadar hesaplamaya girmez.")
        }
    }
}

// MARK: - Kullanici tarifesi ekleme

/// Elle form, CSV, ekran goruntusu (OCR) ya da PDF. Okunan kalemler taslaktir; kaynak zorunludur.
struct UserTariffEditorView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case form, csv, image, pdf
        var id: String { rawValue }
        var title: String {
            switch self {
            case .form: "Form"
            case .csv: "CSV"
            case .image: "Görsel"
            case .pdf: "PDF"
            }
        }
    }

    @Environment(PayrollModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .form
    @State private var sourceNote: String = ""
    @State private var effectiveFrom: Date = Date()
    @State private var amounts: [String: String] = [:]
    @State private var csvText: String = "kalem;tur;etiket;tutar;ust_tutar;alt_esik\n"
    @State private var drafts: [DraftTariffItem] = []
    @State private var errors: [String] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var showPDFImporter: Bool = false
    @State private var isReading: Bool = false

    var body: some View {
        let base: TariffVersion? = model.currentVersion()
        Form {
            Section {
                TextField("Kaynak (zorunlu): ör. sözleşmem, Ekim 2026", text: $sourceNote)
                    .accessibilityIdentifier("userTariff.source")
                DatePicker("Geçerlilik başlangıcı", selection: $effectiveFrom, displayedComponents: .date)
                Picker("Giriş yolu", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            switch mode {
            case .form:
                FormAmountsSection(base: base, amounts: $amounts)
            case .csv:
                Section {
                    TextEditor(text: $csvText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                    Button("CSV'yi oku") { readCSV() }
                } footer: {
                    Text("Sütunlar: kalem;tur;etiket;tutar;ust_tutar;alt_esik;ust_esik;birim;yontem;baslangic;bitis. Ayırıcı noktalı virgül.")
                }
            case .image:
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Ekran görüntüsü seç", systemImage: "photo")
                    }
                    if isReading { ProgressView() }
                } footer: {
                    Text("Görsel cihazda okunur, gönderilmez. Okunan değerler \"doğrulama gerekli\" taslaktır.")
                }
            case .pdf:
                Section {
                    Button { showPDFImporter = true } label: {
                        Label("PDF belgesi seç", systemImage: "doc")
                    }
                } footer: {
                    Text("Belgedeki metin cihazda okunur. Okunan değerler taslaktır.")
                }
            }
            if !drafts.isEmpty {
                Section("Okunan kalemler (taslak)") {
                    ForEach(drafts) { draft in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(draft.item.label).font(.subheadline)
                                Spacer()
                                Text(PayFormat.tl(draft.item.amount)).monospacedDigit()
                            }
                            Text("Okuma güveni %\(Int((draft.score * 100).rounded())) · \(draft.sourceLine)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .onDelete { offsets in drafts.remove(atOffsets: offsets) }
                }
            }
            if !errors.isEmpty {
                Section("Okunamayanlar") {
                    ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                        Text(error).font(.caption).foregroundStyle(Theme.negative)
                    }
                }
            }
            Section {
                Button("Taslak olarak kaydet") { save(base: base, activate: false) }
                Button("Onayla ve hesaplamada kullan") { save(base: base, activate: true) }
                    .accessibilityIdentifier("userTariff.activate")
                if let error = model.lastError {
                    Text(error).font(.caption).foregroundStyle(Theme.negative)
                }
            } footer: {
                Text("Onayladığında bu platformda resmî tarifenin önüne geçer ve \"Kullanıcı tarafından girildi\" olarak gösterilir. Geçmiş kayıtlar değişmez.")
            }
        }
        .navigationTitle("Kendi tarifem")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboard()
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await readImage(item) }
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
            if case let .success(url) = result { readPDF(url) }
        }
    }

    private var versionID: String { "user-\(model.state.activePlatform ?? "x")-\(Int(Date().timeIntervalSince1970))" }

    private func readCSV() {
        let result: TariffImportResult = TariffImport.csv(csvText, platform: model.state.activePlatform ?? "", versionID: "user")
        drafts = result.drafts
        errors = result.errors
    }

    private func readImage(_ item: PhotosPickerItem) async {
        isReading = true
        defer { isReading = false; photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            errors = ["Görsel yüklenemedi."]
            return
        }
        do {
            let lines: [RecognizedLine] = try await VisionTextRecognitionService().recognize(in: image)
            apply(TariffImport.text(lines.map(\.text), platform: model.state.activePlatform ?? "", versionID: "user"))
        } catch {
            errors = [error.localizedDescription]
        }
    }

    private func readPDF(_ url: URL) {
        let accessing: Bool = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let document = PDFDocument(url: url), let text = document.string else {
            errors = ["PDF okunamadı."]
            return
        }
        let lines: [String] = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        apply(TariffImport.text(lines, platform: model.state.activePlatform ?? "", versionID: "user"))
        if sourceNote.isEmpty { sourceNote = url.lastPathComponent }
    }

    private func apply(_ result: TariffImportResult) {
        drafts = result.drafts
        errors = result.errors
    }

    private func save(base: TariffVersion?, activate: Bool) {
        guard let code = model.state.activePlatform else { return }
        var items: [DraftTariffItem] = drafts
        if mode == .form, let base {
            for item in base.items {
                guard let text = amounts[item.key], let amount = PayFormat.parseMoney(text), amount != item.amount else { continue }
                var copy = item
                copy.amount = amount
                copy.amountUpper = nil
                copy.confidence = .userEntered
                items.append(DraftTariffItem(item: copy, score: 1, sourceLine: "Form"))
            }
        }
        let version: TariffVersion = TariffImport.userVersion(platform: code, drafts: items, base: base, sourceNote: sourceNote,
                                                             effectiveFrom: model.day(effectiveFrom), today: model.today, id: versionID)
        if model.saveUserTariff(version, activate: activate) { dismiss() }
    }
}

private struct FormAmountsSection: View {
    let base: TariffVersion?
    @Binding var amounts: [String: String]

    var body: some View {
        let items: [TariffItem] = (base?.items ?? []).filter { !$0.withdrawn && $0.effectiveUntil == nil && $0.unit != .multiplier }
        Section {
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.label).font(.subheadline)
                        Text("Şu an \(PayFormat.range(item.amount, item.amountUpper ?? item.amount))").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Aynı", text: binding(item.key))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                }
            }
        } header: {
            Text("Tutarları düzelt")
        } footer: {
            Text("Yalnızca farklı olanları yaz; boş bırakılan kalemler mevcut tarifeden kopyalanır.")
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { amounts[key] ?? "" }, set: { amounts[key] = $0 })
    }
}

// MARK: - Bildirimler

struct TariffNoticesView: View {
    @Environment(PayrollModel.self) private var model

    var body: some View {
        let code: String = model.state.activePlatform ?? ""
        let notices: [TariffNotice] = model.state.notices.filter { $0.platformCode == code }.sorted { $0.createdAt > $1.createdAt }
        List {
            if notices.isEmpty {
                Text("Bu platform için tarife bildirimi yok.").foregroundStyle(.secondary)
            }
            ForEach(notices) { notice in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notice.title).font(.subheadline.weight(notice.isRead ? .regular : .semibold))
                        Spacer()
                        ConfidenceLabel(status: notice.isVerified ? .verified : .needsVerification, compact: true)
                    }
                    Text(notice.body).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Tarife bildirimleri")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.markNoticesRead() }
        .refreshable { await model.refreshNotices() }
    }
}

// MARK: - Yan haklar

struct SideBenefitsView: View {
    @Environment(PayrollModel.self) private var model

    var body: some View {
        let items: [TariffItem] = (model.currentVersion()?.items ?? []).filter { !$0.isCash && !$0.withdrawn }
        List {
            Section {
                if items.isEmpty {
                    Text("Tarifede yan hak kaydı yok.").foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.label).font(.subheadline)
                            Spacer()
                            Text(item.amount.isZero ? "Tutar belirtilmemiş" : PayFormat.tl(item.amount) + item.unit.suffix)
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                        ConfidenceLabel(status: item.confidence, compact: true)
                        if let note = item.note { Text(note).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            } footer: {
                Text("Yan haklar ve ayni destekler nakit hakedişe eklenmez; koşula bağlı olanlar (örn. kadın istihdam desteği) kurulumda seçtiysen hedef planına eklenir.")
            }
        }
        .navigationTitle("Yan haklar ve destekler")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Gider raporu

struct ExpenseReportView: View {
    @Environment(PayrollModel.self) private var model
    @Query(sort: \ExpenseRecord.date, order: .reverse) private var expenseRecords: [ExpenseRecord]
    @State private var month: Date = Date()

    var body: some View {
        let range: (start: String, end: String) = model.monthRange(containing: month)
        let all: [DatedExpense] = expenseRecords.map(\.datedExpense)
        let monthExpenses: [DatedExpense] = all.filter { $0.day >= range.start && $0.day <= range.end }
        let code: String = model.state.activePlatform ?? ""
        let allLogs: [WorkLog] = model.logs(platform: code)
        let monthLogs: [WorkLog] = allLogs.filter { $0.startDay >= range.start && $0.startDay <= range.end }
        let report: ExpenseReport = ExpenseReport.build(logs: monthLogs, expenses: monthExpenses, allLogs: allLogs, allExpenses: all,
                                                        lastMonth: String(range.start.prefix(7)), months: 6)
        List {
            Section {
                DatePicker("Ay", selection: $month, displayedComponents: .date)
                LabeledContent("Brüt (kayıtlar)", value: PayFormat.tl(report.gross))
                LabeledContent("Gider", value: PayFormat.tl(report.total))
                LabeledContent("Net", value: PayFormat.tl(report.net)).font(.headline)
                LabeledContent("Paket başına net", value: report.perPackageNet.map { PayFormat.tl($0) } ?? "—")
                LabeledContent("Saat başına net", value: report.perHourNet.map { PayFormat.tl($0) } ?? "—")
                LabeledContent("Km başına maliyet", value: report.costPerKm.map { PayFormat.tl($0) } ?? "—")
            } header: {
                Text("Brüt – net")
            } footer: {
                Text("Net = brüt − giderler. Vergi ve SGK gibi yükümlülükler güvenilir veri olmadan hesaba katılmaz.")
            }
            Section("Kategoriye göre") {
                ForEach(ExpenseType.allCases) { type in
                    if let amount = report.byCategory[type] {
                        LabeledContent(type.displayName, value: PayFormat.tl(amount))
                    }
                }
                if report.byCategory.isEmpty {
                    Text("Bu ay gider kaydı yok. Giderleri Bugün sekmesinden ekleyebilirsin.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Günlük gider") {
                ForEach(report.byDay.keys.sorted(by: >), id: \.self) { day in
                    LabeledContent(PayFormat.day(day), value: PayFormat.tl(report.byDay[day] ?? .zero))
                }
            }
            Section("Aylık eğilim") {
                TrendChart(months: report.trend)
                    .frame(height: 180)
            }
        }
        .navigationTitle("Gider ve net")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrendChart: View {
    let months: [ExpenseReport.Month]

    var body: some View {
        Chart {
            ForEach(months) { item in
                BarMark(x: .value("Ay", item.month), y: .value("Net", item.net.doubleValue))
                    .foregroundStyle(item.net.isNegative ? Theme.negative : Theme.accent)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let text = value.as(String.self) { Text(String(text.suffix(2))) }
                }
            }
        }
    }
}

// MARK: - Ayarlar

struct PayrollSettingsView: View {
    @Environment(PayrollModel.self) private var model
    @State private var updatesEnabled: Bool = true

    var body: some View {
        Form {
            Section {
                Picker("Bölge", selection: regionBinding) {
                    Text("Seçilmedi").tag(String?.none)
                    ForEach(regionOptions, id: \.self) { Text(TariffQuestions.regionName($0)).tag(String?.some($0)) }
                }
                if model.state.activePlatform == "pt_restoran" {
                    Stepper("Kıdem: \(model.state.seniorityYears ?? 0) yıl", value: seniorityBinding, in: 0...30)
                    Picker("Günlük çalışma", selection: hoursBinding) {
                        ForEach([9, 10, 11, 12], id: \.self) { Text("\($0) saat").tag($0) }
                    }
                }
            } header: {
                Text(PayrollModel.platformName(model.state.activePlatform ?? ""))
            } footer: {
                Text("Vardiya başlayınca bölge konumundan kendiliğinden güncellenir.")
            }
            Section {
                Toggle("Tarife güncellemelerini al", isOn: $updatesEnabled)
                    .onChange(of: updatesEnabled) { _, value in model.tariffs.isEnabled = value }
            } footer: {
                Text("Yalnızca yayımlanmış tarife tabloları indirilir; cihazından veri gönderilmez. Kapalıysa son bilinen tarife kullanılır.")
            }
            Section {
                Text("Firmanı Profil > Ayarlar > Çalıştığım firma'dan değiştirebilirsin; tarifenin istediği bilgiler de orada sorulur.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Hakediş ayarları")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { updatesEnabled = model.tariffs.isEnabled }
    }

    private var regionBinding: Binding<String?> {
        Binding(get: { model.state.regionTier }, set: { value in
            model.setPreferences(regionTier: value, seniorityYears: model.state.seniorityYears, vehicleType: model.state.vehicleType)
        })
    }

    private var seniorityBinding: Binding<Int> {
        Binding(get: { model.state.seniorityYears ?? 0 }, set: { value in
            model.setPreferences(regionTier: model.state.regionTier, seniorityYears: value, vehicleType: model.state.vehicleType)
        })
    }

    private var regionOptions: [String] {
        model.questions(for: model.state.activePlatform ?? "").regionTiers
    }

    private var hoursBinding: Binding<Int> {
        Binding(get: { model.state.contractHours ?? 10 }, set: { value in model.setContractHours(value) })
    }
}
