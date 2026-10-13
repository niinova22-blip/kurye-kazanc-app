import SwiftUI

/// "Ayrıntılı döküm": paketlerden, km'den, sabit ucretin gune dusen payindan, bonuslardan ayri ayri. Kapali gelir,
/// istenince acilir. Plan (aylik) icin "ayda / günde", gunluk hesap icin tek tutar gosterilir.
struct PayDetailDisclosure: View {
    let detail: PayDetail
    /// Verilirse iki sutun: donem ("Ayda", "Haftada") ve "Günde". nil: tek gunluk hesap, tek sutun.
    var periodTitle: String? = nil
    var identifier: String = "detail.disclosure"
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded.animation(.snappy)) {
            VStack(alignment: .leading, spacing: 14) {
                if let periodTitle { header(periodTitle) }
                ForEach(detail.categories) { category in
                    categoryBlock(category)
                }
                Divider()
                totalRow
                if detail.hasEstimates {
                    Label("Sabit ücret ay sonunda ödenir; burada çalıştığın güne düşen payı gösteriliyor.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Ayrıntılı döküm", systemImage: "list.bullet.rectangle.portrait")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityIdentifier(identifier)
    }

    private func header(_ title: String) -> some View {
        HStack {
            Spacer()
            Text(title).frame(width: 92, alignment: .trailing)
            Text("Günde").frame(width: 76, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func categoryBlock(_ category: PayDetailCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(category.title, systemImage: category.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(category == .side ? Color.secondary : Theme.accent)
                Spacer()
                amounts(detail.total(category), detail.totalPerDay(category), bold: true)
            }
            ForEach(detail.rows(in: category)) { row in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.label + (row.isEstimate ? " (tahmini)" : ""))
                            .font(.footnote)
                        if let quantity = row.quantityText {
                            Text(quantity).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    amounts(row.periodAmount, row.perDay, bold: false)
                }
                .padding(.leading, 26)
            }
        }
    }

    private var totalRow: some View {
        HStack {
            Text(detail.hasEstimates ? "Toplam (sabit ücret payı dahil)" : "Toplam")
                .font(.subheadline.weight(.semibold))
            Spacer()
            amounts(detail.periodTotal, detail.perDayTotal, bold: true)
        }
        .accessibilityIdentifier(identifier + ".total")
    }

    @ViewBuilder
    private func amounts(_ period: Money, _ perDay: Money, bold: Bool) -> some View {
        let font: Font = bold ? .footnote.weight(.semibold).monospacedDigit() : .footnote.monospacedDigit()
        if periodTitle != nil {
            HStack(spacing: 0) {
                Text(PayFormat.tl(period)).frame(width: 92, alignment: .trailing)
                Text(PayFormat.tl(perDay)).frame(width: 76, alignment: .trailing).foregroundStyle(.secondary)
            }
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text(PayFormat.tl(period)).font(font)
        }
    }
}
