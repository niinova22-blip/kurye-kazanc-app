import SwiftUI
import ReplayKit

/// Bugun sekmesindeki "Kazanç taraması" düğmesi: ilk seferde tanıtım, sonra sistem yayın seçicisi.
struct ScanButton: View {
    @AppStorage("scanIntroSeen") private var introSeen = false
    @State private var showIntro = false
    @State private var startAfterIntro = false
    @State private var triggerCount = 0
    @State private var showHint = false

    var body: some View {
        Button(action: tapped) {
            Label("Kazanç taraması", systemImage: "dot.radiowaves.left.and.right")
        }
        .background(pickerView)
        .accessibilityIdentifier("scan.button")
        .alert("Tarama başlatılamadı", isPresented: $showHint) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Denetim Merkezi'nden Ekran Kaydı'na uzun bas → Kurye Kazanç Tarama")
        }
        .sheet(isPresented: $showIntro, onDismiss: introDismissed) {
            ScanIntroView(onStart: introStarted)
                .presentationDetents([.medium, .large])
        }
    }

    private var pickerView: some View {
        BroadcastPicker(trigger: triggerCount, onMissingButton: { showHint = true })
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
    }

    private func tapped() {
        if introSeen {
            triggerCount += 1
        } else {
            showIntro = true
        }
    }

    private func introStarted() {
        introSeen = true
        startAfterIntro = true
        showIntro = false
    }

    private func introDismissed() {
        guard startAfterIntro else { return }
        startAfterIntro = false
        triggerCount += 1
    }
}

/// Sistem yayın seçicisini görünmez tutar; sayaç artınca iç düğmesine dokunur.
private struct BroadcastPicker: UIViewRepresentable {
    let trigger: Int
    let onMissingButton: () -> Void

    final class Coordinator { var lastTrigger = 0 }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = "com.kuryekazanc.app.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        guard trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        if let button = Self.findButton(in: uiView) {
            button.sendActions(for: .touchUpInside)
        } else {
            onMissingButton()
        }
    }

    private static func findButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton { return button }
        for subview in view.subviews {
            if let found = findButton(in: subview) { return found }
        }
        return nil
    }
}
