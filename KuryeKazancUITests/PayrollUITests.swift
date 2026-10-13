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

    func testQuickEstimateAndSave() {
        let app = launch()
        // 1.7: firma kurulumda secilir (-firm trendyol_go); hakedis Kazanc sekmesinde
        XCTAssertTrue(app.tabBars.buttons["Kazanç"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Kazanç"].tap()
        XCTAssertTrue(app.staticTexts["payroll.platformName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["payroll.platformName"].label, "Trendyol GO")

        app.buttons["payroll.quick"].tap()
        let packages = app.textFields["quick.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 5))
        packages.tap()
        packages.typeText("45")
        let estimate = app.staticTexts["estimate.gross"]
        XCTAssertTrue(estimate.waitForExistence(timeout: 5))
        // 45 x 64,50 + 1.610 gunluk bonus (ornek tarife)
        XCTAssertTrue(estimate.label.contains("4.512"), "gelen: \(estimate.label)")

        let save = app.buttons["quick.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        // Kayit sonrasi Hakedis ekranina donulur, pano bu ayin brutunu gosterir
        let monthGross = app.staticTexts["dashboard.monthGross"]
        XCTAssertTrue(monthGross.waitForExistence(timeout: 5))
        XCTAssertTrue(monthGross.label.contains("4.512"), "gelen: \(monthGross.label)")
    }
}
