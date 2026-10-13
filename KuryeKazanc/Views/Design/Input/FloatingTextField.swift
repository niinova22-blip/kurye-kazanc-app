import SwiftUI

/// Etiketi yazmaya baslayinca yukari kayan metin alani.
struct FloatingTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    let identifier: String
    @FocusState private var focused: Bool

    private var raised: Bool { focused || !text.isEmpty }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(title)
                .font(raised ? .caption : .body)
                .foregroundStyle(focused ? Theme.accent : .secondary)
                .offset(y: raised ? -18 : 0)
                .accessibilityHidden(true)
            TextField("", text: $text)
                .keyboardType(keyboard)
                .focused($focused)
                .padding(.top, raised ? 12 : 0)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Theme.groupedBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(focused ? Theme.accent : Color.secondary.opacity(0.2), lineWidth: focused ? 2 : 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: raised)
        .animation(.easeOut(duration: 0.2), value: focused)
        .onChange(of: focused) { _, isFocused in
            if isFocused { Haptics.selection() }
        }
    }
}
