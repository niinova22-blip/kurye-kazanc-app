import SwiftUI
import SwiftData
import Charts

/// Gecmis / Analiz: gunluk, haftalik, aylik ozet + platform bazinda toplam + kayit listesi.
struct HistoryView: View {
    @State private var kind: PeriodKind = .week
    @State private var anchor: Date = .now

    private let periods = PeriodRange()

    var body: some View {
        NavigationStack {
            let interval = periods.interval(of: kind, containing: anchor)
            HistoryContentView(interval: interval, kind: kind)
                .id("\(kind.rawValue)-\(interval.start.timeIntervalSince1970)")
                .safeAreaInset(edge: .top, spacing: 0) {
                    periodHeader(interval: interval)
                }
                .navigationTitle("Geçmiş")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func periodHeader(interval: DateInterval) -> some View {
        VStack(spacing: 10) {
            Picker("Dönem", selection: $kind) {
                ForEach(PeriodKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("history.periodPicker")

            HStack {
                Button {
                    anchor = periods.shift(anchor, kind: kind, by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Önceki dönem")

                Spacer()
                Text(periods.title(of: kind, containing: anchor))
                    .font(.headline)
                    .accessibilityIdentifier("history.periodTitle")
                Spacer()

                Button {
                    anchor = periods.shift(anchor, kind: kind, by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(interval.end > .now)
                .accessibilityLabel("Sonraki dönem")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// Secilen aralik icin @Query'leri tasiyan alt gorunum (aralik degisince yeniden olusturulur).
private struct HistoryContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var earnings: [EarningRecord]
    @Query private var expenses: [ExpenseRecord]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true

    @State private var editingEarning: EarningRecord?
    @State private var editingExpense: ExpenseRecord?

    let interval: DateInterval
    let kind: PeriodKind
    private let periods = PeriodRange()

    init(interval: DateInterval, kind: PeriodKind) {
        self.interval = interval
        self.kind = kind
        let start = interval.start
        let end = interval.end
        _earnings = Query(
            filter: #Predicate<EarningRecord> { $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\EarningRecord.startTime, order: .reverse)]
        )
        _expenses = Query(
            filter: #Predicate<ExpenseRecord> { $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\ExpenseRecord.date, order: .reverse)]
        )
    }

    private var calculator: EarningsCalculator {
        EarningsCalculator(costPerKm: costPerKm, autoEstimateEnabled: autoEstimate)
    }

    var body: some View {
        let daily = calculator.summarizeByDay(
            earnings: earnings.map { (day: $0.date, entry: $0.entry) },
            expenses: expenses.map { (day: $0.date, entry: $0.entry) }
        )
        let summary = daily.values.total
        let byPlatform = platformTotals()

        List {
            Section {
                SummaryGrid(summary: summary)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            if kind != .day, !daily.isEmpty {
                Section("Günlük net kazanç") {
                    Chart(periods.days(in: interval), id: \.self) { day in
                        BarMark(
                            x: .value("Gün", day, unit: .day),
                            y: .value("Net", daily[day]?.netEarnings ?? 0)
                        )
                        .foregroundStyle((daily[day]?.netEarnings ?? 0) >= 0 ? Color.accentColor : Color.red)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: kind == .month ? 7 : 1)) { _ in
                            AxisValueLabel(format: kind == .month
                                           ? .dateTime.day().locale(Formatters.locale)
                                           : .dateTime.weekday(.abbreviated).locale(Formatters.locale))
                        }
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }
            }

            if !byPlatform.isEmpty {
                Section("Platform bazında") {
                    let maxValue = byPlatform.map(\.total).max() ?? 1
                    ForEach(byPlatform, id: \.name) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(Formatters.currency(item.total)).monospacedDigit()
                            }
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.accentColor.gradient)
                                    .frame(width: max(4, proxy.size.width * item.total / max(maxValue, 1)))
                            }
                            .frame(height: 6)
                            Text("\(item.count) kayıt · \(Formatters.duration(item.duration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if earnings.isEmpty && expenses.isEmpty {
                ContentUnavailableView("Bu dönemde kayıt yok", systemImage: "calendar.badge.exclamationmark")
                    .listRowBackground(Color.clear)
            }

            if !earnings.isEmpty {
                Section("Kazançlar") {
                    ForEach(earnings) { record in
                        Button { editingEarning = record } label: {
                            EarningListRow(record: record, showsDate: kind != .day)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { earnings[$0] }.forEach { modelContext.delete($0) }
                        try? modelContext.save()
                    }
                }
            }

            if !expenses.isEmpty {
                Section("Giderler") {
                    ForEach(expenses) { record in
                        Button { editingExpense = record } label: {
                            ExpenseListRow(record: record, showsDate: kind != .day)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { expenses[$0] }.forEach { modelContext.delete($0) }
                        try? modelContext.save()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingEarning) { record in
            EarningFormView(record: record)
        }
        .sheet(item: $editingExpense) { record in
            ExpenseFormView(record: record)
        }
    }

    private struct PlatformTotal {
        var name: String
        var total: Double
        var count: Int
        var duration: TimeInterval
    }

    private func platformTotals() -> [PlatformTotal] {
        let grouped = Dictionary(grouping: earnings) { $0.platform?.name ?? "Platform yok" }
        return grouped.map { name, records in
            PlatformTotal(
                name: name,
                total: records.reduce(0) { $0 + $1.totalEarning },
                count: records.count,
                duration: records.reduce(0) { $0 + $1.duration }
            )
        }
        .sorted { $0.total > $1.total }
    }
}

/// Donem ozeti kutulari.
struct SummaryGrid: View {
    let summary: EarningsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Net kazanç").font(.caption).foregroundStyle(.secondary)
                Text(Formatters.currency(summary.netEarnings))
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .monospacedDigit()
                    .accessibilityIdentifier("history.netEarnings")
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    stat("Net TL/saat", Formatters.perHour(summary.netPerHour))
                    stat("Çalışma", Formatters.duration(summary.workDuration))
                }
                GridRow {
                    stat("Brüt (bonus dahil)", Formatters.currency(summary.totalEarnings))
                    stat("Gider", Formatters.currency(summary.totalExpenses))
                }
                GridRow {
                    stat("Mesafe", Formatters.distance(summary.distanceKm))
                    stat("Tahmini gider", Formatters.currency(summary.estimatedExpenses))
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EarningListRow: View {
    let record: EarningRecord
    var showsDate = false

    private var subtitle: String {
        var parts: [String] = []
        if showsDate {
            parts.append(record.date.formatted(Date.FormatStyle().locale(Formatters.locale).day().month(.abbreviated).weekday(.abbreviated)))
        }
        parts.append("\(Formatters.time(record.startTime))–\(Formatters.time(record.endTime))")
        if let district = record.district { parts.append(district) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.platform?.name ?? "Platform yok")
                        .font(.subheadline.weight(.semibold))
                    if record.source == .ocr {
                        Text("OCR")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.currency(record.totalEarning))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let packages = record.packageCount, packages > 0 {
                    Text("\(packages) paket").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct ExpenseListRow: View {
    let record: ExpenseRecord
    var showsDate = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.type.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.type.displayName).font(.subheadline.weight(.semibold))
                let detail = [
                    showsDate ? record.date.formatted(Date.FormatStyle().locale(Formatters.locale).day().month(.abbreviated)) : nil,
                    record.note,
                ].compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("−" + Formatters.currency(record.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.red)
        }
        .contentShape(Rectangle())
    }
}

extension ExpenseType {
    var symbolName: String {
        switch self {
        case .fuel: "fuelpump"
        case .maintenance: "wrench.and.screwdriver"
        case .tire: "circle.circle"
        case .depreciation: "chart.line.downtrend.xyaxis"
        case .other: "ellipsis.circle"
        }
    }
}
