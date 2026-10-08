import SwiftUI

/// 1.4'te ilce karsilastirmasi ve harita gelecek. Simdilik ne gelecegini anlatan sade ekran.
struct CommunityView: View {
    @AppStorage(AppPreferences.dataSharingOptInKey) private var sharing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.accent)
                            .accessibilityHidden(true)
                        Text("Bölgendeki kuryelerle karşılaştır")
                            .font(.title3.weight(.semibold))
                        Text("İlçende saat başı ortalama net kazanç, en yoğun saatler ve kazanç haritası. Yalnızca ekran görüntüsünden okunup değiştirilmeyen kayıtlar kullanılır.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                Section {
                    if sharing {
                        Label("Paylaşım açık. Topluluk özellikleri açıldığında burada görünecek.", systemImage: "checkmark.circle")
                            .foregroundStyle(Theme.accent)
                    } else {
                        Label("Görmek için Profil'den anonim paylaşımı aç.", systemImage: "person.badge.shield.checkmark")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Kimsenin kazancı tek başına görünmez: bir bölge en az 5 farklı kuryeden veri gelmeden gösterilmez.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Topluluk")
            .accessibilityIdentifier("community.root")
        }
    }
}
