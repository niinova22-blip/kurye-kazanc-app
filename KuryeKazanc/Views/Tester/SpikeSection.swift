import SwiftUI
import ReplayKit

/// DENEME (yalnizca TestFlight/DEBUG): yayin baslat, taklit ekranlar, tarama gunlugu.
struct SpikeSection: View {
    var body: some View {
        Section("Deneme: kazanç taraması") {
            BroadcastPickerButton()
                .frame(height: 44)
            NavigationLink("Deneme ekranları") { MockScreensPager() }
            NavigationLink("Tarama günlüğü") { BroadcastLogView() }
        }
    }
}

private struct BroadcastPickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = "com.kuryekazanc.app.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

private struct MockScreensPager: View {
    private let scenarios = ScenarioGenerator().all().filter { $0.textStyle == .turkish && !$0.splitRows }
    var body: some View {
        TabView {
            ForEach(scenarios) { scenario in
                MockEarningsScreen(scenario: scenario)
            }
        }
        .tabViewStyle(.page)
        .ignoresSafeArea()
    }
}

private struct BroadcastLogView: View {
    @State private var log = BroadcastLog.load()
    var body: some View {
        List {
            if let log {
                LabeledContent("Başlangıç", value: log.startedAt.formatted())
                LabeledContent("Bitiş", value: log.finishedAt?.formatted() ?? "sürüyor / yarıda kaldı")
                LabeledContent("İşlenen kare", value: "\(log.processed)")
                LabeledContent("Tanınmayan", value: "\(log.unrecognized)")
                LabeledContent("Tekrar", value: "\(log.duplicates)")
                LabeledContent("Yakalanan", value: "\(log.captured.count)")
                LabeledContent("En yüksek bellek", value: String(format: "%.1f MB", log.peakMemoryMB))
                LabeledContent("En uzun okuma", value: String(format: "%.2f sn", log.maxOCRSeconds))
                LabeledContent("Ortalama okuma", value: String(format: "%.2f sn", log.processed == 0 ? 0 : log.totalOCRSeconds / Double(log.processed)))
                Section("Yakalanan şablonlar") {
                    ForEach(Array(log.captured.enumerated()), id: \.offset) { _, id in Text(id) }
                }
            } else {
                Text("Henüz tarama yapılmadı.")
            }
        }
        .refreshable { log = BroadcastLog.load() }
        .navigationTitle("Tarama günlüğü")
    }
}
