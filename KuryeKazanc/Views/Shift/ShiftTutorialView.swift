import SwiftUI

/// Canli vardiyanin kisa tanitim filmi: dort sahne kendiliginden akar (hikaye cubuklari). Ilk "Vardiya başlat"ta bir kez
/// gosterilir; vardiya ekranindaki "?" ve Profil'den tekrar izlenir. Saga dokun: ileri, sola dokun: geri.
struct ShiftTutorialView: View {
    enum Mode { case firstRun, replay }

    let mode: Mode
    let onFinish: () -> Void

    @State private var scene = 0
    @State private var sceneStart = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sceneLength: TimeInterval = 4.2
    private let scenes: [(title: String, text: String)] = [
        ("Vardiyayı başlat", "İşe çıkınca tek dokunuş. Süre ve yol kendiliğinden ölçülür."),
        ("Paketi bırakınca dokun", "Ekranın neresine dokunursan dokun, paket o anki saat ve konumla eklenir."),
        ("Paketin bandını bulur", "Akşam ücreti, mesafe ek ödemesi, şehrine özel bonus: tarifedeki yerini hemen görürsün."),
        ("Bitirince hesap hazır", "Paketler, km, sabit ücretin günlük payı ve yakıt. Kazanç ekranına kendiliğinden düşer."),
    ]

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            VStack(spacing: 0) {
                progressBars
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                HStack {
                    Spacer()
                    Button(mode == .replay ? "Kapat" : "Geç") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15), in: Capsule())
                        .accessibilityIdentifier("shiftTutorial.skip")
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer(minLength: 0)
                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                    let t: Double = reduceMotion ? 10 : context.date.timeIntervalSince(sceneStart)
                    sceneArt(scene, t: t)
                        .frame(height: 280)
                        .onChange(of: context.date) { _, now in advanceIfNeeded(now) }
                }
                .id(scene)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

                VStack(spacing: 10) {
                    Text(scenes[scene].title)
                        .font(.title.bold())
                        .accessibilityIdentifier("shiftTutorial.title.\(scene)")
                    Text(scenes[scene].text)
                        .font(.body)
                        .opacity(0.85)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .id("text\(scene)")
                .transition(.opacity)
                Spacer(minLength: 0)

                Button {
                    if scene < scenes.count - 1 { go(to: scene + 1) } else { finish() }
                } label: {
                    Text(scene < scenes.count - 1 ? "Devam" : (mode == .firstRun ? "Anladım, başlat" : "Kapat"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(Theme.accent)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .accessibilityIdentifier(scene < scenes.count - 1 ? "shiftTutorial.next" : "shiftTutorial.done")
            }
        }
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { value in
            // Hikaye gibi: ekranin sol ucte biri geri, kalani ileri
            let width: CGFloat = UIScreen.main.bounds.width
            if value.location.x < width / 3 { go(to: max(0, scene - 1)) } else if scene < scenes.count - 1 { go(to: scene + 1) }
        })
        .onAppear { sceneStart = .now }
    }

    // MARK: - Akis

    private var progressBars: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let elapsed: Double = min(1, context.date.timeIntervalSince(sceneStart) / Self.sceneLength)
            HStack(spacing: 6) {
                ForEach(0..<scenes.count, id: \.self) { index in
                    GeometryReader { proxy in
                        Capsule().fill(.white.opacity(0.3))
                            .overlay(alignment: .leading) {
                                Capsule().fill(.white)
                                    .frame(width: proxy.size.width * fill(index, elapsed: elapsed))
                            }
                    }
                    .frame(height: 4)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(_ index: Int, elapsed: Double) -> CGFloat {
        if index < scene { return 1 }
        if index > scene { return 0 }
        return reduceMotion ? 1 : CGFloat(elapsed)
    }

    private func advanceIfNeeded(_ now: Date) {
        guard !reduceMotion, scene < scenes.count - 1, now.timeIntervalSince(sceneStart) >= Self.sceneLength else { return }
        go(to: scene + 1)
    }

    private func go(to index: Int) {
        guard index != scene else { return }
        Haptics.selection()
        withAnimation(.snappy) { scene = index }
        sceneStart = .now
    }

    private func finish() {
        Haptics.success()
        onFinish()
    }

    // MARK: - Sahneler

    @ViewBuilder
    private func sceneArt(_ index: Int, t: Double) -> some View {
        switch index {
        case 0: StartScene(t: t)
        case 1: TapScene(t: t)
        case 2: ZoneScene(t: t)
        default: ReceiptScene(t: t)
        }
    }
}

/// Nabiz gibi atan "Başlat" dugmesi.
private struct StartScene: View {
    let t: Double

    var body: some View {
        let pulse: Double = (sin(t * 3) + 1) / 2
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                let phase: Double = (t * 0.6 + Double(ring) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .stroke(.white.opacity(0.5 * (1 - phase)), lineWidth: 2)
                    .frame(width: 140 + 140 * phase, height: 140 + 140 * phase)
            }
            Circle()
                .fill(.white)
                .frame(width: 140, height: 140)
                .scaleEffect(1 + 0.04 * pulse)
                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
            VStack(spacing: 6) {
                Image(systemName: "play.fill").font(.system(size: 38, weight: .bold))
                Text("Başlat").font(.headline)
            }
            .foregroundStyle(Theme.accent)
        }
        .accessibilityHidden(true)
    }
}

