import XCTest

/// Hakedis sekmesi: platform secimi, hizli tahmin ve kaydin listede gorunmesi (bellek ici depo, sunucu yok).
final class PayrollUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-costPerKm", "2.5", "-isWorking", "NO",
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", "trendyol_go", "-autoEstimateExpenses", "YES", "-reset-defaults",
        ]
        app.launch()
        return app
    }

    func testManualCalculationAndSave() {
        let app = launch()
        // 1.9: hizli tahmin / detayli kayit yerine "Elle hesapla" (gun / hafta / ay)
        XCTAssertTrue(app.tabBars.buttons["Kazanç"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Kazanç"].tap()
        XCTAssertTrue(app.staticTexts["payroll.platformName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["payroll.platformName"].label, "Trendyol GO")
        XCTAssertFalse(app.buttons["payroll.quick"].exists)

        let manual = app.buttons["payroll.manual"]
        if !manual.waitForExistence(timeout: 3) { app.swipeUp() }
        manual.tap()
        XCTAssertTrue(app.segmentedControls["manual.span"].waitForExistence(timeout: 5))
        let packages = app.textFields["manual.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 5))
        packages.tap()
        packages.typeText("45")
        let net = app.staticTexts["manual.net"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        // 45 x 64,50 + 1.610 gunluk bonus (ornek tarife); km girilmedi -> yakit yok
        XCTAssertTrue(net.label.contains("4.512"), "gelen: \(net.label)")

        let save = app.buttons["manual.save"]
        if !save.isHittable { app.swipeUp() }
        save.tap()
        // Kayit sonrasi Kazanc ekranina donulur, pano bu ayin brutunu gosterir
        let monthGross = app.staticTexts["dashboard.monthGross"]
        XCTAssertTrue(monthGross.waitForExistence(timeout: 8))
        XCTAssertTrue(monthGross.label.contains("4.512"), "gelen: \(monthGross.label)")
    }

    func testManualWeekShowsDailyAverageAndDetail() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Kazanç"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Kazanç"].tap()
        let manual = app.buttons["payroll.manual"]
        if !manual.waitForExistence(timeout: 3) { app.swipeUp() }
        manual.tap()
        XCTAssertTrue(app.segmentedControls["manual.span"].waitForExistence(timeout: 5))
        app.segmentedControls["manual.span"].buttons["Haftalık"].tap()
        XCTAssertTrue(app.textFields["manual.days"].waitForExistence(timeout: 5))
        let packages = app.textFields["manual.packages"]
        packages.tap()
        packages.typeText("270")
        XCTAssertTrue(app.staticTexts["manual.net"].waitForExistence(timeout: 5))
        let detail = app.descendants(matching: .any)["manual.detail"].firstMatch
        if !detail.exists { app.swipeUp() }
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }
}
