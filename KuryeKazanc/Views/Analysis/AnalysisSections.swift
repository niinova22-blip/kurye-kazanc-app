import SwiftUI
import Charts

private let weekdayNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
private let weekdayLongNames = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]

struct BestSlotsSection: View {
    let slots: [RankedSlot]

    var body: some View {
        Section {
            ForEach(slots, id: \.slot) { item in
                BestSlotRow(item: item)
            }
        } header: {
            Text("En kârlı saatlerin")
        } footer: {
            Text("Son 8 hafta, en az 1 saat çalıştığın dilimler. Tahmini net: km başı maliyet düşülür.")
        }
    }
}

/// Tek dilim satiri; erisilebilirlik yazi boyutlarinda alt alta dizilir.
private struct BestSlotRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: RankedSlot

    private var title: String {
        let day: String = weekdayLongNames[item.slot.weekday - 1]
        let nextHour: Int = (item.slot.hour + 1) % 24
        let hours: String = String(format: "%02d:00–%02d:00", item.slot.hour, nextHour)
        return day + " " + hours
    }

    private var value: String {
        Formatters.perHour(item.stat.netPerHour)
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                Text(verbatim: value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack {
                Text(verbatim: title)
                Spacer()
                Text(verbatim: value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct HeatmapSection: View {
    let map: [HourSlot: SlotStat]

    /// Eksen isaretleri; alan -0.5...23.5 oldugundan ilk ve son hucre tam gorunur.
    private static let hourMarks: [Double] = [0, 6, 12, 18, 23]

    private var cells: [RankedSlot] {
        map.filter { $0.value.netPerHour != nil }.map { RankedSlot(slot: $0.key, stat: $0.value) }
    }

    var body: some View {
        Section {
            heatmapChart
                .frame(height: 220)
                .padding(.vertical, 8)
                .accessibilityLabel("Gün ve saate göre net kazanç ısı haritası")
        } header: {
            Text("Ne zaman çalışmalı")
        } footer: {
            Text("Koyu hücre = saat başı daha yüksek net. Son 8 hafta.")
        }
    }

    private var heatmapChart: some View {
        Chart(cells, id: \.slot) { cell in
            RectangleMark(
                xStart: .value("Saat başı", Double(cell.slot.hour) - 0.45),
                xEnd: .value("Saat sonu", Double(cell.slot.hour) + 0.45),
                y: .value("Gün", weekdayNames[cell.slot.weekday - 1]),
                height: .ratio(0.9)
            )
            .foregroundStyle(by: .value("Net ₺/sa", cell.stat.netPerHour ?? 0))
        }
        .chartForegroundStyleScale(range: Gradient(colors: [Theme.accent.opacity(0.15), Theme.accent]))
        .chartYScale(domain: weekdayNames)
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: Self.hourMarks) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(verbatim: String(Int(hour)))
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }
}

struct PlatformComparisonSection: View {
    let stats: [PlatformStat]
    /// platformCode -> gorunen ad
    let names: [String: String]

    var body: some View {
        Section("Platform karşılaştırması") {
            ForEach(stats) { stat in
                PlatformStatRow(stat: stat, name: names[stat.platformCode] ?? "Diğer")
            }
        }
    }
}

/// Platform satiri; erisilebilirlik yazi boyutlarinda ad ve toplam alt alta dizilir.
private struct PlatformStatRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let stat: PlatformStat
    let name: String

    private var detail: String {
        let perHour: String = Formatters.perHour(stat.netPerHour)
        let perPackage: String = stat.netPerPackage.map { Formatters.currency($0) + "/sipariş" } ?? "—/sipariş"
        let perKm: String = stat.netPerKm.map { Formatters.currency($0) + "/km" } ?? "—/km"
        return [perHour, perPackage, perKm].joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("analysis.platform.\(stat.platformCode)")
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).font(.body.weight(.semibold))
                Text(verbatim: Formatters.currency(stat.total)).monospacedDigit()
            }
        } else {
            HStack {
                Text(verbatim: name).font(.body.weight(.semibold))
                Spacer()
                Text(verbatim: Formatters.currency(stat.total)).monospacedDigit()
            }
        }
    }
}
