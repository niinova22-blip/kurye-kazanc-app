import XCTest
import SwiftData
@testable import KuryeKazanc

@MainActor
final class MigrationTests: XCTestCase {
    func testV1StoreMigratesToV2_keepingRecordsAndMarkingOCR() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // 1) 1.0.0 deposu olustur
        do {
            let v1Schema = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(for: v1Schema, configurations: [ModelConfiguration(schema: v1Schema, url: url)])
            let day = Calendar.current.startOfDay(for: .now)
            v1.mainContext.insert(SchemaV1.EarningRecord(
                anonymousDeviceID: UUID(), date: day, startTime: day, endTime: day.addingTimeInterval(3600),
                grossEarning: 500, sourceRaw: "ocr"))
            v1.mainContext.insert(SchemaV1.EarningRecord(
                anonymousDeviceID: UUID(), date: day, startTime: day, endTime: day.addingTimeInterval(3600),
                grossEarning: 300, sourceRaw: "manual"))
            try v1.mainContext.save()
        }

        // 2) 1.1.0 ile ac
        let v2 = ModelContainerFactory.make(url: url)
        let records = try v2.mainContext.fetch(FetchDescriptor<EarningRecord>(sortBy: [SortDescriptor(\.grossEarning)]))
        XCTAssertEqual(records.map(\.grossEarning), [300, 500])
        XCTAssertEqual(records.map(\.verification), [.manual, .ocrUnverified])
        XCTAssertTrue(records.allSatisfy { $0.evidence == nil })
    }

    func testV1StoreMigratesToV2_keepingPlatformsCourierAndExpenses() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-full-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let day = Calendar.current.startOfDay(for: .now)
        let deviceID = UUID()

        // 1) 1.0.0 deposu: platform + bagli kazanc + varsayilan platformlu kurye + gider
        do {
            let v1Schema = Schema(versionedSchema: SchemaV1.self)
            let v1 = try ModelContainer(for: v1Schema, configurations: [ModelConfiguration(schema: v1Schema, url: url)])
            let context = v1.mainContext

            let getir = SchemaV1.Platform(name: "Getir", code: "getir", sortOrder: 1)
            context.insert(getir)
            let earning = SchemaV1.EarningRecord(
                anonymousDeviceID: deviceID, date: day, startTime: day, endTime: day.addingTimeInterval(7200),
                grossEarning: 640, bonus: 60, distanceKm: 35.5, packageCount: 9, sourceRaw: "manual")
            context.insert(earning)
            earning.platform = getir

            let courier = SchemaV1.Courier(name: "Ali", vehicleTypeRaw: VehicleType.scooter.rawValue)
            context.insert(courier)
            courier.defaultPlatforms = [getir]

            let expense = SchemaV1.ExpenseRecord(anonymousDeviceID: deviceID, date: day,
                                                 typeRaw: ExpenseType.fuel.rawValue, amount: 250.5, note: "Benzin")
            context.insert(expense)
            try context.save()
        }

        // 2) 1.1.0 ile ac
        let v2 = ModelContainerFactory.make(url: url)
        let context = v2.mainContext

        let platforms: [Platform] = try context.fetch(FetchDescriptor<Platform>())
        XCTAssertEqual(platforms.count, 1)
        let platform = try XCTUnwrap(platforms.first)
        XCTAssertEqual(platform.code, "getir")
        XCTAssertEqual(platform.name, "Getir")
        XCTAssertEqual(platform.sortOrder, 1)

        let records: [EarningRecord] = try context.fetch(FetchDescriptor<EarningRecord>())
        XCTAssertEqual(records.count, 1)
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.platform?.code, "getir", "Kazanc-platform iliskisi gocte korunmali")
        XCTAssertEqual(platform.earnings.count, 1)
        XCTAssertEqual(record.grossEarning, 640)
        XCTAssertEqual(record.bonus, 60)
        XCTAssertEqual(record.distanceKm, 35.5)
        XCTAssertEqual(record.packageCount, 9)
        XCTAssertEqual(record.anonymousDeviceID, deviceID)
        XCTAssertEqual(record.verification, .manual)
        XCTAssertEqual(record.syncStateRaw, "local")
        XCTAssertNil(record.remoteID)

        let couriers: [Courier] = try context.fetch(FetchDescriptor<Courier>())
        XCTAssertEqual(couriers.count, 1)
        let courier = try XCTUnwrap(couriers.first)
        XCTAssertEqual(courier.name, "Ali")
        XCTAssertEqual(courier.vehicleType, .scooter)
        let defaultCodes: [String] = courier.defaultPlatforms.map(\.code)
        XCTAssertEqual(defaultCodes, ["getir"])

        let expenses: [ExpenseRecord] = try context.fetch(FetchDescriptor<ExpenseRecord>())
        XCTAssertEqual(expenses.count, 1)
        let expense = try XCTUnwrap(expenses.first)
        XCTAssertEqual(expense.type, .fuel)
        XCTAssertEqual(expense.amount, 250.5)
        XCTAssertEqual(expense.note, "Benzin")
        XCTAssertEqual(expense.date, day)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ScreenshotEvidence>()), 0)
    }

    func testEvidenceLinksToRecord() throws {
        let container = ModelContainerFactory.make(inMemory: true)
        let parsed = ParsedEarning(platformCode: "getir", date: .now, packageCount: 3, totalEarning: 300,
                                   bonus: 0, totalIncludesBonus: true, fieldsToReview: [])
        let evidence = ScreenshotEvidence(capturedAt: nil, assetIdentifier: "A1", parsed: parsed,
                                          lines: [RecognizedLine(text: "Getir", x: 0, y: 0, width: 1, height: 0.1)],
                                          isGenuineScreenshot: true)
        let record = EarningRecord(startTime: .now, endTime: .now, grossEarning: 300, source: .ocr, verification: .ocrUnverified)
        record.evidence = evidence
        container.mainContext.insert(record)
        try container.mainContext.save()

        XCTAssertEqual(evidence.records.count, 1)
        XCTAssertEqual(record.evidence?.lines.first?.text, "Getir")
    }
}
