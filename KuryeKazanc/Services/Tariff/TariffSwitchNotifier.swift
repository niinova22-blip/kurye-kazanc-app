import Foundation
import UserNotifications

/// "Tarifeler degisti" yerel bildirimi. Yalnizca bildirim izni zaten verilmisse gonderilir (yeni izin istenmez).
enum TariffSwitchNotifier {
    static func notify(_ suggestion: SwitchSuggestion) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tarifeler değişti"
        let name: String = PayrollModel.platformName(suggestion.platformCode)
        content.body = "Aynı işi \(name)'de yapsan ayda +\(Formatters.currency(suggestion.extraNet.doubleValue)) net. Firmalar'a bak."
        try? await center.add(UNNotificationRequest(identifier: "tariff-switch-\(suggestion.key)", content: content, trigger: nil))
    }
}
