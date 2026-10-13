import XCTest

/// Canli vardiya: ilk kullanimda tanitim filmi, her teslimde dokunma, bitince otomatik hesap ve kayit.
/// Simulatorde konum kapali: paketler ve sure sayilir, mesafe olculmez.
final class LiveShiftUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(firm: String = "trendyol_go") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-costPerKm", "2.5", "-isWorking", "NO",
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", firm, "-autoEstimateExpenses", "YES",
            "-reset-defaults",
        ]
        app.launch()
        return app
    }

    func testFirstShiftShowsTutorialThenCountsTapsAndSaves() {
        let app = launch()
        let start = app.buttons["today.startShift"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        // Ilk kullanim: tanitim filmi, sonra vardiya ekrani
        XCTAssertTrue(app.staticTexts["shiftTutorial.title.0"].waitForExistence(timeout: 5))
        app.buttons["shiftTutorial.skip"].tap()

        let tap = app.buttons["shift.tap"]
        XCTAssertTrue(tap.waitForExistence(timeout: 8))
        let count = app.staticTexts["shift.packages"]
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, "0 paket")
        tap.tap()
        tap.tap()
        tap.tap()
        XCTAssertEqual(count.label, "3 paket")
        let zone = app.staticTexts["shift.zone"]
        XCTAssertTrue(zone.waitForExistence(timeout: 3))
        XCTAssertTrue(zone.label.contains("1 paket eklendi"), "gelen: \(zone.label)")

        // Geri al: son paket silinir
        app.buttons["shift.undo"].tap()
        XCTAssertEqual(count.label, "2 paket")

        app.buttons["shift.finish"].tap()
        let confirm = app.buttons["Bitir ve hesapla"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        let net = app.staticTexts["shiftSummary.net"]
        XCTAssertTrue(net.waitForExistence(timeout: 8))
        let done = app.buttons["shiftSummary.done"]
        if !done.isHittable { app.swipeUp() }
        done.tap()

        // Kayit Bugun'e dustu; vardiya kapandi
        XCTAssertTrue(app.buttons["today.startShift"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["today.liveShift"].exists)
        let row = app.buttons["dashboard.earningRow"]
        if !row.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testMinimizedShiftKeepsCountingAndTutorialOnlyFirstTime() {
        let app = launch()
        let start = app.buttons["today.startShift"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(app.buttons["shiftTutorial.skip"].waitForExistence(timeout: 5))
        app.buttons["shiftTutorial.skip"].tap()
        let tap = app.buttons["shift.tap"]
        XCTAssertTrue(tap.waitForExistence(timeout: 8))
        tap.tap()

        // Kucult: Bugun'de suren vardiya karti
        app.buttons["shift.minimize"].tap()
        let card = app.buttons["today.liveShift"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("1 paket"), "gelen: \(card.label)")
        card.tap()
        XCTAssertTrue(app.buttons["shift.tap"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["shift.packages"].label, "1 paket")

        // Paketsiz bitirmeyle ayni: kapat ve yeniden baslat -> tanitim tekrar gelmez
        app.buttons["shift.undo"].tap()
        app.buttons["shift.finish"].tap()
        let close = app.buttons["Paket yok, kapat"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["today.startShift"].waitForExistence(timeout: 8))
        app.buttons["today.startShift"].tap()
        XCTAssertTrue(app.buttons["shift.tap"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["shiftTutorial.title.0"].exists)
    }
}
