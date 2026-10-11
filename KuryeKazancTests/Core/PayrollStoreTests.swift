import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Kayitlarin kaliciligi, platform degisimi, gecmis surumlerin korunmasi ve acik yeniden hesaplama.
final class PayrollStoreTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        super.setUp()
        url = FileManager.default.temporaryDirectory.appendingPathComponent("payroll-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: url)
        super.tearDown()
    }

    private func dailyLog(_ platform: String, day: String, packages: Int, engine: PayEngine = TariffFixtures.engine,
                          vehicle: String? = nil, method: EntryMethod = .detailed) -> WorkLog {
        var input = TariffFixtures.input(platform, day: day)
        input.dayPackages = packages
        input.hours = 8
        input.vehicleType = vehicle
        return WorkLog(method: method, input: input, result: TariffFixtures.calc(input, engine: engine))
    }

    func testPersistsAndReloads() throws {
        let store = PayrollStore(fileURL: url)
        store.select(platform: "trendyol_go")
        try store.add(dailyLog("trendyol_go", day: "2026-10-05", packages: 45))
        let reloaded = PayrollStore(fileURL: url)
        XCTAssertEqual(reloaded.state, store.state)
        XCTAssertEqual(reloaded.logs().first?.gross, money("4512.50")) // 45 x 64,50 + 1610
    }

    func testPlatformSwitchKeepsOldLogsAndTheirTariff() throws {
        let store = PayrollStore(fileURL: url)
        store.select(platform: "getir", at: Date(timeIntervalSince1970: 0))
        let getirLog = dailyLog("getir", day: "2026-09-10", packages: 20, vehicle: "motorcycle")
        try store.add(getirLog)
        store.select(platform: "trendyol_go", at: Date(timeIntervalSince1970: 100))
        try store.add(dailyLog("trendyol_go", day: "2026-10-05", packages: 10))
        XCTAssertEqual(store.activePlatform, "trendyol_go")
        XCTAssertEqual(store.state.platformHistory.map(\.code), ["getir", "trendyol_go"])
        let kept = store.log(id: getirLog.id)
        XCTAssertEqual(kept?.result, getirLog.result, "eski kayit yeni platform tarifesiyle yeniden hesaplanmaz")
        XCTAssertEqual(kept?.tariffVersionID, "getir-esnaf-motorcycle-v1")
        XCTAssertEqual(store.logs(platform: "getir").count, 1)
    }

    func testNewTariffDoesNotSilentlyChangeHistory() throws {
        let store = PayrollStore(fileURL: url)
        let log = dailyLog("trendyol_go", day: "2026-10-05", packages: 10)
        try store.add(log)
        // Yeni surum yayimlandi (ayni gunu de kapsiyor, daha yuksek surum)
        var v2 = TariffFixtures.bundled("trendyol_go-esnaf-v1")
        v2.id = "tgo-v2"
        v2.versionNumber = 2
        for i in v2.items.indices where v2.items[i].key == "package.day" { v2.items[i].amount = money("70") }
        let newEngine = TariffFixtures.engine([TariffFixtures.bundled("trendyol_go-esnaf-v1"), v2])
        XCTAssertEqual(store.log(id: log.id)?.gross, money("645"), "kayit kendi surumunu korur")
        XCTAssertEqual(store.log(id: log.id)?.recalculations.count, 0)

        // Acik yeniden hesaplama ayri islem olarak kaydedilir
        let recalc = try store.recalculate(logID: log.id, engine: newEngine, reason: "Yeni tarife", at: Date(timeIntervalSince1970: 5))
        XCTAssertEqual(recalc?.previous.gross, money("645"))
        XCTAssertEqual(recalc?.new.gross, money("700"))
        XCTAssertEqual(recalc?.reason, "Yeni tarife")
        XCTAssertEqual(store.log(id: log.id)?.recalculations.count, 1)
        XCTAssertEqual(store.log(id: log.id)?.tariffVersionID, "tgo-v2")
        // Ayni tarifeyle tekrar: degisiklik yok, kayit eklenmez
        XCTAssertNil(try store.recalculate(logID: log.id, engine: newEngine, reason: "tekrar"))
        XCTAssertEqual(store.log(id: log.id)?.recalculations.count, 1)
    }

    func testPeriodLogRejectedWhenDailyLogsOverlap() throws {
        let store = PayrollStore(fileURL: url)
        try store.add(dailyLog("trendyol_go", day: "2026-10-07", packages: 10))
        var input = TariffFixtures.input("trendyol_go", day: "2026-10-05", span: .week, end: "2026-10-11")
        input.dayPackages = 200
        let period = WorkLog(method: .period, input: input, result: TariffFixtures.calc(input))
        XCTAssertThrowsError(try store.add(period)) { error in
            XCTAssertEqual(error as? PayrollStoreError, .periodOverlapsDailyLogs(count: 1))
        }
        // Baska platformun donemiyle cakisma yok
        var other = TariffFixtures.input("yemeksepeti", day: "2026-10-05", span: .week, end: "2026-10-11")
        other.dayPackages = 50
        XCTAssertNoThrow(try store.add(WorkLog(method: .period, input: other, result: TariffFixtures.calc(other))))
    }

    func testUserTariffRequiresSourceAndCannotClaimVerified() throws {
        let store = PayrollStore(fileURL: url)
        var version = TariffFixtures.version("mine", platform: "trendyol_go",
                                             items: [TariffFixtures.item("package.day", .singlePackage, "70", version: "mine")])
        XCTAssertThrowsError(try store.saveUserTariff(version, activate: true))
        version.sourceNote = "Sözleşmem, Ekim 2026"
        try store.saveUserTariff(version, activate: false)
        XCTAssertEqual(store.userTariffs.first?.approvalStatus, .draft)
        XCTAssertEqual(store.userTariffs.first?.items.first?.confidence, .userEntered)
        try store.saveUserTariff(version, activate: true)
        XCTAssertEqual(store.userTariffs.count, 1)
        XCTAssertEqual(store.userTariffs.first?.approvalStatus, .published)
        XCTAssertEqual(store.userTariffs.first?.origin, .user)
    }

    func testManualAdjustmentShownSeparately() throws {
        let store = PayrollStore(fileURL: url)
        let log = dailyLog("trendyol_go", day: "2026-10-05", packages: 10)
        try store.add(log)
        store.setAdjustment(money("-20"), note: "Platform eksik ödedi", logID: log.id)
        XCTAssertEqual(store.log(id: log.id)?.gross, money("625"))
        XCTAssertEqual(store.log(id: log.id)?.result.gross, money("645"), "hesaplama sonucu degismez")
    }

    func testCorruptFileStartsEmptyWithoutCrash() throws {
        try Data("bozuk".utf8).write(to: url)
        let store = PayrollStore(fileURL: url)
        XCTAssertTrue(store.logs().isEmpty)
    }
}
