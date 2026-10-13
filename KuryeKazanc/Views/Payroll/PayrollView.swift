import SwiftUI
import SwiftData

/// Dort platform karti. Secim uygulama genelinde tektir; eski kayitlar kendi platformlarinda kalir.
struct PlatformPickerView: View {
    @Environment(PayrollModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var isFirstRun: Bool = false

    var body: some View {
        List {
            Section {
                ForEach(PayPlatform.all) { platform in
                    Button {
                        model.select(platform: platform.code)
                        if !isFirstRun { dismiss() }
                    } label: {
                        PlatformCard(platform: platform, isSelected: model.state.activePlatform == platform.code)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("platform.\(platform.code)")
                }
            } header: {
                Text("Çalıştığın platform")
            } footer: {
                Text("Hakediş bu platformun tarifesiyle hesaplanır. Platform değiştirirsen eski kayıtların kendi platformu ve tarife sürümüyle kalır. Platform adları yalnızca tanımlama içindir; resmî ortaklık yoktur.")
            }
        }
        .navigationTitle(isFirstRun ? "Hakediş" : "Platform seç")
        .navigationBarTitleDisplayMode(isFirstRun ? .large : .inline)
    }
}

private struct PlatformCard: View {
    let platform: PayPlatform
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PlatformMonogram(platform: platform)
            VStack(alignment: .leading, spacing: 4) {
                Text(platform.name).font(.headline)
                Text(platform.modelSummary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                .font(.title3)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Aylik hakedis panosu: ortak kartlar, platforma ozgu kart, dort hesaplama yontemi, son kayitlar.
struct PayrollDashboardView: View {
    @Environment(PayrollModel.self) private var model
    @Query(sort: \ExpenseRecord.date, order: .reverse) private var expenseRecords: [ExpenseRecord]

    /// Sayfa altindaki tek not: aktif tarifenin dogrulanmamis kalemleri.
    private var unverifiedItems: [UnverifiedItem] {
        guard let version = model.currentVersion() else { return [] }
        return UnverifiedItems.from(version: version, platformName: PayrollModel.platformName(version.platformCode))
    }

    var body: some View {
        let expenses: [DatedExpense] = expenseRecords.map(\.datedExpense)
        let dashboard: PayrollDashboard? = model.dashboard(expenses: expenses)
        List {
            if let platform = model.activePlatform {
                PlatformHeaderSection(platform: platform)
            }
            LiveShiftBanner()
            if let dashboard {
                DashboardCardsSection(dashboard: dashboard)
                PlatformSpecificSection(dashboard: dashboard)
            }
            RecentLogsSection()
            MethodsSection()
            MoreSection()
            VerificationFootnote(items: unverifiedItems)
        }
        .refreshable {
            await model.tariffs.refreshIfNeeded(force: true)
            await model.refreshNotices()
        }
    }
}

private struct PlatformHeaderSection: View {
    @Environment(PayrollModel.self) private var model
    let platform: PayPlatform

    var body: some View {
        Section {
            HStack(spacing: 12) {
                PlatformMonogram(platform: platform)
                VStack(alignment: .leading, spacing: 2) {
                    Text(platform.name).font(.headline).accessibilityIdentifier("payroll.platformName")
                    if let version = model.currentVersion() {
                        Text("Tarife \(version.label) · yürürlük \(PayFormat.day(version.effectiveFrom))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Yayında tarife yok").font(.caption).foregroundStyle(Theme.negative)
                    }
                }
            }
        } footer: {
            Text("Firmanı Profil > Çalıştığım firma'dan değiştirebilirsin.")
        }
    }
}

private struct DashboardCardsSection: View {
    let dashboard: PayrollDashboard

    private let columns: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 10) {
                PayMetricTile(title: "Bu ay tahmini brüt", value: PayFormat.tl(dashboard.estimatedGross),
                              caption: nil, identifier: "dashboard.monthGross")
                PayMetricTile(title: "Tahmini net", value: PayFormat.tl(dashboard.estimatedNet), caption: "Brüt − gider",
                              identifier: "dashboard.monthNet")
                PayMetricTile(title: "Paket", value: "\(dashboard.packages)", identifier: "dashboard.packages")
                PayMetricTile(title: "Bonusa kalan", value: bonusValue, caption: dashboard.nextBonus?.label,
                              identifier: "dashboard.bonusRemaining")
                PayMetricTile(title: "Saat başına", value: dashboard.grossPerHour.map { PayFormat.tl($0) } ?? "—",
                              caption: dashboard.netPerHour.map { "Net \(PayFormat.tl($0))" }, identifier: "dashboard.perHour")
                PayMetricTile(title: "Toplam gider", value: PayFormat.tl(dashboard.expenses), identifier: "dashboard.expenses")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)
            if let difference = dashboard.paymentDifference {
                LabeledContent("Ödeme farkı (gerçekleşen − beklenen)", value: PayFormat.tl(difference))
                    .font(.subheadline)
            }
        } header: {
            Text("Bu ay")
        }
    }

    private var bonusValue: String {
        guard let next = dashboard.nextBonus else { return "—" }
        return "\(next.remaining) paket"
    }
}

/// Yalnizca secili platforma ozgu kart.
private struct PlatformSpecificSection: View {
    @Environment(PayrollModel.self) private var model
    let dashboard: PayrollDashboard

    var body: some View {
        Section(title) {
            switch model.state.activePlatform {
            case "trendyol_go":
                trendyolRows
            case "getir":
                LabeledContent("Araç tipi", value: (model.state.vehicleType ?? "motorcycle") == "car" ? "Araçlı" : "Motorlu")
                LabeledContent("Bu ay km", value: Formatters.distance(dashboard.period.km.doubleValue))
                weeklyProgress
            case "yemeksepeti":
                LabeledContent("Saatlik garanti", value: guaranteeStatus)
                weeklyProgress
            case "migros_hemen":
                LabeledContent("Bölge kademesi", value: regionName)
                LabeledContent("Aylık paket", value: "\(dashboard.packages)")
                monthlyProgress
            default:
                EmptyView()
            }
        }
    }

    private var title: String {
        switch model.state.activePlatform {
        case "trendyol_go": "Gündüz / gece ve günlük bonus"
        case "getir": "Araç, km ve hafta sonu bonusu"
        case "yemeksepeti": "Garanti ve haftalık bonus"
        case "migros_hemen": "Aylık kademe ve sabit ücret"
        default: "Platform"
        }
    }

    @ViewBuilder private var trendyolRows: some View {
        let todayLogs: [WorkLog] = model.logs(platform: "trendyol_go").filter { $0.startDay == model.today && $0.isDaily }
        let day: Int = todayLogs.map(\.input.dayPackages).reduce(0, +)
        let night: Int = todayLogs.map(\.input.nightPackages).reduce(0, +)
        LabeledContent("Bugün gündüz / gece", value: "\(day) / \(night) paket")
        ForEach(Array(dashboard.period.progress.filter { $0.unit == .day }.enumerated()), id: \.offset) { _, progress in
            BonusProgressRow(progress: progress)
        }
    }

    @ViewBuilder private var weeklyProgress: some View {
        let items: [BonusProgress] = dashboard.period.progress.filter { $0.unit == .week }
        if items.isEmpty {
            Text("Bu hafta için bonus kademesi yok ya da hedefe ulaşıldı.").font(.caption).foregroundStyle(.secondary)
        }
        ForEach(Array(items.enumerated()), id: \.offset) { _, progress in
            BonusProgressRow(progress: progress)
        }
    }

    @ViewBuilder private var monthlyProgress: some View {
        ForEach(Array(dashboard.period.progress.filter { $0.unit == .month }.enumerated()), id: \.offset) { _, progress in
            BonusProgressRow(progress: progress)
        }
    }

    private var guaranteeStatus: String {
        guard let item = model.currentVersion()?.items.first(where: { $0.method == .guaranteeTopUp }) else { return "Tarifede yok" }
        return "\(PayFormat.tl(item.amount))/sa"
    }

    private var regionName: String {
        switch model.state.regionTier {
        case "plus": "İstanbul / Ankara Plus"
        case "standard": "Standart bölge"
        default: "Seçilmedi"
        }
    }
}

/// Suren vardiya: Kazanc'tan da vardiya ekranina donulur.
private struct LiveShiftBanner: View {
    @Environment(LiveShiftController.self) private var liveShift
    @State private var showsShift = false

    var body: some View {
        if liveShift.isActive {
            Section {
                Button { showsShift = true } label: {
                    Label("Vardiya sürüyor · \(liveShift.packageCount) paket — aç", systemImage: "hand.tap.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("payroll.liveShift")
            } footer: {
                Text("Vardiyayı bitirince hesap kendiliğinden buraya eklenir.")
            }
            .fullScreenCover(isPresented: $showsShift) { LiveShiftView() }
        }
    }
}

private struct MethodsSection: View {
    var body: some View {
        Section {
            NavigationLink { ManualCalcView() } label: {
                Label("Elle hesapla", systemImage: "square.and.pencil")
            }
            .accessibilityIdentifier("payroll.manual")
            NavigationLink { PeriodSummaryView() } label: {
                Label("Hafta / ay özeti", systemImage: "calendar")
            }
            .accessibilityIdentifier("payroll.period")
            NavigationLink { PaymentCheckView() } label: {
                Label("Ödeme karşılaştırma", systemImage: "checkmark.rectangle.stack")
            }
            .accessibilityIdentifier("payroll.payment")
        } header: {
            Text("Hesapla")
        } footer: {
            Text("Vardiya başlatmayı unuttuysan paket, km ve süreyi elle gir; günlük, haftalık ya da aylık hesaplanır.")
        }
    }
}

private struct RecentLogsSection: View {
    @Environment(PayrollModel.self) private var model

    var body: some View {
        let code: String = model.state.activePlatform ?? ""
        let recent: [WorkLog] = Array(model.logs(platform: code).prefix(5))
        Section("Vardiyalar ve kayıtlar") {
            if recent.isEmpty {
                Text("Henüz kayıt yok. Bugün ekranından vardiya başlat; bitirince hesap buraya kendiliğinden düşer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(recent) { log in
                NavigationLink { WorkLogDetailView(logID: log.id) } label: {
                    WorkLogRow(log: log)
                }
            }
        }
    }
}

struct WorkLogRow: View {
    let log: WorkLog

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.isDaily ? PayFormat.day(log.startDay) : "\(PayFormat.day(log.startDay)) – \(PayFormat.day(log.endDay))")
                    .font(.subheadline)
                Text("\(log.method.displayName) · \(log.input.periodPackages ?? log.input.totalPackages) paket · \(log.result.tariffVersionLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(PayFormat.tl(log.gross))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("payroll.logRow")
    }
}

private struct MoreSection: View {
    @Environment(PayrollModel.self) private var model

    var body: some View {
        Section {
            NavigationLink { PayrollHistoryView() } label: {
                Label("Geçmiş ve platform karşılaştırma", systemImage: "clock.arrow.circlepath")
            }
            NavigationLink { TariffNoticesView() } label: {
                HStack {
                    Label("Tarife bildirimleri", systemImage: "bell")
                    Spacer()
                    if model.unreadNoticeCount > 0 {
                        Text("\(model.unreadNoticeCount)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.negative, in: Capsule())
                    }
                }
            }
            NavigationLink { SideBenefitsView() } label: {
                Label("Yan haklar ve destekler", systemImage: "gift")
            }
            NavigationLink { ExpenseReportView() } label: {
                Label("Gider ve net kazanç raporu", systemImage: "chart.bar.doc.horizontal")
            }
        }
    }
}
