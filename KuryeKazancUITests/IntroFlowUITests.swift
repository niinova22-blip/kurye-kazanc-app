import XCTest

/// 1.8 ilk acilis: firma secimi -> tanitim -> tarife sorulari -> yakit -> hedef.
final class IntroFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testIntroPagesThenFirmSetup() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults"]
        app.launch()
        XCTAssertTrue(app.buttons["firm.migros_hemen"].waitForExistence(timeout: 10))
        app.buttons["firm.migros_hemen"].tap()
        app.buttons["welcome.next"].tap()

        XCTAssertTrue(app.staticTexts["intro.page.0"].waitForExistence(timeout: 10))
        for _ in 0..<5 { app.buttons["intro.next"].tap() }
        XCTAssertTrue(app.buttons["intro.start"].waitForExistence(timeout: 5))
        app.buttons["intro.start"].tap()

        // Firma karsilamada secildi: kurulum dogrudan tarife sorulariyla baslar
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
                               "-hasSeenIntroV18", "YES", "-firm", "migros_hemen", "-sample-data"]
        app.launch()
        let bubble = app.buttons["help.bubble"].firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 10))
        bubble.tap()
        app.buttons["Uygulamayı tanı"].tap()
        XCTAssertTrue(app.staticTexts["intro.page.0"].waitForExistence(timeout: 5))
        app.buttons["intro.close"].tap()
        XCTAssertFalse(app.staticTexts["intro.page.0"].waitForExistence(timeout: 2))
    }

    /// Plan: tutar girilince klavye "Bitti" ile kapanir, gunluk hedefte gun secici gorunmez, plan sonucu acilir.
    func testPlanKeyboardClosesAndDailyGoalHidesDays() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults", "-hasCompletedOnboarding", "YES",
                               "-hasSeenIntroV18", "YES", "-firm", "trendyol_go"]
        app.launch()
        let card = app.buttons["today.goalCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        let amount = app.textFields["plan.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["plan.days"].exists, "Aylik hedefte gun secici gorunur")
        app.segmentedControls["plan.period"].buttons["Günlük"].tap()
        XCTAssertTrue(waitUntilGone(app.staticTexts["plan.days"]), "Gunluk hedefte gun secici olmamali")

        amount.tap()
        amount.typeText("2500")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons["keyboard.done"].firstMatch.tap()
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch), "Klavye kapanmali")

        app.buttons["plan.save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["goal.result"].firstMatch.waitForExistence(timeout: 5))
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
