import SwiftUI
import SwiftData

/// Gelismis: kurye icin teknik ekranlar (platform kurallari ve kaynaklari, tarife surumleri, kendi tarifem, ayarlar).
struct AdvancedView: View {
    var body: some View {
        List {
            Section {
                NavigationLink { TariffInfoView() } label: {
                    Label("Tarife, kaynak ve kendi tarifem", systemImage: "doc.text.magnifyingglass")
                }
                NavigationLink { PayrollSettingsView() } label: {
                    Label("Hakediş ayarları", systemImage: "slider.horizontal.3")
                }
                NavigationLink { AdvancedRulesView() } label: {
                    Label("Platform kuralları ve kaynakları", systemImage: "list.bullet.rectangle")
                }
            } footer: {
                Text("Tarifeler resmî kaynaklardan takip edilir; değişiklikler onaydan geçmeden yayımlanmaz.")
            }
        }
        .navigationTitle("Gelişmiş")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Planlama motorunun platform kurallari (kaynak, durum, kullanici onayi).
private struct AdvancedRulesView: View {
    @Environment(SyncCoordinator.self) private var sync
    @Query(sort: \EarningRecord.startTime, order: .reverse) private var records: [EarningRecord]
    @State private var model: PlannerViewModel?

    var body: some View {
        Group {
            if let model {
                PlatformRulesView(model: model)
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let entries: [EarningEntry] = records.map(\.entry)
            model = PlannerViewModel(rules: sync.ruleSet(), entries: entries)
        }
    }
}
