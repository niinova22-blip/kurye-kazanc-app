import SwiftUI

/// Profil > Hakkinda > Gizlilik ve KVKK. Web surumu: site/gizlilik.html (App Store gizlilik politikasi adresi).
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(PrivacyView.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Link(destination: PrivacyView.policyURL) {
                    Label("Gizlilik politikasını web'de aç", systemImage: "safari")
                }
                .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Gizlilik ve KVKK")
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct PrivacySection {
        let title: String
        let body: String
    }

    /// 1.15.1: sunucu yok; hesap, giris ve yedek kalkti. Ayni metin: site/gizlilik.html.
    private static let sections: [PrivacySection] = [
        PrivacySection(
            title: "Kısaca",
            body: "Kurye Kazanç reklam göstermez, seni takip etmez ve verilerini satmaz. Hesap açman gerekmez; kayıtların yalnızca telefonunda durur ve bize gönderilmez."
        ),
        PrivacySection(
            title: "Telefonunda kalanlar",
            body: "Kazanç ve gider kayıtların, vardiyaların, hedeflerin, tarife ve yakıt ayarların yalnızca telefonunda saklanır. Vardiya sırasında konum km'ni, çalıştığın tarife bölgesini ve teslimat mesafesini hesaplamak için kullanılır; tam konum (koordinat) saklanmaz, yalnızca il / ilçe / semt adı kayda yazılır. Seçtiğin ekran görüntüsü telefonunda okunur; görselin kendisi saklanmaz ve gönderilmez."
        ),
        PrivacySection(
            title: "Satın alımlar",
            body: "Kurye Kazanç Pro ve 14 günlük ücretsiz deneme App Store üzerinden alınır; ödemeyi Apple işler. Kart ya da ödeme bilgin bize hiç ulaşmaz. Pro'nun açık olup olmadığı telefonunda Apple'ın satın alma kaydından kontrol edilir. Aboneliğini Ayarlar > Apple Hesabı > Abonelikler'den yönetebilir ya da iptal edebilirsin."
        ),
        PrivacySection(
            title: "Hizmet sağlayıcılar",
            body: "Sunucumuz yoktur. İlçe adını bulmak için konum, Apple'ın konum hizmetine (ters coğrafi kodlama) gönderilir. Tarifeler uygulamanın içindedir ve uygulama güncellemeleriyle yenilenir. Analitik, reklam ya da takip aracı yoktur."
        ),
        PrivacySection(
            title: "Amaç",
            body: "Kazancını firmanın tarifesiyle telefonunda hesaplamak. Kişisel verilerin bize aktarılmaz."
        ),
        PrivacySection(
            title: "Saklama süresi",
            body: "Kayıtların sen silene ya da uygulamayı kaldırana kadar telefonunda tutulur."
        ),
        PrivacySection(
            title: "Hakların (KVKK m.11)",
            body: "Verilerinin işlenip işlenmediğini öğrenme, bilgi isteme, amacını öğrenme, aktarıldığı üçüncü kişileri bilme, düzeltilmesini ve silinmesini isteme, bunların aktarılanlara bildirilmesini isteme, otomatik analiz sonucuna itiraz etme ve zararın giderilmesini talep etme haklarına sahipsin."
        ),
        PrivacySection(
            title: "Silme",
            body: "Profil > “Tüm kayıtları sil”: telefondaki kayıtların silinir. Uygulamayı silmek de telefondaki tüm verileri siler."
        ),
        PrivacySection(
            title: "İletişim",
            body: "Soru ve talepler için: \(PrivacyView.supportURL.absoluteString)"
        ),
    ]

    static let supportURL = URL(string: "https://niinova22-blip.github.io/kurye-kazanc/")!
    static let policyURL = URL(string: "https://niinova22-blip.github.io/kurye-kazanc/gizlilik.html")!
}
