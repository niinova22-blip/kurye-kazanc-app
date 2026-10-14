import SwiftUI

/// Ilk acilisin ilk ekrani: "Hangi firmayla calisiyorsun?" — Yemeksepeti Express ya da Paket Taxi. Paket Taxi secilince
/// kol (Restoran / Migros / Migros Hemen) sorulur; her kolun tarifesi ayridir. Secim tanitimdan ve kurulumdan once yapilir.
struct FirmWelcomeView: View {
    let onChoose: (String) -> Void

    @State private var brand: String?
    @State private var branch: String?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Secilen tarife kodu (kolu olmayan firmada firmanin tek kolu).
    private var chosenCode: String? {
        guard let brand, let firm = PayPlatform.brands.first(where: { $0.id == brand }) else { return nil }
        return firm.hasBranches ? branch : firm.branches.first?.code
    }

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            VStack(spacing: 0) {
                header
                    .padding(.top, 36)
                    .padding(.horizontal, 24)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(PayPlatform.brands.enumerated()), id: \.element.id) { index, firm in
                            VStack(spacing: 10) {
                                card(firm)
                                if firm.hasBranches, brand == firm.id {
                                    branches(firm)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
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
            Text("Ücretler, primler ve hedefin bu firmanın 2026 tarifesine göre hesaplanır.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(_ firm: FirmBrand) -> some View {
        let isSelected: Bool = brand == firm.id
        return Button {
            withAnimation(.snappy) {
                if brand != firm.id { branch = nil }
                brand = firm.id
            }
            Haptics.selection()
        } label: {
            HStack(spacing: 14) {
                Text(firm.monogram)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(isSelected ? Color.white : Theme.accent)
                    .frame(width: 54, height: 54)
                    .background {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.accent.opacity(0.12)))
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(firm.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(firm.summary)
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
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Color.white.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0.1), radius: isSelected ? 16 : 8, y: 6)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("firm.\(firm.id)")
    }

    /// Paket Taxi kollari: her birinin tarifesi ayri.
    private func branches(_ firm: FirmBrand) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hangi kolunda çalışıyorsun?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.leading, 6)
            ForEach(firm.branches) { option in
                BranchRow(option: option, isSelected: branch == option.code) {
                    withAnimation(.snappy) { branch = option.code }
                    Haptics.selection()
                }
            }
        }
        .padding(.leading, 18)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                guard let chosenCode else { return }
                Haptics.success()
                onChoose(chosenCode)
            } label: {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(chosenCode == nil ? Color.white.opacity(0.6) : Theme.accent)
                    .background(chosenCode == nil ? Color.white.opacity(0.15) : Color.white,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(chosenCode == nil)
            .accessibilityIdentifier("welcome.next")
            Text("Aynı anda tek firmada çalışılır. Sonradan Profil > Çalıştığım firma'dan değiştirebilirsin.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private var buttonTitle: String {
        if brand == nil { return "Firmanı seç" }
        return chosenCode == nil ? "Kolunu seç" : "Devam"
    }
}

/// Firma kolu satiri (Paket Taxi Restoran / Migros / Migros Hemen). Karsilama ve kurulumda ortak.
struct BranchRow: View {
    let option: PayPlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: option.symbol)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : Theme.accent)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.accent.opacity(0.12)))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.branchName ?? option.name).font(.headline).foregroundStyle(.primary)
                    Text(option.modelSummary).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary.opacity(0.5))
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("branch.\(option.code)")
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
                    blob(Theme.brandGlow, size: size.width * 1.1,
                         x: size.width * (0.15 + 0.12 * sin(t / 6)), y: size.height * (0.12 + 0.06 * cos(t / 7)))
                    blob(Color(hex: 0x14B8C8), size: size.width * 0.9,
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
