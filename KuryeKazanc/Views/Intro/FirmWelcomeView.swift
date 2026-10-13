import SwiftUI

/// Ilk acilisin ilk ekrani: "Hangi firmayla calisiyorsun?". Secim tanitimdan ve kurulumdan once yapilir;
/// tanitim ve tum hesaplar bu firmaya gore kisisellesir.
struct FirmWelcomeView: View {
    let onChoose: (String) -> Void

    @State private var selection: String?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            VStack(spacing: 0) {
                header
                    .padding(.top, 36)
                    .padding(.horizontal, 24)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(PayPlatform.all.filter(\.isActive).enumerated()), id: \.element.id) { index, platform in
                            card(platform)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 24)
                                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82)
                                    .delay(0.15 + Double(index) * 0.08), value: appeared)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .onAppear { appeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .scaleEffect(appeared ? 1 : 0.6)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: appeared)
            Text("Kurye Kazanç'a hoş geldin")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text("Hangi firmayla çalışıyorsun?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.title")
            Text("Ücretler, bonuslar ve hedefin bu firmanın güncel tarifesine göre hesaplanır.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(_ platform: PayPlatform) -> some View {
        let isSelected: Bool = selection == platform.code
        return Button {
            withAnimation(.snappy) { selection = platform.code }
            Haptics.selection()
        } label: {
            HStack(spacing: 14) {
                Text(platform.monogram)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(isSelected ? Color.white : Theme.accent)
                    .frame(width: 50, height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.accent.opacity(0.12)))
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(platform.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(platform.modelSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Color.white.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0.1), radius: isSelected ? 16 : 8, y: 6)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("firm.\(platform.code)")
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                guard let selection else { return }
                Haptics.success()
                onChoose(selection)
            } label: {
                Text(selection == nil ? "Firmanı seç" : "Devam")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(selection == nil ? Color.white.opacity(0.6) : Theme.accent)
                    .background(selection == nil ? Color.white.opacity(0.15) : Color.white,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(selection == nil)
            .accessibilityIdentifier("welcome.next")
            Text("Aynı anda tek firmada çalışılır. Sonradan Profil > Çalıştığım firma'dan değiştirebilirsin.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }
}

/// Yavasca dolasan isik lekeli marka zemini (tanitim ve karsilama). "Hareketi azalt" acikken duragan.
struct AnimatedBrandBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t: Double = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size: CGSize = proxy.size
                ZStack {
                    Theme.brandGradient
                    blob(Color(hex: 0x7C8CFF), size: size.width * 1.1,
                         x: size.width * (0.15 + 0.12 * sin(t / 6)), y: size.height * (0.12 + 0.06 * cos(t / 7)))
                    blob(Color(hex: 0xB04BFF), size: size.width * 0.9,
                         x: size.width * (0.95 + 0.1 * cos(t / 8)), y: size.height * (0.55 + 0.08 * sin(t / 5)))
                    blob(Color(hex: 0x2BD9A6), size: size.width * 0.7,
                         x: size.width * (0.2 + 0.1 * sin(t / 9)), y: size.height * (1.0 + 0.05 * cos(t / 6)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.45))
            .frame(width: size, height: size)
            .blur(radius: size * 0.25)
            .position(x: x, y: y)
    }
}
