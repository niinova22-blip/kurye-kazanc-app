import XCTest
import SwiftData
@testable import KuryeKazanc

@MainActor
final class ScanResultsViewModelTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14))! }
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var store: BroadcastCaptureStore!

    private let getirDaily = ["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺980,00", "Sipariş Sayısı", "11"]
    private let uberWeekly = ["Kazançlar", "4 Eki - 10 Eki", "₺6.459,90", "Çevrimiçi 23 sa 32 dk", "54 Teslimat",
                              "73 Puan", "Ayrıntıları gör", "Bakiye: ₺1.550,00"]
    private let orderCardA = ["Kabul oranı %89", "Reddet", "₺147,50", "₺37,00 ek dahil", "Teslim al 1,6 km - 12 dk", "Kabul et"]
    private let orderCardB = ["Kabul oranı %89", "Reddet", "₺120,00", "₺20,00 ek dahil", "Teslim al 2,1 km - 9 dk", "Kabul et"]

    override func setUp() {
        container = ModelContainerFactory.make(inMemory: true)
        DataSeeder.seedPlatformsIfNeeded(in: context)
        store = BroadcastCaptureStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("scan-results-\(UUID())"))
    }

    private func add(_ texts: [String], offset: TimeInterval = 0) throws {
        let lines = texts.enumerated().map { RecognizedLine(text: $1, x: 0, y: Double($0) * 0.05, width: 1, height: 0.04) }
        try store.save(BroadcastCapture(capturedAt: now.addingTimeInterval(offset), lines: lines))
        Thread.sleep(forTimeInterval: 0.01)
    }

    private func makeVM(known: Set<String> = []) -> ScanResultsViewModel {
        ScanResultsViewModel(store: store, templates: nil, knownTextHashes: known, interrupted: false,
                             calendar: calendar, now: now)
    }

    private func platforms() -> [Platform] { (try? context.fetch(FetchDescriptor<Platform>())) ?? [] }

    func testLoadListsItemsWithDefaultSelection() throws {
        try add(getirDaily)
        try add(uberWeekly, offset: 10)
        let vm = makeVM()
        vm.load()
        XCTAssertEqual(vm.rows.count, 2)
        let daily = try XCTUnwrap(vm.rows.first { $0.item.kind == .daily })
        let weekly = try XCTUnwrap(vm.rows.first { $0.item.kind == .weekly })
        XCTAssertTrue(daily.isSelected)
        XCTAssertFalse(weekly.isSelected)
        XCTAssertEqual(vm.selectedCount, 1)
    }

    func testAlreadySavedRowIsNotSelectableNorSaved() throws {
        try add(getirDaily)
        let probe = makeVM()
        probe.load()
        let hash = try XCTUnwrap(probe.rows.first).item.textHash

        let vm = makeVM(known: [hash])
        vm.load()
        let row = try XCTUnwrap(vm.rows.first)
        XCTAssertTrue(row.isAlreadySaved)
        XCTAssertFalse(row.isSelected)
        vm.setSelected(true, for: row.id)
        XCTAssertFalse(try XCTUnwrap(vm.rows.first).isSelected)
        XCTAssertEqual(vm.selectedCount, 0)

        let records = try vm.save(in: context, platforms: platforms())
        XCTAssertTrue(records.isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<EarningRecord>()).count, 0)
    }

    func testSaveCreatesOcrRecordAndDeletesFiles() throws {
        try add(getirDaily)
        let vm = makeVM()
        vm.load()
        let records = try vm.save(in: context, platforms: platforms())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].source, .ocr)
        XCTAssertEqual(records[0].grossEarning, 980, accuracy: 0.001)
        XCTAssertEqual(records[0].platform?.code, "getir")
        XCTAssertEqual(try context.fetch(FetchDescriptor<EarningRecord>()).count, 1)
        XCTAssertEqual(store.pending(), [])
        XCTAssertEqual(vm.skippedCount, 0)
    }

    func testOrderGroupSavesOneRecordWithCardCountAsPackages() throws {
        try add(orderCardA)
        try add(orderCardB, offset: 10)
        let vm = makeVM()
        vm.load()
        XCTAssertEqual(vm.rows.count, 1)
        XCTAssertEqual(vm.rows[0].item.kind, .orderGroup(count: 2))
        XCTAssertTrue(vm.rows[0].isSelected)
        let records = try vm.save(in: context, platforms: platforms())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].packageCount, 2)
        XCTAssertEqual(records[0].grossEarning, 267.5, accuracy: 0.001)
        XCTAssertNotEqual(records[0].verification, .verified)
    }

    func testUnmatchedPlatformIsSkippedAndCounted() throws {
        try add(getirDaily)
        let vm = makeVM()
        vm.load()
        let records = try vm.save(in: context, platforms: [])
        XCTAssertTrue(records.isEmpty)
        XCTAssertEqual(vm.skippedCount, 1)
        XCTAssertEqual(store.pending(), [])
    }

    func testDiscardDeletesFiles() throws {
        try add(getirDaily)
        let vm = makeVM()
        vm.load()
        vm.discard()
        XCTAssertEqual(store.pending(), [])
        XCTAssertTrue(vm.rows.isEmpty)
    }

    func testCorruptFileIsSkipped() throws {
        try add(getirDaily)
        let url = try XCTUnwrap(store.pending().first)
        try add(["Getir", "Kazançlarım", "Bugün", "Toplam Kazanç", "₺500,00"], offset: 10)
        try Data("bozuk".utf8).write(to: url)
        let vm = makeVM()
        vm.load()
        XCTAssertEqual(vm.rows.count, 1)
    }

    func testImportCaptureUsesCapturedAtAndMarksGenuine() {
        let lines = getirDaily.map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.04) }
        let imported = ScreenshotImporter().importCapture(lines: lines, capturedAt: now, referenceDate: now)
        XCTAssertTrue(imported.isGenuine)
        XCTAssertNil(imported.assetIdentifier)
        XCTAssertEqual(imported.capturedAt, now)
        XCTAssertEqual(imported.textHash, TextHash.of(getirDaily))
        XCTAssertEqual(imported.parsed.platformCode, "getir")
    }
}
