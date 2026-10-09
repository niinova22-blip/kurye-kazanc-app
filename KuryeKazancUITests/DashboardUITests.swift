import XCTest

/// Simulatorde calisan UI testleri.
/// Not: GPS, gercek ekran goruntusu OCR'i ve arka plan davranislari simulatorde tam dogrulanamaz;
/// bunlar TestFlight uzerinden gercek cihazda elle test edilir (bkz. TESTFLIGHT_NOTES.md).
final class DashboardUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Onboarding tamamlanmis, konum kapali, bellek ici veritabani.
    private func launch(sampleData: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        // -key value: UserDefaults arguman alani; testleri onceki durumdan bagimsiz kilar.
        app.launchArguments = [
            "-ui-testing", "-costPerKm", "2.5", "-isWorking", "NO",
            "-hasCompletedOnboarding", "YES", "-autoEstimateExpenses", "YES",
            // Paylasim tercihleri testler arasinda tasinmasin
            "-dataSharingOptIn", "NO", "-locationSharingOptIn", "NO", "-calibrationOptIn", "NO",
        ]
        if sampleData { app.launchArguments.append("-sample-data") }
        app.launch()
        return app
    }

    // MARK: - Ana ekran

    func testDashboardShowsKeyMetrics_emptyState() {
        let app = launch(sampleData: false)

        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["dashboard.netPerHour"].exists)
        XCTAssertTrue(app.staticTexts["dashboard.workDuration"].exists)
        XCTAssertTrue(app.staticTexts["dashboard.distance"].exists)
        XCTAssertEqual(app.staticTexts["dashboard.netPerHour"].label, "—")
    }

    func testDashboardSummarizesSampleData() {
        let app = launch(sampleData: true)

        let net = app.staticTexts["dashboard.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 10))
        // 1050 brut - 150 tahmini - 50 manuel = 850
        XCTAssertTrue(net.label.contains("850"), "Beklenen net 850, gelen: \(net.label)")
        XCTAssertEqual(app.staticTexts["dashboard.workDuration"].label, "6 sa")
        XCTAssertTrue(app.staticTexts["dashboard.distance"].label.hasPrefix("60"))
    }

    // MARK: - Kazanc / gider ekleme

    func testAddEarningManually_updatesNet() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        app.buttons["Elle kazanç"].tap()

        let gross = app.textFields["earningForm.gross"]
        XCTAssertTrue(gross.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["form.save"].isEnabled, "Tutar girilmeden kaydedilmemeli")
        gross.tap()
        gross.typeText("500")

        let save = app.buttons["form.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        // 850 + 500 = 1.350
        let net = app.staticTexts["dashboard.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label CONTAINS %@", "1.350")
        expectation(for: predicate, evaluatedWith: net)
        waitForExpectations(timeout: 5)
    }

    func testAddFuelExpense_replacesEstimate() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        app.buttons["Gider"].tap()

        let amount = app.textFields["expenseForm.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("100")
        app.buttons["form.save"].tap()

        // Yakit girildi -> km tahmini (150) duser: 1050 - 50 - 100 = 900
        let net = app.staticTexts["dashboard.netEarnings"]
        let predicate = NSPredicate(format: "label CONTAINS %@", "900")
        expectation(for: predicate, evaluatedWith: net)
        waitForExpectations(timeout: 5)
    }

    func testCancelFormDoesNotSave() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        app.buttons["Elle kazanç"].tap()
        XCTAssertTrue(app.buttons["form.cancel"].waitForExistence(timeout: 5))
        app.buttons["form.cancel"].tap()
        XCTAssertFalse(app.buttons["dashboard.earningRow"].exists)
    }

    func testAddMenuOffersScreenshotFirst() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        XCTAssertTrue(app.buttons["Ekran görüntüsü"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Elle kazanç"].exists)
        XCTAssertTrue(app.buttons["Gider"].exists)
    }

    func testSampleRecordsShowVerificationBadges() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        // Ornek veride bir elle, bir ekran goruntusu kaydi var. Satir bir dugme oldugundan
        // rozet metni dugmenin etiketine katilir (ic kimlikler XCUITest'te gorunmez).
        let labels = app.buttons.matching(identifier: "dashboard.earningRow").allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(labels.count, 2)
        XCTAssertTrue(labels.contains { $0.contains("Elle girildi") }, "\(labels)")
        XCTAssertTrue(labels.contains { $0.contains("Ekran görüntüsü") }, "\(labels)")
    }

    // MARK: - Sekmeler

    func testHistoryAndSettingsTabs() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.tabBars.buttons["Analiz"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Analiz"].tap()
        XCTAssertTrue(app.segmentedControls["history.periodPicker"].waitForExistence(timeout: 5))
        app.segmentedControls["history.periodPicker"].buttons["Gün"].tap()
        let net = app.staticTexts["history.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        XCTAssertTrue(net.label.contains("850"), "Gunluk net 850 olmali, gelen: \(net.label)")

        app.tabBars.buttons["Profil"].tap()
        XCTAssertTrue(app.switches["settings.autoEstimate"].waitForExistence(timeout: 5))
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let sharing = app.switches["settings.dataSharing"]
        for _ in 0..<6 where !sharing.exists {
            app.swipeUp()
        }
        XCTAssertTrue(sharing.exists)
    }

    func testAnalysisShowsPlatformComparison() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.tabBars.buttons["Analiz"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Analiz"].tap()
        app.segmentedControls["history.periodPicker"].buttons["Gün"].tap()
        let platforms = app.staticTexts["analysis.platform.getir"]
        for _ in 0..<4 where !platforms.exists { app.swipeUp() }
        XCTAssertTrue(platforms.exists)
    }

    func testDataSharingRequiresExplicitConsent() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()

        // Ekran goruntusu bolumu eklendi: paylasim satiri ilk ekranda olmayabilir
        XCTAssertTrue(app.switches["settings.autoEstimate"].waitForExistence(timeout: 5))
        let toggle = app.switches["settings.dataSharing"]
        for _ in 0..<6 where !(toggle.exists && toggle.isHittable) { app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0", "Varsayilan kapali olmali (opt-in)")

        toggle.switches.firstMatch.tap()
        // Onay ekrani acilmali; vazgecilirse kapali kalmali
        XCTAssertTrue(app.buttons["consent.accept"].waitForExistence(timeout: 5))
        app.buttons["Vazgeç"].tap()
        XCTAssertEqual(toggle.value as? String, "0")
    }

    func testAcceptingEarningsSharingAlsoTurnsOnLocationDensity() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        let toggle = app.switches["settings.dataSharing"]
        for _ in 0..<6 where !(toggle.exists && toggle.isHittable) { app.swipeUp() }
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["consent.accept"].waitForExistence(timeout: 5))
        app.buttons["consent.accept"].tap()

        let location = app.switches["profile.locationSharing"]
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        // Onay sayfasi kapanirken anahtar degeri bir an gecikebiliyor (Codemagic'te 0 okundu): degeri bekle
        XCTAssertTrue(waitForValue("1", of: toggle), "Kazanc paylasimi acilmadi")
        XCTAssertTrue(waitForValue("1", of: location), "Konum yogunlugu kazanc paylasimiyla birlikte acik gelir")
    }

    private func waitForValue(_ value: String, of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func testLocationSharingRequiresEarningsSharingAndOwnConsent() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        let location = app.switches["profile.locationSharing"]
        for _ in 0..<7 where !location.exists { app.swipeUp() }
        XCTAssertTrue(location.exists)
        XCTAssertFalse(location.isEnabled, "Kazanc paylasimi kapaliyken konum paylasimi acilamamali")
    }

    func testProfileOffersAutoScanToggle() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let autoScan = app.switches["profile.autoScan"]
        for _ in 0..<5 where !autoScan.exists { app.swipeUp() }
        XCTAssertTrue(autoScan.exists)
        // UI testlerinde tarama tercihi bos alandan okunur: kapali baslar (izin istenmez)
        XCTAssertEqual(autoScan.value as? String, "0")
    }

    func testProfileOffersAutoShift() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let toggle = app.switches["profile.autoShift"]
        for _ in 0..<6 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        // UI testlerinde tercih bos alandan okunur: kapali baslar (izin istenmez)
        XCTAssertEqual(toggle.value as? String, "0", "Varsayilan kapali")
    }

    func testProfileCalibrationIsOffByDefault() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let toggle = app.switches["profile.calibration"]
        for _ in 0..<8 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0", "Kalibrasyon varsayilan kapali olmali (opt-in)")
    }

    func testDashboardShowsGrossAndExpenseBreakdown() {
        let app = launch(sampleData: true)
        // Satir birlestirilmis erisilebilirlik ogesi: turu (metin/diger) degisebilir
        let breakdown = app.descendants(matching: .any)["dashboard.breakdown"].firstMatch
        XCTAssertTrue(breakdown.waitForExistence(timeout: 10))
        // 1050 brut; 150 tahmini + 50 elle = 200 gider
        XCTAssertTrue(breakdown.label.contains("1.050"), "Beklenen brut 1.050, gelen: \(breakdown.label)")
        XCTAssertTrue(breakdown.label.contains("200"), "Beklenen gider 200, gelen: \(breakdown.label)")
    }

    func testCommunityTabExists() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Topluluk"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Topluluk"].tap()
        XCTAssertTrue(app.staticTexts["Bölgendeki kuryelerle karşılaştır"].waitForExistence(timeout: 5))
    }
}

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingFlowReachesDashboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults"]
        app.launch()

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(app.buttons["onboarding.vehicle.scooter"].waitForExistence(timeout: 10))
        app.buttons["onboarding.vehicle.scooter"].tap()
        next.tap()                                   // -> platformlar

        XCTAssertTrue(app.buttons["onboarding.platform.getir"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "Platform secmeden devam edilmemeli")
        app.buttons["onboarding.platform.getir"].tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()                                   // -> konum

        XCTAssertTrue(app.staticTexts["Konum yalnızca vardiyada"].waitForExistence(timeout: 5))
        next.tap()                                   // -> paylasim

        XCTAssertTrue(app.staticTexts["Bölgendeki kuryelerle karşılaştır"].waitForExistence(timeout: 5))
        next.tap()                                   // Basla (paylasim acilmadan)

        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
    }
}
