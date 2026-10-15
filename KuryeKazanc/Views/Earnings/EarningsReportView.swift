import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// 1.12.2 Kazanç > Hakediş > Kazanç raporu: geriye donuk gunluk / haftalik / aylik ayrintili kazanc; PDF ve CSV paylasimi.
struct EarningsReportView: View {
    @Environment(PayrollModel.self) private var payroll
    @Query(sort: \ExpenseRecord.date, order: .reverse) private var expenseRecords: [ExpenseRecord]
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true

    @State private var span: EarningsReport.Span = .day
    @State private var anchor: Date = Date()

    private var calendar: Calendar { .current }

    var body: some View {
        let report: EarningsReport? = payroll.earningsReport(span: span, containing: anchor,
                                                              expenses: expenseRecords.map(\.datedExpense),
                                                              fallbackCostPerKm: autoEstimate ? costPerKm : nil)
        List {
            Section {
                Picker("Dönem", selection: $span.animation(.snappy)) {
                    ForEach(EarningsReport.Span.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("report.span")
                navigator
            }
            if let report {
                if report.isEmpty {
                    Section {
                        Text("Bu dönemde kayıt yok.").foregroundStyle(.secondary)
                    }
                } else {
                    summarySection(report)
                    rowsSection(report)
                    if span != .day { daysSection(report) }
                }
            } else {
                Section { Text("Önce firmanı seç.").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Kazanç raporu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let report, !report.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: ReportPDFFile(report: report),
                                  preview: SharePreview("\(report.span.title) kazanç raporu", image: Image(systemName: "doc.richtext"))) {
                            Label("PDF olarak paylaş", systemImage: "doc.richtext")
                        }
                        ShareLink(item: ReportCSVFile(report: report),
                                  preview: SharePreview("\(report.span.title) kazanç (CSV)", image: Image(systemName: "tablecells"))) {
                            Label("Excel (CSV) olarak paylaş", systemImage: "tablecells")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("report.share")
                }
            }
        }
    }

    // MARK: - Donem secimi

    private var navigator: some View {
        let range = payroll.reportRange(span, containing: anchor)
        let isCurrent: Bool = range.end >= payroll.today
        return HStack {
            Button { move(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36)
            }
            .accessibilityLabel("Önceki dönem")
            .accessibilityIdentifier("report.previous")
            Spacer()
            Text(Self.title(span: span, start: range.start, end: range.end))
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("report.title")
            Spacer()
            Button { move(1) } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36)
            }
            .disabled(isCurrent)
            .accessibilityLabel("Sonraki dönem")
            .accessibilityIdentifier("report.next")
        }
        .buttonStyle(.borderless)
    }

    private func move(_ step: Int) {
        let component: Calendar.Component = span == .day ? .day : (span == .week ? .weekOfYear : .month)
        if let next = calendar.date(byAdding: component, value: step, to: anchor) {
            Haptics.selection()
            withAnimation(.snappy) { anchor = min(next, Date()) }
        }
    }

    static func title(span: EarningsReport.Span, start: String, end: String) -> String {
        switch span {
        case .day: return PayFormat.day(start)
        case .week: return "\(PayFormat.day(start)) – \(PayFormat.day(end))"
        case .month:
            guard let date = RuleDay.date(start) else { return start }
            return date.formatted(Date.FormatStyle().locale(Formatters.locale).month(.wide).year())
        }
    }

    // MARK: - Bolumler

