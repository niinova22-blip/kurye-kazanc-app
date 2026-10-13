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

/// Sayisal metin alani (Turkce ondalik, ör. 1.250,50). 1.7: odakta vurgu cercevesi, hafif titresim ve
/// buyuyen rakamlar (elle giris ekranlarinin tamami bu alani kullanir).
struct AmountField: View {
    let title: String
    @Binding var text: String
    var suffix: String = "₺"
    var keyboard: UIKeyboardType = .decimalPad
    var identifier: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(focused ? Theme.accent : Color.primary)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(focused ? .semibold : .regular).monospacedDigit())
                .focused($focused)
                .frame(maxWidth: 140)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(focused ? Theme.accent.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focused ? Theme.accent : Color.secondary.opacity(0.15), lineWidth: focused ? 1.5 : 1)
                )
                .accessibilityIdentifier(identifier)
            if !suffix.isEmpty {
                Text(suffix).foregroundStyle(.secondary)
            }
        }
        .animation(.easeOut(duration: 0.18), value: focused)
        .onChange(of: focused) { _, isFocused in
            if isFocused { Haptics.selection() }
        }
    }
}
