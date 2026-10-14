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

    /// 1.10: "Elle hesapla" Bugun'de; "Hesabı bitir" gunluk kazanca eklensin mi diye sorar.
    private func openManualFromToday(_ app: XCUIApplication) {
        let manual = app.buttons["today.manualCalc"]
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        for _ in 0..<3 where !manual.exists { app.swipeUp() }
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        XCTAssertTrue(app.segmentedControls["manual.span"].waitForExistence(timeout: 5))
    }

    func testManualCalculationAsksBeforeAddingToToday() {
        let app = launch()
        openManualFromToday(app)
        let packages = app.textFields["manual.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 5))
        packages.tap()
        packages.typeText("38")
        let net = app.staticTexts["manual.net"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        // 1. bolge gunluk 38–42 paket primi 2.360 TL + sabit ucretin gunluk payi 55.223 / 26 = 2.123,96 TL; km yok -> yakit yok
        XCTAssertTrue(net.label.contains("4.483"), "gelen: \(net.label)")

        let save = app.buttons["manual.save"]
        // Form tembel yuklenir; klavye de alt kismi kapatir: dugme gorunene kadar kaydirilir
        for _ in 0..<6 where !(save.exists && save.isHittable) { app.swipeUp() }
        save.tap()
        let add = app.alerts.buttons["Evet, ekle"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Hesap bitince bugune eklensin mi diye sorulmali")
        add.tap()

        // Bugun'e donulur; kayit listede
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 8))
        let row = app.buttons["dashboard.earningRow"]
        for _ in 0..<4 where !row.exists { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // Kazanc panosu bu ayin brutunu gosterir; "Elle hesapla" artik orada degil
        app.tabBars.buttons["Kazanç"].tap()
        XCTAssertTrue(app.staticTexts["payroll.platformName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["payroll.platformName"].label, "Paket Taxi Migros")
        XCTAssertFalse(app.buttons["payroll.manual"].exists)
        let monthGross = app.staticTexts["dashboard.monthGross"]
        XCTAssertTrue(monthGross.waitForExistence(timeout: 5))
        // Ay: sabit 55.223 + gunluk prim 2.360
        XCTAssertTrue(monthGross.label.contains("57.583"), "gelen: \(monthGross.label)")
    }

    func testManualCalculationNotAddedWhenDeclined() {
        let app = launch()
        openManualFromToday(app)
        let packages = app.textFields["manual.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 5))
        packages.tap()
        packages.typeText("20")
        XCTAssertTrue(app.staticTexts["manual.net"].waitForExistence(timeout: 5))
        let save = app.buttons["manual.save"]
        // Form tembel yuklenir; klavye de alt kismi kapatir: dugme gorunene kadar kaydirilir
        for _ in 0..<6 where !(save.exists && save.isHittable) { app.swipeUp() }
        save.tap()
        let skip = app.alerts.buttons["Hayır, yalnızca hesapladım"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["dashboard.earningRow"].exists, "Reddedilen hesap kaydedilmemeli")
    }

    func testManualWeekShowsDailyAverageAndDetail() {
        let app = launch()
        openManualFromToday(app)
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
        for _ in 0..<8 where !(detail.exists && detail.isHittable) { app.swipeUp() }
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }

    /// 1.10: Kazanc > "Tutarları düzenle" (kalem) firma tutarini degistirir; sonra firma degerlerine donulebilir.
    func testTariffPencilEditsAmounts() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Kazanç"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Kazanç"].tap()
        let edit = app.buttons["tariff.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.buttons["tariffEdit.save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tariffEdit.reset"].exists, "Duzenleme yokken firma degerine donus gosterilmez")
        let field = app.textFields.element(boundBy: 0)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Imleci sona alip mevcut tutari silerek yeni deger yazilir
        let current: String = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText("999")
        app.buttons["tariffEdit.save"].tap()
        XCTAssertTrue(app.staticTexts["payroll.platformName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kendi değerlerinle hesaplanıyor"].waitForExistence(timeout: 5))
        edit.tap()
        // "Firma değerlerine dön" uzun kalem listesinin altinda: kaydirarak bulunur
        XCTAssertTrue(app.buttons["tariffEdit.save"].waitForExistence(timeout: 5))
        let reset = app.buttons["tariffEdit.reset"]
        for _ in 0..<12 where !reset.exists { app.swipeUp() }
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
    }
}
