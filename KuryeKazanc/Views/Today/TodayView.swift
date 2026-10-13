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
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro
    @Environment(LiveShiftController.self) private var liveShift
    @Environment(LocationService.self) private var location

    @Query private var todaysEarnings: [EarningRecord]
    @Query private var todaysExpenses: [ExpenseRecord]
    @Query private var couriers: [Courier]
    /// Tekrar tarama kontrolu icin tum kazanc kayitlari.
    @Query private var allEarnings: [EarningRecord]
    /// Kaydedilmis ekran goruntuleri (kimlik + metin ozeti) tekrar onerilmez / siraya alinmaz.
    @Query private var evidences: [ScreenshotEvidence]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @AppStorage(AppPreferences.hasSeenShiftTutorialKey) private var hasSeenShiftTutorial = false

    /// Canli vardiya ekrani, ilk kullanim tanitimi ve konum kapali uyarisi.
    @State private var showsLiveShift = false
    @State private var showsShiftTutorial = false
    @State private var showsLocationAlert = false
    @State private var showsShiftReplay = false

    @State private var activeSheet: Sheet?
    @State private var showsHelp = false
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

    private let day: Date

    enum Sheet: Identifiable {
        case addEarning(session: WorkSessionSummary?)
        /// Biten otomatik vardiya: kazanc kaydedilince bekleyenlerden duser.
        case pendingShift(id: UUID, summary: WorkSessionSummary)
        case editEarning(EarningRecord)
        case importedScreenshot(ImportedScreenshot)
        case addExpense
        case editExpense(ExpenseRecord)

        var id: String {
            switch self {
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
    }

    /// Kazanc formunda onceden secili platform: profildeki ilk platform.
    private var defaultPlatform: Platform? {
        couriers.first?.defaultPlatforms.sorted { $0.sortOrder < $1.sortOrder }.first
    }

    /// 1.7: km basi gider yakit fiyatindan (km × tuketim × fiyat); fiyat girilmemisse eski km basi maliyet.
    private var effectiveCostPerKm: Double {
        payroll.fuelModel(fallbackCostPerKm: costPerKm).costPerKm(on: payroll.today).doubleValue
    }

    /// Bugunku hedef: kayitli kazanclar + suren vardiyanin paketleri (her dokunusta dolar) + sabit ucretin gunluk payi.
    private var dailyProgress: DailyGoalProgress? {
        let entries: [EarningEntry] = allEarnings.map(\.entry)
        guard case let .success(plan)? = payroll.goalPlan(entries: entries, fallbackCostPerKm: costPerKm),
              let code = payroll.tariffProfile?.platformCode else { return nil }
        var progress = DailyGoalProgress.today(plan: plan, entries: entries, platform: code, day: payroll.today,
                                               fuel: payroll.fuelModel(fallbackCostPerKm: costPerKm), calendar: .current, now: .now)
        progress.packages += liveShift.packageCount
        if liveShift.isActive, let live = liveShift.liveEstimate() { progress.net = progress.net + live.gross }
        progress.net = progress.net + fixedShareToday
        return progress
    }

    /// Aylik sabit ucretin bugune dusen payi (Paket Taxi gibi): bugun calisildiysa bir kez eklenir.
    private var fixedShareToday: Money {
        guard !todaysEarnings.isEmpty || liveShift.isActive, let version = payroll.currentVersion() else { return .zero }
        let rows: [PayDetailRow] = PayDetailBuilder.fixedShares(version: version, day: payroll.today,
                                                                regionTier: payroll.state.regionTier, days: 1,
                                                                monthWorkDays: payroll.goal?.monthWorkDays ?? 26)
        return rows.map(\.perDay).sum()
    }

    var body: some View {
        let summary: EarningsSummary = TodayViewModel.summary(
            earnings: todaysEarnings,
            expenses: todaysExpenses,
            costPerKm: effectiveCostPerKm,
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
                .sheet(isPresented: $showsHelp) { ScreenHelpSheet(screen: .today) }
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
                // Yayin (broadcast) ile otomatik sonuc acilisi kaldirildi: tarama fotograflardan (ScanGuideView)
                // "Vardiya bitti" bildirimine dokunuldu: bekleyen vardiyanin kazanc formu acilir
                .onAppear(perform: openRequestedPending)
                .onChange(of: autoShift.requestedPendingID) { _, _ in
                    openRequestedPending()
                }
                .fullScreenCover(isPresented: $showsLiveShift) { LiveShiftView() }
                .fullScreenCover(isPresented: $showsShiftTutorial) {
                    ShiftTutorialView(mode: .firstRun) {
                        hasSeenShiftTutorial = true
                        showsShiftTutorial = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(450))
                            beginShift()
                        }
                    }
                }
                .alert("Konum izni kapalı", isPresented: $showsLocationAlert) {
                    Button("Ayarlar'ı aç") { openSystemSettings() }
                    Button("Konumsuz başlat") { startLiveShift() }
                    Button("Vazgeç", role: .cancel) {}
                } message: {
                    Text("Konum olmadan km, yakıt ve mesafe ek ödemesi (bant) hesaplanamaz; yalnızca paket ve saat sayılır.")
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
            shiftStartSection
            Section {
                TodayGoalCard(progress: dailyProgress, hasGoal: payroll.goal != nil)
            }
            fuelReminderSection

            if workSession.isWorking, !liveShift.isActive {
                Section {
                    shiftPanel(summary)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

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
        HelpBubble(screen: .today, showsScreenHelp: $showsHelp, showIntro: showIntro)
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
        }
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
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(PayrollModel.platformName(payroll.tariffProfile?.platformCode ?? ""), systemImage: "sun.max.fill")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    if workSession.isWorking || liveShift.isActive {
                        Label("Vardiyada", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.positive.opacity(0.35), in: Capsule())
                            .symbolEffect(.pulse)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HeroAmount(title: "Bugün cebine kalan", value: summary.netEarnings + fixedShareToday.doubleValue,
                               identifier: "dashboard.netEarnings")
                    NetBreakdownLine(gross: summary.totalEarnings + fixedShareToday.doubleValue, expenses: summary.totalExpenses)
                    if fixedShareToday.value > 0 {
                        Text("Sabit ücretin bugüne düşen payı dahil: \(PayFormat.tl(fixedShareToday))")
                            .font(.footnote)
                            .opacity(0.8)
                            .accessibilityIdentifier("dashboard.fixedShare")
                    }
                }
                MetricStrip(metricItems(summary))
                    .padding(12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if summary.usesEstimatedExpenses {
                    Text("Yakıt (km × tüketim × fiyat): \(Formatters.currency(summary.estimatedExpenses))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .brandCard()
            .environment(\.colorScheme, .dark)
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// Yakit fiyati 7 gunden eskiyse (ya da hic girilmediyse) guncelleme satiri.
    @ViewBuilder
    private var fuelReminderSection: some View {
        if payroll.fuelModel(fallbackCostPerKm: costPerKm).isStale(today: payroll.today) {
            Section {
                NavigationLink {
                    FuelSettingsView()
                } label: {
                    Label("Yakıt fiyatını güncelle", systemImage: "fuelpump")
                }
                .accessibilityIdentifier("today.fuelReminder")
            }
        }
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

    /// Yalnizca otomatik vardiya surerken: sure/mesafe ve "Vardiyayi bitir" (baslatma dugmesi 1.7'de kaldirildi).
    private func shiftPanel(_ summary: EarningsSummary) -> some View {
        VStack(spacing: 8) {
            if let start = workSession.sessionStart {
                TimelineView(.periodic(from: start, by: 30)) { context in
                    Text(shiftStatus(elapsed: context.date.timeIntervalSince(start), summary: summary))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("dashboard.shiftStatus")
                }
            }
            Button("Vardiyayı bitir", action: endShift)
                .buttonStyle(PrimaryActionButtonStyle(isDestructive: true))
                .accessibilityIdentifier("dashboard.endShift")
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

    // MARK: - Canli vardiya

    /// "Vardiya başlat" ya da suren vardiyanin karti (dokununca vardiya ekrani).
    private var shiftStartSection: some View {
        Section {
            if liveShift.isActive {
                Button { showsLiveShift = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .symbolEffect(.pulse)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vardiya sürüyor · \(liveShift.packageCount) paket")
                                .font(.headline)
                            Text("Paket bırakınca dokunmak için aç")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today.liveShift")
            } else {
                VStack(spacing: 8) {
                    Button(action: requestStart) {
                        Label("Vardiya başlat", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("today.startShift")
                    Text("Her paketi bırakınca ekrana dokun; saat, km ve ücret kendiliğinden hesaplanır.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if hasSeenShiftTutorial {
                        Button("Nasıl çalışır? Tanıtımı izle") { showsShiftReplay = true }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("today.shiftTutorial")
                    }
                }
                .fullScreenCover(isPresented: $showsShiftReplay) {
                    ShiftTutorialView(mode: .replay) { showsShiftReplay = false }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
        }
    }

    /// Ilk kullanimda once tanitim filmi; sonra konum kontrolu ve baslatma.
    private func requestStart() {
        Haptics.impact()
        if !hasSeenShiftTutorial {
            showsShiftTutorial = true
        } else {
            beginShift()
        }
    }

    private func beginShift() {
        switch location.authorizationStatus {
        case .denied, .restricted:
            showsLocationAlert = true
        default:
            startLiveShift()
        }
    }

    private func startLiveShift() {
        liveShift.start()
        showsLiveShift = true
    }

    // MARK: - Eylemler

    /// Gelen kutusunu isler, sonra otomatik taramayi calistirir.
    private func refreshImports() async {
        await processInbox()
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

    private func endShift() {
        Haptics.impact()
        // Vardiya bitince kazanc formu sure + mesafe + bolgeyle on doldurulmus acilir
        if let summary = autoShift.endShift() {
            activeSheet = .addEarning(session: summary)
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