/// Parmak her 0,9 sn'de bir dokunur; sayac artar, dalga yayilir.
private struct TapScene: View {
    let t: Double

    var body: some View {
        let period: Double = 0.9
        let count: Int = Int(t / period) + 1
        let phase: Double = (t / period).truncatingRemainder(dividingBy: 1)
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 2))
                .frame(width: 170, height: 270)
            Circle()
                .stroke(.white.opacity(0.6 * (1 - phase)), lineWidth: 3)
                .frame(width: 60 + 120 * phase, height: 60 + 120 * phase)
                .offset(y: 10)
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(count)))
                    .monospacedDigit()
                Text("paket").font(.subheadline.weight(.semibold)).opacity(0.85)
            }
            .foregroundStyle(.white)
            .offset(y: -10)
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 54))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                .scaleEffect(phase < 0.2 ? 0.85 : 1)
                .offset(x: 40, y: 80 - (phase < 0.2 ? 6 : 0))
        }
        .animation(.snappy, value: count)
        .accessibilityHidden(true)
    }
}

/// Konum pini ve sirayla beliren tarife cipleri.
private struct ZoneScene: View {
    let t: Double
    private let chips: [(String, String)] = [
        ("moon.stars.fill", "Akşam bandı · paket başı 78,50 TL"),
        ("point.topleft.down.to.point.bottomright.curvepath.fill", "4–6 km bandı · +25 TL"),
        ("mappin.and.ellipse", "İzmir · haftalık bonus dahil"),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white, Theme.positive)
                .offset(y: -6 * abs(sin(t * 2.4)))
            ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                let visible: Bool = t > 0.6 + Double(index) * 0.9
                Label(chip.1, systemImage: chip.0)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 14)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: visible)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Kalem kalem dolan hesap fisi.
private struct ReceiptScene: View {
    let t: Double
    private let lines: [(String, String)] = [
        ("Paketler", "1.890 TL"), ("Mesafe ek ödemesi", "85 TL"), ("Sabit ücret payı", "2.508 TL"), ("Yakıt", "−240 TL"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let visible: Bool = t > 0.4 + Double(index) * 0.55
                HStack {
                    Text(line.0)
                    Spacer()
                    Text(line.1).monospacedDigit()
                }
                .font(.subheadline)
                .opacity(visible ? 1 : 0)
                .offset(x: visible ? 0 : -16)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: visible)
            }
            Divider().overlay(.white.opacity(0.5))
            let done: Bool = t > 2.8
            HStack {
                Text("Cebine kalan").font(.headline)
                Spacer()
                Text("4.243 TL")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.mintOnDark)
                    .monospacedDigit()
            }
            .opacity(done ? 1 : 0)
            .scaleEffect(done ? 1 : 0.9, anchor: .leading)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: done)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(width: 290)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .accessibilityHidden(true)
    }
}
