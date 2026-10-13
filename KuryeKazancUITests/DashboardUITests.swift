import XCTest

/// Simulatorde calisan UI testleri.
/// Not: GPS, gercek ekran goruntusu OCR'i ve arka plan davranislari simulatorde tam dogrulanamaz;
/// bunlar TestFlight uzerinden gercek cihazda elle test edilir (bkz. TESTFLIGHT_NOTES.md).
final class DashboardUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Onboarding tamamlanmis, konum kapali, bellek ici veritabani.
    private func launch(sampleData: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        // -key value: UserDefaults arguman alani; testleri onceki durumdan bagimsiz kilar.
        app.launchArguments = [
            "-ui-testing", "-costPerKm", "2.5", "-isWorking", "NO",
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", "trendyol_go", "-autoEstimateExpenses", "YES",
            // Paylasim tercihleri testler arasinda tasinmasin. "-anahtar NO" argumani KULLANILMAZ: argumanla
            // verilen deger UserDefaults'ta en ust katmandir; uygulamanin yazdigi "acik" degeri okunamaz olur
            // (paylasim onayindan sonra anahtar ara sira kapali kaliyordu). Bunun yerine kayitli tercihler silinir.
            "-reset-defaults",
        ]
        if sampleData { app.launchArguments.append("-sample-data") }
        app.launch()
        return app
    }

    // MARK: - Ana ekran

    func testDashboardShowsKeyMetrics_emptyState() {
        let app = launch(sampleData: false)

        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["dashboard.netPerHour"].exists)
        XCTAssertTrue(app.staticTexts["dashboard.workDuration"].exists)
        XCTAssertTrue(app.staticTexts["dashboard.distance"].exists)
        XCTAssertEqual(app.staticTexts["dashboard.netPerHour"].label, "—")
    }

    func testTodayShowsScanButton() {
        let app = launch(sampleData: false)

        XCTAssertTrue(app.buttons["scan.button"].waitForExistence(timeout: 10))
    }

    func testDashboardSummarizesSampleData() {
        let app = launch(sampleData: true)

        let net = app.staticTexts["dashboard.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 10))
        // 1050 brut - 150 tahmini - 50 manuel = 850
        XCTAssertTrue(net.label.contains("850"), "Beklenen net 850, gelen: \(net.label)")
        XCTAssertEqual(app.staticTexts["dashboard.workDuration"].label, "6 sa")
        XCTAssertTrue(app.staticTexts["dashboard.distance"].label.hasPrefix("60"))
    }

    // MARK: - Kazanc / gider ekleme

    func testAddEarningManually_updatesNet() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        app.buttons["Elle kazanç"].tap()

        let gross = app.textFields["earningForm.gross"]
        XCTAssertTrue(gross.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["form.save"].isEnabled, "Tutar girilmeden kaydedilmemeli")
        gross.tap()
        gross.typeText("500")

        let save = app.buttons["form.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        // 850 + 500 = 1.350
        let net = app.staticTexts["dashboard.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label CONTAINS %@", "1.350")
        expectation(for: predicate, evaluatedWith: net)
        waitForExpectations(timeout: 5)
    }

    func testAddFuelExpense_replacesEstimate() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        app.buttons["Gider"].tap()

        let amount = app.textFields["expenseForm.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("100")
        app.buttons["form.save"].tap()

        // Yakit girildi -> km tahmini (150) duser: 1050 - 50 - 100 = 900
        let net = app.staticTexts["dashboard.netEarnings"]
        let predicate = NSPredicate(format: "label CONTAINS %@", "900")
        expectation(for: predicate, evaluatedWith: net)
        waitForExpectations(timeout: 5)
    }

    func testCancelFormDoesNotSave() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        app.buttons["Elle kazanç"].tap()
        XCTAssertTrue(app.buttons["form.cancel"].waitForExistence(timeout: 5))
        app.buttons["form.cancel"].tap()
        XCTAssertFalse(app.buttons["dashboard.earningRow"].exists)
    }

    func testAddMenuOffersScreenshotFirst() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.buttons["dashboard.addMenu"].waitForExistence(timeout: 10))
        app.buttons["dashboard.addMenu"].tap()
        XCTAssertTrue(app.buttons["Ekran görüntüsü"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Elle kazanç"].exists)
        XCTAssertTrue(app.buttons["Gider"].exists)
    }

    func testSampleRecordsShowVerificationBadges() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        // Ornek veride bir elle, bir ekran goruntusu kaydi var. Satir bir dugme oldugundan
        // rozet metni dugmenin etiketine katilir (ic kimlikler XCUITest'te gorunmez).
        // 1.8: buyuk ana kart yuzunden ikinci satir ekran disinda kalabilir (liste tembel): kaydirarak topla
        var found: Set<String> = []
        for _ in 0..<4 {
            found.formUnion(app.buttons.matching(identifier: "dashboard.earningRow").allElementsBoundByIndex.map(\.label))
            if found.count >= 2 { break }
            app.swipeUp()
        }
        let labels = Array(found)
        XCTAssertEqual(labels.count, 2)
        XCTAssertTrue(labels.contains { $0.contains("Elle girildi") }, "\(labels)")
        XCTAssertTrue(labels.contains { $0.contains("Ekran görüntüsü") }, "\(labels)")
    }

    // MARK: - Sekmeler

    func testHistoryAndSettingsTabs() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.tabBars.buttons["Kazanç"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Kazanç"].tap()
        app.segmentedControls["earnings.mode"].buttons["Analiz"].tap()
        XCTAssertTrue(app.segmentedControls["history.periodPicker"].waitForExistence(timeout: 5))
        app.segmentedControls["history.periodPicker"].buttons["Gün"].tap()
        let net = app.staticTexts["history.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 5))
        XCTAssertTrue(net.label.contains("850"), "Gunluk net 850 olmali, gelen: \(net.label)")

        app.tabBars.buttons["Profil"].tap()
        XCTAssertTrue(app.switches["settings.autoEstimate"].waitForExistence(timeout: 5))
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let autoScan = app.switches["profile.autoScan"]
        for _ in 0..<6 where !autoScan.exists {
            app.swipeUp()
        }
        XCTAssertTrue(autoScan.exists)
    }

    func testAnalysisShowsPlatformComparison() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.tabBars.buttons["Kazanç"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Kazanç"].tap()
        app.segmentedControls["earnings.mode"].buttons["Analiz"].tap()
        app.segmentedControls["history.periodPicker"].buttons["Gün"].tap()
        let platforms = app.staticTexts["analysis.platform.getir"]
        for _ in 0..<4 where !platforms.exists { app.swipeUp() }
        XCTAssertTrue(platforms.exists)
    }

    func testProfileOffersAutoScanToggle() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let autoScan = app.switches["profile.autoScan"]
        for _ in 0..<5 where !autoScan.exists { app.swipeUp() }
        XCTAssertTrue(autoScan.exists)
        // UI testlerinde tarama tercihi bos alandan okunur: kapali baslar (izin istenmez)
        XCTAssertEqual(autoScan.value as? String, "0")
    }

    func testProfileOffersAutoShift() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let toggle = app.switches["profile.autoShift"]
        for _ in 0..<6 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        // UI testlerinde tercih bos alandan okunur: kapali baslar (izin istenmez)
        XCTAssertEqual(toggle.value as? String, "0", "Varsayilan kapali")
    }

    func testProfileCalibrationIsOffByDefault() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let toggle = app.switches["profile.calibration"]
        for _ in 0..<8 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0", "Kalibrasyon varsayilan kapali olmali (opt-in)")
    }

    func testDashboardShowsGrossAndExpenseBreakdown() {
        let app = launch(sampleData: true)
        // Satir birlestirilmis erisilebilirlik ogesi: turu (metin/diger) degisebilir
        let breakdown = app.descendants(matching: .any)["dashboard.breakdown"].firstMatch
        XCTAssertTrue(breakdown.waitForExistence(timeout: 10))
        // 1050 brut; 150 tahmini + 50 elle = 200 gider
        XCTAssertTrue(breakdown.label.contains("1.050"), "Beklenen brut 1.050, gelen: \(breakdown.label)")
        XCTAssertTrue(breakdown.label.contains("200"), "Beklenen gider 200, gelen: \(breakdown.label)")
    }
}

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingFlowReachesDashboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults"]
        app.launch()

        // Ilk ekran firma secimi, sonra tanitim (gecilir), firma sorulari (Getir: arac), yakit, hedef, konum
        XCTAssertTrue(app.buttons["firm.getir"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["welcome.next"].isEnabled, "Firma secmeden devam edilmemeli")
        app.buttons["firm.getir"].tap()
        app.buttons["welcome.next"].tap()
        XCTAssertTrue(app.buttons["intro.skip"].waitForExistence(timeout: 10))
        app.buttons["intro.skip"].tap()
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 5)) // arac sorusu
        app.buttons["setup.next"].tap()              // -> yakit
        app.buttons["setup.next"].tap()              // -> hedef
        app.buttons["setup.finish"].tap()

        // Arac kurulumda secildi: yalnizca konum adimi kalir
        XCTAssertTrue(app.staticTexts["Konum yalnızca vardiyada"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Bölgendeki kuryelerle karşılaştır"].exists)
        app.buttons["onboarding.next"].tap()         // Basla

        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
    }

}
