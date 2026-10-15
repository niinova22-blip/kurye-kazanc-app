import SwiftUI

/// 1.12.1: aylik sabit ucreti Bugun / vardiya / hedef hesabina kat ya da cikar. Degistirmeden once sorar.
struct FixedPayToggle: View {
    @Environment(PayrollModel.self) private var payroll
    @State private var asks = false

    var body: some View {
        let included: Bool = payroll.includesFixedPay
        Button {
            Haptics.selection()
            asks = true
        } label: {
            Label(included ? "Sabit ücret dahil" : "Sabit ücret hariç · yalnızca paket ve bonus",
                  systemImage: included ? "checkmark.circle.fill" : "circle.slash")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.18), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fixedPay.toggle")
        .confirmationDialog(included ? "Sabit ücreti hesaptan çıkar?" : "Sabit ücreti hesaba kat?",
                            isPresented: $asks, titleVisibility: .visible) {
            Button(included ? "Çıkar ve yeniden hesapla" : "Kat ve yeniden hesapla") {
                payroll.setIncludesFixedPay(!included)
                Haptics.success()
            }
            .accessibilityIdentifier("fixedPay.confirm")
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(included
                 ? "Bugün, vardiya ve günlük hedef yalnızca paket, bonus ve giderlerle yeniden hesaplanacak. Sabit ücretin yine ay sonunda ödenir; istediğin an geri katabilirsin."
                 : "Aylık sabit ücretin bugüne düşen payı yeniden kazancına ve günlük hedefe eklenecek.")
        }
    }
}
