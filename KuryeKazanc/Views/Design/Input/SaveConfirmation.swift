import SwiftUI

/// Kaydet sonrasi cizilen onay isareti + basari titresimi; 0,9 sn sonra kaybolur.
struct SaveConfirmationOverlay: View {
    @Binding var isPresented: Bool
    @State private var trim: CGFloat = 0

    var body: some View {
        if isPresented {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 110, height: 110)
                CheckShape()
                    .trim(from: 0, to: trim)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .frame(width: 48, height: 40)
            }
            .transition(.scale.combined(with: .opacity))
            .onAppear(perform: play)
            .accessibilityElement()
            .accessibilityLabel("Kaydedildi")
            .accessibilityIdentifier("saveConfirmation")
        }
    }

    private func play() {
        Haptics.success()
        trim = 0
        withAnimation(.easeOut(duration: 0.35)) { trim = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation { isPresented = false }
        }
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

extension View {
    func saveConfirmation(isPresented: Binding<Bool>) -> some View {
        overlay { SaveConfirmationOverlay(isPresented: isPresented) }
    }
}
