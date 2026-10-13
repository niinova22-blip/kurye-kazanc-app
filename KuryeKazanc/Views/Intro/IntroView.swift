import SwiftUI

enum IntroMode {
    case firstRun, replay
}

/// Alti sayfalik tanitim; hareketli marka zemini, cam kartli gorseller, ozel sayfa gostergesi.
/// Ilk acilista "Başla" kuruluma gecer; tekrar izlemede "Kapat".
struct IntroView: View {
    let mode: IntroMode
    var firmCode: String? = nil
    let onFinish: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: [IntroPage] {
        let name: String? = firmCode.flatMap { $0.isEmpty ? nil : PayrollModel.platformName($0) }
        return IntroContent.pages(firmName: name)
    }

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(mode == .replay ? "Kapat" : "Geç") { onFinish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15), in: Capsule())
                        .accessibilityIdentifier(mode == .replay ? "intro.close" : "intro.skip")
                }
                .padding()
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        pageView(item).tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                PageDots(count: pages.count, current: page)
                    .padding(.bottom, 18)
                bottomButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .onChange(of: page) { _, _ in Haptics.selection() }
    }

    private func pageView(_ item: IntroPage) -> some View {
        let isActive: Bool = page == item.id
        return VStack(spacing: 22) {
            Spacer(minLength: 0)
            IntroIllustration(page: item.id, isActive: isActive)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.9)
            VStack(spacing: 10) {
                Text(item.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("intro.page.\(item.id)")
                Text(item.text)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .opacity(isActive ? 1 : 0)
            .offset(y: isActive || reduceMotion ? 0 : 16)
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85), value: isActive)
    }

    @ViewBuilder private var bottomButton: some View {
        let isLast: Bool = page >= pages.count - 1
        Button {
            if isLast {
                Haptics.success()
                onFinish()
            } else {
                withAnimation(.snappy) { page += 1 }
            }
        } label: {
            HStack(spacing: 8) {
                Text(isLast ? (mode == .replay ? "Kapat" : "Başla") : "Devam")
                Image(systemName: isLast ? "checkmark" : "arrow.right")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Theme.accent)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(isLast ? (mode == .replay ? "intro.done" : "intro.start") : "intro.next")
    }
}

/// Gecerli sayfada uzayan kapsul noktalar.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == current ? 1 : 0.35))
                    .frame(width: index == current ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: current)
        .accessibilityElement()
        .accessibilityLabel("Sayfa \(current + 1) / \(count)")
    }
}
