import SwiftUI
import SwiftData

/// UI testinde hicbir sey sormayan ve bulmayan kutuphane.
struct NoOpScreenshotLibrary: ScreenshotLibrary {
    var isAuthorized: Bool { false }
    func requestAccess() async -> Bool { false }
    func recentScreenshots(since: Date, limit: Int) async -> [LibraryScreenshot] { [] }
    func recentImages(since: Date, limit: Int) async -> [LibraryScreenshot] { [] }
}

/// Kaydedilen fotograf kimlikleri (tekrar taranmaz): son 2000 kimlik UserDefaults'ta tutulur.
enum ScanSavedAssets {
    static let key = "scanSavedAssetIDs"
    static let maxCount = 2000

    static func load(_ defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    static func append(_ ids: Set<String>, to defaults: UserDefaults = .standard) {
        guard !ids.isEmpty else { return }
        var list: [String] = load(defaults).filter { !ids.contains($0) }
        list.append(contentsOf: ids.sorted())
        defaults.set(Array(list.suffix(maxCount)), forKey: key)
    }
}

/// "Kazanç taraması" rehberi: talimat, izin, fotograflardan otomatik tarama ve sonuclar.
struct ScanGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SyncCoordinator.self) private var sync
    @Environment(LocationService.self) private var location

    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @Query private var couriers: [Courier]
    @Query private var allEarnings: [EarningRecord]
    @Query private var evidences: [ScreenshotEvidence]

    @AppStorage("scanTestWindow") private var testWindow = false

    @State private var service: PhotoScanService
    @State private var permissionDenied = false
    @State private var isBusy = false
    @State private var autoStarted = false
    @State private var showEmpty = false
    @State private var showTruncated = false
    @State private var showResults = false
    @State private var results: ScanResultsViewModel?

    private let library: ScreenshotLibrary

    init() {
        let library: ScreenshotLibrary = LaunchOptions.current.isUITesting
            ? NoOpScreenshotLibrary() : PhotoKitScreenshotLibrary()
        self.library = library
        _service = State(initialValue: PhotoScanService(library: library))
    }

    var body: some View {
        NavigationStack {
            List {
                platformsSection
                stepsSection
                statusSection
                actionSection
            }
            .navigationTitle("Kazanç taraması")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                        .accessibilityIdentifier("scan.guide.close")
                }
            }
            .onChange(of: scenePhase) { old, new in
                if new == .active, old == .background { autoStart() }
            }
            .sheet(isPresented: $showResults, onDismiss: resultsDismissed) {
                if let results {
                    ScanResultsView(viewModel: results)
                }
            }
        }
    }

    // MARK: - Bolumler

    private var guidePlatforms: [Platform] {
        let own: [Platform] = couriers.first?.defaultPlatforms.sorted { $0.sortOrder < $1.sortOrder } ?? []
        return own.isEmpty ? platforms : own
    }

    private var platformsSection: some View {
        Section("Platformların") {
            ForEach(guidePlatforms) { platform in
                Text("\(platform.name) → günlük kazanç ekranı")
            }
        }
    }

    private var stepsSection: some View {
        Section {
            Text("1. Uygulamada günlük kazanç ekranını aç ve ekran görüntüsü al.")
            Text("2. Hepsini alınca buraya dön.")
        } footer: {
            Text("Görüntüler yalnızca cihazında işlenir.")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if service.isScanning {
            Section {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Okunuyor \(service.progress.done)/\(service.progress.total)")
                        .monospacedDigit()
                }
                .accessibilityIdentifier("scan.guide.progress")
            }
        } else if permissionDenied {
            Section {
                Text("Fotoğraflara erişim izni gerekli.")
                Button("Ayarlar'ı aç", action: openSettings)
                    .accessibilityIdentifier("scan.guide.settings")
            }
        } else if showEmpty {
            Section { Text(emptyText).foregroundStyle(.secondary) }
        }
        if showTruncated {
            Section {
                Text("Daha fazla görüntü var; kaydettikten sonra tekrar tara.")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button("Ekran görüntülerini aldım — Tara", action: startTapped)
                .buttonStyle(PrimaryActionButtonStyle(isDestructive: false))
                .disabled(isBusy || service.isScanning)
                .accessibilityIdentifier("scan.guide.start")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var emptyText: String {
        testWindow
            ? "Son 30 günde kazanç ekranı görüntüsü bulunamadı."
            : "Son 24 saatte kazanç ekranı görüntüsü bulunamadı."
    }

    // MARK: - Eylemler

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func startTapped() {
        Task { await runScan() }
    }

    /// Rehber acikken uygulama arka plandan donerse tarama kendiliginden bir kez baslar.
    private func autoStart() {
        guard !autoStarted, !showResults else { return }
        autoStarted = true
        Task { await runScan() }
    }

    private var knownIdentifiers: Set<String> {
        Set(evidences.compactMap(\.assetIdentifier)).union(ScanSavedAssets.load())
    }

    private var knownHashes: Set<String> {
        Set(evidences.map(\.textHash).filter { !$0.isEmpty })
    }

    private var existingDaily: [ScanResultsViewModel.ExistingDaily] {
        allEarnings.map { record in
            ScanResultsViewModel.ExistingDaily(
                platformCode: record.platform?.code, day: record.startTime, gross: record.grossEarning
            )
        }
    }

    private func runScan() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        showEmpty = false
        showTruncated = false
        permissionDenied = false
        if !library.isAuthorized {
            let granted: Bool = await library.requestAccess()
            guard granted else {
                permissionDenied = !LaunchOptions.current.isUITesting
                return
            }
        }
        let region: PlaceRegion? = location.isAuthorized ? await location.currentRegion() : nil
        let testMode: Bool = testWindow
        let templates: [OCRTemplate] = sync.mergedTemplates()
        let found: [PhotoScanResult] = await service.scan(
            since: ScanWindow.start(now: .now, testMode: testMode),
            includeAllPhotos: testMode,
            knownIdentifiers: knownIdentifiers,
            knownTextHashes: knownHashes,
            templates: templates
        )
        showTruncated = service.didTruncate
        guard !found.isEmpty else {
            showEmpty = true
            return
        }
        results = ScanResultsViewModel(
            photoResults: found, templates: templates, knownTextHashes: knownHashes,
            existingDaily: existingDaily, region: region
        )
        showResults = true
    }

    private func resultsDismissed() {
        // Sonuc ekrani kapaninca kaydedilenlerin kimlikleri kalici yazilir
        if let saved = results?.savedAssetIdentifiers { ScanSavedAssets.append(saved) }
        results = nil
        if !showTruncated { dismiss() }
    }
}
