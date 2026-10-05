import Foundation

/// Calisma ortami: gelistirme / TestFlight / App Store.
enum BuildEnvironment {
    /// TestFlight ve DEBUG build'lerinde testci araclari (OCR raporu gibi) gosterilir; App Store'da gizlenir.
    static let showsTesterTools: Bool = {
        #if DEBUG
        return true
        #else
        return isTestFlight
        #endif
    }()

    /// TestFlight build'leri sandbox makbuzuyla calisir.
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
}
