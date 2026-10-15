import SwiftUI

/// 1.12.2 Bugun: gunluk / haftalik / aylik toplam paket ve prim / bonus kademesi.
/// Paket Taxi: gunluk prim + aylik bonus (hafta yalnizca sayac). Yemeksepeti: gunluk + haftalik bonus (aylik yok).
struct BonusTrackSection: View {
    let tracks: [BonusTrack]

    var body: some View {
        if !tracks.isEmpty {
            Section {
                ForEach(tracks) { track in
                    BonusTrackRow(track: track)
                }
            } header: {
                Text("Paket sayacı")
            } footer: {
                Text(footer)
            }
        }
    }

    private var footer: String {
        var parts: [String] = ["Gün 00:00'da"]
        if tracks.contains(where: { $0.scope == .week }) { parts.append("hafta Pazartesi") }
        if tracks.contains(where: { $0.scope == .month }) { parts.append("ay 1'inde") }
        return parts.joined(separator: ", ") + " sıfırlanır. Prim / bonus o dönemin TOPLAM paketine göre tek kademe ödenir."
    }
}

private struct BonusTrackRow: View {
    let track: BonusTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(track.scope.title).font(.headline)
                Spacer()
                Text("\(Formatters.groupedInt(track.packages)) paket")
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("bonusTrack.\(track.scope.rawValue).packages")
            }
            if track.hasBonus {
                if let label = track.reachedLabel, !track.reached.isZero {
                    Label("\(label): \(PayFormat.tl(track.reached))", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.positive)
                } else {
                    Text(noneText).font(.subheadline).foregroundStyle(.secondary)
                }
                if let next = track.next {
                    ProgressView(value: Double(track.packages), total: Double(max(1, next.target)))
                        .tint(Theme.accent)
                    Text("\(Formatters.groupedInt(next.target)). pakete \(Formatters.groupedInt(next.remaining)) paket kaldı → \(PayFormat.tl(next.reward))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Bu firmada \(track.scope == .week ? "haftalık" : "aylık") bonus yok; yalnızca sayaç.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var noneText: String {
        switch track.scope {
        case .day: "Henüz günlük prim kademesine ulaşılmadı."
        case .week: "Henüz haftalık bonus kademesine ulaşılmadı."
        case .month: "Henüz aylık bonus kademesine ulaşılmadı."
        }
    }
}
