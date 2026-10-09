import SwiftUI
import SwiftData

/// Topluluk: ilce karsilastirmasi, gun x saat isi haritasi, platformlar ve en iyi saatler.
/// Veri yalnizca anonim paylasim aciksa gosterilir; sunucu en az 5 kurye olmayan hucreyi vermez.
struct CommunityView: View {
    @Environment(SyncCoordinator.self) private var sync

    var body: some View {
        CommunityContent(client: sync.communityClient)
    }
}

/// Istemci ortamdan gelir; gorunum modeli bir kez kurulur.
private struct CommunityContent: View {
    @Query(sort: \EarningRecord.startTime, order: .reverse) private var records: [EarningRecord]
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @AppStorage(AppPreferences.dataSharingOptInKey) private var sharing = false
    @State private var model: CommunityViewModel

    init(client: (any SupabaseServing)?) {
        let enabled: Bool = UserDefaults.standard.bool(forKey: AppPreferences.dataSharingOptInKey)
        _model = State(initialValue: CommunityViewModel(client: client, sharingEnabled: enabled))
    }

    private struct LoadKey: Hashable {
        let sharing: Bool
        let district: CommunityViewModel.District?
    }

    private var loadKey: LoadKey {
        LoadKey(sharing: sharing, district: model.selected)
    }

    private var platformNames: [String: String] {
        var names: [String: String] = [:]
        for item in Platform.defaults { names[item.code] = item.name }
        for platform in platforms { names[platform.code] = platform.name }
        return names
    }

    var body: some View {
        NavigationStack {
            List {
                CommunityIntroSection()
                if sharing {
                    sharedContent
                } else {
                    CommunityInviteSection()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Topluluk")
            .accessibilityIdentifier("community.root")
            .refreshable { await model.load() }
            .task(id: loadKey) {
                model.sharingEnabled = sharing
                model.update(records: records)
                await model.load()
            }
            .onChange(of: records.count) {
                model.update(records: records)
            }
        }
    }

    @ViewBuilder
    private var sharedContent: some View {
        if !model.districts.isEmpty {
            districtSection
        }
        switch model.state {
        case .sharingOff, .loading:
            Section { ProgressView().frame(maxWidth: .infinity) }
        case .noDistrict:
            Section { CommunityMessage(text: "Henüz bölge bilgisi olan bir kaydın yok. Konumla kayıt ekledikçe ilçen burada görünür.") }
        case .insufficient:
            Section {
                CommunityMessage(text: "Bu ilçede henüz yeterli veri yok (en az 5 kurye gerekir).")
                    .accessibilityIdentifier("community.insufficient")
            }
        case .failed:
            failedSection
        case .loaded(let summary, let cells):
            CommunityLoadedSections(
                summary: summary, cells: cells, ownPerHour: model.ownPerHour, names: platformNames
            )
        }
    }

    private var districtSection: some View {
        Section {
            Picker("İlçe", selection: $model.selected) {
                ForEach(model.districts, id: \.self) { item in
                    Text(verbatim: item.title).tag(Optional(item))
                }
            }
            .accessibilityIdentifier("community.districtPicker")
        }
    }

    private var failedSection: some View {
        Section {
            CommunityMessage(text: "Topluluk verisi şu an alınamadı. İnternet bağlantını kontrol edip tekrar dene.")
            Button("Tekrar dene") {
                Task { await model.load() }
            }
            .accessibilityIdentifier("community.retry")
        }
    }
}

private struct CommunityMessage: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(.secondary)
    }
}

