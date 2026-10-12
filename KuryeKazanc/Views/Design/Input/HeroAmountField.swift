import SwiftUI

/// Buyuk TL girisi: odakta vurgu parlamasi + titresim, gecersiz degerde sallanma, rakam gecis animasyonu.
struct HeroAmountField: View {
    let title: String
    @Binding var value: Decimal?
    var unit: String = "TL"
    let identifier: String

    @State private var text: String = ""
    @State private var shake: CGFloat = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            field
        }
        .onAppear { text = value.map { Formatters.decimalText($0) } ?? "" }
        .onChange(of: focused) { _, isFocused in
            if isFocused { Haptics.selection() }
        }
        .onChange(of: text) { _, newText in parse(newText) }
    }

    private var field: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .focused($focused)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
            Text(unit)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.groupedBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(focused ? Theme.accent : Color.secondary.opacity(0.2), lineWidth: focused ? 2 : 1)
        )
        .shadow(color: Theme.accent.opacity(focused ? 0.25 : 0), radius: 10)
        .modifier(ShakeEffect(travel: shake))
        .animation(.easeOut(duration: 0.2), value: focused)
    }

    private func parse(_ newText: String) {
        if newText.isEmpty {
            value = nil
            return
        }
        if let parsed = Money.parse(newText), parsed >= 0 {
            value = parsed
        } else {
            Haptics.warning()
            withAnimation(.default) { shake += 1 }
        }
    }
}

/// Yatay sallanma (gecersiz giris).
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(travel * .pi * 4), y: 0))
    }
}