    private func summarySection(_ report: EarningsReport) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cebine kalan (net)").font(.subheadline).foregroundStyle(.secondary)
                Text(PayFormat.tl(report.net))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(report.net.value >= 0 ? Theme.positive : Theme.negative)
                    .accessibilityIdentifier("report.net")
                HStack {
                    metric("\(Formatters.groupedInt(report.packages))", "paket")
                    metric(Formatters.decimalText(report.hours), "saat")
                    metric(Formatters.decimalText(Money.round(report.km, scale: 0)), "km")
                }
            }
            .padding(.vertical, 4)
            LabeledContent("Firmadan (brüt)", value: PayFormat.tl(report.gross))
            LabeledContent("Yakıt", value: "−" + PayFormat.tl(report.fuel))
            if !report.otherExpenses.isZero {
                LabeledContent("Diğer giderler", value: "−" + PayFormat.tl(report.otherExpenses))
            }
        }
    }

    private func metric(_ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func rowsSection(_ report: EarningsReport) -> some View {
        Section {
            ForEach(report.rows) { row in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label).font(.subheadline)
                        if let note = row.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text(PayFormat.tl(row.amount)).font(.subheadline.monospacedDigit())
                }
            }
            HStack {
                Text("Toplam (brüt)").font(.subheadline.weight(.semibold))
                Spacer()
                Text(PayFormat.tl(report.gross)).font(.subheadline.weight(.semibold).monospacedDigit())
            }
        } header: {
            Text("Kalem kalem")
        } footer: {
            if !report.notes.isEmpty { Text(report.notes.joined(separator: " ")) }
        }
    }

    private func daysSection(_ report: EarningsReport) -> some View {
        Section("Gün gün") {
            ForEach(report.days) { day in
                Button {
                    if let date = RuleDay.date(day.day) {
                        withAnimation(.snappy) {
                            span = .day
                            anchor = calendar.date(byAdding: .hour, value: 12, to: date) ?? date
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PayFormat.day(day.day)).font(.subheadline).foregroundStyle(.primary)
                            Text("\(day.packages) paket · \(Formatters.decimalText(day.hours)) sa")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(PayFormat.tl(day.gross)).font(.subheadline.monospacedDigit()).foregroundStyle(.primary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Disa aktarim

/// Rapor dosya adi: "kurye-kazanc-gunluk-2026-10-15".
private func reportFileName(_ report: EarningsReport) -> String {
    let span: String = report.span == .day ? "gunluk" : (report.span == .week ? "haftalik" : "aylik")
    return "kurye-kazanc-\(span)-\(report.start)"
}

struct ReportCSVFile: Transferable {
    let report: EarningsReport

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(reportFileName(file.report) + ".csv")
            // Excel Turkce karakterleri dogru acsin diye UTF-8 BOM
            let data = Data([0xEF, 0xBB, 0xBF]) + Data(file.report.csv().utf8)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct ReportPDFFile: Transferable {
    let report: EarningsReport

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(reportFileName(file.report) + ".pdf")
            await MainActor.run { ReportPDFRenderer.render(file.report, to: url) }
            return SentTransferredFile(url)
        }
    }
}

@MainActor
enum ReportPDFRenderer {
    static let width: CGFloat = 595 // A4 genisligi (pt)

    static func render(_ report: EarningsReport, to url: URL) {
        let renderer = ImageRenderer(content: ReportPrintView(report: report).frame(width: width))
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: width, height: max(842, size.height)))
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            // Kisa raporda icerik sayfanin ustunde kalsin
            context.translateBy(x: 0, y: box.height - size.height)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
    }
}

/// PDF'e basilan sade rapor (beyaz zemin, siyah yazi).
private struct ReportPrintView: View {
    let report: EarningsReport

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kurye Kazanç · \(report.span.title) kazanç raporu").font(.title2.bold())
                Text("\(report.platformName) · \(EarningsReportView.title(span: report.span, start: report.start, end: report.end))")
                    .font(.subheadline)
            }
            HStack(spacing: 24) {
                item("Paket", Formatters.groupedInt(report.packages))
                item("Saat", Formatters.decimalText(report.hours))
                item("Km", Formatters.decimalText(Money.round(report.km, scale: 0)))
                item("Net", PayFormat.tl(report.net))
            }
            Divider()
            ForEach(report.rows) { row in line(row.label, PayFormat.tl(row.amount)) }
            Divider()
            line("Firmadan (brüt)", PayFormat.tl(report.gross), bold: true)
            line("Yakıt", "−" + PayFormat.tl(report.fuel))
            if !report.otherExpenses.isZero { line("Diğer giderler", "−" + PayFormat.tl(report.otherExpenses)) }
            line("Cebine kalan (net)", PayFormat.tl(report.net), bold: true)
            if report.days.count > 1 {
                Divider()
                Text("Gün gün").font(.headline)
                ForEach(report.days) { day in
                    line("\(PayFormat.day(day.day)) · \(day.packages) paket · \(Formatters.decimalText(day.hours)) sa",
                         PayFormat.tl(day.gross))
                }
            }
            if !report.notes.isEmpty {
                Text(report.notes.joined(separator: " ")).font(.caption)
            }
            Text("Tutarlar firmanın tarifesine göre hesaplanmış tahmindir; resmî bordro değildir.")
                .font(.caption2)
        }
        .padding(36)
        .foregroundStyle(.black)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    private func item(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption)
            Text(value).font(.headline)
        }
    }

    private func line(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(bold ? .subheadline.bold() : .subheadline)
    }
}
