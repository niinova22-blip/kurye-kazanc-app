import SwiftUI

enum IntroMode {
    case firstRun, replay
}

/// Alti sayfalik tanitim. Ilk acilista "Basla" kuruluma gecer; tekrar izlemede "Kapat".
struct IntroView: View {
    let mode: IntroMode
    let onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(mode == .replay ? "Kapat" : "Geç") { onFinish() }
                    .accessibilityIdentifier(mode == .replay ? "intro.close" : "intro.skip")
            }
            .padding()
            TabView(selection: $page) {
                ForEach(IntroContent.pages) { item in
                    pageView(item).tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            bottomButton
                .padding()
        }
        .background(Theme.groupedBackground.ignoresSafeArea())
    }

    private func pageView(_ item: IntroPage) -> some View {
        VStack(spacing: 24) {
            IntroIllustration(page: item.id, isActive: page == item.id)
            Text(item.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("intro.page.\(item.id)")
            Text(item.text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder private var bottomButton: some View {
        if page < IntroContent.pages.count - 1 {
            Button("Devam") {
                withAnimation { page += 1 }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityIdentifier("intro.next")
        } else {
            Button(mode == .replay ? "Kapat" : "Başla") { onFinish() }
                .buttonStyle(PrimaryActionButtonStyle())
                .accessibilityIdentifier(mode == .replay ? "intro.done" : "intro.start")
        }
    }
}
