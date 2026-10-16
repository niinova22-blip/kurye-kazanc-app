import SwiftUI

struct IntroPage: Identifiable {
    let id: Int
    let title: String
    let text: String
}

enum IntroContent {
    /// Tanitim sayfalari; secilen firmanin adi metne girer.
    static func pages(firmName: String?) -> [IntroPage] {
        let tariffTitle: String = firmName.map { "\($0) tarifesiyle hesap" } ?? "Firmanın tarifesiyle hesap"
        // 1.13: 6 sayfadan 4'e indi (yakit ve "daha iyi yollar" ilgili sayfalarla birlesti)
        return [
            IntroPage(id: 0, title: "Ne kazandığını, ne kaldığını bil",
                      text: "Günlük, haftalık ve aylık net kazancın tek ekranda. Yakıt fiyatını girersin, her km netinden düşülür."),
            IntroPage(id: 1, title: "Paketini tek dokunuşla say",
                      text: "Vardiyayı başlat, paketi bırakınca ekrana ya da kilit ekranındaki +1'e dokun. Km, bölge ve ücret kendiliğinden hesaplanır."),
            IntroPage(id: 2, title: tariffTitle,
                      text: "Sabit ücret, paket ücreti, km ve bonuslar firmanın güncel tarifesinden hesaplanır. Tarife değişince haber verir."),
            IntroPage(id: 3, title: "Hedefini koy, yolunu gör",
                      text: "Örneğin ayda 80.000 TL: günde kaç paket ve kaç saat gerektiğini, aynı paraya daha az saatte ulaşmanın yollarını gösterir."),
        ]
    }
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
            case 0: NetIllustration(isActive: animates)
            case 1: ShiftIllustration(isActive: animates)
            case 2: TariffIllustration(isActive: animates)
            default: GoalIllustration(isActive: animates)
            }
        }
        .frame(height: 280)
        .accessibilityHidden(true)
    }
}

/// Beyaz cam kart (tanitim gorselleri icin).
private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 12)
    }
}

// MARK: - 0: Net kazanc

private struct NetIllustration: View {
    let isActive: Bool
    @State private var value: Double = 3_850
    @State private var drawn: CGFloat = 1
    @State private var pulse = false
    private let points: [CGFloat] = [0.55, 0.62, 0.48, 0.7, 0.66, 0.82, 0.78, 0.95]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Bugün net", systemImage: "sun.max.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "turkishlirasign.circle.fill")
                        .font(.title)
                        .foregroundStyle(Theme.positive)
                        .scaleEffect(pulse ? 1.12 : 1)
                }
                Text(Formatters.currency(value))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: value))
                Sparkline(points: points)
                    .trim(from: 0, to: drawn)
                    .stroke(Theme.positiveGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(height: 70)
                HStack(spacing: 16) {
                    Label("Brüt 4.320 ₺", systemImage: "arrow.up.right")
                    Label("Yakıt 470 ₺", systemImage: "fuelpump.fill")
                }
                .font(.caption.weight(.semibold))
                .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(width: 280)
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            value = 0
            drawn = 0
            withAnimation(.easeOut(duration: 1.4)) { value = 3_850 }
            withAnimation(.easeInOut(duration: 1.6).delay(0.2)) { drawn = 1 }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct Sparkline: Shape {
    let points: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        let step: CGFloat = rect.width / CGFloat(points.count - 1)
        for (index, value) in points.enumerated() {
            let point = CGPoint(x: CGFloat(index) * step, y: rect.height * (1 - value))
            if index == 0 {
                path.move(to: point)
            } else {
                let previous = CGPoint(x: CGFloat(index - 1) * step, y: rect.height * (1 - points[index - 1]))
                let mid = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
                path.addQuadCurve(to: mid, control: previous)
                path.addQuadCurve(to: point, control: point)
            }
        }
        return path
    }
}

// MARK: - 1: Canli vardiya (paket sayma)

private struct ShiftIllustration: View {
    let isActive: Bool
    @State private var count = 0
    @State private var pulse = false

    private let rows: [(String, String)] = [("Bölge", "Kadıköy · 1. bölge"), ("Km", "42,6"), ("Brüt", "₺2.910")]

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.45), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulse ? 1.12 : 0.95)
                    .opacity(pulse ? 0.2 : 0.9)
                Circle()
                    .fill(.white)
                    .frame(width: 110, height: 110)
                VStack(spacing: 2) {
                    Image(systemName: "hand.tap.fill").font(.title2)
                    Text("\(count)").font(.title.weight(.heavy)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("paket").font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("+1 paket", systemImage: "lock.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2), in: Capsule())
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.0).font(.caption2).opacity(0.75)
                        Text(row.1).font(.subheadline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(width: 130, alignment: .leading)
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else {
                pulse = false
                return
            }
            count = 31
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true }
            for step in 1...3 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.9 * Double(step))) { count = 31 + step }
            }
        }
    }
}

// MARK: - 2: Tarife

private struct TariffIllustration: View {
    let isActive: Bool
    @State private var shown = 4
    private let rows: [(String, String, String)] = [
        ("calendar", "Aylık sabit ücret", "65.223 ₺"),
        ("shippingbox.fill", "Paket ücreti", "64,5 ₺"),
        ("road.lanes", "Km ücreti", "6,5 ₺/km"),
        ("gift.fill", "Bonus kademesi", "1.610 ₺"),
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 12) {
                    Image(systemName: row.0)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(row.1).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(row.2).font(.subheadline.weight(.bold)).monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .opacity(index < shown ? 1 : 0)
                .offset(x: index < shown ? 0 : 60)
                .rotation3DEffect(.degrees(index < shown ? 0 : 25), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(width: 300)
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            shown = 0
            for index in 1...rows.count {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(Double(index) * 0.18)) { shown = index }
            }
        }
    }
}

// MARK: - 3: Hedef

private struct GoalIllustration: View {
    let isActive: Bool
    @State private var fraction: Double = 0.72
    @State private var dropped = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 20)
                .frame(width: 200, height: 200)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(AngularGradient(colors: [Theme.brandGlow, Theme.positive, Theme.brandGlow], center: .center),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
            VStack(spacing: 2) {
                Text("\(Int(fraction * 38))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: fraction))
                Text("/ 38 paket")
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "shippingbox.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .offset(x: CGFloat(index - 1) * 70 + 10, y: index < dropped ? 130 : -160)
                    .opacity(index < dropped ? 1 : 0)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            fraction = 0
            dropped = 0
            withAnimation(.easeInOut(duration: 1.5)) { fraction = 0.72 }
            for index in 1...3 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.25 * Double(index))) { dropped = index }
            }
        }
    }
}
