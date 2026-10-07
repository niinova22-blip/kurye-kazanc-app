import SwiftUI

/// Tek tasarim kaynagi. Kural: sistem renkleri + tek vurgu (yesil). Kirmizi yalnizca gider ve "bitir".
enum Theme {
    static let accent = Color.accentColor
    static let negative = Color.red
    static let surface = Color(.secondarySystemGroupedBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let cornerRadius: CGFloat = 12
}
