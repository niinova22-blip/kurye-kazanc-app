import SwiftUI
import SwiftData

/// Firmalar: ayni isi diger firmalarda yapsan (yeni baslayan kademesiyle) ne kazanirdin. Ucret yalnizca tarifeden.
/// Kurye ayni anda tek firmada calisir; bu ekran tarifeler degisince fikrini gozden gecirmesi icindir.
struct FirmsView: View {
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.showIntro) private var showIntro
    @Query(sort: \EarningRecord.startTime, order: .reverse) private var records: [EarningRecord]
    @AppStorage(AppPreferences.costPerKmKey) private var costPerKm = AppPreferences.defaultCostPerKm

    @State private var packagesPerDay = 30
    @State private var hoursPerDay = 8
    @State private var kmPerPackage: Decimal = Decimal(string: "3.5")!
    @State private var days = 26
    @State private var loaded = false
    @State private var showsHelp = false

    private var workload: WorkloadSpec {
        WorkloadSpec(packagesPerDay: packagesPerDay, hoursPerDay: Decimal(hoursPerDay), kmPerPackage: kmPerPackage,
                     daysPerMonth: days)
    }

    var body: some View {
        let rows: [FirmComparisonRow] = payroll.comparison(workload: workload, fallbackCostPerKm: costPerKm)
        NavigationStack {
            List {
                switchBanner
                workloadSection
                FirmRowsSection(rows: rows, costPerKm: costPerKm)
                fuelSection
                VerificationFootnote(items: unverified(rows))
            }
            .navigationTitle("Firmalar")
            .toolbar { HelpBubble(screen: .firms, showsScreenHelp: $showsHelp, showIntro: showIntro) }
            .sheet(isPresented: $showsHelp) { ScreenHelpSheet(screen: .firms) }
            .onAppear(perform: loadDefaults)
        }
    }

    private func unverified(_ rows: [FirmComparisonRow]) -> [UnverifiedItem] {
        UnverifiedItems.merge(rows.map {
            UnverifiedItems.from($0.breakdown, platformName: PayrollModel.platformName($0.platformCode))
        })
    }

    @ViewBuilder private var switchBanner: some View {
        if let suggestion = payroll.pendingSwitchSuggestion(workload: workload, fallbackCostPerKm: costPerKm) {
            Section {
                Label("Güncel tarifelerle bu işi \(PayrollModel.platformName(suggestion.platformCode))'de yapsan ayda +\(PayFormat.tl(suggestion.extraNet)) net.",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                Button("Anladım") {
                    withAnimation { payroll.markSwitchSeen(suggestion) }
                }
            }
            .accessibilityIdentifier("firms.switchBanner")
        }
    }

    private var workloadSection: some View {
        Section {
            CountStepper(title: "Günde paket", value: $packagesPerDay, range: 1...120, identifier: "firms.packages")
            CountStepper(title: "Günde saat", value: $hoursPerDay, range: 1...16, identifier: "firms.hours")
            DecimalStepper(title: "Paket başı km", value: $kmPerPackage, range: Decimal(string: "0.5")!...20,
                           step: Decimal(string: "0.5")!, identifier: "firms.km")
            CountStepper(title: "Ayda gün", value: $days, range: 1...31, identifier: "firms.days")
        } header: {
            Text("Aynı iş")
        } footer: {
            Text("Diğer firmalar yeni başlayan kademesiyle hesaplanır; geçersen bu kademeden başlarsın. Ücretler yalnızca firmaların tarifelerinden gelir.")
        }
    }

    @ViewBuilder private var fuelSection: some View {
        let fuel: FuelCostModel = payroll.fuelModel(fallbackCostPerKm: costPerKm)
        Section("Yakıt") {
            if let price = fuel.price(on: payroll.today) {
                LabeledContent("Fiyat", value: "\(PayFormat.tl(price.pricePerUnit))/\(price.type.unitName) · \(PayFormat.day(price.day))")
            } else {
                Text("Yakıt fiyatı girilmedi; km başı tahmini maliyet kullanılıyor.")
                    .foregroundStyle(.secondary)
            }
            NavigationLink("Yakıt fiyatını güncelle") { FuelSettingsView() }
        }
    }

    private func loadDefaults() {
        guard !loaded else { return }
        loaded = true
        let base = WorkloadSpec.from(pace: payroll.pace(entries: records.map(\.entry)), goal: payroll.goal)
        packagesPerDay = max(1, base.packagesPerDay)
        hoursPerDay = max(1, NSDecimalNumber(decimal: base.hoursPerDay).intValue)
        kmPerPackage = base.kmPerPackage
        days = base.daysPerMonth
    }
}

private struct FirmRowsSection: View {
    @Environment(PayrollModel.self) private var payroll
    let rows: [FirmComparisonRow]
    let costPerKm: Double

    var body: some View {
        Section("Aylık net (yakıt düşülmüş)") {
            if rows.isEmpty {
                Text("Önce Profil > Çalıştığım firma'dan firmanı seç.").foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                NavigationLink {
                    FirmDetailView(row: row,
                                   version: payroll.catalog.versions.first { $0.id == row.versionID },
                                   correlation: payroll.correlation(platform: row.platformCode, fallbackCostPerKm: costPerKm))
                } label: {
                    FirmRowLabel(row: row)
                }
                .accessibilityIdentifier("firms.row.\(row.platformCode)")
            }
        }
    }
}

private struct FirmRowLabel: View {
    let row: FirmComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(PayrollModel.platformName(row.platformCode)).font(.headline)
                if row.isCurrent {
                    Text("Şu anki firman")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                }
                Spacer()
                Text(PayFormat.tl(row.net))
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
            }
            HStack {
                Text(detailText)
                Spacer()
                if let difference = row.differenceFromCurrent {
                    Text((difference.value >= 0 ? "+" : "") + PayFormat.tl(difference))
                        .foregroundStyle(difference.value >= 0 ? Theme.accent : Theme.negative)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .animation(.snappy, value: row.net)
    }

    private var detailText: String {
        var parts: [String] = ["Tarife \(row.versionLabel)"]
        if !row.effectiveFrom.isEmpty { parts.append("yürürlük \(PayFormat.day(row.effectiveFrom))") }
        parts += row.assumptions
        return parts.joined(separator: " · ")
    }
}
