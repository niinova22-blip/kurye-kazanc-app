import UIKit
import UserNotifications

/// iOS uygulamayi konum olayiyla arka planda yeniden baslattiginda da otomatik vardiya kurulur.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NavigationHaptics.install()
        ShiftNotifications.registerCategories()
        // Arka planda soguk baslatmada SwiftUI sahnesi olmayabilir: ortam burada kurulur
        // (Canli Etkinlik koprusu dahil) ve izleme yeniden baslatilir.
        MainActor.assumeIsolated {
            AppEnvironment.shared.autoShift.resume()
        }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let pendingID = (info[ShiftNotifications.pendingIDKey] as? String).flatMap(UUID.init(uuidString:))
        await MainActor.run {
            let coordinator = AppEnvironment.shared.autoShift
            if action == ShiftNotifications.cancelAction {
                coordinator.cancelAutoShift()
            } else if let pendingID {
                coordinator.requestedPendingID = pendingID
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        AppSounds.notificationSound == nil ? [.banner, .list] : [.banner, .list, .sound]
    }
}
