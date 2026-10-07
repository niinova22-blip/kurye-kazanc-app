import XCTest
import SwiftData
@testable import KuryeKazanc

@MainActor
final class ModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = ModelContainerFactory.make(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    func testEarningRecord_normalizesDateToStartOfDay() {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 14, minute: 30))!
        let record = EarningRecord(startTime: start, endTime: start.addingTimeInterval(3600), grossEarning: 100)
        XCTAssertEqual(record.date, Calendar.current.startOfDay(for: start))
        XCTAssertEqual(record.duration, 3600)
    }

    func testRecordsCarryAnonymousDeviceID_andNoPersonalLink() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let deviceID = AnonymousDeviceID.current(in: defaults)

        // Ayni cihazda sabit kalmali
        XCTAssertEqual(AnonymousDeviceID.current(in: defaults), deviceID)

        let earning = EarningRecord(anonymousDeviceID: deviceID, startTime: .now, endTime: .now, grossEarning: 1)
        let expense = ExpenseRecord(anonymousDeviceID: deviceID, date: .now, type: .fuel, amount: 1)
        XCTAssertEqual(earning.anonymousDeviceID, deviceID)
        XCTAssertEqual(expense.anonymousDeviceID, deviceID)
    }

    func testEnumRawValueFallbacks() {
        let record = EarningRecord(startTime: .now, endTime: .now, grossEarning: 0, source: .ocr)
        XCTAssertEqual(record.source, .ocr)
        record.sourceRaw = "bozuk"
        XCTAssertEqual(record.source, .manual)

        let expense = ExpenseRecord(date: .now, type: .tire, amount: 1)
        expense.typeRaw = "bilinmeyen"
        XCTAssertEqual(expense.type, .other)
    }

    func testPlatformSeeding_isIdempotent() throws {
        DataSeeder.seedPlatformsIfNeeded(in: context)
        DataSeeder.seedPlatformsIfNeeded(in: context)
        let platforms = try context.fetch(FetchDescriptor<Platform>())
        XCTAssertEqual(platforms.count, Platform.defaults.count)
        XCTAssertTrue(platforms.contains { $0.code == "trendyol_go" })
        XCTAssertTrue(platforms.contains { $0.code == "getir" })
    }

    func testEarningPlatformRelationship() throws {
        let getir = Platform(name: "Getir", code: "getir")
        context.insert(getir)
        let record = EarningRecord(startTime: .now, endTime: .now, platform: getir, grossEarning: 50)
        context.insert(record)
        try context.save()

        XCTAssertEqual(getir.earnings.count, 1)
        XCTAssertEqual(record.entry.platformCode, "getir")
    }

    func testCourierDefaultPlatforms() throws {
        let tgo = Platform(name: "Trendyol GO", code: "trendyol_go")
        context.insert(tgo)
        let courier = Courier(name: "Test", vehicleType: .motorcycle, defaultPlatforms: [tgo])
        context.insert(courier)
        try context.save()

        XCTAssertEqual(courier.defaultPlatforms.map(\.code), ["trendyol_go"])
        XCTAssertEqual(courier.vehicleType, .motorcycle)
    }

    private func recordWithEvidence() -> (EarningRecord, ScreenshotEvidence) {
        let parsed = ParsedEarning(platformCode: "getir", date: .now, packageCount: 1, totalEarning: 100,
                                   bonus: 0, totalIncludesBonus: true, fieldsToReview: [])
        let evidence = ScreenshotEvidence(capturedAt: nil, assetIdentifier: nil, parsed: parsed,
                                          lines: [RecognizedLine(text: "IBAN TR00", x: 0, y: 0, width: 1, height: 0.1)],
                                          isGenuineScreenshot: true)
        let record = EarningRecord(startTime: .now, endTime: .now, grossEarning: 100, source: .ocr)
        context.insert(evidence)
        context.insert(record)
        record.evidence = evidence
        return (record, evidence)
    }

    func testDeletingEarningAlsoDeletesItsEvidence() throws {
        let (record, _) = recordWithEvidence()
        try context.save()
        try context.deleteEarning(record)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScreenshotEvidence>()), 0,
                       "OCR metni (isim, IBAN olabilir) kayitla birlikte silinmeli")
    }

    func testDeleteAllRecordsRemovesEvidence() throws {
        _ = recordWithEvidence()
        context.insert(ExpenseRecord(date: .now, type: .fuel, amount: 50))
        try context.save()
        try context.deleteAllRecords()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EarningRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScreenshotEvidence>()), 0)
    }

    func testEvidenceStoresTextHashOfItsLines() throws {
        let (_, evidence) = recordWithEvidence()
        try context.save()
        XCTAssertEqual(evidence.textHash, TextHash.of(["IBAN TR00"]))
        XCTAssertEqual(evidence.textHash.count, 16)
    }

    func testEarningRecordSyncFieldsDefaultToLocal() throws {
        let record = EarningRecord(startTime: .now, endTime: .now, grossEarning: 100)
        context.insert(record)
        try context.save()
        XCTAssertEqual(record.syncStateRaw, "local")
        XCTAssertNil(record.remoteID)
    }
}
