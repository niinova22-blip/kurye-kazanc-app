import XCTest

/// 1.14 Pro: ilk 10 gun ucretsiz deneme, bitince uygulama yerine kapatilamaz Pro kapisi. StoreKit UI testlerinde
/// kullanilmaz (fiyatlar yuklenmez); erisim baslatma argumanindan gelir ("-trial-new", "-trial", "-free" = deneme bitti).
final class ProGateUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ access: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", access, "-costPerKm", "2.5", "-isWorking", "NO",
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", "yemeksepeti",
            "-autoEstimateExpenses", "YES", "-reset-defaults",
        ]
        app.launch()
        return app
    }

    func testNewUserStartsTenDayTrial() {
        let app = launch("-trial-new")
        let startTrial = app.buttons["paywall.startTrial"]
        XCTAssertTrue(startTrial.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["paywall.close"].exists)
        XCTAssertFalse(app.tabBars.buttons["Bugün"].exists)
        startTrial.tap()

        // Deneme basladi: uygulama acilir, canli vardiya da acik
        XCTAssertTrue(app.tabBars.buttons["Bugün"].waitForExistence(timeout: 5))
        let start = app.buttons["today.startShift"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
    }

    func testEndedTrialBlocksAppWithoutClose() {
        let app = launch("-free")
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["paywall.headline"].exists)
        XCTAssertTrue(app.buttons["paywall.restore"].exists)
        XCTAssertFalse(app.buttons["paywall.close"].exists)
        XCTAssertFalse(app.buttons["paywall.startTrial"].exists)
        XCTAssertFalse(app.tabBars.buttons["Bugün"].exists)
        // Kapi asagi kaydirilarak kapanmaz
        app.swipeDown()
        XCTAssertFalse(app.tabBars.buttons["Bugün"].exists)
    }

    func testTrialShowsDaysLeftAndUpgradeInProfile() {
        let app = launch("-trial")
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.pro.trial"].waitForExistence(timeout: 5))
        let upgrade = app.buttons["profile.pro.upgrade"]
        XCTAssertTrue(upgrade.exists)
        XCTAssertTrue(app.buttons["profile.pro.restore"].exists)
        upgrade.tap()
        XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
    }
}
