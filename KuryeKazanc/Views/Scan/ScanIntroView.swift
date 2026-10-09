import SwiftUI

/// Kazanc taramasi ilk kullanim tanitimi: uc adim ve gizlilik notu.
struct ScanIntroView: View {
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    stepRow("1", "Taramayı başlat")
                    stepRow("2", "Platform uygulamalarında kazanç panelini aç, birkaç saniye bekle, kapat")
                    stepRow("3", "Durdurunca bulunanları onaylarsın")
                } footer: {
                    Text("Görüntü saklanmaz, yalnızca okunan rakamlar.")
                }
                Section {
                    Button("Anladım, başlat", action: onStart)
                        .buttonStyle(PrimaryActionButtonStyle(isDestructive: false))
                        .accessibilityIdentifier("scan.intro.start")
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Kazanç taraması")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func stepRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text(text)
        }
    }
}
