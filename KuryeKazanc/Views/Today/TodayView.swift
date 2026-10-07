import SwiftUI
import SwiftData

/// Bugun sekmesi: net kazanc, net TL/saat, calisma suresi, mesafe, haftalik hedef ve vardiya dugmesi.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkSessionManager.self) private var workSession
    @Environment(ScreenshotScanner.self) private var scanner
    @Environment(\.scenePhase) private var scenePhase

    @Query private var todaysEarnings: [EarningRecord]
    @Query private var todaysExpenses: [ExpenseRecord]
    @Query private var weekEarnings: [EarningRecord]
    @Query private var weekExpenses: [ExpenseRecord]
    @Query private var couriers: [Courier]
    /// Yalnizca assetIdentifier icin: kaydedilmis ekran goruntuleri tekrar onerilmez.
    @Query private var evidences: [ScreenshotEvidence]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @AppStorage(AppPreferences.weeklyGoalKey) private var weeklyGoal = 0.0

    @State private var activeSheet: Sheet?
    /// Paylas eklentisinden gelen, sirada bekleyen ekran goruntuleri.
    @State private var inboxQueue: [ImportedScreenshot] = []

    private let inbox = LaunchOptions.current.isUITesting ? ScreenshotInbox(directory: nil) : .shared

    private let day: Date

    enum Sheet: Identifiable {
        case addEarning(session: WorkSessionSummary?, opensPicker: Bool)
        case editEarning(EarningRecord)
        case importedScreenshot(ImportedScreenshot)
        case addExpense
        case editExpense(ExpenseRecord)

        var id: String {
            switch self {
            case .addEarning: "addEarning"
            case .editEarning(let record): "editEarning-\(record.id)"
            case .importedScreenshot: "imported"
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
        let week = PeriodRange().interval(of: .week, containing: start)
        let weekStart = week.start
        let weekEnd = week.end
        _weekEarnings = Query(filter: #Predicate<EarningRecord> { $0.date >= weekStart && $0.date < weekEnd })
        _weekExpenses = Query(filter: #Predicate<ExpenseRecord> { $0.date >= weekStart && $0.date < weekEnd })
    }

    /// Kazanc formunda onceden secili platform: profildeki ilk platform.
    private var defaultPlatform: Platform? {
        couriers.first?.defaultPlatforms.sorted { $0.sortOrder < $1.sortOrder }.first
    }

    private var calculator: EarningsCalculator {
        EarningsCalculator(costPerKm: costPerKm, autoEstimateEnabled: autoEstimate)
    }

    private var weekGoal: GoalProgress {
        TodayViewModel.weekGoal(
            target: weeklyGoal, earnings: weekEarnings, expenses: weekExpenses, calculator: calculator
        )
    }

    var body: some View {
        let summary = TodayViewModel.summary(
            earnings: todaysEarnings,
            expenses: todaysExpenses,
            costPerKm: costPerKm,
            autoEstimate: autoEstimate
        )
        let goal = weekGoal

        NavigationStack {
            List {
                if let suggestion = scanner.suggestion {
                    suggestionSection(suggestion)
                }

                Section {
                    HStack(alignment: .center, spacing: 16) {
                        HeroAmount(title: "Net kazanç", value: summary.netEarnings, identifier: "dashboard.netEarnings")
                        if goal.isSet {
                            VStack(spacing: 4) {
                                GoalRing(progress: goal).frame(width: 56, height: 56)
                                Text("Hafta %\(Int(goal.fraction * 100))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    MetricStrip([
                        .init(title: "Net ₺/saat", value: Formatters.perHour(summary.netPerHour), identifier: "dashboard.netPerHour"),
                        .init(title: "Çalışma", value: Formatters.duration(summary.workDuration), identifier: "dashboard.workDuration"),
                        .init(title: "Mesafe", value: Formatters.distance(summary.distanceKm), identifier: "dashboard.distance"),
                    ])
                    if summary.usesEstimatedExpenses {
                        Text("Yakıt ve bakım km başına tahmini: \(Formatters.currency(summary.estimatedExpenses))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowSeparator(.hidden)

                Section {
                    shiftButton
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                earningsSection
                if !todaysExpenses.isEmpty {
                    expensesSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bugün")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(Formatters.longDay(day))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .task {
                await processInbox()
                await scanner.scan(knownIdentifiers: knownIDs)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await processInbox()
                        await scanner.scan(knownIdentifiers: knownIDs)
                    }
                }
            }
            .sheet(item: $activeSheet, onDismiss: showNextFromInbox) { sheet in
                switch sheet {
                case .addEarning(let session, let opensPicker):
                    EarningFormView(session: session, defaultPlatform: defaultPlatform, opensPhotoPicker: opensPicker)
                case .editEarning(let record):
                    EarningFormView(record: record)
                case .importedScreenshot(let imported):
                    EarningFormView(defaultPlatform: defaultPlatform, imported: imported)
                case .addExpense:
                    ExpenseFormView()
                case .editExpense(let record):
                    ExpenseFormView(record: record)
                }
            }
        }
    }

    // MARK: - Bolumler

    private var knownIDs: Set<String> {
        Set(evidences.compactMap(\.assetIdentifier))
    }

    private func platformName(_ code: String?) -> String {
        Platform.defaults.first { $0.code == code }?.name ?? "Platform"
    }

    private func suggestionSection(_ suggestion: ImportedScreenshot) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yeni kazanç ekranı bulundu")
                        .font(.subheadline.weight(.semibold))
                    Text("\(platformName(suggestion.parsed.platformCode)) · \(Formatters.currency(suggestion.parsed.totalEarning))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Ekle") {
                    if let imported = scanner.consumeSuggestion() {
                        activeSheet = .importedScreenshot(imported)
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("today.suggestion.add")
            }
            .swipeActions {
                Button("Gizle", role: .destructive) { scanner.dismissSuggestion() }
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Ekran görüntüsü", systemImage: "text.viewfinder") {
                activeSheet = .addEarning(session: nil, opensPicker: true)
            }
            Button("Elle kazanç", systemImage: "square.and.pencil") {
                activeSheet = .addEarning(session: nil, opensPicker: false)
            }
            Button("Gider", systemImage: "fuelpump") { activeSheet = .addExpense }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Ekle")
        .accessibilityIdentifier("dashboard.addMenu")
    }

    private var shiftButton: some View {
        VStack(spacing: 8) {
            Button(workSession.isWorking ? "Vardiyayı bitir" : "Vardiyayı başlat", action: toggleWork)
                .buttonStyle(PrimaryActionButtonStyle(isDestructive: workSession.isWorking))
                .accessibilityIdentifier("dashboard.workToggle")
            if workSession.isWorking, let start = workSession.sessionStart {
                TimelineView(.periodic(from: start, by: 30)) { context in
                    Text(shiftStatus(elapsed: context.date.timeIntervalSince(start)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else {
                Text("Süre ve mesafe ölçülür; konum yalnızca vardiya boyunca kullanılır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var earningsSection: some View {
        Section("Kazançlar") {
            if todaysEarnings.isEmpty {
                Text("Platformun kazanç ekranının görüntüsünü ekle — + düğmesinden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !scanner.isEnabled {
                    Button("Ekran görüntülerini otomatik bul") {
                        Task {
                            if await scanner.enable() {
                                await scanner.scan(knownIdentifiers: knownIDs)
                            }
                        }
                    }
                    .accessibilityIdentifier("today.enableScan")
                }
            } else {
                ForEach(todaysEarnings) { record in
                    Button { activeSheet = .editEarning(record) } label: {
                        EarningListRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard.earningRow")
                }
                .onDelete { offsets in
                    offsets.map { todaysEarnings[$0] }.forEach { delete($0) }
                }
            }
        }
    }

    private var expensesSection: some View {
        Section("Giderler") {
            ForEach(todaysExpenses) { record in
                Button { activeSheet = .editExpense(record) } label: {
                    ExpenseListRow(record: record)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { todaysExpenses[$0] }.forEach { delete($0) }
            }
        }
    }

    // MARK: - Eylemler

    /// Paylas eklentisinin biraktigi gorselleri okur, siler ve sirayla forma aktarir.
    private func processInbox() async {
        let importer = ScreenshotImporter()
        for url in inbox.pending() {
            defer { inbox.remove(url) }
            guard let data = try? Data(contentsOf: url),
                  let result = try? await importer.importImage(data: data, assetIdentifier: nil) else { continue }
            inboxQueue.append(result)
        }
        if activeSheet == nil {
            showNextFromInbox()
        }
    }

    private func showNextFromInbox() {
        guard !inboxQueue.isEmpty else { return }
        activeSheet = .importedScreenshot(inboxQueue.removeFirst())
    }

    private func shiftStatus(elapsed: TimeInterval) -> String {
        let isLocationAvailable = workSession.location.isAuthorized || !workSession.location.isEnabled
        var parts = [Formatters.duration(elapsed)]
        if isLocationAvailable {
            parts.append(Formatters.distance(workSession.sessionDistanceKm))
        } else {
            parts.append("mesafe ölçülmüyor")
        }
        return parts.joined(separator: " · ")
    }

    private func toggleWork() {
        Haptics.impact()
        if workSession.isWorking {
            // Vardiya bitince kazanc formu sure + mesafe + bolgeyle on doldurulmus acilir
            if let summary = workSession.stop() {
                activeSheet = .addEarning(session: summary, opensPicker: false)
            }
        } else {
            workSession.start()
        }
    }

    private func delete(_ model: some PersistentModel) {
        modelContext.delete(model)
        try? modelContext.save()
    }
}

#Preview("Örnek veri") {
    let location = LocationService(isEnabled: false)
    return TodayView()
        .modelContainer(SampleData.previewContainer)
        .environment(location)
        .environment(WorkSessionManager(location: location))
        .environment(ScreenshotScanner())
}
