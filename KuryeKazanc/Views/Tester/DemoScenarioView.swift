import SwiftUI
import SwiftData

/// Test araclari > Test senaryolari: hazir veriyi telefondaki veritabanina yukler / siler.
struct DemoScenarioView: View {
    @Environment(PayrollModel.self) private var payroll
    @Environment(\.modelContext) private var context
    @State private var pending: DemoScenario?
    @State private var message: String?

    private var loader: DemoScenarioLoader { DemoScenarioLoader(payroll: payroll, context: context) }

    var body: some View {
        List {
            Section {
                ForEach(DemoScenarioCatalog.all) { scenario in
                    Button {
                        if loader.hasRealData { pending = scenario } else { load(scenario) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.title).font(.headline).foregroundStyle(.primary)
                            Text(scenario.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("demo.\(scenario.id)")
                }
            } footer: {
                Text("Senaryo verisi gerçek kayıtlarına eklenir; \"Senaryoyu sil\" yalnızca senaryo kayıtlarını siler ve ayarlarını senaryo öncesine döndürür. Senaryo tarifeleri örnektir.")
            }
            Section {
                Button("Senaryoyu sil", role: .destructive) {
                    loader.clear()
                    message = "Senaryo kayıtları silindi."
                }
                .disabled(payroll.state.demoLogIDs.isEmpty && payroll.state.userTariffs.allSatisfy { !$0.id.hasPrefix("demo-") })
                .accessibilityIdentifier("demo.clear")
                NavigationLink("Veritabanını görüntüle") { DatabaseInspectorView() }
                    .accessibilityIdentifier("demo.database")
            }
            if let message {
                Section {
                    Text(message).accessibilityIdentifier("demo.message")
                }
            }
        }
        .navigationTitle("Test senaryoları")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Gerçek kayıtların var. Senaryo verisi bunlara eklenecek.",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible) {
            Button("Yine de yükle") {
                if let pending { load(pending) }
            }
        }
    }

    private func load(_ scenario: DemoScenario) {
        loader.load(scenario)
        Haptics.success()
        message = "\(scenario.title) yüklendi: \(payroll.state.demoLogIDs.count) kayıt."
    }
}
