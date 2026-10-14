import SwiftUI
import SwiftData
import Charts

/// Analiz: gunluk / haftalik / aylik ozet, onceki doneme gore degisim, en karli saatler,
/// isi haritasi, platform karsilastirmasi ve kayit listesi.
/// 1.7: Kazanc sekmesinin "Analiz" gorunumu; kendi NavigationStack'i yok (EarningsTabView saglar).
struct AnalysisView: View {
    @State private var kind: PeriodKind = .week
    @State private var anchor: Date = .now

    private let periods = PeriodRange()

    var body: some View {
        let interval = periods.interval(of: kind, containing: anchor)
        let previous = periods.interval(of: kind, containing: periods.shift(anchor, kind: kind, by: -1))
        AnalysisContentView(interval: interval, previous: previous, kind: kind)
            .id("\(kind.rawValue)-\(interval.start.timeIntervalSince1970)")
            .safeAreaInset(edge: .top, spacing: 0) {
                periodHeader(interval: interval)
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
                    .multilineTextAlignment(.center)
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
    @Environment(SyncCoordinator.self) private var sync
    @Query private var earnings: [EarningRecord]
    @Query private var expenses: [ExpenseRecord]
    @Query private var previousEarnings: [EarningRecord]
    @Query private var previousExpenses: [ExpenseRecord]
    /// Son 8 hafta: isi haritasi + en iyi dilimler
    @Query private var recentEarnings: [EarningRecord]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @Environment(PayrollModel.self) private var payroll

    /// Bugun ekraniyla ayni: yakit fiyati girildiyse km × tuketim × fiyat, yoksa km basi maliyet.
    private var effectiveCostPerKm: Double {
        payroll.fuelModel(fallbackCostPerKm: costPerKm).costPerKm(on: payroll.today).doubleValue
    }

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
        // Son 8 hafta: gun basina normalize edilir (sinir gun icinde kaymasin)
        let calendar = Calendar.current
        let shifted: Date = calendar.date(byAdding: .day, value: -56, to: .now) ?? .distantPast
        let recentStart: Date = calendar.startOfDay(for: shifted)
        _recentEarnings = Query(filter: #Predicate<EarningRecord> { $0.date >= recentStart })
    }

    private var calculator: EarningsCalculator {
        EarningsCalculator(costPerKm: effectiveCostPerKm, autoEstimateEnabled: autoEstimate)
    }

    private var analytics: EarningsAnalytics {
        EarningsAnalytics(calendar: .current, costPerKm: effectiveCostPerKm)
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

    // Derleyicinin tip denetimi zaman asimina ugramasin diye govde kucuk parcalara bolundu.
    var body: some View {
        let daily: [Date: EarningsSummary] = summarize(earnings, expenses)
        let summary: EarningsSummary = daily.values.total

        List {
            summarySection(summary: summary)
            dailyChartSection(daily: daily)
            insightSections
            emptyState
            earningsSection
            expensesSection
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingEarning) { record in
            EarningFormView(record: record)
        }
        .sheet(item: $editingExpense) { record in
            ExpenseFormView(record: record)
        }
    }

    // MARK: - Ozet

    private func summarySection(summary: EarningsSummary) -> some View {
        Section {
            HeroAmount(title: "Net kazanç", value: summary.netEarnings, identifier: "history.netEarnings")
            changeLine(currentNet: summary.netEarnings)
            MetricStrip(primaryMetrics(summary))
            MetricStrip(secondaryMetrics(summary))
        }
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func changeLine(currentNet: Double) -> some View {
        let previousNet: Double = summarize(previousEarnings, previousExpenses).values.total.netEarnings
        if let change = EarningsAnalytics.percentChange(current: currentNet, previous: previousNet) {
            let text: String = Self.changeText(change)
            Text(verbatim: text)
                .font(.subheadline)
                .foregroundStyle(change >= 0 ? Theme.accent : Theme.negative)
        }
    }

    /// "%" yerellestirme bicim belirteci gibi yorumlanmasin diye metin once String olarak kurulur.
    static func changeText(_ change: Double) -> String {
        let sign: String = change >= 0 ? "+" : "−"
        let percent: Int = Int(abs(change).rounded())
        return "Önceki döneme göre " + sign + "%" + String(percent)
    }

    private func primaryMetrics(_ summary: EarningsSummary) -> [MetricStrip.Item] {
        [
            MetricStrip.Item(title: "Saatlik net", value: Formatters.perHour(summary.netPerHour), identifier: "history.netPerHour"),
            MetricStrip.Item(title: "Çalışma süresi", value: Formatters.duration(summary.workDuration), identifier: "history.workDuration"),
            MetricStrip.Item(title: "Mesafe", value: Formatters.distance(summary.distanceKm), identifier: "history.distance"),
        ]
    }

    private func secondaryMetrics(_ summary: EarningsSummary) -> [MetricStrip.Item] {
        [
            MetricStrip.Item(title: "Brüt", value: Formatters.currency(summary.totalEarnings), identifier: "history.gross"),
            MetricStrip.Item(title: "Toplam gider", value: Formatters.currency(summary.totalExpenses), identifier: "history.expenses"),
            MetricStrip.Item(title: "Yakıt (tahmini)", value: Formatters.currency(summary.estimatedExpenses), identifier: "history.estimated"),
        ]
    }

    // MARK: - Grafik ve analizler

    @ViewBuilder
    private func dailyChartSection(daily: [Date: EarningsSummary]) -> some View {
        if kind != .day, !daily.isEmpty {
            Section("Günlük net") {
                DailyNetChart(days: periods.days(in: interval), daily: daily, kind: kind)
            }
        }
    }

    @ViewBuilder
    private var insightSections: some View {
        let recent: [EarningEntry] = recentEarnings.map(\.entry)
        let bestSlots: [RankedSlot] = analytics.topSlots(recent)
        let heatmap: [HourSlot: SlotStat] = analytics.heatmap(recent)
        let platformStats: [PlatformStat] = analytics.platformStats(earnings.map(\.entry))

        if !bestSlots.isEmpty {
            BestSlotsSection(slots: bestSlots)
        }
        if !heatmap.isEmpty {
            HeatmapSection(map: heatmap)
        }
        if !platformStats.isEmpty {
            PlatformComparisonSection(stats: platformStats, names: platformNames)
        }
    }

    // MARK: - Kayitlar

    @ViewBuilder
    private var emptyState: some View {
        if earnings.isEmpty && expenses.isEmpty {
            ContentUnavailableView("Bu dönemde kayıt yok", systemImage: "calendar.badge.exclamationmark")
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var earningsSection: some View {
        if !earnings.isEmpty {
            Section("Kazançlar") {
                ForEach(earnings) { record in
                    Button { editingEarning = record } label: {
                        EarningListRow(record: record, showsDate: kind != .day)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteEarnings)
            }
        }
    }

    @ViewBuilder
    private var expensesSection: some View {
        if !expenses.isEmpty {
            Section("Giderler") {
                ForEach(expenses) { record in
                    Button { editingExpense = record } label: {
                        ExpenseListRow(record: record, showsDate: kind != .day)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteExpenses)
            }
        }
    }

    private func deleteEarnings(at offsets: IndexSet) {
        let records: [EarningRecord] = offsets.map { earnings[$0] }
        for record in records {
            let id: UUID = record.id
            try? modelContext.deleteEarning(record)
            // Silinen kaydin bekleyen gonderimi de dusulur
            sync.recordDeleted(id: id)
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        let records: [ExpenseRecord] = offsets.map { expenses[$0] }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}

/// Donemin gunluk net cubuk grafigi.
private struct DailyNetChart: View {
    let days: [Date]
    let daily: [Date: EarningsSummary]
    let kind: PeriodKind

    private func net(on day: Date) -> Double {
        daily[day]?.netEarnings ?? 0
    }

    private func barColor(on day: Date) -> Color {
        net(on: day) >= 0 ? Theme.accent : Theme.negative
    }

    private var strideCount: Int {
        kind == .month ? 7 : 1
    }

    private var axisFormat: Date.FormatStyle {
        if kind == .month {
            return Date.FormatStyle().locale(Formatters.locale).day()
        }
        return Date.FormatStyle().locale(Formatters.locale).weekday(.abbreviated)
    }

    var body: some View {
        Chart(days, id: \.self) { day in
            BarMark(
                x: .value("Gün", day, unit: .day),
                y: .value("Net", net(on: day))
            )
            .foregroundStyle(barColor(on: day))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideCount)) { _ in
                AxisValueLabel(format: axisFormat)
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }
}
