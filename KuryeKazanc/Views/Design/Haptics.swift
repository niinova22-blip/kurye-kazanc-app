import UIKit

/// Dokunsal geri bildirim: kayit, vardiya baslat/bitir.
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
