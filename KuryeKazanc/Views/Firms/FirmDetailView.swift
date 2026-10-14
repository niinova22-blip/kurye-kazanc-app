import SwiftUI

/// Bir firmanin tarifesi: bu is icin hesap, kalemler, kampanyalar (bitis tarihli), tarife-yakit iliskisi.
struct FirmDetailView: View {
    let row: FirmComparisonRow
    let version: TariffVersion?
    let correlation: TariffFuelCorrelation?

    private var items: [TariffItem] { version?.items.filter { !$0.withdrawn } ?? [] }
    private var campaigns: [TariffItem] { items.filter { $0.effectiveUntil != nil } }
    private var regular: [TariffItem] { items.filter { $0.effectiveUntil == nil } }

    var body: some View {
        List {
            Section("Bu iş için (aylık)") {
                LabeledContent("Brüt", value: PayFormat.tl(row.gross))
                if row.sideIncome.value > 0 {
                    LabeledContent("Ek destek", value: "+" + PayFormat.tl(row.sideIncome))
                }
                LabeledContent("Yakıt", value: "−" + PayFormat.tl(row.fuel))
                LabeledContent("Net", value: PayFormat.tl(row.net))
                    .font(.headline)
                if let perHour = row.netPerHour {
                    LabeledContent("Net / saat", value: PayFormat.tl(perHour))
                }
            }
            if let correlation { CorrelationSection(correlation: correlation) }
            Section("Tarife") {
                ForEach(regular) { item in TariffItemLine(item: item) }
            }
            if !campaigns.isEmpty {
                Section("Kampanyalar ve süreli bonuslar") {
                    ForEach(campaigns) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            TariffItemLine(item: item)
                            Text("Bitiş: \(PayFormat.day(item.effectiveUntil ?? ""))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let version {
                Section {
                    LabeledContent("Sürüm", value: version.label)
                    LabeledContent("Yürürlük", value: PayFormat.day(version.effectiveFrom))
                }
            }
            VerificationFootnote(items: unverified)
        }
        .navigationTitle(PayrollModel.platformName(row.platformCode))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Yalnizca calistigi firmanin tutarlari duzenlenir (diger firmalar karsilastirma icin firma degeriyle kalir)
            if row.isCurrent {
                ToolbarItem(placement: .topBarTrailing) { TariffEditButton() }
            }
        }
    }

    private var unverified: [UnverifiedItem] {
        guard let version else { return [] }
        return UnverifiedItems.from(version: version, platformName: PayrollModel.platformName(row.platformCode))
    }
}

private struct TariffItemLine: View {
    let item: TariffItem

    var body: some View {
        HStack {
            Text(item.label)
            Spacer()
            Text(item.amount.isZero ? "Tutar belirtilmemiş" : PayFormat.tl(item.amount) + item.unit.suffix)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

private struct CorrelationSection: View {
    let correlation: TariffFuelCorrelation

    var body: some View {
        Section("Tarife ve yakıt") {
            Text("\(PayFormat.day(correlation.toDay)): tarife %\(Formatters.decimalText(correlation.tariffChange)) · aynı dönemde yakıt %\(Formatters.decimalText(correlation.fuelChange))")
                .font(.subheadline)
            verdict
        }
    }

    @ViewBuilder private var verdict: some View {
        switch correlation.verdict {
        case .consistent:
            Label("Yakıt değişimiyle uyumlu", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
        case .check:
            Label("Yakıtla ters yönde — kontrol et", systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
        case .neutral:
            Label("Yakıtta belirgin değişim yok", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        }
    }
}
