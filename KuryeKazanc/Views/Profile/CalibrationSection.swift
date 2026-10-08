import SwiftUI

/// Profil > Kalibrasyon: maskelenmis OCR satirlarini gondermek icin ayri acik riza.
struct CalibrationSection: View {
    @Environment(SyncCoordinator.self) private var sync

    @AppStorage(AppPreferences.calibrationOptInKey) private var calibrationOptIn = false
    @State private var showConsentSheet = false

    var body: some View {
        Section {
            // Liste icinde Section'a eklenen degistiriciler her satira uygulanabilir: sheet anahtar satirinda durur.
            Toggle("Kalibrasyona katıl", isOn: enabledBinding)
                .accessibilityIdentifier("profile.calibration")
                .sheet(isPresented: $showConsentSheet) {
                    CalibrationConsentView {
                        setConsent(true)
                    }
                }
        } header: {
            Text("Kalibrasyon")
        } footer: {
            Text("Platform ekranlarını tanımamıza yardım eder.")
        }
    }

    /// Acmak once riza ekranini gosterir (onaysiz acilmaz); kapatmak hemen kapatir.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { calibrationOptIn },
            set: { newValue in
                if newValue {
                    showConsentSheet = true
                } else {
                    setConsent(false)
                }
            }
        )
    }

    /// Riza anahtari ONCE yazilir; koordinator kuyrugu bu degere gore bosaltir.
    private func setConsent(_ enabled: Bool) {
        calibrationOptIn = enabled
        sync.calibrationConsentChanged(enabled: enabled)
    }
}
