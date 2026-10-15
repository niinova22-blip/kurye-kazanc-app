import SwiftUI

/// Profil > Ses ve titreşim (1.12.1).
struct FeedbackSettingsView: View {
    @AppStorage(AppPreferences.hapticsEnabledKey) private var haptics = true
    @AppStorage(AppPreferences.packageSoundKey) private var packageSound = true
    @AppStorage(AppPreferences.notificationSoundKey) private var notificationSound = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $haptics) {
                    Label("Titreşim", systemImage: "iphone.radiowaves.left.and.right")
                }
                .accessibilityIdentifier("feedback.haptics")
                .onChange(of: haptics) { _, isOn in if isOn { Haptics.impact() } }
            } footer: {
                Text("Düğmelerde, geri tuşunda, sekme değişiminde ve her pakette hafif titreşim.")
            }
            Section {
                Toggle(isOn: $packageSound) {
                    Label("Paket ve kayıt sesi", systemImage: "speaker.wave.2")
                }
                .accessibilityIdentifier("feedback.packageSound")
                .onChange(of: packageSound) { _, isOn in if isOn { AppSounds.package() } }
                Toggle(isOn: $notificationSound) {
                    Label("Bildirim sesi", systemImage: "bell.and.waves.left.and.right")
                }
                .accessibilityIdentifier("feedback.notificationSound")
            } header: {
                Text("Ses")
            } footer: {
                Text("Paket sesi vardiya ekranında her dokunuşta ve vardiya bitince çalar (telefon sessizdeyse çalmaz). Bildirim sesi kapalıysa hatırlatmalar sessiz gelir; yeni planlananlar için geçerlidir.")
            }
        }
        .navigationTitle("Ses ve titreşim")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: notificationSound) { _, _ in
            // Planli hatirlatmalar yeni sesle yeniden kurulur
            ReminderScheduler.shared.reschedule()
        }
    }
}
