import SwiftUI

/// Bugun sekmesindeki "Kazanç taraması" düğmesi: her basışta rehber sayfasını açar.
/// (Yayin secicisi kaldirildi; yayin eklentisi hedefi ve kodu duruyor ama kullanilmiyor.)
struct ScanButton: View {
    @State private var showGuide = false

    var body: some View {
        Button {
            showGuide = true
        } label: {
            Label("Kazanç taraması", systemImage: "text.viewfinder")
        }
        .accessibilityIdentifier("scan.button")
        .sheet(isPresented: $showGuide) {
            ScanGuideView()
        }
    }
}
