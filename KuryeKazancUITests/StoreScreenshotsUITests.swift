import XCTest

/// App Store ekran goruntuleri. Yalnizca `screenshots.yml` calistirir: SCREENSHOT_DIR yoksa atlanir
/// (normal CI'yi yavaslatmaz). Goruntuler hem bu klasore PNG olarak yazilir hem sonuca eklenir.
final class StoreScreenshotsUITests: XCTestCase {
    private var outputDir: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("SCREENSHOT_DIR yok: magaza goruntuleri yalnizca screenshots is akisinda alinir")
        }
        outputDir = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir!, withIntermediateDirectories: true)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-costPerKm", "2.5", "-isWorking", "NO",
            "-hasCompletedOnboarding", "YES", "-hasSeenIntroV18", "YES", "-firm", "yemeksepeti",
            "-autoEstimateExpenses", "YES", "-reset-defaults", "-sample-data",
        ]
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        // Animasyonlar otursun
        Thread.sleep(forTimeInterval: 1.2)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let outputDir {
            try? shot.pngRepresentation.write(to: outputDir.appendingPathComponent("\(name).png"))
        }
    }

    func testCaptureStoreScreens() {
        let app = launch()

        // 1) Bugun: net kazanc, hedef halkasi
        XCTAssertTrue(app.staticTexts["dashboard.netEarnings"].waitForExistence(timeout: 10))
        snap("01-bugun")

        // 2) Gun dokumu
        let breakdown = app.buttons["today.breakdown"]
        if breakdown.waitForExistence(timeout: 5) {
            breakdown.tap()
            if app.staticTexts["dayBreakdown.net"].waitForExistence(timeout: 5) { snap("02-gun-dokumu") }
            let close = app.buttons["dayBreakdown.close"]
            for _ in 0..<5 where close.exists && !close.isHittable { app.swipeUp() }
            if close.exists { close.tap() }
        }

        // 3) Canli vardiya: paket sayaci
        let start = app.buttons["today.startShift"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        if app.buttons["shiftTutorial.skip"].waitForExistence(timeout: 5) {
            snap("03-vardiya-tanitim")
            app.buttons["shiftTutorial.skip"].tap()
        }
        let tap = app.buttons["shift.tap"]
        XCTAssertTrue(tap.waitForExistence(timeout: 8))
        for _ in 0..<14 { tap.tap() }
        snap("04-canli-vardiya")
        app.buttons["shift.minimize"].tap()

        // 4) Bugun'de suren vardiya karti
        XCTAssertTrue(app.buttons["today.liveShift"].waitForExistence(timeout: 5))
        snap("05-bugun-vardiya")

        // 5) Kazanc: hakedis ve tarife
        app.tabBars.buttons["Kazanç"].tap()
        XCTAssertTrue(app.staticTexts["payroll.platformName"].waitForExistence(timeout: 5))
        snap("06-kazanc")

        // 6) Firmalar
        app.tabBars.buttons["Firmalar"].tap()
        snap("07-firmalar")

        // 7) Plan
        app.tabBars.buttons["Bugün"].tap()
        let plan = app.buttons["today.planButton"]
        for _ in 0..<3 where !plan.exists { app.swipeUp() }
        if plan.waitForExistence(timeout: 3) {
            plan.tap()
            snap("08-plan")
        }
    }
}
