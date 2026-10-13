import SwiftUI

/// Sayfanin en altindaki TEK "dogrulanmadi" notu. Kalem yoksa hic gorunmez; dokununca kalem listesi acilir.
struct VerificationFootnote: View {
    let items: [UnverifiedItem]

    var body: some View {
        if !items.isEmpty {
            Section {
                NavigationLink {
                    UnverifiedItemsList(items: items)
                } label: {
                    Label {
                        Text("Bu sayfadaki bazı tarife değerleri henüz firmanın resmi kaynağıyla doğrulanmadı; sonuçlar tahminidir.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("verificationFootnote")
            }
        }
    }
}

private struct UnverifiedItemsList: View {
    let items: [UnverifiedItem]

    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Doğrulanmamış değerler")
        .navigationBarTitleDisplayMode(.inline)
    }
}
