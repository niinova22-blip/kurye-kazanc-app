import SwiftUI

/// Soru balonunun ekrana ozel kisa aciklamasi.
enum HelpScreen {
    case today, earnings, firms, plan

    var title: String {
        switch self {
        case .today: "Bugün"
        case .earnings: "Kazanç"
        case .firms: "Firmalar"
        case .plan: "Plan"
        }
    }

    var lines: [String] {
        switch self {
        case .today:
            ["\"Vardiya başlat\" ile işe çık; her paketi bırakınca ekrana bir kez dokun.",
             "Uygulama paketin saat ve mesafe bandını bulur; bitirince hesap kendiliğinden kaydedilir.",
             "Hedef halkası her dokunuşta dolar; altındaki \"Plan oluştur\" ile hedefini ve günlük paket sayını ayarla.",
             "Vardiyayı başlatmayı unuttuysan \"Elle hesapla\" ile paket, km ve saati gir; bitince bugüne eklensin mi diye sorarız.",
             "Net = kazanç − yakıt (km × tüketim × yakıt fiyatı). Saatlik net en az yarım saat çalışınca gösterilir."]
        case .earnings:
            ["Bitirdiğin vardiyalar ve eklediğin hesaplar buraya kendiliğinden düşer; ayın brütü ve neti güncellenir.",
             "Tutarlar sözleşmenden farklıysa \"Tutarları düzenle\" (kalem) ile kendi değerini gir.",
             "\"Ayrıntılı döküm\" paketleri, km'yi, bonusları ve sabit ücretin güne düşen payını ayrı gösterir."]
        case .firms:
            ["Aynı işi diğer firmalarda yapsaydın ne kazanırdın?",
             "Yemeksepeti ile Paket Taxi kolları aynı iş yüküyle karşılaştırılır; diğer firma kıdemsiz ve en düşük bölgeyle hesaplanır.",
             "Tarife değişiklikleri yakıt fiyatıyla karşılaştırılır."]
        case .plan:
            ["Hedefini gir; firmanın tarifesine göre günde kaç paket ve kaç saat gerektiğini görürsün.",
             "Günlük hedefte gün seçilmez; haftalık ve aylıkta çalışacağın günleri seçersin.",
             "\"Daha iyi yollar\" aynı paraya daha az saatle ulaşmanın yollarını gösterir; dokununca hedefine uygulanır.",
             "Hız kendi kayıtlarından hesaplanır; az kayıt varsa tahmin kullanılır."]
        }
    }
}

/// Tanitimi tekrar acan eylem (RootView ortamdan saglar).
struct ShowIntroAction {
    var action: () -> Void = {}
    func callAsFunction() { action() }
}

private struct ShowIntroKey: EnvironmentKey {
    static let defaultValue = ShowIntroAction()
}

extension EnvironmentValues {
    var showIntro: ShowIntroAction {
        get { self[ShowIntroKey.self] }
        set { self[ShowIntroKey.self] = newValue }
    }
}

/// Ust cubuktaki soru balonu: "Uygulamayi tani" (tanitimi tekrar oynatir) ve "Bu ekran ne gosteriyor?".
struct HelpBubble: ToolbarContent {
    let screen: HelpScreen
    @Binding var showsScreenHelp: Bool
    let showIntro: ShowIntroAction

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("Uygulamayı tanı", systemImage: "play.circle") { showIntro() }
                Button("Bu ekran ne gösteriyor?", systemImage: "text.bubble") { showsScreenHelp = true }
            } label: {
                Image(systemName: "questionmark.bubble")
            }
            .accessibilityLabel("Yardım")
            .accessibilityIdentifier("help.bubble")
        }
    }
}

struct ScreenHelpSheet: View {
    let screen: HelpScreen
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(screen.lines, id: \.self) { line in
                Label(line, systemImage: "lightbulb")
            }
            .navigationTitle(screen.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamam") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
