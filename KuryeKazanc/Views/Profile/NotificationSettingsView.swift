import SwiftUI

/// Profil > Bildirimler: vardiya hatirlatmasi (saatli), gun sonu, haftalik yakit, hedef kutlamasi, tarife degisikligi.
struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var reminders = ReminderScheduler.shared

    var body: some View {
        Form {
            if reminders.status == .denied {
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label("Bildirim izni kapalı — Ayarlar'dan aç", systemImage: "bell.slash")
                    }
                    .accessibilityIdentifier("notifications.denied")
                }
            }
            Section {
                toggle("Vardiya hatırlatması", systemImage: "alarm", isOn: $reminders.isShiftOn, identifier: "notifications.shift")
                if reminders.isShiftOn {
                    DatePicker("Saat", selection: shiftTime, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("notifications.shiftTime")
                }
                toggle("Gün sonu kontrolü (22:00)", systemImage: "moon.stars", isOn: $reminders.isEveningOn,
                       identifier: "notifications.evening")
                toggle("Haftalık yakıt fiyatı (Pazartesi)", systemImage: "fuelpump", isOn: $reminders.isFuelOn,
                       identifier: "notifications.fuel")
            } header: {
                Text("Hatırlatmalar")
            } footer: {
                Text("Vardiyayı başlatmayı ya da günü kaydetmeyi unutmaman için. Hepsi telefonunda planlanır.")
            }
            Section {
                toggle("Günlük hedefe ulaşınca", systemImage: "flag.checkered", isOn: $reminders.isGoalOn,
                       identifier: "notifications.goal")
                toggle("Tarifemde değişiklik olunca", systemImage: "doc.badge.clock", isOn: $reminders.isTariffOn,
                       identifier: "notifications.tariff")
            } header: {
                Text("Haberler")
            }
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reminders.refreshStatus() }
    }

    /// Acilinca once izin istenir; izin verilmezse anahtar kapali kalir.
    private func toggle(_ title: String, systemImage: String, isOn: Binding<Bool>, identifier: String) -> some View {
        Toggle(isOn: Binding(
            get: { isOn.wrappedValue },
            set: { value in
                guard value else { isOn.wrappedValue = false; return }
                Task { @MainActor in
                    if await reminders.ensureAuthorization() { isOn.wrappedValue = true }
                }
            }
        )) {
            Label(title, systemImage: systemImage)
        }
        .accessibilityIdentifier(identifier)
    }

    private var shiftTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminders.shiftMinutes / 60, minute: reminders.shiftMinutes % 60,
                                      second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminders.shiftMinutes = (parts.hour ?? 10) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
