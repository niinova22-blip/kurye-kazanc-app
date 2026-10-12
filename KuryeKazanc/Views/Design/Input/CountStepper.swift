import SwiftUI

/// −/+ sayi secici; basili tutunca hizlanir, her adimda hafif titresim.
struct CountStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String? = nil
    let identifier: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            RepeatButton(symbol: "minus", identifier: identifier + ".minus", isEnabled: value > range.lowerBound) {
                change(-step)
            }
            Text(label)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText(value: Double(value)))
                .frame(minWidth: 64)
                .accessibilityIdentifier(identifier)
            RepeatButton(symbol: "plus", identifier: identifier + ".plus", isEnabled: value < range.upperBound) {
                change(step)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var label: String {
        guard let unit else { return "\(value)" }
        return "\(value) \(unit)"
    }

    private func change(_ delta: Int) {
        let next: Int = min(range.upperBound, max(range.lowerBound, value + delta))
        guard next != value else { return }
        withAnimation(.snappy) { value = next }
        Haptics.selection()
    }
}

/// Ondalik −/+ secici (saat, km, tuketim).
struct DecimalStepper: View {
    let title: String
    @Binding var value: Decimal
    let range: ClosedRange<Decimal>
    let step: Decimal
    var unit: String? = nil
    let identifier: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            RepeatButton(symbol: "minus", identifier: identifier + ".minus", isEnabled: value > range.lowerBound) {
                change(-step)
            }
            Text(label)
                .font(.headline.monospacedDigit())
                .frame(minWidth: 72)
                .accessibilityIdentifier(identifier)
            RepeatButton(symbol: "plus", identifier: identifier + ".plus", isEnabled: value < range.upperBound) {
                change(step)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var label: String {
        let text: String = Formatters.decimalText(value)
        guard let unit else { return text }
        return "\(text) \(unit)"
    }

    private func change(_ delta: Decimal) {
        let next: Decimal = min(range.upperBound, max(range.lowerBound, value + delta))
        guard next != value else { return }
        withAnimation(.snappy) { value = next }
        Haptics.selection()
    }
}

/// Dokununca bir kez, basili tutunca giderek hizlanan tekrar.
struct RepeatButton: View {
    let symbol: String
    let identifier: String
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var timer: Timer?
    @State private var ticks = 0

    var body: some View {
        Image(systemName: symbol)
            .font(.headline)
            .frame(width: 40, height: 40)
            .background(Theme.accent.opacity(isEnabled ? 0.12 : 0.05), in: Circle())
            .foregroundStyle(isEnabled ? Theme.accent : Color.secondary)
            .contentShape(Circle())
            .onTapGesture {
                if isEnabled { action() }
            }
            .onLongPressGesture(minimumDuration: 0.35, perform: start, onPressingChanged: { pressing in
                if !pressing { stop() }
            })
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(symbol == "plus" ? "Artır" : "Azalt")
            .accessibilityIdentifier(identifier)
            .onDisappear(perform: stop)
    }

    private func start() {
        guard isEnabled else { return }
        ticks = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func tick() {
        ticks += 1
        let repeats: Int = ticks > 20 ? 5 : (ticks > 8 ? 2 : 1)
        for _ in 0..<repeats { action() }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}
