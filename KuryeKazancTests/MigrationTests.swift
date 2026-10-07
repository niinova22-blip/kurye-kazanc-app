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
