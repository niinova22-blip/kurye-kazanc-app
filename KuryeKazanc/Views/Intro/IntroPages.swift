import SwiftUI

struct IntroPage: Identifiable {
    let id: Int
    let title: String
    let text: String
}

enum IntroContent {
    static let pages: [IntroPage] = [
        IntroPage(id: 0, title: "Ne kazandığını, ne kaldığını bil",
                  text: "Kurye Kazanç günlük, haftalık ve aylık net kazancını tek yerde gösterir."),
        IntroPage(id: 1, title: "Kazancını saniyeler içinde ekle",
                  text: "Firmanın kazanç ekranının görüntüsünü ekle ya da elle gir; rakamlar okunur ve kaydedilir."),
        IntroPage(id: 2, title: "Firmanın tarifesiyle hesap",
                  text: "Sabit ücret, paket başı ücret, bonus ve kampanyalar firmanın yayımladığı tarifeden hesaplanır."),
        IntroPage(id: 3, title: "Hedefini koy",
                  text: "Örneğin aylık 100.000 TL. Uygulama günde kaç paket, kaç saat ve hangi bölgede çalışman gerektiğini söyler."),
        IntroPage(id: 4, title: "Yakıt ve km doğru düşülür",
                  text: "Yakıt fiyatını gir; her km'nin maliyeti netinden düşülür."),
        IntroPage(id: 5, title: "Tarifeler değişirse karşılaştır",
                  text: "Firmalar sekmesi aynı işi diğer firmalarda yapsan ne kazanacağını gösterir. Verilerin telefonunda kalır."),
    ]
}

/// Sayfa gorseli: SwiftUI ile cizilir (gorsel dosyasi yok), sayfa gorununce oynar; "Hareketi azalt" acikken duragan.
struct IntroIllustration: View {
    let page: Int
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animates: Bool { isActive && !reduceMotion }

    var body: some View {
        Group {
            switch page {
            case 0: CounterIllustration(isActive: animates)
            case 1: ScanIllustration(isActive: animates)
            case 2: TariffIllustration(isActive: animates)
            case 3: GoalIllustration(isActive: animates)
            case 4: FuelIllustration(isActive: animates)
            default: FirmsIllustration(isActive: animates)
            }
        }
        .frame(height: 260)
        .accessibilityHidden(true)
    }
}

private struct CounterIllustration: View {
    let isActive: Bool
    @State private var value: Double = 3_850

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "turkishlirasign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: isActive)
            Text(Formatters.currency(value))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            value = 0
            withAnimation(.easeOut(duration: 1.4)) { value = 3_850 }
        }
    }
}

private struct ScanIllustration: View {
    let isActive: Bool
    @State private var sweep = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.secondary, lineWidth: 3)
                .frame(width: 140, height: 240)
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: index == 1 ? 70 : 100, height: 12)
                }
            }
            Rectangle()
                .fill(Theme.accent.opacity(0.6))
                .frame(width: 130, height: 3)
                .offset(y: sweep ? 105 : -105)
            Image(systemName: "text.viewfinder")
                .font(.title)
                .foregroundStyle(Theme.accent)
                .offset(x: 90, y: -90)
                .symbolEffect(.pulse, isActive: isActive)
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { sweep = true }
            } else {
                sweep = false
            }
        }
    }
}

private struct TariffIllustration: View {
    let isActive: Bool
    @State private var shown = 4
    private let rows: [String] = ["Aylık sabit ücret", "Paket başı ücret", "Hafta sonu bonusu", "Kampanya"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text(row)
                    Spacer()
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .opacity(index < shown ? 1 : 0)
                .offset(x: index < shown ? 0 : 30)
            }
        }
        .padding(.horizontal, 32)
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            shown = 0
            for index in 1...rows.count {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.25)) { shown = index }
            }
        }
    }
}

private struct GoalIllustration: View {
    let isActive: Bool
    @State private var fraction: Double = 0.7

    var body: some View {
        ZStack {
            GoalRing(progress: GoalProgress(target: 1, achieved: fraction), lineWidth: 18)
                .frame(width: 180, height: 180)
            VStack {
                Text("\(Int(fraction * 38)) paket")
                    .font(.title.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText(value: fraction))
                Text("günlük hedef 38")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            fraction = 0
            withAnimation(.easeInOut(duration: 1.5)) { fraction = 0.7 }
        }
    }
}

private struct FuelIllustration: View {
    let isActive: Bool
    @State private var angle: Double = 40

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.1, to: 0.9)
                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(90))
                .frame(width: 190, height: 190)
            Capsule()
                .fill(Theme.accent)
                .frame(width: 6, height: 80)
                .offset(y: -40)
                .rotationEffect(.degrees(angle))
            Image(systemName: "drop.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
                .offset(y: 60)
                .symbolEffect(.bounce, value: isActive)
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            angle = -60
            withAnimation(.spring(response: 1, dampingFraction: 0.5)) { angle = 40 }
        }
    }
}

private struct FirmsIllustration: View {
    let isActive: Bool
    @State private var swapped = true

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                card("Senin firman", "92.400 TL", highlight: !swapped)
                card("Diğer firma", "97.100 TL", highlight: swapped)
            }
            Image(systemName: swapped ? "lock.fill" : "lock.open.fill")
                .font(.title)
                .foregroundStyle(Theme.accent)
                .contentTransition(.symbolEffect(.replace))
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            swapped = false
            withAnimation(.spring.delay(0.6)) { swapped = true }
        }
    }

    private func card(_ title: String, _ value: String, highlight: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .padding()
        .frame(width: 140)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(highlight ? Theme.accent : Color.clear, lineWidth: 2))
        .scaleEffect(highlight ? 1.05 : 0.95)
    }
}
