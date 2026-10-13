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
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", "pt_migros", "-autoEstimateExpenses", "YES", "-reset-defaults",
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
        XCTAssertEqual(app.staticTexts["payroll.platformName"].label, "Paket Taxi Migros")
        XCTAssertFalse(app.buttons["payroll.quick"].exists)

        let manual = app.buttons["payroll.manual"]
        if !manual.waitForExistence(timeout: 3) { app.swipeUp() }
        manual.tap()
        XCTAssertTrue(app.segmentedControls["manual.span"].waitForExistence(timeout: 5))
        let packages = app.textFields["manual.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 5))
        packages.tap()
        packages.typeText("38")
        let net = app.staticTexts["manual.net"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        // 1. bolge gunluk 38–42 paket primi 2.360 TL + sabit ucretin gunluk payi 55.223 / 26 = 2.123,96 TL; km yok -> yakit yok
        XCTAssertTrue(net.label.contains("4.483"), "gelen: \(net.label)")

        let save = app.buttons["manual.save"]
        if !save.isHittable { app.swipeUp() }
        save.tap()
        // Kayit sonrasi Kazanc ekranina donulur (liste asagi kaydirilmis kalabilir), pano bu ayin brutunu gosterir
        XCTAssertTrue(app.buttons["payroll.manual"].waitForExistence(timeout: 8))
        let monthGross = app.staticTexts["dashboard.monthGross"]
        if !monthGross.exists { app.swipeDown() }
        XCTAssertTrue(monthGross.waitForExistence(timeout: 5))
        // Ay: sabit 55.223 + gunluk prim 2.360
        XCTAssertTrue(monthGross.label.contains("57.583"), "gelen: \(monthGross.label)")
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
        // Klavye kapanir (kaydirinca), dokum basligina kadar inilir
        // DisclosureGroup basligi Form'da dugme olarak gorunur: etiketle aranir
        let detail = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Ayrıntılı döküm")).firstMatch
        for _ in 0..<4 where !(detail.exists && detail.isHittable) { app.swipeUp() }
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }
}
