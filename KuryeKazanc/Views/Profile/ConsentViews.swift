import SwiftUI

/// Acik onay ekranlarinin ortak iskeleti: ne paylasilir, ne asla paylasilmaz.
private struct ConsentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let purpose: String
    let shared: [String]
    let never: [String]
    let note: String
    let acceptIdentifier: String
    let onAccept: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title2.bold())
                        Text(purpose)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("Paylaşılacaklar") {
                    ForEach(shared, id: \.self) { item in
                        Label(item, systemImage: "checkmark")
                    }
                }
                Section {
                    ForEach(never, id: \.self) { item in
                        Label(item, systemImage: "xmark")
                    }
                } header: {
                    Text("Asla paylaşılmayacaklar")
                } footer: {
                    Text(note)
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Onaylıyorum") {
                        onAccept()
                        dismiss()
                    }
                    .accessibilityIdentifier(acceptIdentifier)
                }
            }
        }
    }
}

/// Kalibrasyon ornegi gonderimi icin ayri acik riza.
struct CalibrationConsentView: View {
    let onAccept: () -> Void

    var body: some View {
        ConsentSheet(
            title: "Kalibrasyon",
            purpose: "Amaç: platform kazanç ekranlarını daha doğru tanımamız. Yalnızca kazanç formunda “Kalibrasyona gönder”e dokunduğunda gönderilir.",
            shared: [
                "Ekran görüntüsünden okunan metin satırları (maskelenmiş)",
                "Satırların ekrandaki konumları (kutular)",
                "Platform ve tanınan şablon adı",
            ],
            never: [
                "Ekran görüntüsünün kendisi (görsel)",
                "IBAN, telefon numarası, TC kimlik numarası, e-posta (gönderilmeden önce maskelenir)",
                "Uygulamadaki adın ve profil bilgilerin",
            ],
            note: "Ekranda adın veya kurye numaran yazıyorsa o ekranı gönderme: isimler otomatik maskelenmez. İstediğin an kapatabilirsin; bekleyen örnekler gönderilmeden silinir. Gönderilmiş örneklerini Profil > Verilerimi sil ile sunucudan sildirebilirsin.",
            acceptIdentifier: "consent.calibration.accept",
            onAccept: onAccept
        )
    }
}