private struct CommunityIntroSection: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text("Bölgendeki kuryelerle karşılaştır")
                    .font(.title3.weight(.semibold))
                Text("İlçende saat başı ortalama kazanç, en yoğun saatler ve kazanç haritası. Yalnızca ekran görüntüsünden okunup değiştirilmeyen kayıtlar kullanılır.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

private struct CommunityInviteSection: View {
    var body: some View {
        Section {
            Label("Topluluğu görmek için Profil'den anonim paylaşımı aç — veri paylaşan görür.", systemImage: "person.badge.shield.checkmark")
                .foregroundStyle(.secondary)
        } footer: {
            Text("Kimsenin kazancı tek başına görünmez: bir bölge en az 5 farklı kuryeden veri gelmeden gösterilmez.")
        }
    }
}

/// Yuklenen veriden: ozet karti, isi haritasi, platformlar, en iyi saatler.
private struct CommunityLoadedSections: View {
    let summary: CommunitySummary
    let cells: [CommunityCell]
    let ownPerHour: Double?
    let names: [String: String]

    private var heatValues: [HourSlot: Double] {
        var result: [HourSlot: Double] = [:]
        for cell in cells where (1...7).contains(cell.weekday) && (0...23).contains(cell.hour) {
            result[HourSlot(weekday: cell.weekday, hour: cell.hour)] = cell.perHour
        }
        return result
    }

    var body: some View {
        if let average = summary.perHour {
            CommunityAverageSection(average: average, couriers: summary.couriers, ownPerHour: ownPerHour)
        }
        if !heatValues.isEmpty {
            Section {
                HeatmapChart(values: heatValues)
                    .frame(height: 220)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Gün ve saate göre ilçe kazanç ısı haritası")
            } header: {
                Text("Ne zaman çalışmalı")
            } footer: {
                Text("Koyu hücre = saat başı daha yüksek kazanç. Son 8 hafta, brüt + bonus.")
            }
        }
        if !summary.platforms.isEmpty {
            Section("Platformlar") {
                ForEach(summary.platforms, id: \.code) { stat in
                    CommunityPlatformRow(stat: stat, name: names[stat.code] ?? "Diğer")
                }
            }
        }
        if !summary.best.isEmpty {
            Section("İlçenin en iyi saatleri") {
                ForEach(summary.best, id: \.slotKey) { cell in
                    CommunityBestRow(cell: cell)
                }
            }
        }
    }
}

private extension CommunityCell {
    var slotKey: Int { weekday * 100 + hour }
}

private struct CommunityAverageSection: View {
    let average: Double
    let couriers: Int?
    let ownPerHour: Double?

    private var courierText: String {
        guard let couriers else { return "" }
        return String(couriers) + " kurye"
    }

    private var comparison: String {
        guard let own = ownPerHour else {
            return "Son 8 haftada kaydın yok; karşılaştırma için vardiya kaydet."
        }
        let head: String = "Sen: " + Formatters.perHour(own)
        guard let diff = CommunityComparison.percentDifference(own: own, community: average) else { return head }
        let percent: Int = Int(abs(diff).rounded())
        if percent == 0 { return head + " — ilçe ortalamasıyla aynı düzeyde" }
        let direction: String = diff > 0 ? "üstünde" : "altında"
        return head + " — ilçe ortalamasının %" + String(percent) + " " + direction
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("İlçende ₺/saat")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(verbatim: Formatters.perHour(average))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                if !courierText.isEmpty {
                    Text(verbatim: courierText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: comparison)
                    .font(.subheadline)
                    .accessibilityIdentifier("community.comparison")
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        } footer: {
            Text("Son 8 hafta, brüt + bonus. Senin değerin de aynı ölçüyle hesaplanır (gider düşülmez).")
        }
    }
}

private struct CommunityPlatformRow: View {
    let stat: CommunityPlatformStat
    let name: String

    private var detail: String {
        let perHour: String = Formatters.perHour(stat.perHour)
        let perPackage: String = stat.perPackage.map { Formatters.currency($0) + "/paket" } ?? "—/paket"
        return [perHour, perPackage, String(stat.couriers) + " kurye"].joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: name).font(.body.weight(.semibold))
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct CommunityBestRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let cell: CommunityCell

    private var title: String {
        let day: String = weekdayLongNames[min(max(cell.weekday, 1), 7) - 1]
        let nextHour: Int = (cell.hour + 1) % 24
        return day + " " + String(format: "%02d:00–%02d:00", cell.hour, nextHour)
    }

    var body: some View {
        let value: String = Formatters.perHour(cell.perHour)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                Text(verbatim: value).monospacedDigit().foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack {
                Text(verbatim: title)
                Spacer()
                Text(verbatim: value).monospacedDigit().foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
