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

/// Kazanc paylasimi icin acik riza.
struct DataSharingConsentView: View {
    let onAccept: () -> Void

    var body: some View {
        ConsentSheet(
            title: "Anonim kazanç paylaşımı",
            purpose: "Amaç: kuryelerin bölge ve platform bazında gerçek net kazançlarını görebilmesi.",
            shared: [
                "Kazanç, bonus, paket sayısı (yalnızca ekran görüntüsünden okunup değiştirilmeyen kayıtlar)",
                "Çalışma süresi ve mesafe (yuvarlanmış)",
                "Platform, il, ilçe ve araç türü",
                "Haftanın günü ve 15 dakikalık zaman dilimi",
                "Konum yoğunluğu: vardiyada bulunduğun ~500 m'lik bölge hücreleri (sonraki sürümde; Profil'den ayrıca kapatılabilir)",
            ],
            never: [
                "Adın ve profil bilgilerin",
                "Ekran görüntülerinin kendisi",
                "Semt ve tam konumun",
                "Telefon numarası, e-posta",
            ],
            note: "Onaydan sonra kaydettiğin uygun vardiyalar gönderilir; geçmiş kayıtlar gönderilmez. Topluluk özellikleri açıldığında bölgendeki kuryelerle karşılaştırmayı görürsün. İstediğin an kapatabilirsin; bekleyen gönderimler silinir. Gönderilmiş vardiyalarını Profil > Verilerimi sil ile sunucudan sildirebilirsin.",
            acceptIdentifier: "consent.accept",
            onAccept: onAccept
        )
    }
}

/// Konum yogunlugu paylasimi icin ayri acik riza.
struct LocationSharingConsentView: View {
    let onAccept: () -> Void

    var body: some View {
        ConsentSheet(
            title: "Konum yoğunluğu",
            purpose: "Amaç: hangi bölgede, hangi saatte kurye yoğunluğu olduğunu gösteren haritayı oluşturmak.",
            shared: [
                "Vardiya sırasında bulunduğun ~500 m'lik bölge hücreleri",
                "Tarih ve 15 dakikalık zaman dilimi",
                "Hücrede geçen ve durarak geçen süre",
            ],
            never: [
                "Ham GPS koordinatı veya güzergâh",
                "Vardiyanın ilk ve son 10 dakikası (evinin bulunamaması için)",
                "Hesabınla bağlantı (her hafta değişen takma kimlik kullanılır)",
            ],
            note: "Konum verisi hesabına bağlı olmadığı için sonradan tek tek silinemez. Konum yoğunluğu bu sürümde henüz gönderilmiyor; onayın kaydedilir.",
            acceptIdentifier: "consent.location.accept",
            onAccept: onAccept
        )
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
