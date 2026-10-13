import XCTest

/// Test senaryosu yuklenir, Veritabani ekraninda satirlar gorunur.
final class DemoScenarioUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLoadScenarioShowsRowsInDatabase() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults", "-hasCompletedOnboarding", "YES",
                               "-hasSeenIntroV18", "YES", "-firm", "getir"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        let link = app.buttons["Test senaryoları"]
        for _ in 0..<8 where !link.exists || !link.isHittable { app.swipeUp() }
        link.tap()
        app.buttons["demo.paketTaxi30"].tap()
        XCTAssertTrue(app.staticTexts["demo.message"].waitForExistence(timeout: 15))
        app.buttons["demo.database"].tap()
        XCTAssertTrue(app.staticTexts["26 satır"].waitForExistence(timeout: 5))
    }
}
