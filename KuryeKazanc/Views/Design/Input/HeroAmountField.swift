import SwiftUI

/// Buyuk TL girisi: odakta vurgu parlamasi + titresim, gecersiz degerde sallanma, rakam gecis animasyonu.
/// 1.11: yazarken binlik ayracla gosterilir ("100000" -> "100.000"); kurus icin virgul yazilabilir.
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
        .onAppear { text = value.map(Self.display) ?? "" }
        .onChange(of: focused) { _, isFocused in
            if isFocused { Haptics.selection() }
        }
        .onChange(of: text) { _, newText in parse(newText) }
        .onChange(of: value) { _, newValue in
            // Disaridan gelen deger (kayitli hedef yuklendi) odak disindayken metne yansir
            guard !focused else { return }
            let formatted: String = newValue.map(Self.display) ?? ""
            if Money.parse(text) != newValue { text = formatted }
        }
    }

    private var field: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { focused = false }
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

    /// Gosterim: tam kisim binlik ayracli, varsa kurus virgulle ("100.000", "1.250,5").
    static func display(_ amount: Decimal) -> String {
        let text: String = Formatters.decimalText(amount)
        let parts: [Substring] = text.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let whole: String = grouped(String(parts[0]))
        return parts.count > 1 ? whole + "," + parts[1] : whole
    }

    /// Yalnizca rakamlardan olusan tam kismi "100.000" bicimine getirir.
    static func grouped(_ digits: String) -> String {
        let clean: String = digits.filter(\.isNumber)
        guard let number = Int(clean) else { return clean }
        return Formatters.groupedInt(number)
    }

    /// Yazilan metin: noktalar binlik ayraci sayilir, virgulden sonrasi kurus. Bicim degisirse metin yeniden yazilir.
    private func parse(_ newText: String) {
        if newText.isEmpty {
            value = nil
            return
        }
        let parts: [Substring] = newText.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let wholeDigits: String = parts[0].replacingOccurrences(of: ".", with: "")
        var reformatted: String = Self.grouped(wholeDigits)
        if parts.count > 1 { reformatted += "," + parts[1].filter(\.isNumber).prefix(2) }
        if !wholeDigits.isEmpty, wholeDigits.allSatisfy(\.isNumber), reformatted != newText {
            text = reformatted
            return
        }
        // Virgul yeni yazildi ("1.000,"): kurus henuz yok, tutar tam kisimdir
        let normalized: String = wholeDigits + (parts.count > 1 && !parts[1].isEmpty ? "," + parts[1] : "")
        if let parsed = Money.parse(normalized), parsed >= 0 {
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
