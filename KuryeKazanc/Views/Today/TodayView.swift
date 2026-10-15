import SwiftUI
import SwiftData
import TipKit

/// Bugun sekmesi: net kazanc, saatlik net, vardiya, gunluk hedef + plan, elle hesap, gunun ipucu ve kayitlar.
/// 1.10: ekran goruntusu taramasi ve sag ustteki + menusu (elle kazanc / gider) kaldirildi; yerine "Elle hesapla".
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkSessionManager.self) private var workSession
    @Environment(AutoShiftCoordinator.self) private var autoShift
    @Environment(SyncCoordinator.self) private var sync
    @Environment(\.openURL) private var openURL
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro
    @Environment(LiveShiftController.self) private var liveShift
    @Environment(LocationService.self) private var location

    @Query private var todaysEarnings: [EarningRecord]
    @Query private var todaysExpenses: [ExpenseRecord]
    @Query private var couriers: [Courier]
    /// Hedef ilerlemesi icin tum kazanc kayitlari.
    @Query private var allEarnings: [EarningRecord]
    /// Donem temposu (gun dokumu) icin tum giderler.
    @Query private var allExpenses: [ExpenseRecord]

    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm
    @AppStorage(AppPreferences.autoEstimateExpensesKey) private var autoEstimate = true
    @AppStorage(AppPreferences.hasSeenShiftTutorialKey) private var hasSeenShiftTutorial = false

    /// Canli vardiya ekrani, ilk kullanim tanitimi ve konum kapali uyarisi.
    @State private var showsLiveShift = false
    @State private var showsShiftTutorial = false
    @State private var showsLocationAlert = false
    @State private var showsShiftReplay = false

    @State private var activeSheet: Sheet?
    /// 1.11: ust karta dokununca tam ekran gun dokumu.
    @State private var showsBreakdown = false
    @State private var showsHelp = false

    private let manualTip = ManualCalcTip()
    private let shiftTip = ShiftTip()

    private let day: Date

    enum Sheet: Identifiable {
        case addEarning(session: WorkSessionSummary?)
        /// Biten otomatik vardiya: kazanc kaydedilince bekleyenlerden duser.
        case pendingShift(id: UUID, summary: WorkSessionSummary)
        case editEarning(EarningRecord)
        case editExpense(ExpenseRecord)

        var id: String {
            switch self {
            case .addEarning: "addEarning"
            case .pendingShift(let id, _): "pending-\(id)"
            case .editEarning(let record): "editEarning-\(record.id)"
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
    /// 1.12: govdede bir kez hesaplanir ve asagi aktarilir (eskiden her cizimde 5-6 kez tum kayitlar islenirdi).
    private func computeDailyProgress(entries: [EarningEntry]) -> DailyGoalProgress? {
        guard case let .success(plan)? = payroll.goalPlan(entries: entries, fallbackCostPerKm: costPerKm),
              let code = payroll.tariffProfile?.platformCode else { return nil }
        var progress = DailyGoalProgress.today(plan: plan, entries: entries, platform: code, day: payroll.today,
                                               fuel: payroll.fuelModel(fallbackCostPerKm: costPerKm), calendar: .current, now: .now)
        progress.packages += liveShift.packagesToday
        if liveShift.isActive, let live = liveShift.liveEstimate() { progress.net = progress.net + live.gross }
        progress.net = progress.net + fixedShareToday
        // Sabit ucret haric tutuluyorsa gunluk hedef de sabit ucretin gunluk payi kadar azalir (yalnizca paket + bonus)
        if !payroll.includesFixedPay {
            let share: Money = payroll.fixedShareRowsToday(ignoringPreference: true).map(\.perDay).sum()
            progress.targetNet = Money(max(0, (progress.targetNet - share).value))
        }
        return progress
    }

    /// Aylik sabit ucretin bugune dusen payi (Paket Taxi gibi): bugun calisildiysa bir kez eklenir.
    private var fixedShareToday: Money {
        guard !todaysEarnings.isEmpty || liveShift.isActive else { return .zero }
        return payroll.fixedShareToday()
    }

    /// Suren vardiyanin su ana kadarki brutu (ust kart ve dokum bunu da gosterir).
    private var liveGross: Double {
        guard liveShift.isActive, let live = liveShift.liveEstimate() else { return 0 }
        return live.gross.doubleValue
    }

    var body: some View {
        let summary: EarningsSummary = TodayViewModel.summary(
            earnings: todaysEarnings,
            expenses: todaysExpenses,
            costPerKm: effectiveCostPerKm,
            autoEstimate: autoEstimate
        )

        let entries: [EarningEntry] = allEarnings.map(\.entry)
        let progress: DailyGoalProgress? = computeDailyProgress(entries: entries)

        NavigationStack {
            todayList(summary, progress: progress)
                .listStyle(.insetGrouped)
                .navigationTitle("Bugün")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showsHelp) { ScreenHelpSheet(screen: .today) }
                .sheet(item: $activeSheet, onDismiss: openRequestedPending) { sheet in
                    sheetContent(sheet)
                }
                // "Vardiya bitti" bildirimine dokunuldu: bekleyen vardiyanin kazanc formu acilir
                .onAppear(perform: openRequestedPending)
                .onChange(of: autoShift.requestedPendingID) { _, _ in
                    openRequestedPending()
                }
                .onChange(of: progress?.fraction ?? 0) { _, fraction in
                    // Gunluk hedefe ulasildiginda (gunde bir kez) kutlama bildirimi
                    if fraction >= 1 { ReminderScheduler.shared.goalReached(day: payroll.today) }
                }
                // 1.12: her paket / kayitta "hedefe su kadar kaldi" hatirlatmalari guncel ilerlemeyle yeniden kurulur
                .task(id: nudgeSignature(progress)) { scheduleGoalNudges(summary: summary, progress: progress, entries: entries) }
                // 1.12: widget'taki bugunku paket, net, hedef ve bolge
                .task(id: widgetSignature(summary, progress: progress)) { publishWidget(summary, progress: progress) }
                .fullScreenCover(isPresented: $showsLiveShift) { LiveShiftView() }
                // 1.12: widget'taki "Vardiya" dugmesi
                .onChange(of: liveShift.presentationRequested, initial: true) { _, requested in
                    guard requested else { return }
                    liveShift.presentationRequested = false
                    if liveShift.isActive { showsLiveShift = true }
                }
                .fullScreenCover(isPresented: $showsBreakdown) {
                    TodayBreakdownView(content: breakdownContent(summary, progress: progress)) { showsBreakdown = false }
                }
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

    private func todayList(_ summary: EarningsSummary, progress: DailyGoalProgress?) -> some View {
        List {
            autoShiftSections
            heroSection(summary)
            if workSession.isWorking, !liveShift.isActive {
                Section {
                    shiftPanel(summary)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            shiftStartSection
            Section {
                TodayGoalCard(progress: progress, hasGoal: payroll.goal != nil)
            }
            // 1.12.2: bugun / bu hafta / bu ay toplam paket ve prim kademesi
            BonusTrackSection(tracks: payroll.bonusTracks(live: liveShift.packagesByDay()))
            manualCalcSection
            fuelReminderSection
            DailyHintSection(firmCode: payroll.tariffProfile?.platformCode, progress: progress)
            earningsSection
            if !todaysExpenses.isEmpty {
                expensesSection
            }
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
        ToolbarItem(placement: .topBarTrailing) {
            Text(Formatters.longDay(day))
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    private func heroSection(_ summary: EarningsSummary) -> some View {
        // Kartin tamami dokununca dokumu acar; icindeki metinler (testler ve VoiceOver) ayri kalsin diye Button degil
        Section {
            heroCard(summary)
                .contentShape(Rectangle())
                .onTapGesture(perform: openBreakdown)
                .accessibilityAction(named: "Bugünün dökümünü aç", openBreakdown)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func heroCard(_ summary: EarningsSummary) -> some View {
        let extra: Double = fixedShareToday.doubleValue + liveGross
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(PayrollModel.platformName(payroll.tariffProfile?.platformCode ?? ""), systemImage: "building.2.fill")
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
                HeroAmount(title: "Bugün cebine kalan", value: summary.netEarnings + extra,
                           identifier: "dashboard.netEarnings")
                NetBreakdownLine(gross: summary.totalEarnings + extra, expenses: summary.totalExpenses)
                if fixedShareToday.value > 0 {
                    Text("Sabit ücretin bugüne düşen payı dahil: \(PayFormat.tl(fixedShareToday))")
                        .font(.footnote)
                        .opacity(0.8)
                        .accessibilityIdentifier("dashboard.fixedShare")
                }
            }
            MetricStrip(metricItems(summary, extraNet: fixedShareToday.doubleValue))
                .padding(12)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button(action: openBreakdown) {
                HStack {
                    Label("Kalem kalem döküm ve hedefe göre durum", systemImage: "list.bullet.rectangle.portrait")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today.breakdown")
        }
        .brandCard()
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 4)
    }

    // MARK: - Gun dokumu

    private func openBreakdown() {
        Haptics.selection()
        showsBreakdown = true
    }

    private func breakdownContent(_ summary: EarningsSummary, progress: DailyGoalProgress?) -> TodayBreakdownView.Content {
        let recordIDs: Set<UUID> = Set(todaysEarnings.map(\.id))
        let todayLogs: [WorkLog] = payroll.logs.filter { log in
            guard log.isDaily, log.startDay == payroll.today, let id = log.earningRecordID else { return false }
            return recordIDs.contains(id)
        }
        let linked: Set<UUID> = Set(todayLogs.compactMap(\.earningRecordID))
        let logInputs: [(detail: PayDetail, recordTotal: Money?)] = todayLogs.map { log in
            let record: EarningRecord? = todaysEarnings.first { $0.id == log.earningRecordID }
            let total: Money? = record.map { Money(Money.round(Decimal($0.grossEarning + $0.bonus))) }
            return (PayDetailBuilder.make(breakdown: log.result, days: 1), total)
        }
        let unlinked: Double = todaysEarnings.filter { !linked.contains($0.id) }.map { $0.grossEarning + $0.bonus }.reduce(0, +)
        let worked: Bool = !todaysEarnings.isEmpty || liveShift.isActive
        let breakdown = DayBreakdown.make(logs: logInputs, unlinkedRecords: Money(Money.round(Decimal(unlinked))),
                                          liveShift: Money(Money.round(Decimal(liveGross))),
                                          fixedShare: worked ? payroll.fixedShareRowsToday() : [])
        let manual: [(label: String, amount: Double)] = todaysExpenses.map { ($0.type.displayName, $0.amount) }
        let net: Double = summary.netEarnings + fixedShareToday.doubleValue + liveGross
        let packages: Int = todaysEarnings.compactMap(\.packageCount).reduce(0, +) + liveShift.packageCount
        return TodayBreakdownView.Content(
            breakdown: breakdown, packages: packages, workDuration: summary.workDuration, distanceKm: summary.distanceKm,
            fuelEstimate: summary.estimatedExpenses, manualExpenses: manual, net: net,
            dailyTarget: progress?.targetNet, pace: goalPace(todayNet: net), goal: payroll.goal
        )
    }

    private var savedPackagesToday: Int { todaysEarnings.compactMap(\.packageCount).reduce(0, +) }

    private func widgetSignature(_ summary: EarningsSummary, progress: DailyGoalProgress?) -> String {
        "\(payroll.today)|\(savedPackagesToday)|\(summary.netEarnings.isFinite ? Int(summary.netEarnings) : 0)|\(progress?.targetPackages ?? 0)|\(payroll.state.regionTier ?? "")"
    }

    private func publishWidget(_ summary: EarningsSummary, progress: DailyGoalProgress?) {
        let day: String = WidgetSnapshot.dayKey(.now)
        let saved: Int = savedPackagesToday
        let net: Double = summary.netEarnings + fixedShareToday.doubleValue
        let target: Int = progress?.targetPackages ?? 0
        let place: String? = todaysEarnings.last(where: { $0.district != nil })?.district
        let region: String = WidgetPublisher.regionText(place: liveShift.shift?.district ?? place, tier: payroll.state.regionTier)
        let firm: String = payroll.tariffProfile.map { PayrollModel.platformName($0.platformCode) } ?? ""
        WidgetPublisher.publish { snapshot in
            snapshot.day = day
            snapshot.savedPackages = saved
            snapshot.todayNet = net
            snapshot.targetPackages = target
            snapshot.region = region
            snapshot.firm = firm
        }
    }

    /// Hatirlatmalari yeniden kurmayi gerektiren degerler.
    private func nudgeSignature(_ progress: DailyGoalProgress?) -> String {
        guard let progress, let goal = payroll.goal else { return "none" }
        return "\(payroll.today)|\(progress.packages)|\(progress.targetPackages)|\(progress.net.value)|\(goal.amount.value)|\(goal.period.rawValue)"
    }

    private func scheduleGoalNudges(summary: EarningsSummary, progress: DailyGoalProgress?, entries: [EarningEntry]) {
        guard let goal = payroll.goal, let progress else {
            ReminderScheduler.shared.scheduleGoalNudges([])
            return
        }
        let calendar: Calendar = .current
        let now: Date = .now
        let rate: Decimal = payroll.pace(entries: entries).packagesPerHour
        var nudges: [GoalNudge] = GoalNudgePlanner.today(progress: progress, packagesPerHour: rate, now: now, calendar: calendar,
                                                         isWorkDay: GoalNudgePlanner.isWorkDay(goal: goal, now: now, calendar: calendar))
        let todayNet: Double = summary.netEarnings + fixedShareToday.doubleValue + liveGross
        let perPackage: Decimal = progress.targetPackages > 0 ? progress.targetNet.value / Decimal(progress.targetPackages) : 0
        if let period = GoalNudgePlanner.period(pace: goalPace(todayNet: todayNet), netPerPackage: perPackage,
                                                daysLeft: GoalNudgePlanner.remainingWorkDays(goal: goal, now: now, calendar: calendar),
                                                now: now, calendar: calendar) {
            nudges.append(period)
        }
        ReminderScheduler.shared.scheduleGoalNudges(nudges)
    }

    /// Hedef doneminde calisilan gunlerin netleri (gecmis gunlere sabit ucret payi eklenir; bugun ust karttaki net).
    private func goalPace(todayNet: Double) -> GoalPace? {
        guard let goal = payroll.goal else { return nil }
        let todayMoney = Money(Money.round(Decimal(todayNet)))
        guard goal.period != .day else { return GoalPace.project(goal: goal, dailyNets: [todayMoney]) }
        let range: (start: String, end: String) = goal.period == .week
            ? payroll.weekRange(containing: .now)
            : payroll.monthRange(containing: .now)
        let calculator = EarningsCalculator(costPerKm: effectiveCostPerKm, autoEstimateEnabled: autoEstimate)
        let earnings: [(day: Date, entry: EarningEntry)] = allEarnings.compactMap { record in
            let key: String = payroll.day(record.date)
            guard key >= range.start, key < payroll.today else { return nil }
            return (record.date, record.entry)
        }
        let expenses: [(day: Date, entry: ExpenseEntry)] = allExpenses.compactMap { record in
            let key: String = payroll.day(record.date)
            guard key >= range.start, key < payroll.today else { return nil }
            return (record.date, record.entry)
        }
        let share: Double = payroll.fixedShareToday().doubleValue
        let days: [EarningsSummary] = Array(calculator.summarizeByDay(earnings: earnings, expenses: expenses).values)
        let past: [Money] = days.filter { $0.totalEarnings > 0 }
            .map { Money(Money.round(Decimal($0.netEarnings + share))) }
        return GoalPace.project(goal: goal, dailyNets: past + [todayMoney])
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
            } footer: {
                Text("Net kazanç güncel yakıt fiyatıyla hesaplanır.")
            }
        }
    }

    /// Saat basi, ustteki "cebine kalan" ile ayni neti (sabit ucret payi dahil) kullanir; yarim saatten kisa surede "—".
    private func metricItems(_ summary: EarningsSummary, extraNet: Double) -> [MetricStrip.Item] {
        let perHour = MetricStrip.Item(
            title: "Saatlik net", value: Formatters.perHour(summary.netPerHour(adding: extraNet)),
            identifier: "dashboard.netPerHour"
        )
        let duration = MetricStrip.Item(
            title: "Çalışma süresi", value: Formatters.duration(summary.workDuration), identifier: "dashboard.workDuration"
        )
        let distance = MetricStrip.Item(
            title: "Mesafe", value: Formatters.distance(summary.distanceKm), identifier: "dashboard.distance"
        )
        return [perHour, duration, distance]
    }

    /// Yalnizca otomatik vardiya surerken: sure/mesafe ve "Vardiyayi bitir" (baslatma dugmesi 1.7'de kaldirildi).
    private func shiftPanel(_ summary: EarningsSummary) -> some View {
        VStack(spacing: 8) {
            if let start = workSession.sessionStart {
                TimelineView(.everyMinute) { context in
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
        Section {
            if todaysEarnings.isEmpty {
                Text("Henüz kayıt yok. Vardiya başlat ya da “Elle hesapla” ile ekle.")
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
        } header: {
            Text("Bugünün kayıtları")
        } footer: {
            if !todaysEarnings.isEmpty {
                Text("Düzeltmek için kayda dokun, silmek için sola kaydır.")
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

    // MARK: - Elle hesap

    /// Vardiyayi baslatmayi unuttugu gunler icin hakedis hesabi; sonuc bugune eklensin mi diye sorulur.
    private var manualCalcSection: some View {
        Section {
            TipView(manualTip, arrowEdge: .bottom)
            NavigationLink {
                ManualCalcView()
                    .onAppear { manualTip.invalidate(reason: .actionPerformed) }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Elle hesapla")
                            .font(.headline)
                        Text("Paket, km ve saatten hakedişini hesapla")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityIdentifier("today.manualCalc")
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
                    TipView(shiftTip, arrowEdge: .bottom)
                    Button(action: requestStart) {
                        Label("Vardiya başlat", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("today.startShift")
                    if hasSeenShiftTutorial {
                        Button("Nasıl çalışır? Tanıtımı izle") { showsShiftReplay = true }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("today.shiftTutorial")
                    } else {
                        Text("Her paketi bırakınca ekrana dokun; saat, km ve ücret kendiliğinden hesaplanır.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
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
        shiftTip.invalidate(reason: .actionPerformed)
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

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
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
    /// Acik bir form varsa degistirilmez: istek form kapaninca islenir.
    private func openRequestedPending() {
        guard activeSheet == nil, let id = autoShift.requestedPendingID else { return }
        autoShift.requestedPendingID = nil
        openPending(id)
    }

    private func delete(_ model: some PersistentModel) {
        if let record = model as? EarningRecord {
            let id: UUID = record.id
            // 1.12.1: bagli hakedis kaydi da silinir, gunun diger vardiyalari yeniden paylastirilir
            if !payroll.deleteLog(linkedTo: id, context: modelContext) {
                try? modelContext.deleteEarning(record)
            }
            // Silinen kaydin bekleyen gonderimi de dusulur
            sync.recordDeleted(id: id)
            return
        }
        modelContext.delete(model)
        try? modelContext.save()
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
        .environment(environment.autoShift)
        .environment(environment.sync)
        .environment(environment.account)
}
