import SwiftUI

/// Profil > Hakkinda > Gizlilik ve KVKK: `docs/legal` taslaklarinin uygulama ici kisa surumu.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Taslak — hukuki inceleme bekliyor", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("privacy.draftNote")

                ForEach(PrivacyView.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
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

    private static let sections: [PrivacySection] = [
        PrivacySection(
            title: "Veri sorumlusu",
            body: "[Veri sorumlusu]. 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında veri sorumlusudur."
        ),
        PrivacySection(
            title: "Cihazında kalanlar",
            body: "Kazanç ve gider kayıtların, profilin, hedeflerin ve vardiya konumların telefonunda saklanır; Apple ile giriş yapmadıkça yedeklenmez, vardiya konumların hiç gönderilmez. Ekran görüntüleri cihazında işlenir; görselin kendisi hiçbir zaman saklanmaz ve gönderilmez."
        ),
        PrivacySection(
            title: "Açık rızanla işlenenler",
            body: "Kazanç paylaşımı (açarsan): platform, il ve ilçe, araç türü, haftanın günü, 15 dakikalık başlangıç dilimi, süre, brüt kazanç, bonus, paket sayısı, yuvarlanmış mesafe, doğrulama seviyesi, şablon bilgisi, ekran metninin özeti (aynı kaydın iki kez sayılmaması için) ve kaydın rastgele kimliği. Yalnızca ekran görüntüsünden okunup değiştirilmeyen kayıtlar gönderilir; elle girilen veya okunan değeri düzeltilen kayıtlar gönderilmez.\n\nKalibrasyon (açarsan, yalnızca “Kalibrasyona gönder”e dokunduğunda): maskelenmiş OCR satırları, ekrandaki konumları, platform ve şablon adı. IBAN, telefon, TC kimlik numarası ve e-posta gönderilmeden önce maskelenir; ekranda yazan ad veya kurye numarası maskelenmez.\n\nHesap ve yedek (Apple ile giriş yaparsan): Apple'ın bu uygulamaya özel verdiği kullanıcı kimliği; kayıtların ve ayarların yedeği. Ad ve e-posta istenmez.\n\nGönderimler, cihazında rastgele oluşturulan bir kullanıcı kimliğiyle yapılır; adın, telefon numaran veya e-postan bu kimliğe bağlanmaz. Konum yoğunluğu bu sürümde gönderilmez."
        ),
        PrivacySection(
            title: "Amaç",
            body: "Kuryelerin bölge ve platform bazında gerçek net kazançlarını karşılaştırabilmesi, kazanç ekranlarının daha doğru tanınması ve istersen kayıtlarının yeni telefona taşınabilmesi."
        ),
        PrivacySection(
            title: "Hukuki sebep",
            body: "Açık rıza (KVKK m.5/1). Her paylaşım türü için ayrı onay istenir; onay vermezsen uygulama aynen çalışır ve hiçbir veri gönderilmez."
        ),
        PrivacySection(
            title: "Yurt dışına aktarım",
            body: "Veriler Avrupa Birliği'nde (Supabase, Frankfurt — Almanya) barındırılır. Bu, yurt dışına aktarım sayılır; ilgili paylaşımı açarken verdiğin onay bu aktarıma da açık rızanı içerir (KVKK m.9)."
        ),
        PrivacySection(
            title: "Saklama süresi",
            body: "Gönderilen veriler, sen silene ya da hizmet sona erene kadar saklanır. Yedeğin, “Verilerimi sil” ile ya da yeni yedekle değiştirilinceye kadar tutulur."
        ),
        PrivacySection(
            title: "Hakların (KVKK m.11)",
            body: "Verilerinin işlenip işlenmediğini öğrenme, bilgi isteme, amacını öğrenme, aktarıldığı üçüncü kişileri bilme, düzeltilmesini ve silinmesini isteme, bunların aktarılanlara bildirilmesini isteme, otomatik analiz sonucuna itiraz etme ve zararın giderilmesini talep etme haklarına sahipsin."
        ),
        PrivacySection(
            title: "Başvuru ve silme",
            body: "Profil > Hesap ve yedek > “Verilerimi sil” sunucudaki gönderilmiş vardiyalarını, kalibrasyon örneklerini ve yedeğini siler, paylaşımları kapatır. Telefondaki kayıtların silinmez. Diğer talepler için: [Başvuru adresi]."
        ),
    ]
}
