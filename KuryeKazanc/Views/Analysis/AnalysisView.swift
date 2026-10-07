import SwiftUI
import SwiftData
import Charts

/// Analiz: gunluk / haftalik / aylik ozet, onceki doneme gore degisim, en karli saatler,
/// isi haritasi, platform karsilastirmasi ve kayit listesi.
struct AnalysisView: View {
    @State private var kind: PeriodKind = .week
    @State private var anchor: Date = .now

    private let periods = PeriodRange()

    var body: some View {
        NavigationStack {
            let interval = periods.interval(of: kind, containing: anchor)
            let previous = periods.interval(of: kind, containing: periods.shift(anchor, kind: kind, by: -1))
            AnalysisContentView(interval: interval, previous: previous, kind: kind)
                .id("\(kind.rawValue)-\(interval.start.timeIntervalSince1970)")
                .safeAreaInset(edge: .top, spacing: 0) {
                    periodHeader(interval: interval)
                }
                .navigationTitle("Analiz")
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
private struct AnalysisContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var earnings: [EarningRecord]
    @Query private var expenses: [ExpenseRecord]
    @Query private var previousEarnings: [EarningRecord]
    @Query private var previousExpenses: [ExpenseRecord]
    /// Son 8 hafta: isi haritasi + en iyi dilimler
    @Query private var recentEarnings: [EarningRecord]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true

    @State private var editingEarning: EarningRecord?
    @State private var editingExpense: ExpenseRecord?

    let interval: DateInterval
    let kind: PeriodKind
    private let periods = PeriodRange()

    init(interval: DateInterval, previous: DateInterval, kind: PeriodKind) {
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
        let previousStart = previous.start
        let previousEnd = previous.end
        _previousEarnings = Query(filter: #Predicate<EarningRecord> { $0.date >= previousStart && $0.date < previousEnd })
        _previousExpenses = Query(filter: #Predicate<ExpenseRecord> { $0.date >= previousStart && $0.date < previousEnd })
        let recentStart = Calendar.current.date(byAdding: .day, value: -56, to: .now) ?? .distantPast
        _recentEarnings = Query(filter: #Predicate<EarningRecord> { $0.date >= recentStart })
    }

    private var calculator: EarningsCalculator {
        EarningsCalculator(costPerKm: costPerKm, autoEstimateEnabled: autoEstimate)
    }

    private var analytics: EarningsAnalytics {
        EarningsAnalytics(calendar: .current, costPerKm: costPerKm)
    }

    private var platformNames: [String: String] {
        Dictionary(platforms.map { ($0.code, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func summarize(_ earnings: [EarningRecord], _ expenses: [ExpenseRecord]) -> [Date: EarningsSummary] {
        calculator.summarizeByDay(
            earnings: earnings.map { (day: $0.date, entry: $0.entry) },
            expenses: expenses.map { (day: $0.date, entry: $0.entry) }
        )
    }

    var body: some View {
        let daily = summarize(earnings, expenses)
        let summary = daily.values.total
        let previousNet = summarize(previousEarnings, previousExpenses).values.total.netEarnings
        let change = EarningsAnalytics.percentChange(current: summary.netEarnings, previous: previousNet)
        let recent = recentEarnings.map(\.entry)
        let bestSlots = analytics.topSlots(recent)
        let heatmap = analytics.heatmap(recent)
        let platformStats = analytics.platformStats(earnings.map(\.entry))

        List {
            Section {
                HeroAmount(title: "Net kazanç", value: summary.netEarnings, identifier: "history.netEarnings")
                if let change {
                    Text("Önceki döneme göre \(change >= 0 ? "+" : "−")%\(Int(abs(change).rounded()))")
                        .font(.subheadline)
                        .foregroundStyle(change >= 0 ? Theme.accent : Theme.negative)
                }
                MetricStrip([
                    .init(title: "Net ₺/saat", value: Formatters.perHour(summary.netPerHour), identifier: "history.netPerHour"),
                    .init(title: "Çalışma", value: Formatters.duration(summary.workDuration), identifier: "history.workDuration"),
                    .init(title: "Mesafe", value: Formatters.distance(summary.distanceKm), identifier: "history.distance"),
                ])
                MetricStrip([
                    .init(title: "Brüt", value: Formatters.currency(summary.totalEarnings), identifier: "history.gross"),
                    .init(title: "Gider", value: Formatters.currency(summary.totalExpenses), identifier: "history.expenses"),
                    .init(title: "Tahmini gider", value: Formatters.currency(summary.estimatedExpenses), identifier: "history.estimated"),
                ])
            }
            .listRowSeparator(.hidden)

            if kind != .day, !daily.isEmpty {
                Section("Günlük net") {
                    Chart(periods.days(in: interval), id: \.self) { day in
                        BarMark(
                            x: .value("Gün", day, unit: .day),
                            y: .value("Net", daily[day]?.netEarnings ?? 0)
                        )
                        .foregroundStyle((daily[day]?.netEarnings ?? 0) >= 0 ? Theme.accent : Theme.negative)
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

            if !bestSlots.isEmpty {
                BestSlotsSection(slots: bestSlots)
            }

            if !heatmap.isEmpty {
                HeatmapSection(map: heatmap)
            }

            if !platformStats.isEmpty {
                PlatformComparisonSection(stats: platformStats, names: platformNames)
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
}
