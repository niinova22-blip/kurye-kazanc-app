import SwiftUI
import SwiftData

/// Ana ekran: bugunun net kazanci, net TL/saat, calisma suresi, mesafe ve "Calisiyorum" modu.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkSessionManager.self) private var workSession

    @Query private var todaysEarnings: [EarningRecord]
    @Query private var todaysExpenses: [ExpenseRecord]
    @Query private var couriers: [Courier]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true

    @State private var activeSheet: Sheet?

    private let day: Date

    enum Sheet: Identifiable {
        case addEarning(WorkSessionSummary?)
        case editEarning(EarningRecord)
        case addExpense
        case editExpense(ExpenseRecord)

        var id: String {
            switch self {
            case .addEarning: "addEarning"
            case .editEarning(let record): "editEarning-\(record.id)"
            case .addExpense: "addExpense"
            case .editExpense(let record): "editExpense-\(record.id)"
            }
        }
    }

    /// - Parameter day: Gosterilecek gun. Gece yarisi gecince MainTabView yeni gunle yeniden olusturur.
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

    /// Kazanc formunda onceden secili platform: profildeki ilk platform.
    private var defaultPlatform: Platform? {
        couriers.first?.defaultPlatforms.sorted { $0.sortOrder < $1.sortOrder }.first
    }

    var body: some View {
        let summary = DashboardViewModel.summary(
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
                        isWorking: workSession.isWorking,
                        sessionStart: workSession.sessionStart,
                        distanceKm: workSession.sessionDistanceKm,
                        isLocationAvailable: workSession.location.isAuthorized || !workSession.location.isEnabled,
                        action: toggleWork
                    )
                    earningsSection
                    if !todaysExpenses.isEmpty {
                        expensesSection
                    }
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
                        Button("Kazanç ekle", systemImage: "turkishlirasign.circle") { activeSheet = .addEarning(nil) }
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
                switch sheet {
                case .addEarning(let session):
                    EarningFormView(session: session, defaultPlatform: defaultPlatform)
                case .editEarning(let record):
                    EarningFormView(record: record)
                case .addExpense:
                    ExpenseFormView()
                case .editExpense(let record):
                    ExpenseFormView(record: record)
                }
            }
        }
    }

    private func toggleWork() {
        if workSession.isWorking {
            // Oturum bitince kazanc formu sure + mesafe + bolgeyle on doldurulmus acilir
            if let summary = workSession.stop() {
                activeSheet = .addEarning(summary)
            }
        } else {
            workSession.start()
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

    private var earningsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bugünkü kazançlar")
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
                        Button { activeSheet = .editEarning(record) } label: {
                            EarningListRow(record: record)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Düzenle", systemImage: "pencil") { activeSheet = .editEarning(record) }
                            Button("Sil", systemImage: "trash", role: .destructive) { delete(record) }
                        }
                        .accessibilityIdentifier("dashboard.earningRow")
                        if record.id != todaysEarnings.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bugünkü giderler")
                .font(.headline)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(todaysExpenses) { record in
                    Button { activeSheet = .editExpense(record) } label: {
                        ExpenseListRow(record: record)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Düzenle", systemImage: "pencil") { activeSheet = .editExpense(record) }
                        Button("Sil", systemImage: "trash", role: .destructive) { delete(record) }
                    }
                    if record.id != todaysExpenses.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func delete(_ model: some PersistentModel) {
        modelContext.delete(model)
        try? modelContext.save()
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
    let distanceKm: Double
    let isLocationAvailable: Bool
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
                        TimelineView(.periodic(from: sessionStart, by: 30)) { context in
                            Text(statusText(elapsed: context.date.timeIntervalSince(sessionStart)))
                                .font(.caption)
                        }
                    } else {
                        Text("Süre ve mesafe ölçülür; konum yalnızca bu mod açıkken takip edilir")
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

    private func statusText(elapsed: TimeInterval) -> String {
        var parts = ["Süre: \(Formatters.duration(elapsed))"]
        if isLocationAvailable {
            parts.append(Formatters.distance(distanceKm))
        } else {
            parts.append("konum izni yok, mesafe ölçülmüyor")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview("Örnek veri") {
    let location = LocationService(isEnabled: false)
    return DashboardView()
        .modelContainer(SampleData.previewContainer)
        .environment(location)
        .environment(WorkSessionManager(location: location))
}
