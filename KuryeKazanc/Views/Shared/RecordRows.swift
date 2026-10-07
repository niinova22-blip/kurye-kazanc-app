import SwiftUI

/// Kazanc ve gider liste satirlari (Bugun ve Analiz ortak).
struct EarningListRow: View {
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.platform?.name ?? "Platform yok")
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VerificationBadge(level: record.verification)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Formatters.currency(record.totalEarning))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                if let packages = record.packageCount, packages > 0 {
                    Text("\(packages) paket").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct ExpenseListRow: View {
    let record: ExpenseRecord
    var showsDate = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.type.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.type.displayName).font(.subheadline.weight(.semibold))
                let detail = [
                    showsDate ? record.date.formatted(Date.FormatStyle().locale(Formatters.locale).day().month(.abbreviated)) : nil,
                    record.note,
                ].compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("−" + Formatters.currency(record.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.negative)
        }
        .contentShape(Rectangle())
    }
}

extension ExpenseType {
    var symbolName: String {
        switch self {
        case .fuel: "fuelpump"
        case .maintenance: "wrench.and.screwdriver"
        case .tire: "circle.circle"
        case .depreciation: "chart.line.downtrend.xyaxis"
        case .other: "ellipsis.circle"
        }
    }
}
