import XCTest
import SwiftData
import UIKit
@testable import KuryeKazanc

@MainActor
final class FormViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    override func setUp() async throws {
        container = ModelContainerFactory.make(inMemory: true)
        DataSeeder.seedPlatformsIfNeeded(in: context)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private var platforms: [Platform] {
        (try? context.fetch(FetchDescriptor<Platform>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
    }

    // MARK: - Kazanc formu

    func testManualEarning_savesParsedTurkishAmounts() throws {
        let vm = EarningFormViewModel(defaultPlatform: platforms.first, now: at(6, 18), calendar: calendar)
        vm.startTime = at(6, 9)
        vm.endTime = at(6, 17, 30)
        vm.grossText = "1.250,50"
        vm.bonusText = "100"
        vm.distanceText = "84,5"
        vm.packageText = "22"
        vm.district = " Kadıköy "

        XCTAssertTrue(vm.canSave, "\(vm.validationErrors)")
        let record = try vm.save(in: context)

        XCTAssertEqual(record.grossEarning, 1250.5)
        XCTAssertEqual(record.bonus, 100)
        XCTAssertEqual(record.distanceKm, 84.5)
        XCTAssertEqual(record.packageCount, 22)
        XCTAssertEqual(record.district, "Kadıköy")
        XCTAssertNil(record.province) // bos alan nil kaydedilir
        XCTAssertEqual(record.source, .manual)
        XCTAssertEqual(record.duration, 8.5 * 3600)
        XCTAssertEqual(record.date, calendar.startOfDay(for: at(6, 0)))
    }

    func testOvernightShiftEndsNextDay() {
        let vm = EarningFormViewModel(defaultPlatform: platforms.first, now: at(6, 23), calendar: calendar)
        vm.startTime = at(6, 20)
        vm.endTime = at(6, 2)
        let interval = vm.resolvedInterval()
        XCTAssertEqual(interval.start, at(6, 20))
        XCTAssertEqual(interval.end, at(7, 2))
    }

    func testValidation() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.grossText = "abc"
        XCTAssertFalse(vm.canSave)
        XCTAssertEqual(vm.validationErrors.count, 2) // platform + tutar

        vm.platform = platforms.first
        vm.grossText = "500"
        vm.packageText = "3,5"
        XCTAssertFalse(vm.canSave)
        vm.packageText = "3"
        XCTAssertTrue(vm.canSave)
    }

    func testApplyOCR_fillsFieldsAndKeepsReviewFlags() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.startTime = at(6, 10)
        vm.endTime = at(6, 16)

        let parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(5, 0)),
            packageCount: 12, totalEarning: 1000, bonus: 100,
            totalIncludesBonus: true, fieldsToReview: [.bonus]
        )
        vm.apply(parsed, platforms: platforms)

        XCTAssertEqual(vm.platform?.code, "getir")
        XCTAssertEqual(vm.grossText, "900")      // toplam - bonus
        XCTAssertEqual(vm.bonusText, "100")
        XCTAssertEqual(vm.packageText, "12")
        XCTAssertEqual(vm.source, .ocr)
        XCTAssertEqual(vm.fieldsToReview, [.bonus, .hours]) // saatler ekranda yok -> her zaman kontrol
        XCTAssertNotNil(vm.reviewMessage)
        // Saatler OCR tarihine tasinir
        XCTAssertEqual(vm.resolvedInterval().start, at(5, 10))

        vm.markReviewed(.bonus)
        vm.markReviewed(.hours)
        XCTAssertNil(vm.reviewMessage)
    }

    func testApplyOCR_unknownPlatformIsFlagged() {
        let vm = EarningFormViewModel(defaultPlatform: platforms.first, now: at(6, 18), calendar: calendar)
        let parsed = ParsedEarning(
            platformCode: nil, date: at(6, 0), packageCount: 0, totalEarning: 300, bonus: 0,
            totalIncludesBonus: true, fieldsToReview: [.platform]
        )
        vm.apply(parsed, platforms: platforms)
        XCTAssertTrue(vm.fieldsToReview.contains(.platform))
    }

    func testImportScreenshot_usesRecognizerAndParser() async throws {
        struct FakeRecognizer: TextRecognizing {
            func recognize(in image: UIImage) async throws -> [RecognizedLine] {
                ["Trendyol GO", "05.10.2026", "Toplam Kazanç", "₺1.200,00", "Teslimat Sayısı", "15", "Bonus", "₺200,00"]
                    .map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.05) }
            }
        }
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        await vm.importScreenshot(
            UIImage(), recognizer: FakeRecognizer(),
            parser: EarningsScreenshotParser(calendar: calendar),
            platforms: platforms, referenceDate: at(6, 18)
        )
        XCTAssertEqual(vm.ocrState, .finished)
        XCTAssertEqual(vm.platform?.code, "trendyol_go")
        XCTAssertEqual(vm.grossText, "1000")
        XCTAssertEqual(vm.fieldsToReview, [.hours])

        // Testci raporu: satirlar teste yapistirilabilir Swift dizisi olarak
        let report = try XCTUnwrap(vm.ocrDiagnosticReport)
        XCTAssertTrue(report.contains("\"Toplam Kazanç\","), report)
        XCTAssertTrue(report.contains("let lines = ["))
    }

    func testImportScreenshot_failureIsReported() async {
        struct FailingRecognizer: TextRecognizing {
            func recognize(in image: UIImage) async throws -> [RecognizedLine] {
                throw TextRecognitionError.noTextFound
            }
        }
        let vm = EarningFormViewModel(now: at(6, 18), calendar: calendar)
        await vm.importScreenshot(UIImage(), recognizer: FailingRecognizer(), platforms: platforms)
        guard case .failed = vm.ocrState else { return XCTFail("Hata durumu bekleniyordu") }
    }

    func testPrefillFromWorkSession() {
        let session = WorkSessionSummary(start: at(6, 8), end: at(6, 14, 15), distanceKm: 42.36)
        let vm = EarningFormViewModel(session: session, defaultPlatform: platforms.first, calendar: calendar)
        XCTAssertEqual(vm.resolvedInterval().start, at(6, 8))
        XCTAssertEqual(vm.resolvedInterval().end, at(6, 14, 15))
        XCTAssertEqual(vm.distanceText, "42,4")
    }

    func testEditingUpdatesExistingRecord() throws {
        let record = EarningRecord(startTime: at(6, 9), endTime: at(6, 12), platform: platforms.first,
                                   grossEarning: 300, calendar: calendar)
        context.insert(record)
        try context.save()

        let vm = EarningFormViewModel(record: record, calendar: calendar)
        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.grossText, "300")
        vm.grossText = "450"
        vm.date = calendar.startOfDay(for: at(5, 0))
        try vm.save(in: context)

        let all = try context.fetch(FetchDescriptor<EarningRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(record.grossEarning, 450)
        XCTAssertEqual(record.date, calendar.startOfDay(for: at(5, 0)))
        XCTAssertEqual(record.startTime, at(5, 9))
    }

    // MARK: - Gider formu

    func testExpenseForm() throws {
        let vm = ExpenseFormViewModel(now: at(6, 18), calendar: calendar)
        vm.amountText = ""
        XCTAssertFalse(vm.canSave)
        vm.amountText = "0"
        XCTAssertFalse(vm.canSave)
        vm.amountText = "350,75"
        vm.type = .fuel
        vm.note = "  "
        XCTAssertTrue(vm.canSave)
        XCTAssertTrue(vm.replacesEstimate)

        let record = try vm.save(in: context)
        XCTAssertEqual(record.amount, 350.75)
        XCTAssertEqual(record.type, .fuel)
        XCTAssertNil(record.note)
        XCTAssertEqual(record.date, calendar.startOfDay(for: at(6, 0)))

        let edit = ExpenseFormViewModel(record: record, calendar: calendar)
        edit.type = .tire
        try edit.save(in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExpenseRecord>()).count, 1)
        XCTAssertEqual(record.type, .tire)
    }

    // MARK: - Onboarding

    func testOnboardingCreatesCourierAndSetsDefaults() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let vm = OnboardingViewModel()
        XCTAssertTrue(vm.canContinue)
        vm.next(); vm.next()
        XCTAssertEqual(vm.step, .platforms)
        XCTAssertFalse(vm.canContinue) // en az bir platform
        vm.togglePlatform("getir")
        vm.togglePlatform("trendyol_go")
        vm.togglePlatform("getir")
        XCTAssertTrue(vm.canContinue)
        vm.vehicleType = .car
        vm.name = "  "

        try vm.complete(in: context, platforms: platforms, defaults: defaults)

        let couriers = try context.fetch(FetchDescriptor<Courier>())
        XCTAssertEqual(couriers.count, 1)
        XCTAssertEqual(couriers[0].name, "Kurye")
        XCTAssertEqual(couriers[0].vehicleType, .car)
        XCTAssertEqual(couriers[0].defaultPlatforms.map(\.code), ["trendyol_go"])
        XCTAssertTrue(defaults.bool(forKey: AppPreferences.hasCompletedOnboardingKey))
        XCTAssertEqual(defaults.double(forKey: AppPreferences.costPerKmKey), VehicleType.car.defaultCostPerKm)
    }

    // MARK: - Calisiyorum modu

    func testWorkSessionPersistsAndProducesSummary() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let manager = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)

        XCTAssertFalse(manager.isWorking)
        manager.start(now: at(6, 9))
        XCTAssertTrue(manager.isWorking)

        // Uygulama yeniden acildi: oturum devam ediyor
        let restored = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
        XCTAssertTrue(restored.isWorking)
        XCTAssertEqual(restored.sessionStart, at(6, 9))

        let summary = restored.stop(now: at(6, 13))
        XCTAssertEqual(summary?.start, at(6, 9))
        XCTAssertEqual(summary?.end, at(6, 13))
        XCTAssertFalse(restored.isWorking)
        XCTAssertFalse(defaults.bool(forKey: AppPreferences.isWorkingKey))
        XCTAssertNil(restored.stop())
    }
}
