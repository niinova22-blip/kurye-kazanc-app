import SwiftUI
import SwiftData

/// Ana ekran: bugunun net kazanci, net TL/saat, calisma suresi, mesafe ve "Calisiyorum" modu.
struct DashboardView: View {
    @Query private var todaysEarnings: [EarningRecord]
    @Query private var todaysExpenses: [ExpenseRecord]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true

    @State private var viewModel = DashboardViewModel()
    @State private var activeSheet: Sheet?

    private let day: Date

    enum Sheet: String, Identifiable {
        case addEarning, addExpense
        var id: String { rawValue }
    }

    /// - Parameter day: Gosterilecek gun. Gece yarisi gecisi icin sonraki adimda scenePhase ile yenilenecek.
    init(day: Date = .now) {
        let start = Calendar.current.startOfDay(for: day)
        self.day = start
        _todaysEarnings = Query(
            filter: #Predicate<EarningRecord> { $0.date == start },
            sort: \EarningRecord.startTime
        )
        _todaysExpenses = Query(
            filter: #Predicate<ExpenseRecord> { $0.date == start },
            sort: \ExpenseRecord.createdAt
        )
    }

    var body: some View {
        let summary = viewModel.summary(
            earnings: todaysEarnings,
            expenses: todaysExpenses,
            costPerKm: costPerKm,
            autoEstimate: autoEstimate
        )

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NetEarningsCard(summary: summary)
                    metricsRow(summary)
                    WorkModeButton(
                        isWorking: viewModel.isWorking,
                        sessionStart: viewModel.workSessionStart,
                        action: { viewModel.toggleWorking() }
                    )
                    recordsSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bugün")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(Formatters.longDay(day))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Kazanç ekle", systemImage: "turkishlirasign.circle") { activeSheet = .addEarning }
                        Button("Gider ekle", systemImage: "fuelpump") { activeSheet = .addExpense }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Ekle")
                    .accessibilityIdentifier("dashboard.addMenu")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                // TODO: AddEarningView (manuel + OCR) ve AddExpenseView sonraki adimlarda.
                ComingSoonView(title: sheet == .addEarning ? "Kazanç ekle" : "Gider ekle")
            }
        }
    }

    private func metricsRow(_ summary: EarningsSummary) -> some View {
        HStack(spacing: 12) {
            MetricTile(
                title: "Net TL/saat",
                value: Formatters.perHour(summary.netPerHour),
                systemImage: "gauge.with.dots.needle.67percent",
                identifier: "dashboard.netPerHour"
            )
            MetricTile(
                title: "Çalışma",
                value: Formatters.duration(summary.workDuration),
                systemImage: "clock",
                identifier: "dashboard.workDuration"
            )
            MetricTile(
                title: "Mesafe",
                value: Formatters.distance(summary.distanceKm),
                systemImage: "road.lanes",
                identifier: "dashboard.distance"
            )
        }
    }

    @ViewBuilder
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bugünkü kayıtlar")
                .font(.headline)
                .padding(.horizontal, 4)

            if todaysEarnings.isEmpty {
                ContentUnavailableView {
                    Label("Henüz kazanç yok", systemImage: "tray")
                } description: {
                    Text("Sağ üstteki + ile manuel giriş yap ya da ekran görüntüsü yükle.")
                }
                .frame(maxWidth: .infinity)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(todaysEarnings) { record in
                        EarningRow(record: record)
                        if record.id != todaysEarnings.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Bilesenler

private struct NetEarningsCard: View {
    let summary: EarningsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net kazanç")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))

            Text(Formatters.currency(summary.netEarnings))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier("dashboard.netEarnings")

            HStack(spacing: 16) {
                breakdown("Brüt", Formatters.currency(summary.totalEarnings))
                breakdown("Gider", "−" + Formatters.currency(summary.totalExpenses))
                if summary.bonusEarnings > 0 {
                    breakdown("Bonus", Formatters.currency(summary.bonusEarnings))
                }
            }

            if summary.usesEstimatedExpenses {
                Label("Yakıt+bakım km başına tahmini (\(Formatters.currency(summary.estimatedExpenses)))",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .accessibilityElement(children: .contain)
    }

    private func breakdown(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier(identifier)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WorkModeButton: View {
    let isWorking: Bool
    let sessionStart: Date?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isWorking ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isWorking ? "Çalışmayı bitir" : "Çalışmaya başla")
                        .font(.headline)
                    if isWorking, let sessionStart {
                        TimelineView(.periodic(from: sessionStart, by: 60)) { context in
                            Text("Süre: \(Formatters.duration(context.date.timeIntervalSince(sessionStart))) · konum takibi açık")
                                .font(.caption)
                        }
                    } else {
                        Text("Konum yalnızca bu mod açıkken takip edilir")
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .foregroundStyle(isWorking ? .white : Color.accentColor)
            .padding(16)
            .background(
                isWorking ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(.background),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard.workToggle")
    }
}

private struct EarningRow: View {
    let record: EarningRecord

    private var subtitle: String {
        let range = "\(Formatters.time(record.startTime))–\(Formatters.time(record.endTime))"
        guard let district = record.district else { return range }
        return "\(range) · \(district)"
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
            Text(Formatters.currency(record.totalEarning))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ComingSoonView: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text("Bu ekran bir sonraki adımda eklenecek."))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { dismiss() }
                    }
                }
        }
    }
}

#Preview("Örnek veri") {
    DashboardView()
        .modelContainer(SampleData.previewContainer)
}

#Preview("Boş") {
    DashboardView()
        .modelContainer(ModelContainerFactory.make(inMemory: true))
}
