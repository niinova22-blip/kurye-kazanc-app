import SwiftUI
import SwiftData

/// "Plan öner": gunun en karli / dusuk riskli / az saatli plani, gerekce ve belirsizliklerle.
/// Dogrulanmamis ya da guncelligi bilinmeyen kosul varsa plan "kesin degil" gosterilir.
struct PlannerView: View {
    @Environment(SyncCoordinator.self) private var sync
    @Query(sort: \EarningRecord.startTime, order: .reverse) private var records: [EarningRecord]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @State private var model: PlannerViewModel?

    var body: some View {
        Group {
            if let model {
                PlannerContent(model: model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Plan öner")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let entries: [EarningEntry] = records.map(\.entry)
            let vm: PlannerViewModel = model ?? PlannerViewModel(rules: sync.ruleSet(), entries: entries)
            vm.update(rules: sync.ruleSet(), entries: entries, names: platformNames)
            if model == nil { model = vm }
            vm.plan()
        }
    }

    private var platformNames: [String: String] {
        var names: [String: String] = [:]
        for item in Platform.defaults { names[item.code] = item.name }
        for platform in platforms { names[platform.code] = platform.name }
        return names
    }
}

private struct PlannerContent: View {
    @Bindable var model: PlannerViewModel

    var body: some View {
        List {
            Section {
                DatePicker("Gün", selection: $model.day, displayedComponents: .date)
                    .onChange(of: model.day) { _, _ in model.plan() }
                NavigationLink {
                    WorkProfileView(model: model)
                } label: {
                    Label("Çalışma profili", systemImage: "person.text.rectangle")
                }
                NavigationLink {
                    PlatformRulesView(model: model)
                } label: {
                    Label("Platform kuralları ve kaynakları", systemImage: "doc.text.magnifyingglass")
                }
            } footer: {
                Text("Öneriler yalnızca senin kayıtlarından ve girdiğin ücretlerden hesaplanır; platform tarifesi uydurulmaz.")
            }

            if model.savedPlanIsForDay, let check = model.savedPlanCheck {
                SavedPlanSection(model: model, check: check)
            }

            if let result = model.result {
                if let message = result.message {
                    Section { Text(message).foregroundStyle(.secondary) }
                }
                ForEach(result.proposals) { proposal in
                    ProposalSection(model: model, proposal: proposal)
                }
                if !result.excluded.isEmpty {
                    Section("Plana alınmayan platformlar") {
                        ForEach(result.excluded.keys.sorted(), id: \.self) { code in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.name(code)).font(.subheadline.weight(.semibold))
                                Text(result.excluded[code] ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SavedPlanSection: View {
    let model: PlannerViewModel
    let check: PlanCheck

    var body: some View {
        Section {
            if check.rulesChanged {
                Label("Platform kuralları değişti — seçtiğin plan yeniden denetlendi.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
            if check.isConfirmed {
                Label("Seçtiğin plan kurallara uygun.", systemImage: "checkmark.seal")
                    .foregroundStyle(Color.green)
            } else {
                ForEach(Array(check.issues.enumerated()), id: \.offset) { _, issue in
                    Label(issue.message(name: model.name), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.negative)
                        .font(.subheadline)
                }
                if !check.uncertainties.isEmpty {
                    Text("\(check.uncertainties.count) koşul doğrulanmadı — plan kesin değil.")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            Button("Seçimi kaldır", role: .destructive) { model.clearSavedPlan() }
        } header: {
            Text("Seçtiğin plan")
        }
    }
}

private struct ProposalSection: View {
    let model: PlannerViewModel
    let proposal: PlanProposal

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        Section {
            statusRow
            ForEach(Array(proposal.blocks.enumerated()), id: \.offset) { _, block in
                HStack {
                    Text(timeFormatter.string(from: block.start) + "–" + timeFormatter.string(from: block.end))
                        .monospacedDigit()
                    Spacer()
                    Text(model.name(block.platformCode)).fontWeight(.semibold)
                }
            }
            EstimateRows(estimate: proposal.estimate, confidence: proposal.confidence)
            if !proposal.reasons.isEmpty {
                DisclosureGroup("Neden bu plan") {
                    ForEach(proposal.reasons, id: \.self) { Text($0).font(.caption) }
                }
            }
            ForEach(proposal.notes, id: \.self) { note in
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(proposal.issues.enumerated()), id: \.offset) { _, issue in
                Label(issue.message(name: model.name), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Theme.negative)
            }
            ForEach(proposal.uncertainties) { item in
                UncertaintyRow(model: model, item: item)
            }
            Button("Bu planı seç") { model.choose(proposal) }
                .disabled(!proposal.isValid)
        } header: {
            Text(proposal.kind.title)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if !proposal.isValid {
            Label("Kurallara aykırı", systemImage: "xmark.octagon").foregroundStyle(Theme.negative)
        } else if proposal.isConfirmed {
            Label("Kurallara uygun", systemImage: "checkmark.seal").foregroundStyle(Color.green)
        } else {
            Label("Kesin değil — koşullar doğrulanmadı", systemImage: "questionmark.diamond").foregroundStyle(.orange)
        }
    }
}

private struct EstimateRows: View {
    let estimate: PlanEstimate
    let confidence: PlanConfidence

    var body: some View {
        Group {
            row("Toplam süre", Formatters.duration(estimate.hours * 3600))
            row("Brüt (düşük–yüksek)", Formatters.currency(estimate.grossLow) + " – " + Formatters.currency(estimate.grossHigh))
            row("Brüt (orta)", Formatters.currency(estimate.grossMid))
            row("Yakıt + bakım", "−" + Formatters.currency(estimate.vehicleCost))
            if estimate.fixedCost > 0 { row("Bağ-Kur / sabit gider (günlük)", "−" + Formatters.currency(estimate.fixedCost)) }
            row("Net (vergi öncesi)", Formatters.currency(estimate.netMid))
            if estimate.taxRate > 0 { row("Vergi sonrası", Formatters.currency(estimate.afterTaxMid)) }
            row("Net/saat", Formatters.perHour(estimate.netPerHour))
            row("Mesafe", Formatters.distance(estimate.km))
            if let packages = estimate.packages { row("Teslimat (tahmini)", String(Int(packages.rounded()))) }
            row("Güven", confidence.displayName)
        }
        .font(.subheadline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}

/// Dogrulanmamis kosul: kullanici kendi sozlesmesine gore onaylar ya da reddeder.
struct UncertaintyRow: View {
    let model: PlannerViewModel
    let item: PlanUncertainty

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.name(item.platformCode) + " · " + item.category.displayName)
                .font(.caption.weight(.semibold))
            Text(item.description).font(.caption)
            Text(item.isUnknownTerm ? "Bilinmeyen koşul" : item.status.displayName)
                .font(.caption2)
                .foregroundStyle(.orange)
            if let url = item.sourceURL.flatMap(URL.init(string:)) {
                Link("Kaynak", destination: url).font(.caption2)
            }
            HStack {
                Button("Sözleşmemde var") { model.setConfirmation(.applies, ruleID: item.ruleID) }
                Button("Bende geçerli değil") { model.setConfirmation(.notApplicable, ruleID: item.ruleID) }
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}
