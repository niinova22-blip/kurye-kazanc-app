import XCTest

/// Simulatorde calisan UI duman testleri.
/// Not: GPS, OCR (gercek ekran goruntusu) ve arka plan davranislari simulatorde tam dogrulanamaz;
/// bunlar TestFlight uzerinden gercek cihazda elle test edilir (bkz. TESTFLIGHT_NOTES.md).
final class DashboardUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(sampleData: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        // -costPerKm / -isWorking: UserDefaults arguman alani; testleri onceki durumdan bagimsiz kilar.
        app.launchArguments = ["-ui-testing", "-costPerKm", "2.5", "-isWorking", "NO"]
        if sampleData { app.launchArguments.append("-sample-data") }
        app.launch()
        return app
    }

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

    func testAddMenuOpensSheets() {
        let app = launch(sampleData: false)
        let addMenu = app.buttons["dashboard.addMenu"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 10))
        addMenu.tap()
        app.buttons["Kazanç ekle"].tap()
        XCTAssertTrue(app.buttons["Kapat"].waitForExistence(timeout: 5))
    }
}
