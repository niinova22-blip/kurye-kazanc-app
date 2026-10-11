import Foundation
import Observation

/// Yayimlanan hakedis tarifelerini sunucudan ceker ve cihazda saklar.
///
/// Hata kurali: istek basarisiz olursa son bilinen tarife (yoksa gomulu ornek tarife) kullanilmaya devam eder;
/// hakedis hesaplamasi hicbir zaman ag bekleyerek durmaz. Yalnizca herkese acik tablolar okunur, cihazdan veri gitmez.
@MainActor
@Observable
final class TariffSyncService {
    static let refreshInterval: TimeInterval = 6 * 60 * 60

    private(set) var remoteVersions: [TariffVersion]
    private(set) var fetchedAt: Date?
    /// Son deneme basarisiz mi (Tarifeler ekraninda "guncellenemedi" notu).
    private(set) var lastAttemptFailed: Bool = false

    private let client: (any SupabaseServing)?
    private let defaults: UserDefaults
    private let fileURL: URL?
    private let clock: () -> Date
    @ObservationIgnored private var isRefreshing: Bool = false

    /// - Parameter fileURL: nil ise bellekte (UI testleri).
    init(client: (any SupabaseServing)?, defaults: UserDefaults = .standard, fileURL: URL? = TariffSyncService.defaultFileURL(),
         clock: @escaping () -> Date = { Date() }) {
        self.client = client
        self.defaults = defaults
        self.fileURL = fileURL
        self.clock = clock
        var loaded: [TariffVersion] = []
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([TariffVersion].self, from: data) {
            loaded = decoded
        }
        self.remoteVersions = loaded
        let stamp: Double = defaults.double(forKey: AppPreferences.tariffsFetchedAtKey)
        self.fetchedAt = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    var isServerAvailable: Bool { client != nil }

    var isEnabled: Bool {
        get { defaults.object(forKey: AppPreferences.tariffUpdatesEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: AppPreferences.tariffUpdatesEnabledKey) }
    }

    nonisolated static func defaultFileURL() -> URL {
        let base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("tariff_versions.json")
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard let client, isEnabled, !isRefreshing else { return }
        let now: Date = clock()
        if !force, let fetchedAt {
            let elapsed: TimeInterval = now.timeIntervalSince(fetchedAt)
            if elapsed >= 0, elapsed < TariffSyncService.refreshInterval { return }
        }
        isRefreshing = true
        defer { isRefreshing = false }
        guard let versions = await client.fetchTariffVersions() else {
            lastAttemptFailed = true
            return
        }
        lastAttemptFailed = false
        // Bos yanit (sunucu henuz tohumlanmadi) eldeki tarifeyi silmez
        guard !versions.isEmpty else { return }
        remoteVersions = versions
        fetchedAt = now
        defaults.set(now.timeIntervalSince1970, forKey: AppPreferences.tariffsFetchedAtKey)
        save(versions)
    }

    func events(platform: String) async -> [TariffChangeEvent] {
        guard let client, isEnabled else { return [] }
        return await client.fetchTariffEvents(platform: platform) ?? []
    }

    private func save(_ versions: [TariffVersion]) {
        guard let fileURL else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(versions) else { return }
        try? data.write(to: fileURL, options: OutboxQueue.writeOptions)
    }
}
