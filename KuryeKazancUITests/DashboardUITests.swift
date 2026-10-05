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
        app.buttons["Kazanç ekle"].tap()

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
        app.buttons["Gider ekle"].tap()

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
        app.buttons["Kazanç ekle"].tap()
        XCTAssertTrue(app.buttons["form.cancel"].waitForExistence(timeout: 5))
        app.buttons["form.cancel"].tap()
        XCTAssertFalse(app.buttons["dashboard.earningRow"].exists)
    }

    // MARK: - Sekmeler

    func testHistoryAndSettingsTabs() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.tabBars.buttons["Geçmiş"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Geçmiş"].tap()
        XCTAssertTrue(app.segmentedControls["history.periodPicker"].waitForExistence(timeout: 5))
        app.segmentedControls["history.periodPicker"].buttons["Gün"].tap()
        let net = app.staticTexts["history.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        XCTAssertTrue(net.label.contains("850"), "Gunluk net 850 olmali, gelen: \(net.label)")

        app.tabBars.buttons["Ayarlar"].tap()
        XCTAssertTrue(app.switches["settings.autoEstimate"].waitForExistence(timeout: 5))
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let sharing = app.switches["settings.dataSharing"]
        for _ in 0..<4 where !sharing.exists {
            app.swipeUp()
        }
        XCTAssertTrue(sharing.exists)
    }

    func testDataSharingRequiresExplicitConsent() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Ayarlar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ayarlar"].tap()

        let toggle = app.switches["settings.dataSharing"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0", "Varsayilan kapali olmali (opt-in)")

        toggle.switches.firstMatch.tap()
        // Onay ekrani acilmali; vazgecilirse kapali kalmali
        XCTAssertTrue(app.buttons["consent.accept"].waitForExistence(timeout: 5))
        app.buttons["Vazgeç"].tap()
        XCTAssertEqual(toggle.value as? String, "0")
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
        XCTAssertTrue(next.waitForExistence(timeout: 10))

        let name = app.textFields["onboarding.name"]
        name.tap()
        name.typeText("Test")
        next.tap()                                   // -> arac

        XCTAssertTrue(app.buttons["onboarding.vehicle.scooter"].waitForExistence(timeout: 5))
        app.buttons["onboarding.vehicle.scooter"].tap()
        next.tap()                                   // -> platformlar

        XCTAssertTrue(app.buttons["onboarding.platform.getir"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "Platform secmeden devam edilmemeli")
        app.buttons["onboarding.platform.getir"].tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()                                   // -> konum bilgisi

        XCTAssertTrue(app.staticTexts["Konum yalnızca çalışırken"].waitForExistence(timeout: 5))
        next.tap()                                   // Bitir

        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
    }
}
