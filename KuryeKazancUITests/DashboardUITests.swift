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
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", "yemeksepeti", "-autoEstimateExpenses", "YES",
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

    /// 1.10: tarama ve + menusu kalkti; yerine Bugun'de "Elle hesapla" ve hedef halkasinin altinda plan dugmesi.
    func testTodayShowsManualCalcInsteadOfScanAndAddMenu() {
        let app = launch(sampleData: false)

        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["dashboard.addMenu"].exists)
        let manual = app.buttons["today.manualCalc"]
        for _ in 0..<3 where !manual.exists { app.swipeUp() }
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today.planButton"].exists)
        XCTAssertFalse(app.buttons["scan.button"].exists)
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

    // MARK: - Kayit duzenleme

    /// Kayda dokununca form acilir; vazgecince net degismez.
    func testEditFormCancelKeepsNet() {
        let app = launch(sampleData: true)
        let net = app.staticTexts["dashboard.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 10))
        let before: String = net.label
        let row = app.buttons.matching(identifier: "dashboard.earningRow").firstMatch
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.buttons["form.cancel"].waitForExistence(timeout: 5))
        app.buttons["form.cancel"].tap()
        for _ in 0..<4 where !net.isHittable { app.swipeDown() }
        XCTAssertEqual(net.label, before)
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

        // 1.10: gider tahmini Profil > Gelismis'te; Profil'de Bildirimler var, tarama ve kalibrasyon yok
        app.tabBars.buttons["Profil"].tap()
        let notifications = app.buttons["profile.notifications"]
        for _ in 0..<3 where !notifications.exists { app.swipeUp() }
        XCTAssertTrue(notifications.waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["profile.autoScan"].exists)
        let advanced = app.buttons["profile.advanced"]
        for _ in 0..<3 where !advanced.isHittable { app.swipeUp() }
        advanced.tap()
        XCTAssertTrue(app.switches["settings.autoEstimate"].waitForExistence(timeout: 5))
    }

    func testAnalysisShowsPlatformComparison() {
        let app = launch(sampleData: true)
        XCTAssertTrue(app.tabBars.buttons["Kazanç"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Kazanç"].tap()
        app.segmentedControls["earnings.mode"].buttons["Analiz"].tap()
        app.segmentedControls["history.periodPicker"].buttons["Gün"].tap()
        let platforms = app.staticTexts["analysis.platform.migros_hemen"]
        for _ in 0..<4 where !platforms.exists { app.swipeUp() }
        XCTAssertTrue(platforms.exists)
    }

    /// 1.10: Hesap (Apple ile giris) Profil'in en ustunde.
    func testProfileShowsAccountFirst() {
        let app = launch(sampleData: false)
        XCTAssertTrue(app.tabBars.buttons["Profil"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Profil"].tap()
        let signIn = app.buttons["profile.appleSignIn"]
        let unavailable = app.staticTexts["profile.serverUnavailable"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5) || unavailable.exists, "Hesap bolumu en ustte gorunmeli")
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
        XCTAssertTrue(app.buttons["firm.yemeksepeti"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["welcome.next"].isEnabled, "Firma secmeden devam edilmemeli")
        app.buttons["firm.yemeksepeti"].tap()
        app.buttons["welcome.next"].tap()
        XCTAssertTrue(app.buttons["intro.skip"].waitForExistence(timeout: 10))
        app.buttons["intro.skip"].tap()
        // Yemeksepeti: sehir grubu sorusu (haftalik bonus)
        XCTAssertTrue(app.buttons["question.region.ys_istanbul"].waitForExistence(timeout: 5))
        app.buttons["question.region.ys_istanbul"].tap()
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
