import XCTest
import UIKit
@testable import KuryeKazanc

/// Katman B (spec 1.4a §4.3): taklit ekran -> goruntu -> Vision -> cozumleyici. Simulatorde (CI) calisir.
@MainActor
final class ScenarioImageTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var reference: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 14))! }
    private var fixtures: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures") }

    func testMockScreensMeetBaseline() async throws {
        let recognizer = VisionTextRecognitionService()
        let parser = EarningsScreenshotParser(calendar: calendar)
        var tally = ScenarioTally()
        // Sure icin her ikinci senaryo (tum set ~2.7 dk ekliyordu)
        for scenario in ScenarioGenerator().all().enumerated().filter({ $0.offset % 2 == 0 }).map(.element) {
            let image = MockEarningsScreen.render(scenario)
            let lines = (try? await recognizer.recognize(in: image).map(\.text)) ?? []
            let parsed = parser.parse(lines: lines, referenceDate: reference)
            tally.add(platform: scenario.platformCode, results: scenario.expected.check(parsed))
        }
        let report = tally.markdown(title: "Taklit ekranlar (Vision)")
        appendReport(report)
        print(report)

        let baselineURL = fixtures.appendingPathComponent("scenario-baseline.json")
        guard let data = try? Data(contentsOf: baselineURL),
              let baseline = try? JSONDecoder().decode([String: Double].self, from: data) else {
            let json = tally.baselineJSON()
            appendReport("\nTaban dosyasi yok. Olculen deger (Fixtures/scenario-baseline.json olarak kaydet):\n```json\n\(json)\n```")
            print("SCENARIO_BASELINE_BEGIN\n\(json)\nSCENARIO_BASELINE_END")
            return
        }
        let drops = tally.drops(from: baseline, tolerance: 5)
        XCTAssertTrue(drops.isEmpty, "Dogruluk tabanin altina dustu:\n" + drops.joined(separator: "\n"))
    }

    /// Gercek (karartilmis) ekranlar: Fixtures/RealScreens/<platform>/<ad>.png + <ad>.json (ScenarioExpectation).
    func testRealScreens() async throws {
        let root = fixtures.appendingPathComponent("RealScreens")
        let files = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "png" }
        guard !files.isEmpty else { throw XCTSkip("Henuz gercek ekran yok") }
        let recognizer = VisionTextRecognitionService()
        let parser = EarningsScreenshotParser(calendar: calendar)
        var tally = ScenarioTally()
        for file in files {
            let expectationURL = file.deletingPathExtension().appendingPathExtension("json")
            guard let image = UIImage(contentsOfFile: file.path),
                  let data = try? Data(contentsOf: expectationURL),
                  let expected = try? JSONDecoder().decode(ScenarioExpectation.self, from: data) else {
                XCTFail("Okunamadi: \(file.lastPathComponent)")
                continue
            }
            let lines = (try? await recognizer.recognize(in: image).map(\.text)) ?? []
            let parsed = parser.parse(lines: lines, referenceDate: reference)
            tally.add(platform: file.deletingLastPathComponent().lastPathComponent, results: expected.check(parsed))
        }
        let report = tally.markdown(title: "Gercek ekranlar")
        appendReport(report)
        print(report)
    }

    private func appendReport(_ text: String) {
        guard let path = ProcessInfo.processInfo.environment["SCENARIO_REPORT"] else { return }
        let url = URL(fileURLWithPath: path)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + text + "\n\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
