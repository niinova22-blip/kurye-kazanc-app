import SwiftUI

/// Buyuk ana rakam (Bugun'un net kazanci, Analiz'in donem neti).
struct HeroAmount: View {
    let title: String
    let value: Double
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Formatters.currency(value))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(value < 0 ? Theme.negative : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// Yan yana kucuk metrikler: deger ustte, baslik altta. Kart degil; ayraclarla bolunmus tek satir.
struct MetricStrip: View {
    struct Item: Identifiable {
        var title: String
        var value: String
        var identifier: String
        var id: String { identifier }
    }

    let items: [Item]

    init(_ items: [Item]) { self.items = items }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().frame(height: 28).padding(.horizontal, 12)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value)
                        .font(.headline)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityIdentifier(item.identifier)
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Kayit satirindaki dogrulama rozeti: yalnizca simge + kisa metin, renkli dolgu yok.
struct VerificationBadge: View {
    let level: VerificationLevel

    var body: some View {
        Label(level.displayName, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(level == .verified ? Theme.accent : .secondary)
            .labelStyle(.titleAndIcon)
            .accessibilityIdentifier("verification.\(level.rawValue)")
    }

    private var symbol: String {
        switch level {
        case .manual: "pencil"
        case .ocrEdited: "text.viewfinder"
        case .ocrUnverified: "text.viewfinder"
        case .verified: "checkmark.seal.fill"
        }
    }
}

/// Fitness tarzi hedef halkasi.
struct GoalRing: View {
    let progress: GoalProgress
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(Theme.accent.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth, value: progress.fraction)
        }
        .accessibilityElement()
        .accessibilityLabel("Hedef")
        .accessibilityValue("Yüzde \(Int(progress.fraction * 100))")
    }
}

/// Tam genislikte ana eylem dugmesi (Vardiyayi baslat/bitir, onboarding Devam).
struct PrimaryActionButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(isDestructive ? Theme.negative : Theme.accent, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
