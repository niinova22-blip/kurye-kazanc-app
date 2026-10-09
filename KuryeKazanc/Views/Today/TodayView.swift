import SwiftUI
import SwiftData
import PhotosUI

/// Bugun sekmesi: net kazanc, net TL/saat, calisma suresi, mesafe, haftalik hedef ve vardiya dugmesi.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkSessionManager.self) private var workSession
    @Environment(ScreenshotScanner.self) private var scanner
    @Environment(AutoShiftCoordinator.self) private var autoShift
    @Environment(SyncCoordinator.self) private var sync
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @Query private var todaysEarnings: [EarningRecord]
    @Query private var todaysExpenses: [ExpenseRecord]
    @Query private var weekEarnings: [EarningRecord]
    @Query private var weekExpenses: [ExpenseRecord]
    @Query private var couriers: [Courier]
    /// Kaydedilmis ekran goruntuleri (kimlik + metin ozeti) tekrar onerilmez / siraya alinmaz.
    @Query private var evidences: [ScreenshotEvidence]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @AppStorage(AppPreferences.weeklyGoalKey) private var weeklyGoal = 0.0
    @AppStorage(AppPreferences.dailyGoalKey) private var dailyGoal = 0.0

    @State private var activeSheet: Sheet?
    /// Paylas eklentisinden / coklu secimden gelen, sirada bekleyen ekran goruntuleri.
    @State private var inboxQueue: [ImportedScreenshot] = []
    @State private var isProcessingInbox = false
    /// "+ > Ekran goruntusu": en fazla 5 ekran goruntusu secilir, sirayla forma aktarilir.
    @State private var showScreenshotPicker = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isImportingPicked = false
    /// Su an acik formdaki ekran goruntusunun ozeti (kuyruktan cikti ama henuz kaydedilmedi).
    @State private var presentedHash: String?
    /// Okunamayan / zaten kayitli gorseller icin engellemeyen bildirimler.
    @State private var notices: [String] = []

    private let inbox = LaunchOptions.current.isUITesting ? ScreenshotInbox(directory: nil) : .shared

    private let captureStore = LaunchOptions.current.isUITesting ? BroadcastCaptureStore(directory: nil) : .shared

    private let day: Date

    enum Sheet: Identifiable {
        case addEarning(session: WorkSessionSummary?)
        /// Biten otomatik vardiya: kazanc kaydedilince bekleyenlerden duser.
        case pendingShift(id: UUID, summary: WorkSessionSummary)
        case editEarning(EarningRecord)
        case importedScreenshot(ImportedScreenshot)
        case addExpense
        case editExpense(ExpenseRecord)
        case scanResults(ScanResultsViewModel)

        var id: String {
            switch self {
            case .scanResults: "scanResults"
            case .addEarning: "addEarning"
            case .pendingShift(let id, _): "pending-\(id)"
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
        let summary: EarningsSummary = TodayViewModel.summary(
            earnings: todaysEarnings,
            expenses: todaysExpenses,
            costPerKm: costPerKm,
            autoEstimate: autoEstimate
        )

        NavigationStack {
            todayList(summary)
                .listStyle(.insetGrouped)
                .navigationTitle("Bugün")
                .toolbar { toolbarContent }
                .task { await refreshImports() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await refreshImports() }
                    }
                }
                .sheet(item: $activeSheet, onDismiss: sheetDismissed) { sheet in
                    sheetContent(sheet)
                }
                .photosPicker(isPresented: $showScreenshotPicker, selection: $pickedItems,
                              maxSelectionCount: 5, matching: .screenshots, photoLibrary: .shared())
                .onChange(of: pickedItems) { _, items in
                    guard !items.isEmpty else { return }
                    pickedItems = []
                    Task { await importPicked(items) }
                }
                // "Vardiya bitti" bildirimine dokunuldu: bekleyen vardiyanin kazanc formu acilir
                .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                    openScanResultsIfPending()
                }
                .onAppear(perform: openRequestedPending)
                .onChange(of: autoShift.requestedPendingID) { _, _ in
                    openRequestedPending()
                }
        }
    }

    // MARK: - Bolumler

    private func todayList(_ summary: EarningsSummary) -> some View {
        List {
            if let suggestion = scanner.suggestion {
                suggestionSection(suggestion)
            }
            noticesSection
            autoShiftSections
            heroSection(summary)

            Section {
                shiftPanel(summary)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section { ScanButton() }
            earningsSection
            if !todaysExpenses.isEmpty {
                expensesSection
            }
            scanSection
        }
    }

    /// Otomatik vardiya: iptal satiri, biten vardiyalar, izin uyarisi.
    @ViewBuilder
    private var autoShiftSections: some View {
        cancelAutoShiftSection
        pendingShiftsSection
        autoShiftPermissionSection
    }

    @ViewBuilder
    private var cancelAutoShiftSection: some View {
        if workSession.isWorking, workSession.origin == .auto {
            Section {
                Button(role: .destructive) {
                    autoShift.cancelAutoShift()
                } label: {
                    Label("Bu bir vardiya değil", systemImage: "xmark.circle")
                }
                .accessibilityIdentifier("today.cancelAutoShift")
            } footer: {
                Text("Vardiya hareketle kendiliğinden başladı.")
            }
        }
    }

    @ViewBuilder
    private var pendingShiftsSection: some View {
        if !autoShift.pendingShifts.isEmpty {
            Section("Biten vardiyalar") {
                ForEach(autoShift.pendingShifts) { (shift: PendingShift) in
                    pendingShiftButton(shift)
                }
            }
        }
    }

    private func pendingShiftButton(_ shift: PendingShift) -> some View {
        Button {
            openPending(shift.id)
        } label: {
            PendingShiftRow(shift: shift)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Sil", role: .destructive) { autoShift.dismissPending(id: shift.id) }
        }
        .accessibilityIdentifier("today.pendingShift")
    }

    /// Mod aciksa her izin sorunu; kapaliyken yalnizca reddedilen hareket izni gosterilir.
    @ViewBuilder
    private var autoShiftPermissionSection: some View {
        if let problem = autoShift.permissionProblem, autoShift.isEnabled || problem == .motion {
            Section {
                Button(action: openSystemSettings) {
                    Label(autoShiftProblemText(problem), systemImage: "exclamationmark.triangle")
                }
                .accessibilityIdentifier("today.autoShiftPermission")
            }
        }
    }

    private func autoShiftProblemText(_ problem: AutoShiftCoordinator.PermissionProblem) -> String {
        switch problem {
        case .motion: "Otomatik vardiya için hareket izni gerekli — Ayarlar"
        case .locationAlways: "Otomatik vardiya için konum izni “Her zaman” olmalı — Ayarlar"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Text(Formatters.longDay(day))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            addMenu
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .addEarning(let session):
            EarningFormView(session: session, defaultPlatform: defaultPlatform)
        case .pendingShift(let id, let summary):
            pendingShiftForm(id: id, summary: summary)
        case .editEarning(let record):
            EarningFormView(record: record)
        case .importedScreenshot(let imported):
            EarningFormView(defaultPlatform: defaultPlatform, imported: imported)
        case .addExpense:
            ExpenseFormView()
        case .editExpense(let record):
            ExpenseFormView(record: record)
        case .scanResults(let viewModel):
            ScanResultsView(viewModel: viewModel)
        }
    }

    /// Yayin eklentisinin biraktigi yakalama varsa "Taramada bulunanlar" sayfasini acar.
    private func openScanResultsIfPending() {
        guard activeSheet == nil, !captureStore.pending().isEmpty else { return }
        let log: BroadcastLog? = BroadcastLog.load()
        // Yayin suruyorsa dosyalar yazilmaya devam eder: sonuc sayfasi acilmaz
        if UIScreen.main.isCaptured { return }
        let unfinished: Bool = log != nil && log?.finishedAt == nil
        let lastFrame: Date = log?.lastFrameAt ?? .distantPast
        if unfinished, Date.now.timeIntervalSince(lastFrame) < 10 { return }
        let interrupted: Bool = unfinished
        let viewModel = ScanResultsViewModel(
            store: captureStore, templates: sync.mergedTemplates(),
            knownTextHashes: queuedAndKnownHashes, interrupted: interrupted
        )
        activeSheet = .scanResults(viewModel)
    }

    private func pendingShiftForm(id: UUID, summary: WorkSessionSummary) -> some View {
        let coordinator: AutoShiftCoordinator = autoShift
        return EarningFormView(
            session: summary,
            defaultPlatform: defaultPlatform,
            onSaved: { coordinator.dismissPending(id: id) }
        )
    }

    private var knownIDs: Set<String> {
        Set(evidences.compactMap(\.assetIdentifier))
    }

    /// Kayitli kanitlarin metin ozetleri (bos ozet eslesme sayilmaz).
    private var knownHashes: Set<String> {
        let hashes: [String] = evidences.map(\.textHash).filter { !$0.isEmpty }
        return Set(hashes)
    }

    /// Sirada bekleyen ve su an formda acik ekran goruntulerinin metin ozetleri.
    private var pendingHashes: Set<String> {
        var hashes: [String] = inboxQueue.map(\.textHash)
        if let presentedHash { hashes.append(presentedHash) }
        return Set(hashes.filter { !$0.isEmpty })
    }

    /// Kayitli + bekleyen + acik ekran goruntulerinin metin ozetleri.
    private var queuedAndKnownHashes: Set<String> {
        knownHashes.union(pendingHashes)
    }

    private func platformName(_ code: String?) -> String {
        Platform.defaults.first { $0.code == code }?.name ?? "Platform"
    }

    private func heroSection(_ summary: EarningsSummary) -> some View {
        let goal: GoalProgress = weekGoal
        let dayGoal = GoalProgress(target: dailyGoal, achieved: summary.netEarnings)
        return Section {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HeroAmount(title: "Net kazanç", value: summary.netEarnings, identifier: "dashboard.netEarnings")
                    NetBreakdownLine(gross: summary.totalEarnings, expenses: summary.totalExpenses)
                }
                if goal.isSet {
                    weekGoalRing(goal)
                }
            }
            MetricStrip(metricItems(summary))
            if summary.usesEstimatedExpenses {
                Text("Yakıt ve bakım km başına tahmini: \(Formatters.currency(summary.estimatedExpenses))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if dayGoal.isSet {
                dailyGoalLine(dayGoal)
            }
        }
        .listRowSeparator(.hidden)
    }

    private func metricItems(_ summary: EarningsSummary) -> [MetricStrip.Item] {
        let perHour = MetricStrip.Item(
            title: "Net ₺/saat", value: Formatters.perHour(summary.netPerHour), identifier: "dashboard.netPerHour"
        )
        let duration = MetricStrip.Item(
            title: "Çalışma", value: Formatters.duration(summary.workDuration), identifier: "dashboard.workDuration"
        )
        let distance = MetricStrip.Item(
            title: "Mesafe", value: Formatters.distance(summary.distanceKm), identifier: "dashboard.distance"
        )
        return [perHour, duration, distance]
    }

    private func weekGoalRing(_ goal: GoalProgress) -> some View {
        VStack(spacing: 4) {
            GoalRing(progress: goal).frame(width: 56, height: 56)
            Text("Hafta %\(Int(goal.fraction * 100))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dailyGoalLine(_ progress: GoalProgress) -> some View {
        if progress.isReached {
            Label("Günlük hedefe ulaştın", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("dashboard.dailyGoal")
        } else {
            Text(dailyGoalText(progress))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityIdentifier("dashboard.dailyGoal")
        }
    }

    private func dailyGoalText(_ progress: GoalProgress) -> String {
        let target = Formatters.currency(progress.target)
        let remaining = Formatters.currency(progress.remaining)
        return "Günlük hedef: \(target) · kalan \(remaining)"
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
                        presentedHash = imported.textHash
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

    /// Ice aktarma sirasinda ilerleme; sonrasinda okunamayan / tekrar eden gorsel bildirimleri.
    @ViewBuilder
    private var noticesSection: some View {
        if isImportingPicked || !notices.isEmpty {
            Section {
                if isImportingPicked {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Ekran görüntüleri okunuyor…")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(notices, id: \.self) { notice in
                    Label(notice, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                if !notices.isEmpty {
                    Button("Tamam") { notices.removeAll() }
                        .accessibilityIdentifier("today.dismissNotices")
                }
            }
        }
    }

    /// Otomatik tarama kapaliysa davet satiri; fotograf izni kapatildiysa Ayarlar'a yonlendirme.
    @ViewBuilder
    private var scanSection: some View {
        if scanner.isPermissionMissing {
            Section {
                Button(action: openSystemSettings) {
                    Label("Fotoğraf izni kapalı — Ayarlar'dan aç", systemImage: "exclamationmark.triangle")
                }
                .accessibilityIdentifier("today.photoPermission")
            }
        } else if !scanner.isEnabled {
            Section {
                Button(action: enableScan) {
                    Label("Ekran görüntülerini otomatik bul", systemImage: "text.viewfinder")
                }
                .accessibilityIdentifier("today.enableScan")
            } footer: {
                Text("Son 48 saatin kazanç ekranları öneri olarak gösterilir. Görüntüler cihazında işlenir.")
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("Ekran görüntüsü", systemImage: "text.viewfinder") {
                showScreenshotPicker = true
            }
            // Onceki secim okunurken ikinci bir toplu okuma baslamasin
            .disabled(isImportingPicked)
            Button("Elle kazanç", systemImage: "square.and.pencil") {
                activeSheet = .addEarning(session: nil)
            }
            Button("Gider", systemImage: "fuelpump") { activeSheet = .addExpense }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Ekle")
        .accessibilityIdentifier("dashboard.addMenu")
    }

    private func shiftPanel(_ summary: EarningsSummary) -> some View {
        VStack(spacing: 8) {
            Button(workSession.isWorking ? "Vardiyayı bitir" : "Vardiyayı başlat", action: toggleWork)
                .buttonStyle(PrimaryActionButtonStyle(isDestructive: workSession.isWorking))
                .accessibilityIdentifier("dashboard.workToggle")
            if workSession.isWorking, let start = workSession.sessionStart {
                TimelineView(.periodic(from: start, by: 30)) { context in
                    Text(shiftStatus(elapsed: context.date.timeIntervalSince(start), summary: summary))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("dashboard.shiftStatus")
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

    /// Gelen kutusunu isler, sonra otomatik taramayi calistirir.
    private func refreshImports() async {
        await processInbox()
        openScanResultsIfPending()
        await scanner.scan(knownIdentifiers: knownIDs, knownTextHashes: queuedAndKnownHashes)
    }

    private func enableScan() {
        Task {
            if await scanner.enable() {
                await scanner.scan(knownIdentifiers: knownIDs, knownTextHashes: queuedAndKnownHashes)
            }
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    /// Paylas eklentisinin biraktigi gorselleri okur, siler ve sirayla forma aktarir.
    private func processInbox() async {
        // .task ve scenePhase ayni anda tetikleyebilir: tek calisma
        guard !isProcessingInbox else { return }
        isProcessingInbox = true
        defer { isProcessingInbox = false }
        let importer = ScreenshotImporter(templates: sync.mergedTemplates())
        // Kayitli bir ekranla ayni metin yine forma gelir (form "daha once kaydedilmis" uyarir);
        // yalnizca ayni anda bekleyen kopyalar elenir.
        var batch = ImportBatch(seenHashes: pendingHashes, seenAssets: knownIDs)
        for pending in inbox.pending() {
            guard let url = inbox.claim(pending) else { continue }
            defer { inbox.remove(url) }
            var result: ImportedScreenshot?
            if let data = try? Data(contentsOf: url) {
                result = try? await importer.importImage(data: data, assetIdentifier: nil)
            }
            batch.add(result)
        }
        finish(batch)
    }

    /// Coklu secimle gelen ekran goruntulerini okur ve siraya ekler.
    private func importPicked(_ items: [PhotosPickerItem]) async {
        isImportingPicked = true
        defer { isImportingPicked = false }
        let importer = ScreenshotImporter(templates: sync.mergedTemplates())
        var batch = ImportBatch(seenHashes: pendingHashes, seenAssets: knownIDs)
        for item in items {
            let identifier: String? = item.itemIdentifier
            if let identifier, batch.seenAssets.contains(identifier) {
                batch.duplicates += 1
                continue
            }
            let capturedAt: Date? = PhotoAssetInfo.creationDate(localIdentifier: identifier)
            var result: ImportedScreenshot?
            if let data = try? await item.loadTransferable(type: Data.self) {
                result = try? await importer.importImage(
                    data: data, assetIdentifier: identifier, capturedAt: capturedAt
                )
            }
            batch.add(result)
        }
        finish(batch)
    }

    /// Kabul edilenleri siraya ekler, bildirimleri gosterir; form acik degilse ilkini acar.
    private func finish(_ batch: ImportBatch) {
        inboxQueue.append(contentsOf: batch.accepted)
        let newNotices: [String] = TodayViewModel.importNotices(
            failures: batch.failures, duplicates: batch.duplicates
        )
        for notice in newNotices where !notices.contains(notice) {
            notices.append(notice)
        }
        if activeSheet == nil {
            showNextFromInbox()
        }
    }

    private func showNextFromInbox() {
        guard !inboxQueue.isEmpty else { return }
        let next = inboxQueue.removeFirst()
        presentedHash = next.textHash
        activeSheet = .importedScreenshot(next)
    }

    private func sheetDismissed() {
        presentedHash = nil
        // Bildirimden gelen bekleyen vardiya istegi once; sonra siradaki ekran goruntusu
        openRequestedPending()
        if activeSheet == nil {
            showNextFromInbox()
        }
        openScanResultsIfPending()
    }

    private func shiftStatus(elapsed: TimeInterval, summary: EarningsSummary) -> String {
        let isLocationAvailable = workSession.location.isAuthorized || !workSession.location.isEnabled
        var parts: [String] = [Formatters.duration(elapsed)]
        if isLocationAvailable {
            parts.append(Formatters.distance(workSession.sessionDistanceKm))
        } else {
            parts.append("mesafe ölçülmüyor")
        }
        let estimate: Double? = TodayViewModel.liveNetPerHour(
            todayNet: summary.netEarnings, workedSeconds: summary.workDuration, elapsed: elapsed
        )
        if let estimate {
            parts.append("~\(Formatters.currency(estimate.rounded()))/saat tahmini")
        }
        return parts.joined(separator: " · ")
    }

    private func toggleWork() {
        Haptics.impact()
        if workSession.isWorking {
            // Vardiya bitince kazanc formu sure + mesafe + bolgeyle on doldurulmus acilir
            if let summary = autoShift.endShift() {
                activeSheet = .addEarning(session: summary)
            }
        } else {
            autoShift.startManualShift()
        }
    }

    /// Bekleyen vardiya listeden silinmeden acilir; kazanc kaydedilince (onSaved) duser.
    private func openPending(_ id: UUID) {
        if let summary = autoShift.pendingSummary(id: id) {
            activeSheet = .pendingShift(id: id, summary: summary)
        }
    }

    /// Bildirimden gelen istek bir kez tuketilir (soguk acilista onAppear, sonra onChange).
    /// Acik bir form varsa degistirilmez: istek form kapaninca (sheetDismissed) islenir.
    private func openRequestedPending() {
        guard activeSheet == nil, let id = autoShift.requestedPendingID else { return }
        autoShift.requestedPendingID = nil
        openPending(id)
    }

    private func delete(_ model: some PersistentModel) {
        if let record = model as? EarningRecord {
            let id: UUID = record.id
            try? modelContext.deleteEarning(record)
            // Silinen kaydin bekleyen gonderimi de dusulur
            sync.recordDeleted(id: id)
            return
        }
        modelContext.delete(model)
        try? modelContext.save()
    }
}

/// Toplu ice aktarmada sayaclar ve tekrar kontrolu (kayitli + ayni partide gorulenler).
private struct ImportBatch {
    var seenHashes: Set<String>
    var seenAssets: Set<String>
    var failures = 0
    var duplicates = 0
    var accepted: [ImportedScreenshot] = []

    /// nil veya metinsiz sonuc = okunamadi.
    mutating func add(_ result: ImportedScreenshot?) {
        guard let result, !result.lines.isEmpty else {
            failures += 1
            return
        }
        let hash: String = result.textHash
        if !hash.isEmpty, seenHashes.contains(hash) {
            duplicates += 1
            return
        }
        if !hash.isEmpty {
            seenHashes.insert(hash)
        }
        if let identifier = result.assetIdentifier {
            seenAssets.insert(identifier)
        }
        accepted.append(result)
    }
}

private struct PendingShiftRow: View {
    let shift: PendingShift

    private var detail: String {
        let range: String = "\(Formatters.time(shift.start))–\(Formatters.time(shift.end))"
        var parts: [String] = [range, Formatters.distance(shift.distanceKm)]
        if let district = shift.district { parts.append(district) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Kazancını ekle")
                .font(.body.weight(.semibold))
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Örnek veri") {
    // Koordinator, gorunumle ayni vardiya yoneticisini kullanmali: ortak nesne grafigi
    let environment = AppEnvironment.shared
    return TodayView()
        .modelContainer(SampleData.previewContainer)
        .environment(environment.location)
        .environment(environment.workSession)
        .environment(environment.scanner)
        .environment(environment.autoShift)
        .environment(environment.sync)
        .environment(environment.account)
}
