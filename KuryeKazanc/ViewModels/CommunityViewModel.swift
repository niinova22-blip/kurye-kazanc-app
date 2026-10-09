import Foundation
import Observation

/// Topluluk sekmesi durumu: ilce secenekleri, secili ilce, kendi TL/saat ve sunucu yuklemesi.
/// Paylasim kapaliyken (ya da ilce yokken) istemciye hicbir cagri yapilmaz.
@MainActor
@Observable
final class CommunityViewModel {
    struct District: Hashable {
        let province: String
        let name: String

        var title: String { name + ", " + province }
    }

    enum State: Equatable {
        case sharingOff
        case noDistrict
        case loading
        case loaded(CommunitySummary, [CommunityCell])
        case insufficient
        case failed
    }

    /// Kendi TL/saat icin geriye bakis (gun).
    static let lookbackDays: Int = 56

    private(set) var state: State
    private(set) var districts: [District] = []
    private(set) var ownPerHour: Double?
    var selected: District?
    var sharingEnabled: Bool

    private let client: (any SupabaseServing)?

    init(client: (any SupabaseServing)?, sharingEnabled: Bool) {
        self.client = client
        self.sharingEnabled = sharingEnabled
        self.state = sharingEnabled ? .noDistrict : .sharingOff
    }

    /// Ilce secenekleri: bos olmayan (il, ilce) ciftleri, en yeni kayit once.
    static func districtOptions(from records: [EarningRecord]) -> [District] {
        let sorted: [EarningRecord] = records.sorted { $0.startTime > $1.startTime }
        var seen: Set<District> = []
        var result: [District] = []
        for record in sorted {
            let province: String = (record.province ?? "").trimmingCharacters(in: .whitespaces)
            let name: String = (record.district ?? "").trimmingCharacters(in: .whitespaces)
            guard !province.isEmpty, !name.isEmpty else { continue }
            let item = District(province: province, name: name)
            if seen.insert(item).inserted { result.append(item) }
        }
        return result
    }

    /// Kayitlar degisince cagrilir: secenekler, secim ve kendi TL/saat yenilenir (ag yok).
    /// Secim hala gecerliyse korunur, degilse en yeni ilce secilir.
    func update(records: [EarningRecord], now: Date = .now, calendar: Calendar = .current) {
        districts = Self.districtOptions(from: records)
        if selected == nil || !districts.contains(selected!) {
            selected = districts.first
        }
        let cutoff: Date = calendar.date(byAdding: .day, value: -Self.lookbackDays, to: now) ?? .distantPast
        let recent: [EarningEntry] = records.filter { $0.startTime >= cutoff }.map(\.entry)
        ownPerHour = CommunityComparison.ownPerHour(recent)
    }

    /// Secili ilce icin ozet ve isi haritasini yukler.
    func load() async {
        guard sharingEnabled else {
            state = .sharingOff
            return
        }
        guard let district = selected else {
            state = .noDistrict
            return
        }
        guard let client else {
            state = .failed
            return
        }
        state = .loading
        async let summaryResult = client.communitySummary(province: district.province, district: district.name)
        async let cellsResult = client.communityHeatmap(province: district.province, district: district.name)
        let summary: CommunitySummary? = await summaryResult
        let cells: [CommunityCell]? = await cellsResult
        // Yukleme surerken ilce ya da riza degistiyse eski sonuc yazilmaz (yeni yukleme durumu belirler).
        guard !Task.isCancelled, sharingEnabled, selected == district else { return }
        guard let summary, let cells else {
            state = .failed
            return
        }
        if summary.isInsufficient && cells.isEmpty {
            state = .insufficient
        } else {
            state = .loaded(summary, cells)
        }
    }
}
