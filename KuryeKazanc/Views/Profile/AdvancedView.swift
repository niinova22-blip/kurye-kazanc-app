import SwiftUI

/// Gelismis: kurye icin teknik ekranlar (tarife surumleri ve kaynaklari, kendi tarifem, ayarlar).
struct AdvancedView: View {
    var body: some View {
        List {
            Section {
                NavigationLink { TariffInfoView() } label: {
                    Label("Tarife, kaynak ve kendi tarifem", systemImage: "doc.text.magnifyingglass")
                }
                NavigationLink { PayrollSettingsView() } label: {
                    Label("Hakediş ayarları", systemImage: "slider.horizontal.3")
                }
            } footer: {
                Text("Tarifeler resmî kaynaklardan takip edilir; değişiklikler onaydan geçmeden yayımlanmaz.")
            }
        }
        .navigationTitle("Gelişmiş")
        .navigationBarTitleDisplayMode(.inline)
    }
}
