import SwiftUI

/// Yayin eklentisinin olcumleri (yalnizca TestFlight/DEBUG).
struct ScanLogView: View {
    @State private var log = BroadcastLog.load()
    var body: some View {
        List {
            if let log {
                LabeledContent("Başlangıç", value: log.startedAt.formatted())
                LabeledContent("Bitiş", value: log.finishedAt?.formatted() ?? "sürüyor / yarıda kaldı")
                LabeledContent("İşlenen kare", value: "\(log.processed)")
                LabeledContent("Tanınmayan", value: "\(log.unrecognized)")
                LabeledContent("Tekrar", value: "\(log.duplicates)")
                LabeledContent("Onaylanmayan", value: "\(log.unconfirmed)")
                LabeledContent("Kabul edilen", value: "\(log.accepted)")
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
