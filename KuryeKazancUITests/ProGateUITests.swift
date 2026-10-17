import XCTest

/// 1.14 Pro: ucretsiz kullanici ("-free") canli vardiyayi baslatamaz, satin alma ekrani acilir; Profil'de Pro'ya gecis
/// ve geri yukleme gorunur. StoreKit UI testlerinde kullanilmaz (fiyatlar yuklenmez), yalnizca kapi denenir.
final class ProGateUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-free", "-costPerKm", "2.5", "-isWorking", "NO",
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", "yemeksepeti",
            "-autoEstimateExpenses", "YES", "-reset-defaults",
        ]
        app.launch()
        return app
    }

    func testFreeUserSeesPaywallInsteadOfLiveShift() {
        let app = launch()
        let start = app.buttons["today.startShift"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shift.tap"].exists)
        XCTAssertTrue(app.buttons["paywall.restore"].exists)
        app.buttons["paywall.close"].tap()

        // Vardiya baslamadi
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["today.liveShift"].exists)
    }

    func testProfileOffersUpgradeAndRestore() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        let upgrade = app.buttons["profile.pro.upgrade"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.pro.restore"].exists)
        upgrade.tap()
        XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
    }
}
