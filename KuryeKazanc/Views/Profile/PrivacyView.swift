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

    /// 1.13: guncel durum (paylasim ve kalibrasyon 1.8 / 1.10'da kalkti). Ayni metin: site/gizlilik.html.
    private static let sections: [PrivacySection] = [
        PrivacySection(
            title: "Kısaca",
            body: "Kurye Kazanç reklam göstermez, seni takip etmez ve verilerini satmaz. Kayıtların telefonunda durur; yalnızca Apple ile giriş yaparsan yedeklenir."
        ),
        PrivacySection(
            title: "Telefonunda kalanlar",
            body: "Kazanç ve gider kayıtların, vardiyaların, hedeflerin, tarife ve yakıt ayarların yalnızca telefonunda saklanır. Vardiya sırasında konum km'ni, çalıştığın tarife bölgesini ve teslimat mesafesini hesaplamak için kullanılır; tam konum (koordinat) saklanmaz, yalnızca il / ilçe / semt adı kayda yazılır. Seçtiğin ekran görüntüsü telefonunda okunur; görselin kendisi saklanmaz ve gönderilmez."
        ),
        PrivacySection(
            title: "Apple ile giriş yaparsan",
            body: "Kayıtlarını yeni telefona taşıyabilmen için yedek alınır: Apple'ın bu uygulamaya özel verdiği kullanıcı kimliği, kazanç ve gider kayıtların (kayıtlardaki il / ilçe / semt dahil), hedeflerin ve ayarların. Ad ve e-posta istenmez. Giriş yapmazsan hiçbir kaydın sunucuya gönderilmez."
        ),
        PrivacySection(
            title: "Hizmet sağlayıcılar",
            body: "Yedek, Supabase üzerinde Avrupa Birliği'nde (Frankfurt, Almanya) barındırılır; bu yurt dışına aktarım sayılır ve Apple ile giriş yaparken buna da onay vermiş olursun (KVKK m.9). İlçe adını bulmak için konum, Apple'ın konum hizmetine (ters coğrafi kodlama) gönderilir. Güncel tarifeler sunucudan indirilir; bu sırada kişisel veri gönderilmez. Analitik, reklam ya da takip aracı yoktur."
        ),
        PrivacySection(
            title: "Amaç ve hukuki sebep",
            body: "Kazancını firmanın güncel tarifesiyle hesaplamak ve istersen kayıtlarını yedeklemek. Yedek, Apple ile giriş yaparak verdiğin açık rızaya dayanır (KVKK m.5/1); rızanı istediğin an hesabını silerek geri alabilirsin."
        ),
        PrivacySection(
            title: "Saklama süresi",
            body: "Yedeğin, yeni yedekle değiştirilene ya da hesabını silene kadar tutulur. Hesabını silince yedeğin ve hesabın kalıcı olarak silinir."
        ),
        PrivacySection(
            title: "Hakların (KVKK m.11)",
            body: "Verilerinin işlenip işlenmediğini öğrenme, bilgi isteme, amacını öğrenme, aktarıldığı üçüncü kişileri bilme, düzeltilmesini ve silinmesini isteme, bunların aktarılanlara bildirilmesini isteme, otomatik analiz sonucuna itiraz etme ve zararın giderilmesini talep etme haklarına sahipsin."
        ),
        PrivacySection(
            title: "Silme",
            body: "Profil > Hesap > “Hesabımı ve verilerimi sil”: hesabın ve sunucudaki tüm verilerin kalıcı olarak silinir. Profil > “Tüm kayıtları sil”: telefondaki kayıtların silinir. Uygulamayı silmek de telefondaki tüm verileri siler."
        ),
        PrivacySection(
            title: "İletişim",
            body: "Soru ve talepler için: \(PrivacyView.supportURL.absoluteString)"
        ),
    ]

    static let supportURL = URL(string: "https://niinova22-blip.github.io/kurye-kazanc/")!
    static let policyURL = URL(string: "https://niinova22-blip.github.io/kurye-kazanc/gizlilik.html")!
}
