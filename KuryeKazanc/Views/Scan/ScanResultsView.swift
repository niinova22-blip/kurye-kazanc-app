import SwiftUI
import SwiftData

/// "Taramada bulunanlar": yayın eklentisinin yakaladığı kazanç ekranları; seçilenler kaydedilir.
struct ScanResultsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncCoordinator.self) private var sync
    @Environment(AccountService.self) private var account

    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @Query private var couriers: [Courier]

    @State private var viewModel: ScanResultsViewModel
    @State private var saveError: String?

    init(viewModel: ScanResultsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.interrupted {
                    Text("Tarama beklenmedik şekilde durdu; bulunanlar aşağıda.")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                rowsContent
                estimateFootnote
                if let saveError {
                    Text(saveError).foregroundStyle(.red)
                }
            }
            .navigationTitle("Taramada bulunanlar")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { actionBar }
            .onAppear { viewModel.loadIfNeeded() }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var rowsContent: some View {
        if viewModel.rows.isEmpty {
            Text("Kazanç ekranı bulunamadı — platform uygulamasında kazanç panelini açtığından emin ol.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(viewModel.rows) { row in
                rowView(row)
            }
        }
    }

    @ViewBuilder
    private var estimateFootnote: some View {
        if !viewModel.rows.isEmpty {
            Text("Ekranda çalışma süresi yoksa saatler tahminidir (4 sa); kaydı açıp düzenleyebilirsin. Bu kayıtlar topluluğa gönderilmez.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button("Kaydet (\(viewModel.selectedCount))", action: save)
                .buttonStyle(PrimaryActionButtonStyle(isDestructive: false))
                .disabled(viewModel.selectedCount == 0)
                .accessibilityIdentifier("scan.results.save")
            Button("Vazgeç", action: discard)
                .accessibilityIdentifier("scan.results.discard")
        }
        .padding()
        .background(.bar)
    }

    private func rowView(_ row: ScanResultsViewModel.Row) -> some View {
        let id: String = row.id
        let binding = Binding<Bool>(
            get: { row.isSelected },
            set: { viewModel.setSelected($0, for: id) }
        )
        return Toggle(isOn: binding) {
            rowLabel(row)
        }
        .disabled(row.isAlreadySaved)
        .opacity(row.isAlreadySaved ? 0.5 : 1)
    }

    private func rowLabel(_ row: ScanResultsViewModel.Row) -> some View {
        let item: ScanItem = row.item
        let detail: String = "\(Formatters.longDay(item.parsed.date)) · \(Formatters.currency(item.parsed.totalEarning))"
        return VStack(alignment: .leading, spacing: 2) {
            Text(platformName(item))
                .font(.body.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(kindText(item.kind))
                .font(.caption)
                .foregroundStyle(.secondary)
            if row.isAlreadySaved {
                Text("Zaten kayıtlı")
                    .font(.caption.weight(.semibold))
            } else if row.hasSameDayRecord {
                Text("Bu gün için kayıt var")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func platformName(_ item: ScanItem) -> String {
        let code: String? = item.parsed.platformCode
        if let name = Platform.defaults.first(where: { $0.code == code })?.name {
            return name
        }
        return item.parsed.templateID ?? "Platform"
    }

    private func kindText(_ kind: ScanItem.Kind) -> String {
        switch kind {
        case .daily: "Günlük"
        case .weekly: "Haftalık özet — vardiya değil"
        case .orderGroup(let count): "\(count) sipariş"
        case .unknown: "Belirsiz"
        }
    }

    private func save() {
        do {
            let saved: [EarningRecord] = try viewModel.save(in: modelContext, platforms: platforms)
            afterSave(saved)
            if let message = failureMessage() {
                saveError = message
            } else {
                dismiss()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func failureMessage() -> String? {
        let skipped: Int = viewModel.skippedCount
        let failed: Int = viewModel.failedCount
        guard skipped + failed > 0 else { return nil }
        let reason: String = viewModel.firstSkipReason ?? "kayıt sırasında hata oluştu"
        return "\(skipped + failed) kalem kaydedilemedi: \(reason). Eksiği giderip tekrar dene ya da Vazgeç."
    }

    private func discard() {
        viewModel.discard()
        dismiss()
    }

    /// Form kaydı sonrasıyla aynı: eşitleme kuyruğu, gönderim ve 24 saatlik yedek.
    private func afterSave(_ records: [EarningRecord]) {
        let vehicle: String = (couriers.first?.vehicleType ?? .motorcycle).rawValue
        let sendable: Set<UUID> = viewModel.sendableRecordIDs
        for record in records where sendable.contains(record.id) {
            sync.recordSaved(record, vehicle: vehicle)
        }
        let coordinator: SyncCoordinator = sync
        let service: AccountService = account
        let context: ModelContext = modelContext
        Task { await coordinator.flush() }
        Task { await service.backupIfDue(context: context) }
    }
}
