import XCTest

/// 1.15 ilk acilis: firma secimi; Paket Taxi Restoran'da tek soru (gunluk saat), gerisi varsayilan.
final class IntroFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFirmThenSingleHoursQuestion() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults"]
        app.launch()
        // 1.9: iki firma; Paket Taxi secilince kol sorulur
        XCTAssertTrue(app.buttons["firm.pakettaxi"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["firm.yemeksepeti"].exists)
        app.buttons["firm.pakettaxi"].tap()
        XCTAssertTrue(app.buttons["branch.pt_restoran"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["welcome.next"].isEnabled, "Kol secmeden devam edilmemeli")
        app.buttons["branch.pt_restoran"].tap()
        app.buttons["welcome.next"].tap()

        // Bolge, kidem, yakit, hedef sorulmaz; yalnizca gunluk saat (hazir secili)
        XCTAssertTrue(app.staticTexts["quickSetup.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["question.region.r1"].exists)
        app.buttons["quickSetup.start"].tap()
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
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
                               "-hasSeenIntroV18", "YES", "-firm", "yemeksepeti"]
        app.launch()
        // 1.10: hedef halkasinin altinda acik "Plan oluştur" dugmesi
        let card = app.buttons["today.planButton"]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
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

        // 1.11: tutar yazilmisken donem degisirse once sorulur; karsiligina cevrilerek yeniden hesaplanir
        let period = app.segmentedControls["plan.period"]
        for _ in 0..<4 where !period.isHittable { app.swipeDown() }
        period.buttons["Aylık"].tap()
        // Onay sayfasi dugmelerinde kimlik her iOS surumunde gorunmeyebilir: etiketle aranir
        let convert = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ile yeniden hesapla")).firstMatch
        XCTAssertTrue(convert.waitForExistence(timeout: 5), "Donem degisince onay sorulmali")
        convert.tap()
        XCTAssertTrue(app.descendants(matching: .any)["goal.result"].firstMatch.waitForExistence(timeout: 5))
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
