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

    func testApplyOCR_dailyDurationSetsStartButKeepsHoursReview() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.endTime = at(6, 17)
        var parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(6, 0)), packageCount: 12,
            totalEarning: 1000, bonus: 0, totalIncludesBonus: true, fieldsToReview: []
        )
        parsed.period = .day
        parsed.workDuration = 6 * 3600 + 30 * 60
        vm.apply(parsed, platforms: platforms)

        XCTAssertEqual(vm.resolvedInterval().start, at(6, 10, 30))
        XCTAssertEqual(vm.resolvedInterval().end, at(6, 17))
        XCTAssertTrue(vm.fieldsToReview.contains(.hours))
    }

    func testApplyOCR_dailyDurationKeepsSessionTimes() {
        let session = WorkSessionSummary(start: at(6, 8), end: at(6, 14, 15), distanceKm: 10)
        let vm = EarningFormViewModel(session: session, defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        var parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(6, 0)), packageCount: 12,
            totalEarning: 1000, bonus: 0, totalIncludesBonus: true, fieldsToReview: []
        )
        parsed.period = .day
        parsed.workDuration = 3 * 3600
        vm.apply(parsed, platforms: platforms)

        XCTAssertEqual(vm.resolvedInterval().start, at(6, 8))
        XCTAssertEqual(vm.resolvedInterval().end, at(6, 14, 15))
        XCTAssertTrue(vm.fieldsToReview.contains(.hours))
    }

    func testApplyOCR_dailyDurationCrossingMidnightNotApplied() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 9), calendar: calendar)
        vm.startTime = at(6, 6)
        vm.endTime = at(6, 9)
        var parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(6, 0)), packageCount: 12,
            totalEarning: 1000, bonus: 0, totalIncludesBonus: true, fieldsToReview: []
        )
        parsed.period = .day
        parsed.workDuration = 10 * 3600
        vm.apply(parsed, platforms: platforms)

        XCTAssertEqual(vm.resolvedInterval().start, at(6, 6))
        XCTAssertTrue(vm.fieldsToReview.contains(.hours))
    }

    /// Review Focus 4: haftalik sure tek vardiya saatine yazilmaz.
    func testApplyOCR_weeklyDurationIgnored() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.startTime = at(6, 10)
        vm.endTime = at(6, 16)
        var parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(6, 0)), packageCount: 54,
            totalEarning: 6000, bonus: 0, totalIncludesBonus: true, fieldsToReview: []
        )
        parsed.period = .week
        parsed.workDuration = 23 * 3600 + 32 * 60
        vm.apply(parsed, platforms: platforms)

        XCTAssertEqual(vm.resolvedInterval().start, at(6, 10))
        XCTAssertTrue(vm.fieldsToReview.contains(.hours))
    }

    func testImportedOrderCard_forcesReviewAndVATNote() {
        var item = imported(period: .order)
        item.parsed.amountsExcludeVAT = true
        item.assessment.issues = ["Tek sipariş ekranı: günlük kazanç ekranını kullan."]
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: item, now: at(6, 18), calendar: calendar)
        XCTAssertTrue(vm.fieldsToReview.contains(.gross))
        XCTAssertTrue(vm.assessmentIssues.contains { $0.contains("Tek sipariş") })
        XCTAssertEqual(vm.amountNote, "Bu ekrandaki tutarlar KDV hariç gösteriliyor.")
    }

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
        let importer = ScreenshotImporter(
            recognizer: FakeRecognizer(), parser: EarningsScreenshotParser(calendar: calendar),
            verifier: ScreenshotVerifier(calendar: calendar), assetIsScreenshot: { _ in nil }
        )
        await vm.importScreenshot(
            data: Self.pngData(), assetIdentifier: nil, importer: importer,
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
        await vm.importScreenshot(
            data: Self.pngData(), assetIdentifier: nil,
            importer: ScreenshotImporter(recognizer: FailingRecognizer(), assetIsScreenshot: { _ in nil }),
            platforms: platforms
        )
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
        XCTAssertEqual(vm.step, .vehicle)
        XCTAssertTrue(vm.canContinue)
        vm.next()
        XCTAssertEqual(vm.step, .platforms)
        XCTAssertFalse(vm.canContinue) // en az bir platform
        vm.togglePlatform("getir")
        vm.togglePlatform("trendyol_go")
        vm.togglePlatform("getir")
        XCTAssertTrue(vm.canContinue)
        vm.vehicleType = .car
        vm.next(); vm.next()
        XCTAssertEqual(vm.step, .sharing)
        XCTAssertTrue(vm.isLastStep)

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
        manager.start(at: at(6, 9))
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

    func testAutoShiftStartsBackdatedAndCanBeCancelled() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let manager = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
        manager.start(at: at(6, 9, 55), origin: .auto)
        XCTAssertEqual(manager.origin, .auto)
        XCTAssertEqual(manager.sessionStart, at(6, 9, 55))

        let restored = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
        XCTAssertEqual(restored.origin, .auto, "Kaynak kalici")

        manager.cancel()
        XCTAssertFalse(manager.isWorking)
        XCTAssertNil(manager.origin)
        XCTAssertNil(manager.stop(), "Iptal sonrasi ozet yok")
    }

    func testStopUsesExplicitEnd() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let manager = WorkSessionManager(location: LocationService(isEnabled: false, defaults: defaults), defaults: defaults)
        manager.start(at: at(6, 10), origin: .auto)
        let summary = manager.stop(now: at(6, 12), end: at(6, 11, 40))
        XCTAssertEqual(summary?.end, at(6, 11, 40), "Bitis son hareket ani")
    }

    // MARK: - Dogrulama seviyesi

    private func imported(total: Double = 1000, bonus: Double = 100, candidate: VerificationLevel = .ocrUnverified,
                          period: OCRTemplate.Period = .day) -> ImportedScreenshot {
        let parsed = ParsedEarning(
            platformCode: "getir", date: calendar.startOfDay(for: at(5, 0)), packageCount: 12,
            totalEarning: total, bonus: bonus, totalIncludesBonus: true, fieldsToReview: [],
            templateID: "getir.earnings", templateVersion: 1, templateStatus: .calibrating,
            fingerprintMatches: 3, period: period
        )
        let assessment = ScreenshotAssessment(
            isGenuine: true, templateActive: candidate == .verified, fingerprintOK: true, dateRecent: true,
            isDailyScreen: period == .day || period == .unknown, internallyConsistent: true, candidate: candidate,
            issues: period == .week ? ["Haftalık ekran: vardiya için günlük kazanç ekranını kullan."] : []
        )
        return ImportedScreenshot(lines: [RecognizedLine(text: "Getir", x: 0, y: 0, width: 1, height: 0.1)],
                                  parsed: parsed, assessment: assessment, capturedAt: nil,
                                  assetIdentifier: "asset-1", isGenuine: true,
                                  textHash: TextHash.of(["Getir"]))
    }

    func testDuplicateScreenshot_isOcrEditedWithIssue() throws {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.apply(imported(candidate: .verified), platforms: platforms, knownTextHashes: [TextHash.of(["Getir"])])
        XCTAssertTrue(vm.isDuplicateScreenshot)
        XCTAssertEqual(vm.pendingVerification, .ocrEdited, "Daha once kullanilmis ekran topluluga giremez")
        XCTAssertTrue(vm.assessmentIssues.contains("Bu ekran görüntüsü daha önce kaydedilmiş."))

        let record = try vm.save(in: context)
        XCTAssertEqual(record.verification, .ocrEdited)
        XCTAssertEqual(record.evidence?.textHash, TextHash.of(["Getir"]))
    }

    func testUnknownScreenshot_isNotDuplicate() {
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        vm.apply(imported(candidate: .verified), platforms: platforms, knownTextHashes: ["0000000000000000"])
        XCTAssertFalse(vm.isDuplicateScreenshot)
        XCTAssertEqual(vm.pendingVerification, .verified)
        XCTAssertFalse(vm.assessmentIssues.contains("Bu ekran görüntüsü daha önce kaydedilmiş."))

        // Varsayilan parametreyle eski cagri bicimi de calisir
        vm.apply(imported(), platforms: platforms)
        XCTAssertFalse(vm.isDuplicateScreenshot)
    }

    func testImportScreenshot_marksDuplicateAndPassesCaptureDate() async {
        let lines = ["Getir", "Kazançlarım", "Toplam Kazanç", "₺700"]
        struct FakeRecognizer: TextRecognizing {
            var lines: [String]
            func recognize(in image: UIImage) async throws -> [RecognizedLine] {
                lines.map { RecognizedLine(text: $0, x: 0, y: 0, width: 1, height: 0.05) }
            }
        }
        let importer = ScreenshotImporter(
            recognizer: FakeRecognizer(lines: lines), parser: EarningsScreenshotParser(calendar: calendar),
            verifier: ScreenshotVerifier(calendar: calendar), assetIsScreenshot: { _ in nil }
        )
        let captured = at(5, 23)
        let vm = EarningFormViewModel(defaultPlatform: nil, now: at(6, 18), calendar: calendar)
        await vm.importScreenshot(
            data: Self.pngData(), assetIdentifier: nil, capturedAt: captured, importer: importer,
            platforms: platforms, knownTextHashes: [TextHash.of(lines)], referenceDate: at(6, 18)
        )
        XCTAssertEqual(vm.ocrState, .finished)
        XCTAssertTrue(vm.isDuplicateScreenshot)
        XCTAssertEqual(vm.pendingVerification, .ocrEdited)
        XCTAssertEqual(vm.imported?.capturedAt, captured)

        // Ozet bilinmiyorsa (ornegin onceki kayit silindi) isaret kalkar
        await vm.importScreenshot(data: Self.pngData(), assetIdentifier: nil, importer: importer,
                                  platforms: platforms, knownTextHashes: [], referenceDate: at(6, 18))
        XCTAssertFalse(vm.isDuplicateScreenshot)
    }

    func testScreenshotSave_storesEvidenceAndCandidateLevel() throws {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(candidate: .verified), now: at(6, 18), calendar: calendar)
        vm.startTime = at(5, 10); vm.endTime = at(5, 16) // saat degisikligi seviyeyi dusurmez
        let record = try vm.save(in: context)
        XCTAssertEqual(record.verification, .verified)
        XCTAssertEqual(record.source, .ocr)
        XCTAssertEqual(record.evidence?.assetIdentifier, "asset-1")
        XCTAssertEqual(record.evidence?.parsedTotal, 1000)
    }

    func testScreenshotSave_editedAmountBecomesOcrEdited() throws {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(candidate: .verified), now: at(6, 18), calendar: calendar)
        vm.grossText = "950"
        let record = try vm.save(in: context)
        XCTAssertEqual(record.verification, .ocrEdited)
        XCTAssertNotNil(record.evidence, "Kanit duzenlemede de saklanir")
    }

    func testScreenshotSave_reformattedSameValueIsNotAnEdit() throws {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(), now: at(6, 18), calendar: calendar)
        vm.grossText = "900,00" // ayni deger, farkli yazim
        XCTAssertEqual(try vm.save(in: context).verification, .ocrUnverified)
    }

    func testWeeklyScreenShowsIssue() {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(period: .week), now: at(6, 18), calendar: calendar)
        XCTAssertTrue(vm.assessmentIssues.contains { $0.contains("Haftalık") })
        XCTAssertEqual(vm.pendingVerification, .ocrUnverified)
    }

    func testImportedWeeklyScreen_forcesReviewAndShowsAssessment() {
        let vm = EarningFormViewModel(defaultPlatform: nil, imported: imported(period: .week), now: at(6, 18), calendar: calendar)
        XCTAssertEqual(vm.ocrState, .finished, "Paylasim/oneri ile acilan formda degerlendirme gorunmeli")
        XCTAssertTrue(vm.fieldsToReview.contains(.gross))
        XCTAssertTrue(vm.fieldsToReview.contains(.date))
    }

    func testManualSave_isManualWithoutEvidence() throws {
        let vm = EarningFormViewModel(defaultPlatform: platforms.first, now: at(6, 18), calendar: calendar)
        vm.grossText = "500"
        let record = try vm.save(in: context)
        XCTAssertEqual(record.verification, .manual)
        XCTAssertNil(record.evidence)
    }

    func testEditingOcrRecordKeepsLevelUnlessValuesChange() throws {
        let first = EarningFormViewModel(defaultPlatform: nil, imported: imported(), now: at(6, 18), calendar: calendar)
        let record = try first.save(in: context)

        let edit = EarningFormViewModel(record: record, now: at(6, 19), calendar: calendar)
        edit.district = "Kadıköy"
        XCTAssertEqual(try edit.save(in: context).verification, .ocrUnverified)

        let edit2 = EarningFormViewModel(record: record, now: at(6, 19), calendar: calendar)
        edit2.bonusText = "150"
        XCTAssertEqual(try edit2.save(in: context).verification, .ocrEdited)
    }

    /// Ice aktarici icin gecerli (kucuk) PNG verisi.
    static func pngData() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }.pngData()!
    }
}
