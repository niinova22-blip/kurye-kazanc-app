import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class ScreenshotVerifierTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 20))! }
    private var verifier: ScreenshotVerifier { ScreenshotVerifier(calendar: calendar) }

    private func activeTemplate() -> OCRTemplate {
        var t = BundledTemplates.template(id: "getir.earnings")!
        t.status = .active
        return t
    }

    private func parsed(total: Double = 980, packages: Int = 11, daysAgo: Int = 0,
                        period: OCRTemplate.Period = .day, fingerprint: Int = 3,
                        review: Set<ParsedEarning.Field> = []) -> ParsedEarning {
        ParsedEarning(
            platformCode: "getir",
            date: calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!,
            packageCount: packages, totalEarning: total, bonus: 0, totalIncludesBonus: true,
            fieldsToReview: review, templateID: "getir.earnings", templateVersion: 1,
            templateStatus: .active, fingerprintMatches: fingerprint, period: period
        )
    }

    // MARK: - Gercek ekran goruntusu

    func testAuthenticity() {
        XCTAssertTrue(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: true, pixelWidth: 1, pixelHeight: 1, hasCameraMetadata: false))
        XCTAssertFalse(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: false, pixelWidth: 1179, pixelHeight: 2556, hasCameraMetadata: false))
        // PhotoKit bilgisi yoksa: bilinen iPhone ekran cozunurlugu + kamera EXIF'i yok
        XCTAssertTrue(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: nil, pixelWidth: 1179, pixelHeight: 2556, hasCameraMetadata: false))
        XCTAssertFalse(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: nil, pixelWidth: 1179, pixelHeight: 2556, hasCameraMetadata: true))
        XCTAssertFalse(ScreenshotAuthenticity.isGenuine(assetIsScreenshot: nil, pixelWidth: 3024, pixelHeight: 4032, hasCameraMetadata: false))
    }

    // MARK: - Aday seviye

    func testAllChecksPass_isVerified() {
        let result = verifier.assess(parsed(), template: activeTemplate(), isGenuine: true, referenceDate: now)
        XCTAssertEqual(result.candidate, .verified, "\(result.issues)")
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testCalibratingTemplate_isUnverified() {
        let result = verifier.assess(parsed(), template: BundledTemplates.template(id: "getir.earnings"), isGenuine: true, referenceDate: now)
        XCTAssertEqual(result.candidate, .ocrUnverified)
        XCTAssertFalse(result.templateActive)
    }

    func testNotGenuine_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(), template: activeTemplate(), isGenuine: false, referenceDate: now).candidate, .ocrUnverified)
    }

    func testWeeklyScreen_isUnverifiedWithIssue() {
        let result = verifier.assess(parsed(period: .week), template: activeTemplate(), isGenuine: true, referenceDate: now)
        XCTAssertEqual(result.candidate, .ocrUnverified)
        XCTAssertFalse(result.isDailyScreen)
        XCTAssertTrue(result.issues.contains { $0.contains("Haftalık") })
    }

    func testOldOrFutureDate_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(daysAgo: 15), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        XCTAssertEqual(verifier.assess(parsed(daysAgo: -1), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        XCTAssertEqual(verifier.assess(parsed(daysAgo: 14), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .verified)
    }

    func testFingerprintBelowMinimum_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(fingerprint: 1), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
    }

    func testInconsistentPackageFee_isUnverified() {
        // 11 paket x en fazla 250 TL = 2.750; 9.000 TL aciklanamaz
        XCTAssertEqual(verifier.assess(parsed(total: 9000), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        // 11 paket x en az 40 TL = 440; 100 TL fazla dusuk
        XCTAssertEqual(verifier.assess(parsed(total: 100), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        // Paket okunamadiysa ucret kontrolu yapilmaz
        XCTAssertEqual(verifier.assess(parsed(total: 9000, packages: 0), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .verified)
    }

    func testUncertainTotalOrPlatform_isUnverified() {
        XCTAssertEqual(verifier.assess(parsed(review: [.totalEarning]), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        XCTAssertEqual(verifier.assess(parsed(), template: nil, isGenuine: true, referenceDate: now).candidate, .ocrUnverified)
        // Bonus/paket belirsizligi seviyeyi dusurmez
        XCTAssertEqual(verifier.assess(parsed(review: [.bonus]), template: activeTemplate(), isGenuine: true, referenceDate: now).candidate, .verified)
    }

    // MARK: - Son seviye

    func testResolve() {
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: false, userEditedReadValues: false, candidate: .verified), .manual)
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: true, userEditedReadValues: true, candidate: .verified), .ocrEdited)
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: true, userEditedReadValues: false, candidate: .verified), .verified)
        XCTAssertEqual(VerificationLevel.resolve(isFromScreenshot: true, userEditedReadValues: false, candidate: .ocrUnverified), .ocrUnverified)
        XCTAssertTrue(VerificationLevel.verified.countsForCommunity)
        XCTAssertFalse(VerificationLevel.ocrUnverified.countsForCommunity)
    }
}
