import XCTest
@testable import KuryeKazanc

@MainActor
private final class FakeCommunityClient: SupabaseServing {
    var summary: CommunitySummary?
    var cells: [CommunityCell]? = []
    private(set) var summaryCalls: [String] = []
    private(set) var heatmapCalls: [String] = []

    var session: AuthSession? { nil }

    func communitySummary(province: String, district: String) async -> CommunitySummary? {
        summaryCalls.append(province + "/" + district)
        return summary
    }

    func communityHeatmap(province: String, district: String) async -> [CommunityCell]? {
        heatmapCalls.append(province + "/" + district)
        return cells
    }

    func submitShift(_ p: ShiftPayload) async -> OutboxResult { .ok }
    func submitCalibration(platformCode: String?, templateID: String?, lines: [RecognizedLine]) async -> OutboxResult { .ok }
    func fetchTemplates() async -> [OCRTemplate]? { [] }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession { throw SupabaseError.notSignedIn }
    func uploadBackup(_ payload: Data) async throws {}
    func downloadBackup() async throws -> Data? { nil }
    func deleteMyData() async throws {}
    func signOut() {}
}

@MainActor
final class CommunityViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(daysAgo: Int, province: String?, district: String?, gross: Double = 300) -> EarningRecord {
        let start: Date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
        return EarningRecord(
            startTime: start, endTime: start.addingTimeInterval(3600),
            province: province, district: district, grossEarning: gross
        )
    }

    private func loadedSummary() -> CommunitySummary {
        CommunitySummary(perHour: 350, couriers: 7, platforms: [], best: [])
    }

    func testSharingOffMakesNoCall() async {
        let client = FakeCommunityClient()
        let vm = CommunityViewModel(client: client, sharingEnabled: false)
        vm.update(records: [record(daysAgo: 1, province: "Ankara", district: "Sincan")], now: now)
        await vm.load()
        XCTAssertEqual(vm.state, .sharingOff)
        XCTAssertTrue(client.summaryCalls.isEmpty)
        XCTAssertTrue(client.heatmapCalls.isEmpty)
    }

    func testNoDistrict() async {
        let client = FakeCommunityClient()
        let vm = CommunityViewModel(client: client, sharingEnabled: true)
        vm.update(records: [
            record(daysAgo: 1, province: nil, district: ""),
            record(daysAgo: 2, province: "Ankara", district: nil),
        ], now: now)
        await vm.load()
        XCTAssertEqual(vm.state, .noDistrict)
        XCTAssertTrue(client.summaryCalls.isEmpty)
    }

    func testDistrictOptionsMostRecentFirstAndDefault() {
        let vm = CommunityViewModel(client: nil, sharingEnabled: true)
        vm.update(records: [
            record(daysAgo: 10, province: "İstanbul", district: "Kadıköy"),
            record(daysAgo: 1, province: "Ankara", district: "Sincan"),
            record(daysAgo: 5, province: "Ankara", district: "Sincan"),
            record(daysAgo: 3, province: "", district: "Etimesgut"),
        ], now: now)
        XCTAssertEqual(vm.districts.map(\.title), ["Sincan, Ankara", "Kadıköy, İstanbul"])
        XCTAssertEqual(vm.selected?.name, "Sincan")
    }

    func testSelectionKeptWhenStillAvailable() {
        let vm = CommunityViewModel(client: nil, sharingEnabled: true)
        let records = [
            record(daysAgo: 1, province: "Ankara", district: "Sincan"),
            record(daysAgo: 10, province: "İstanbul", district: "Kadıköy"),
        ]
        vm.update(records: records, now: now)
        vm.selected = CommunityViewModel.District(province: "İstanbul", name: "Kadıköy")
        vm.update(records: records, now: now)
        XCTAssertEqual(vm.selected?.name, "Kadıköy")
    }

    func testLoaded() async {
        let client = FakeCommunityClient()
        client.summary = loadedSummary()
        let cell = CommunityCell(weekday: 5, hour: 20, perHour: 400, couriers: 6, shifts: 8)
        client.cells = [cell]
        let vm = CommunityViewModel(client: client, sharingEnabled: true)
        vm.update(records: [record(daysAgo: 1, province: "Ankara", district: "Sincan")], now: now)
        await vm.load()
        XCTAssertEqual(vm.state, .loaded(loadedSummary(), [cell]))
        XCTAssertEqual(client.summaryCalls, ["Ankara/Sincan"])
        XCTAssertEqual(client.heatmapCalls, ["Ankara/Sincan"])
    }

    func testInsufficient() async {
        let client = FakeCommunityClient()
        client.summary = CommunitySummary(perHour: nil, couriers: nil, platforms: [], best: [])
        client.cells = []
        let vm = CommunityViewModel(client: client, sharingEnabled: true)
        vm.update(records: [record(daysAgo: 1, province: "Ankara", district: "Sincan")], now: now)
        await vm.load()
        XCTAssertEqual(vm.state, .insufficient)
    }

    func testFailedWhenServerReturnsNilOrNoClient() async {
        let client = FakeCommunityClient()
        client.summary = nil
        let vm = CommunityViewModel(client: client, sharingEnabled: true)
        vm.update(records: [record(daysAgo: 1, province: "Ankara", district: "Sincan")], now: now)
        await vm.load()
        XCTAssertEqual(vm.state, .failed)

        let offline = CommunityViewModel(client: nil, sharingEnabled: true)
        offline.update(records: [record(daysAgo: 1, province: "Ankara", district: "Sincan")], now: now)
        await offline.load()
        XCTAssertEqual(offline.state, .failed)
    }

    func testOwnPerHourOverLastEightWeeksOnly() {
        let vm = CommunityViewModel(client: nil, sharingEnabled: true)
        vm.update(records: [
            record(daysAgo: 1, province: "Ankara", district: "Sincan", gross: 400),
            record(daysAgo: 3, province: "Ankara", district: "Sincan", gross: 200),
            record(daysAgo: 100, province: "Ankara", district: "Sincan", gross: 5000),
        ], now: now)
        // Iki kayit ayri gunlerde, 1 saatten toplam 2 saat: 600 / 2 = 300
        XCTAssertEqual(vm.ownPerHour ?? 0, 300, accuracy: 0.001)
    }
}
