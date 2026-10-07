import Foundation
import AppIntents

/// Uygulama, acilista vardiyayi bitiren islevi buraya baglar. Eklentide nil kalir
/// (LiveActivityIntent uygulama surecinde calisir).
enum ShiftIntentBridge {
    @MainActor static var endShift: (@MainActor () -> Void)?
}

/// Canli Etkinlikteki "Vardiyayi bitir" dugmesi.
struct EndShiftIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Vardiyayı bitir"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ShiftIntentBridge.endShift?()
        return .result()
    }
}
