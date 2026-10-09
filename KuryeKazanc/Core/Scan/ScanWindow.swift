import Foundation

/// Tarama penceresi: fotograflardan taramada hangi gorsellerin dikkate alinacagi.
struct ScanWindow {
    static let normal: TimeInterval = 24 * 3600
    static let test: TimeInterval = 30 * 24 * 3600

    /// Pencerenin baslangici; bundan eski gorseller taranmaz.
    static func start(now: Date, testMode: Bool) -> Date {
        now.addingTimeInterval(-(testMode ? test : normal))
    }
}
