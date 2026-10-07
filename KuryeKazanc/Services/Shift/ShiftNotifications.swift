import Foundation
import UserNotifications

protocol ShiftNotifying {
    func requestAccess() async -> Bool
    func autoShiftStarted()
    func clearAutoShiftStarted()
    func shiftEnded(_ shift: PendingShift)
}

/// Yerel bildirimler: otomatik vardiya basladi (iptal eylemli), vardiya bitti (kazanc ekle).
final class ShiftNotifications: ShiftNotifying {
    static let startedCategory = "AUTO_SHIFT_STARTED"
    static let endedCategory = "SHIFT_ENDED"
    static let cancelAction = "CANCEL_AUTO_SHIFT"
    static let pendingIDKey = "pendingShiftID"
    private static let startedID = "auto-shift-started"

    private let center = UNUserNotificationCenter.current()

    static func registerCategories() {
        let cancel = UNNotificationAction(identifier: cancelAction, title: "Bu bir vardiya değil", options: [.destructive])
        let started = UNNotificationCategory(identifier: startedCategory, actions: [cancel], intentIdentifiers: [], options: [])
        let ended = UNNotificationCategory(identifier: endedCategory, actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([started, ended])
    }

    func requestAccess() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func autoShiftStarted() {
        let content = UNMutableNotificationContent()
        content.title = "Vardiya başladı"
        content.body = "Hareket algılandı; süre ve km kaydediliyor. Yanlışsa basılı tut, “Bu bir vardiya değil”i seç."
        content.categoryIdentifier = Self.startedCategory
        center.add(UNNotificationRequest(identifier: Self.startedID, content: content, trigger: nil))
    }

    func clearAutoShiftStarted() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.startedID])
    }

    func shiftEnded(_ shift: PendingShift) {
        let content = UNMutableNotificationContent()
        content.title = "Vardiya bitti"
        content.body = "\(Formatters.duration(shift.end.timeIntervalSince(shift.start))) · \(Formatters.distance(shift.distanceKm)). Kazancını eklemek için dokun."
        content.categoryIdentifier = Self.endedCategory
        content.userInfo = [Self.pendingIDKey: shift.id.uuidString]
        center.add(UNNotificationRequest(identifier: "shift-ended-\(shift.id.uuidString)", content: content, trigger: nil))
    }
}
