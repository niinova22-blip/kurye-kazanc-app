import Foundation
import Observation
import UserNotifications

/// 1.10 hatirlatmalar: vardiya hatirlatmasi (her gun secilen saatte), gun sonu kontrolu (22:00), haftalik yakit fiyati,
/// gunluk hedefe ulasinca kutlama ve yeni tarife bildirimi. Hepsi cihazda planlanir; sunucu yok.
/// UI testlerinde hicbir sey planlanmaz ve izin istenmez.
@MainActor
@Observable
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    enum Key {
        static let shift = "reminders.shift"
        static let shiftMinutes = "reminders.shiftMinutes"
        static let evening = "reminders.evening"
        static let fuel = "reminders.fuel"
        static let goal = "reminders.goal"
        static let tariff = "reminders.tariff"
        static let goalNotifiedDay = "reminders.goalNotifiedDay"
        static let notifiedTariffCount = "reminders.notifiedTariffCount"
    }

    private enum ID {
        static let shift = "reminder.shift"
        static let evening = "reminder.evening"
        static let fuel = "reminder.fuel"
        static let goal = "reminder.goal"
        static let tariff = "reminder.tariff"
    }

    /// Bildirim izni durumu (ayarlar ekrani gosterir).
    private(set) var status: UNAuthorizationStatus = .notDetermined

    var isShiftOn: Bool { didSet { store(isShiftOn, Key.shift) } }
    /// Vardiya hatirlatmasinin saati (gece yarisindan dakika). Varsayilan 10:00.
    var shiftMinutes: Int { didSet { defaults.set(shiftMinutes, forKey: Key.shiftMinutes); reschedule() } }
    var isEveningOn: Bool { didSet { store(isEveningOn, Key.evening) } }
    var isFuelOn: Bool { didSet { store(isFuelOn, Key.fuel) } }
    var isGoalOn: Bool { didSet { store(isGoalOn, Key.goal) } }
    var isTariffOn: Bool { didSet { store(isTariffOn, Key.tariff) } }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let isDisabled: Bool
    private var center: UNUserNotificationCenter { .current() }

    init(defaults: UserDefaults = .standard, isDisabled: Bool = LaunchOptions.current.isUITesting) {
        self.defaults = defaults
        self.isDisabled = isDisabled
        isShiftOn = defaults.object(forKey: Key.shift) as? Bool ?? false
        shiftMinutes = defaults.object(forKey: Key.shiftMinutes) as? Int ?? 10 * 60
        isEveningOn = defaults.object(forKey: Key.evening) as? Bool ?? false
        isFuelOn = defaults.object(forKey: Key.fuel) as? Bool ?? false
        isGoalOn = defaults.object(forKey: Key.goal) as? Bool ?? true
        isTariffOn = defaults.object(forKey: Key.tariff) as? Bool ?? true
    }

    var isAuthorized: Bool { status == .authorized || status == .provisional || status == .ephemeral }
    /// Kullanici hic acmadiysa (Bugun'deki ipucu bildirimleri onerir).
    var hasAnyScheduled: Bool { isShiftOn || isEveningOn || isFuelOn }

    func refreshStatus() async {
        guard !isDisabled else { return }
        status = await center.notificationSettings().authorizationStatus
    }

    /// Izin ister; verilirse onerilen hatirlatmalar (vardiya, gun sonu, yakit) acilir.
    @discardableResult
    func enableRecommended() async -> Bool {
        guard !isDisabled else { return false }
        let granted: Bool = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshStatus()
        guard granted else { return false }
        isShiftOn = true
        isEveningOn = true
        isFuelOn = true
        return true
    }

    /// Bir anahtar acilinca izin yoksa once izin istenir.
    func ensureAuthorization() async -> Bool {
        guard !isDisabled else { return false }
        await refreshStatus()
        if isAuthorized { return true }
        let granted: Bool = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshStatus()
        return granted
    }

    // MARK: - Planlama

    /// Tekrarlayan hatirlatmalari ayarlara gore yeniden kurar.
    func reschedule() {
        guard !isDisabled else { return }
        center.removePendingNotificationRequests(withIdentifiers: [ID.shift, ID.evening, ID.fuel])
        if isShiftOn {
            add(id: ID.shift, title: "Vardiyaya çıkıyor musun?",
                body: "Başlarken “Vardiya başlat”a dokun; her paketi tek dokunuşla say, kazancın kendiliğinden hesaplansın.",
                hour: shiftMinutes / 60, minute: shiftMinutes % 60)
        }
        if isEveningOn {
            add(id: ID.evening, title: "Gün bitti mi?",
                body: "Bugünün kazancını kontrol et. Vardiyayı başlatmayı unuttuysan “Elle hesapla” ile ekle.",
                hour: 22, minute: 0)
        }
        if isFuelOn {
            add(id: ID.fuel, title: "Yakıt fiyatı güncel mi?",
                body: "Net kazancın yakıt fiyatıyla hesaplanıyor. Fiyat değiştiyse Profil > Araç ve yakıt'tan güncelle.",
                hour: 9, minute: 30, weekday: 2)
        }
    }

    /// Gunluk hedefe ulasilinca gunde bir kez.
    func goalReached(day: String) {
        guard !isDisabled, isGoalOn, defaults.string(forKey: Key.goalNotifiedDay) != day else { return }
        defaults.set(day, forKey: Key.goalNotifiedDay)
        immediate(id: ID.goal, title: "Bugünkü hedefe ulaştın 🎉",
                  body: "Planladığın paket sayısını tamamladın. Devam edersen her paket hedefin üstüne yazılır.")
    }

    /// Okunmamis tarife bildirimi sayisi arttiysa bir kez haber verir.
    func tariffNotices(unread: Int) {
        guard !isDisabled else { return }
        // Ilk acilista mevcut bildirimler icin haber verilmez; yalnizca sonradan gelenler
        guard defaults.object(forKey: Key.notifiedTariffCount) != nil else {
            defaults.set(unread, forKey: Key.notifiedTariffCount)
            return
        }
        let notified: Int = defaults.integer(forKey: Key.notifiedTariffCount)
        defer { defaults.set(unread, forKey: Key.notifiedTariffCount) }
        guard isTariffOn, unread > notified else { return }
        immediate(id: ID.tariff, title: "Tarifende değişiklik var",
                  body: "Firmanın ücretlerinde yeni bir bildirim var. Kazanç > Tarife bildirimleri'nden bak.")
    }

    // MARK: - Yardimcilar

    private func store(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
        reschedule()
    }

    private func add(id: String, title: String, body: String, hour: Int, minute: Int, weekday: Int? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.weekday = weekday
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func immediate(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
