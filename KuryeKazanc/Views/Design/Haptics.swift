import UIKit
import AudioToolbox
import UserNotifications

/// Dokunsal geri bildirim: kayit, secim, uyari. 1.12.1: Profil > Ses ve titreşim'den kapatilabilir.
enum Haptics {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppPreferences.hapticsEnabledKey) as? Bool ?? true
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func impact() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func light() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// 1.12.1 uygulama ici sesler (sessiz modda calmaz; sistem sesi).
enum AppSounds {
    static var isPackageSoundOn: Bool {
        UserDefaults.standard.object(forKey: AppPreferences.packageSoundKey) as? Bool ?? true
    }

    /// Paket eklendi ("tink").
    static func package() {
        guard isPackageSoundOn else { return }
        AudioServicesPlaySystemSound(1057)
    }

    /// Vardiya bitti / kaydedildi.
    static func saved() {
        guard isPackageSoundOn else { return }
        AudioServicesPlaySystemSound(1025)
    }

    /// Bildirim sesi: kapaliysa bildirim sessiz gelir (titresim / banner iOS ayarina gore).
    static var notificationSound: UNNotificationSound? {
        let isOn: Bool = UserDefaults.standard.object(forKey: AppPreferences.notificationSoundKey) as? Bool ?? true
        return isOn ? .default : nil
    }
}

/// 1.12.1: geri tusu ve kaydirarak geri donuste hafif titresim (tum NavigationStack ekranlari).
enum NavigationHaptics {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        let original = #selector(UINavigationController.popViewController(animated:))
        let replacement = #selector(UINavigationController.kk_popViewController(animated:))
        guard let a = class_getInstanceMethod(UINavigationController.self, original),
              let b = class_getInstanceMethod(UINavigationController.self, replacement) else { return }
        method_exchangeImplementations(a, b)
    }
}

extension UINavigationController {
    /// Degistirilmis uygulama: once titresim, sonra (degis tokus edilmis) asil popViewController.
    @objc fileprivate func kk_popViewController(animated: Bool) -> UIViewController? {
        Haptics.light()
        return kk_popViewController(animated: animated)
    }
}
