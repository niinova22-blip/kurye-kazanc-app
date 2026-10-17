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
        // 1.15: ust kartta tek satir (paket · sure); saatlik / km seridi dokumde
        let line = app.staticTexts["dashboard.dayLine"]
        XCTAssertTrue(line.exists)
        XCTAssertTrue(line.label.hasPrefix("0 paket"), "gelen: \(line.label)")
        XCTAssertFalse(app.staticTexts["dashboard.netPerHour"].exists)
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
        // 1.15 varsayilan yakit: 60 km × 2,5 L/100 km × 85 TL = 127,5; 1050 brut - 127,5 - 50 manuel = 872,5
        XCTAssertTrue(net.label.contains("872,5"), "Beklenen net 872,5, gelen: \(net.label)")
        let line = app.staticTexts["dashboard.dayLine"].label
        XCTAssertTrue(line.contains("23 paket") && line.contains("6 sa"), "gelen: \(line)")
    }

    /// 1.11: ust kart tam ekran gun dokumunu acar; net ust kartla ayni.
    func testHeroOpensDayBreakdown() {
        let app = launch(sampleData: true)
        let net = app.staticTexts["dashboard.netEarnings"]
        XCTAssertTrue(net.waitForExistence(timeout: 10))
        let open = app.buttons["today.breakdown"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let dayNet = app.staticTexts["dayBreakdown.net"]
        XCTAssertTrue(dayNet.waitForExistence(timeout: 5))
        XCTAssertTrue(dayNet.label.contains("872,5"), "gelen: \(dayNet.label)")
        let close = app.buttons["dayBreakdown.close"]
        for _ in 0..<5 where !close.isHittable { app.swipeUp() }
        close.tap()
        XCTAssertTrue(net.waitForExistence(timeout: 5))
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
        XCTAssertTrue(net.label.contains("872,5"), "Gunluk net 872,5 olmali, gelen: \(net.label)")

        // 1.15: gider tahmini Profil > Diğer ayarlar > Gelismis'te; Profil'de Bildirimler var
        app.tabBars.buttons["Profil"].tap()
        let notifications = app.buttons["profile.notifications"]
        for _ in 0..<3 where !notifications.exists { app.swipeUp() }
        XCTAssertTrue(notifications.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.region"].exists, "Bolge Diğer ayarlar altinda")
        openMore(app)
        let advanced = app.buttons["profile.advanced"]
        for _ in 0..<4 where !advanced.isHittable { app.swipeUp() }
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
        openMore(app)
        // Form tembel yuklenir: ekran disindaki satirlar kaydirilinca olusur
        let toggle = app.switches["profile.autoShift"]
        for _ in 0..<6 where !toggle.exists { app.swipeUp() }
        XCTAssertTrue(toggle.exists)
        // UI testlerinde tercih bos alandan okunur: kapali baslar (izin istenmez)
        XCTAssertEqual(toggle.value as? String, "0", "Varsayilan kapali")
    }

    /// Profil > Diğer ayarlar.
    private func openMore(_ app: XCUIApplication) {
        let more = app.buttons["profile.more"]
        for _ in 0..<4 where !more.isHittable { app.swipeUp() }
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(app.navigationBars["Diğer ayarlar"].waitForExistence(timeout: 5))
    }
}

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 1.15: ilk acilista yalnizca firma sorulur; hesap secimi, tanitim, yakit / hedef / konum adimlari yok.
    func testOnboardingFlowReachesDashboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-defaults"]
        app.launch()

        XCTAssertTrue(app.buttons["firm.yemeksepeti"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["welcome.guest"].exists)
        XCTAssertFalse(app.buttons["welcome.next"].isEnabled, "Firma secmeden devam edilmemeli")
        app.buttons["firm.yemeksepeti"].tap()
        app.buttons["welcome.next"].tap()

        // Yemeksepeti: soru yok, dogrudan Bugun
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["intro.skip"].exists)
        XCTAssertFalse(app.buttons["setup.next"].exists)
    }
}
