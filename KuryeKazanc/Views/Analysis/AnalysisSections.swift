import SwiftUI
import Charts

private let weekdayNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
private let weekdayLongNames = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]

struct BestSlotsSection: View {
    let slots: [RankedSlot]

    var body: some View {
        Section {
            ForEach(slots, id: \.slot) { item in
                LabeledContent {
                    Text(Formatters.perHour(item.stat.netPerHour)).monospacedDigit()
                } label: {
                    Text("\(weekdayLongNames[item.slot.weekday - 1]) \(String(format: "%02d:00–%02d:00", item.slot.hour, (item.slot.hour + 1) % 24))")
                }
            }
        } header: {
            Text("En kârlı saatlerin")
        } footer: {
            Text("Son 8 hafta, en az 1 saat çalıştığın dilimler. Tahmini net: km başı maliyet düşülür.")
        }
    }
}

struct HeatmapSection: View {
    let map: [HourSlot: SlotStat]

    private var cells: [RankedSlot] {
        map.filter { $0.value.netPerHour != nil }.map { RankedSlot(slot: $0.key, stat: $0.value) }
    }

    var body: some View {
        Section {
            Chart(cells, id: \.slot) { cell in
                RectangleMark(
                    x: .value("Saat", cell.slot.hour),
                    y: .value("Gün", weekdayNames[cell.slot.weekday - 1]),
                    width: .ratio(0.9), height: .ratio(0.9)
                )
                .foregroundStyle(by: .value("Net ₺/sa", cell.stat.netPerHour ?? 0))
            }
            .chartForegroundStyleScale(range: Gradient(colors: [Theme.accent.opacity(0.15), Theme.accent]))
            .chartYScale(domain: weekdayNames)
            .chartXScale(domain: 0...23)
            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
            .chartLegend(.hidden)
            .frame(height: 220)
            .padding(.vertical, 8)
            .accessibilityLabel("Gün ve saate göre net kazanç ısı haritası")
        } header: {
            Text("Ne zaman çalışmalı")
        } footer: {
            Text("Koyu hücre = saat başı daha yüksek net. Son 8 hafta.")
        }
    }
}

struct PlatformComparisonSection: View {
    let stats: [PlatformStat]
    /// platformCode -> gorunen ad
    let names: [String: String]

    var body: some View {
        Section("Platform karşılaştırması") {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(names[stat.platformCode] ?? "Diğer").font(.body.weight(.semibold))
                        Spacer()
                        Text(Formatters.currency(stat.total)).monospacedDigit()
                    }
                    Text([
                        Formatters.perHour(stat.netPerHour),
                        stat.netPerPackage.map { Formatters.currency($0) + "/sipariş" } ?? "—/sipariş",
                        stat.netPerKm.map { Formatters.currency($0) + "/km" } ?? "—/km",
                    ].joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("analysis.platform.\(stat.platformCode)")
            }
        }
    }
}
