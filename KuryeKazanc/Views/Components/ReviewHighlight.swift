import SwiftUI

/// OCR'in emin olamadigi alanlari turuncu cerceve + ikonla vurgular.
struct ReviewHighlight: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        HStack(spacing: 6) {
            content
            if isActive {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Kontrol et")
            }
        }
        .listRowBackground(isActive ? Color.orange.opacity(0.12) : nil)
    }
}

extension View {
    func reviewHighlight(_ isActive: Bool) -> some View {
        modifier(ReviewHighlight(isActive: isActive))
    }
}

/// Sayisal metin alani (Turkce ondalik, ör. 1.250,50).
struct AmountField: View {
    let title: String
    @Binding var text: String
    var suffix: String = "₺"
    var keyboard: UIKeyboardType = .decimalPad
    var identifier: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .accessibilityIdentifier(identifier)
            if !suffix.isEmpty {
                Text(suffix).foregroundStyle(.secondary)
            }
        }
    }
}
