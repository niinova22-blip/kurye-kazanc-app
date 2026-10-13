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
        return [
            IntroPage(id: 0, title: "Ne kazandığını, ne kaldığını bil",
                      text: "Günlük, haftalık ve aylık net kazancın tek ekranda. Yakıt düşülmüş, gerçek rakam."),
            IntroPage(id: 1, title: "Kazancını saniyeler içinde ekle",
                      text: "Kazanç ekranının görüntüsünü ekle ya da elle yaz; rakamlar okunur, sen onaylarsın."),
            IntroPage(id: 2, title: tariffTitle,
                      text: "Sabit ücret, paket ücreti, km ve bonuslar firmanın yayımladığı güncel tarifeden hesaplanır."),
            IntroPage(id: 3, title: "Hedefini koy, yolunu gör",
                      text: "Örneğin ayda 80.000 TL. Günde kaç paket ve kaç saat çalışman gerektiğini söyler."),
            IntroPage(id: 4, title: "Daha iyi yolları gösterir",
                      text: "Bonus eşiği, akşam saatleri ya da farklı gün sayısıyla aynı paraya daha az saatte nasıl ulaşacağını önerir."),
            IntroPage(id: 5, title: "Yakıt düşülür, tarife izlenir",
                      text: "Yakıt fiyatını gir; her km netinden düşülür. Tarife değişince haber verir, verilerin telefonunda kalır."),
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
            case 1: ScanIllustration(isActive: animates)
            case 2: TariffIllustration(isActive: animates)
            case 3: GoalIllustration(isActive: animates)
            case 4: PathsIllustration(isActive: animates)
            default: FuelIllustration(isActive: animates)
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

// MARK: - 1: Ekran goruntusu tarama

private struct ScanIllustration: View {
    let isActive: Bool
    @State private var sweep = false
    @State private var read = 3

    private let rows: [(String, String)] = [("Paket", "34"), ("Kazanç", "₺2.910"), ("Km", "96,4"), ("Süre", "8 sa 10 dk")]

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 3))
                    .frame(width: 130, height: 240)
                VStack(spacing: 14) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.35))
                            .frame(width: index.isMultiple(of: 2) ? 90 : 64, height: 10)
                    }
                }
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.positive, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 120, height: 4)
                    .shadow(color: Theme.positive, radius: 8)
                    .offset(y: sweep ? 100 : -100)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.positive)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(row.0).font(.caption2).opacity(0.75)
                            Text(row.1).font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                    }
                    .opacity(index < read ? 1 : 0.15)
                    .scaleEffect(index < read ? 1 : 0.9, anchor: .leading)
                }
            }
            .foregroundStyle(.white)
            .frame(width: 120, alignment: .leading)
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active {
                read = 0
                sweep = false
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { sweep = true }
                for index in 1...rows.count {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.35 * Double(index))) { read = index }
                }
            } else {
                sweep = false
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
                .stroke(AngularGradient(colors: [Color(hex: 0x9FB0FF), Theme.positive, Color(hex: 0x9FB0FF)], center: .center),
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

// MARK: - 4: Daha iyi yollar

private struct PathsIllustration: View {
    let isActive: Bool
    @State private var progress: CGFloat = 1
    @State private var showsBadge = true

    var body: some View {
        ZStack {
            // Uzun yol (soluk)
            LongPath()
                .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 10]))
            // Kisa yol (parlak, cizilerek)
            ShortPath()
                .trim(from: 0, to: progress)
                .stroke(Theme.positiveGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .shadow(color: Theme.positive.opacity(0.6), radius: 8)
            marker("figure.outdoor.cycle", at: CGPoint(x: 30, y: 230))
            marker("flag.checkered", at: CGPoint(x: 270, y: 40))
            VStack(spacing: 4) {
                Image(systemName: "gift.fill").font(.title2)
                Text("−36 saat / ay").font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(10)
            .background(Theme.highlight.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .position(x: 170, y: 150)
            .scaleEffect(showsBadge ? 1 : 0.2)
            .opacity(showsBadge ? 1 : 0)
        }
        .frame(width: 300, height: 270)
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            progress = 0
            showsBadge = false
            withAnimation(.easeInOut(duration: 1.4)) { progress = 1 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(1.1)) { showsBadge = true }
        }
    }

    private func marker(_ symbol: String, at point: CGPoint) -> some View {
        Image(systemName: symbol)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.white.opacity(0.2), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .position(point)
    }
}

private struct LongPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 30, y: 230))
        path.addCurve(to: CGPoint(x: 270, y: 40), control1: CGPoint(x: 330, y: 260), control2: CGPoint(x: -40, y: 20))
        return path
    }
}

private struct ShortPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 30, y: 230))
        path.addQuadCurve(to: CGPoint(x: 270, y: 40), control: CGPoint(x: 120, y: 90))
        return path
    }
}

// MARK: - 5: Yakit ve tarife takibi

private struct FuelIllustration: View {
    let isActive: Bool
    @State private var angle: Double = 40
    @State private var showsAlert = true

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .trim(from: 0.1, to: 0.9)
                    .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 170, height: 170)
                Circle()
                    .trim(from: 0.1, to: 0.1 + 0.8 * (angle + 120) / 240)
                    .stroke(Theme.positiveGradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 170, height: 170)
                Capsule()
                    .fill(.white)
                    .frame(width: 6, height: 70)
                    .offset(y: -35)
                    .rotationEffect(.degrees(angle))
                Circle().fill(.white).frame(width: 16, height: 16)
                Image(systemName: "fuelpump.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .offset(y: 55)
            }
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tarife güncellendi").font(.subheadline.weight(.bold))
                    Text("Paket ücreti +%8 · yakıt +%11").font(.caption).opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .offset(y: showsAlert ? 0 : 40)
            .opacity(showsAlert ? 1 : 0)
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            angle = -110
            showsAlert = false
            withAnimation(.spring(response: 1.1, dampingFraction: 0.5)) { angle = 40 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.8)) { showsAlert = true }
        }
    }
}
