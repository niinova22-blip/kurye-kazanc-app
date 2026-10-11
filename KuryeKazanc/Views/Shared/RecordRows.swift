import SwiftUI

/// Kazanc ve gider liste satirlari (Bugun ve Analiz ortak).
/// Erisilebilirlik yazi boyutlarinda tutar sutunu alta gecer (yan yana sikisip kesilmesin).
struct EarningListRow: View {
    // private degil: dosya disindaki EarningListRow(record:showsDate:) cagrilari etkilenmesin
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let record: EarningRecord
    var showsDate = false

    private var subtitle: String {
        var parts: [String] = []
        if showsDate {
            parts.append(record.date.formatted(Date.FormatStyle().locale(Formatters.locale).day().month(.abbreviated).weekday(.abbreviated)))
        }
        parts.append("\(Formatters.time(record.startTime))–\(Formatters.time(record.endTime))")
        if let district = record.district { parts.append(district) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        rowLayout
            .padding(.vertical, 2)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var rowLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                infoColumn
                amountColumn(alignment: .leading)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                infoColumn
                Spacer()
                amountColumn(alignment: .trailing)
            }
        }
    }

    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(record.platform?.name ?? "Platform yok")
                .font(.body.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VerificationBadge(level: record.verification)
        }
    }

    private func amountColumn(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(Formatters.currency(record.totalEarning))
                .font(.body.weight(.semibold))
                .monospacedDigit()
            if let packages = record.packageCount, packages > 0 {
                Text("\(packages) paket").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

struct ExpenseListRow: View {
    // private degil: dosya disindaki ExpenseListRow(record:showsDate:) cagrilari etkilenmesin
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let record: ExpenseRecord
    var showsDate = false

    private var detail: String {
        let date: String? = showsDate
            ? record.date.formatted(Date.FormatStyle().locale(Formatters.locale).day().month(.abbreviated))
            : nil
        let parts: [String] = [date, record.note].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    private var amountText: String {
        "−" + Formatters.currency(record.amount)
    }

    var body: some View {
        rowLayout
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var rowLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                infoColumn
                amountLabel
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: record.type.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                infoColumn
                Spacer()
                amountLabel
            }
        }
    }

    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.type.displayName).font(.subheadline.weight(.semibold))
            if !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var amountLabel: some View {
        Text(amountText)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.negative)
    }
}

extension ExpenseType {
    var symbolName: String {
        switch self {
        case .fuel: "fuelpump"
        case .maintenance: "wrench.and.screwdriver"
        case .tire: "circle.circle"
        case .insurance: "shield"
        case .phone: "iphone"
        case .equipment: "backpack"
        case .depreciation: "chart.line.downtrend.xyaxis"
        case .other: "ellipsis.circle"
        }
    }
}
