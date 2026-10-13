import SwiftUI
import UIKit

/// Tek tasarim kaynagi (1.8). Marka: derin indigo → elektrik mor. Para / basari: nane yesili. Bonus / ipucu: kehribar.
/// Kirmizi yalnizca gider ve "bitir". Acik ve koyu gorunumde ayri tonlar.
enum Theme {
    /// Marka rengi (AccentColor: acikta #5A3FF5, koyuda #8D7DFF).
    static let accent = Color.accentColor
    /// Kazanc, net, hedefe ulasildi.
    static let positive = dynamic(light: 0x0F9F6E, dark: 0x34D399)
    /// Bonus, kademe ipucu, uyari olmayan dikkat.
    static let highlight = dynamic(light: 0xD97706, dark: 0xFBBF24)
    static let negative = Color.red
    static let surface = Color(.secondarySystemGroupedBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let cornerRadius: CGFloat = 12
    static let cardRadius: CGFloat = 22

    /// Kahraman kartlarinin zemini (Bugun neti, Plan sonucu, tanitim).
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x3B2BD9), Color(hex: 0x6D3BF0), Color(hex: 0x8E3BFF)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Para / basari vurgusu icin yumusak gecis.
    static let positiveGradient = LinearGradient(
        colors: [Color(hex: 0x10B981), Color(hex: 0x34D399)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Marka gecisli kahraman kart: beyaz yazi, yumusak golge, buyuk kose.
struct BrandCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x3B2BD9).opacity(0.35), radius: 18, y: 10)
    }
}

/// Yuzey kart: sistem yuzeyi, ince kenar, buyuk kose (List disindaki bloklar icin).
struct SurfaceCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius - 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius - 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func brandCard() -> some View { modifier(BrandCardStyle()) }
    func surfaceCard() -> some View { modifier(SurfaceCardStyle()) }
}
