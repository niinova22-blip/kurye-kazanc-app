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
            ["Hedefinden bugüne düşen paket ve saat payını gösterir.",
             "+ ile ekran görüntüsünden ya da elle kazanç ve gider eklersin.",
             "Net = kazanç − yakıt (km × tüketim × yakıt fiyatı)."]
        case .earnings:
            ["Gün, hafta ya da ay için brüt, gider ve net.",
             "Hakediş kayıtları firmanın tarifesiyle hesaplanır."]
        case .firms:
            ["Aynı işi diğer firmalarda yapsaydın ne kazanırdın?",
             "Diğer firmalar yeni başlayan kademesiyle hesaplanır.",
             "Tarife değişiklikleri yakıt fiyatıyla karşılaştırılır."]
        case .plan:
            ["Hedefini gir; firmanın tarifesine göre gereken paket, saat ve bölgeyi görürsün.",
             "Hız kendi kayıtlarından hesaplanır; az kayıt varsa varsayım kullanılır."]
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
