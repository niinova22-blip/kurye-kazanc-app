import XCTest

/// 1.7 tanitim ve kurulum: tanitim -> firma -> tarife sorulari -> yakit -> hedef.
final class IntroFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testIntroPagesThenFirmSetup() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults"]
        app.launch()
        XCTAssertTrue(app.staticTexts["intro.page.0"].waitForExistence(timeout: 10))
        for _ in 0..<5 { app.buttons["intro.next"].tap() }
        XCTAssertTrue(app.buttons["intro.start"].waitForExistence(timeout: 5))
        app.buttons["intro.start"].tap()

        XCTAssertTrue(app.buttons["firm.migros_hemen"].waitForExistence(timeout: 5))
        app.buttons["firm.migros_hemen"].tap()
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["question.region.plus"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["setup.next"].isEnabled, "Bolge secmeden devam edilmemeli")
        app.buttons["question.region.plus"].tap()
        app.buttons["setup.next"].tap()
        let price = app.textFields["fuel.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        price.tap()
        price.typeText("45")
        app.buttons["setup.next"].tap()
        let amount = app.textFields["goal.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("100000")
        app.buttons["setup.finish"].tap()

        XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
    }

    func testReplayFromHelpBubble() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults", "-hasCompletedOnboarding", "YES",
                               "-hasSeenIntroV17", "YES", "-firm", "migros_hemen", "-sample-data"]
        app.launch()
        let bubble = app.buttons["help.bubble"].firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 10))
        bubble.tap()
        app.buttons["Uygulamayı tanı"].tap()
        XCTAssertTrue(app.staticTexts["intro.page.0"].waitForExistence(timeout: 5))
        app.buttons["intro.close"].tap()
        XCTAssertFalse(app.staticTexts["intro.page.0"].waitForExistence(timeout: 2))
    }
}
