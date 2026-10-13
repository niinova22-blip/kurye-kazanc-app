import SwiftUI
import SwiftData

/// Hesap sonucu ya da hata.
struct CalculationSections: View {
    let result: Result<PayBreakdown, PayError>

    var body: some View {
        switch result {
        case let .success(breakdown):
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tahmini brüt hakediş").font(.subheadline).foregroundStyle(.secondary)
                    Text(PayFormat.range(breakdown.gross, breakdown.grossUpper))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .accessibilityIdentifier("estimate.gross")
                }
            }
            BreakdownSections(breakdown: breakdown)
            VerificationFootnote(items: UnverifiedItems.from(breakdown, platformName: PayrollModel.platformName(breakdown.platformCode)))
        case let .failure(error):
            Section {
                Label(error.message, systemImage: "xmark.octagon").foregroundStyle(Theme.negative)
            }
        }
    }
}
