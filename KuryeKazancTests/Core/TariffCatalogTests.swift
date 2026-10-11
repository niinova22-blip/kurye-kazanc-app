import XCTest
@testable import KuryeCore

/// Tarife secimi, surumleme ve onaysiz tarifenin hesaplamaya sizmamasi.
final class TariffCatalogTests: XCTestCase {
    private func packageVersion(_ id: String, platform: String = "trendyol_go", amount: String, status: ApprovalStatus = .published,
                                from: String = "2026-01-01", until: String? = nil, number: Int = 1, region: String? = nil,
                                origin: TariffOrigin = .remote) -> TariffVersion {
        TariffFixtures.version(id, platform: platform, items: [TariffFixtures.item("package.day", .singlePackage, amount, version: id)],
                               status: status, from: from, until: until, number: number, region: region, origin: origin)
    }

    func testBundledSeedDecodesAllFourPlatforms() {
        let versions = BundledTariffs.all
        XCTAssertEqual(versions.count, 5)
        XCTAssertEqual(Set(versions.map(\.platformCode)), ["trendyol_go", "getir", "yemeksepeti", "migros_hemen"])
        for version in versions {
            XCTAssertEqual(version.verificationStatus, .unverified, "ornek tarife dogrulanmis gosterilmemeli")
            XCTAssertTrue(version.items.allSatisfy { $0.confidence == .needsVerification }, version.id)
        }
        XCTAssertEqual(PayPlatform.all.map(\.code), ["trendyol_go", "getir", "yemeksepeti", "migros_hemen"])
    }

    func testOnlyPublishedVersionsReachTheEngine() {
        for status in [ApprovalStatus.draft, .pendingVerification, .needsMoreSources, .approved, .rejected, .withdrawn] {
            let engine = TariffFixtures.engine([packageVersion("x", amount: "100", status: status)])
            var input = TariffFixtures.input("trendyol_go")
            input.dayPackages = 1
            XCTAssertEqual(engine.calculate(input).failureValue, .noTariff(platform: "trendyol_go", day: "2026-10-07"), status.rawValue)
        }
    }

    func testDraftCandidateDoesNotOverridePublished() {
        let engine = TariffFixtures.engine([
            packageVersion("live", amount: "60"),
            packageVersion("draft", amount: "999", status: .pendingVerification, number: 2),
        ])
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 1
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).gross, money("60"))
    }

    func testFutureVersionNotAppliedEarly() {
        let engine = TariffFixtures.engine([
            packageVersion("v1", amount: "60", until: "2026-11-01"),
            packageVersion("v2", amount: "70", from: "2026-11-01", number: 2),
        ])
        var input = TariffFixtures.input("trendyol_go", day: "2026-10-31")
        input.dayPackages = 1
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).tariffVersionID, "v1")
        input.startDay = "2026-11-01"
        input.endDay = "2026-11-01"
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).tariffVersionID, "v2")
    }

    func testFutureDatedItemRevisionNotAppliedEarly() {
        let id = "rev"
        let version = TariffFixtures.version(id, platform: "trendyol_go", items: [
            TariffFixtures.item("package.day", .singlePackage, "60", version: id, until: "2026-11-01"),
            TariffFixtures.item("package.day.r1", .singlePackage, "66", version: id, from: "2026-11-01"),
        ])
        var input = TariffFixtures.input("trendyol_go", day: "2026-10-31")
        input.dayPackages = 1
        let engine = TariffFixtures.engine([version])
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).gross, money("60"))
        input.startDay = "2026-11-01"
        input.endDay = "2026-11-01"
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).gross, money("66"))
    }

    func testWithdrawnItemIsIgnored() {
        var version = packageVersion("w", amount: "60")
        version.items[0].withdrawn = true
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 1
        let result = TariffFixtures.calc(input, engine: TariffFixtures.engine([version]))
        XCTAssertEqual(result.gross, .zero)
        XCTAssertTrue(result.notices.contains { $0.kind == .missing })
    }

    func testSelectedPlatformNeverUsesAnotherPlatformsTariff() {
        // Getir secili: yalnizca Paket Taxi tarifesi varken hesaplama yapilmaz
        let engine = TariffFixtures.engine([TariffFixtures.bundled("migros_hemen-esnaf-v1")])
        var input = TariffFixtures.input("getir")
        input.vehicleType = "motorcycle"
        input.dayPackages = 10
        XCTAssertEqual(engine.calculate(input).failureValue, .noTariff(platform: "getir", day: "2026-10-07"))
        // Yanlis platformun surumuyle zorla hesaplama reddedilir
        let forced = TariffFixtures.engine.calculate(input, version: TariffFixtures.bundled("migros_hemen-esnaf-v1"))
        XCTAssertEqual(forced.failureValue, .platformMismatch(expected: "getir", got: "migros_hemen"))
    }

    func testRegionalVersionAppliesOnlyToItsRegion() {
        let engine = TariffFixtures.engine([
            packageVersion("general", amount: "60"),
            packageVersion("istanbul", amount: "65", region: "istanbul"),
        ])
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 1
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).tariffVersionID, "general")
        input.regionID = "istanbul"
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).tariffVersionID, "istanbul")
        input.regionID = "ankara"
        XCTAssertEqual(TariffFixtures.calc(input, engine: engine).tariffVersionID, "general")
    }

    func testRemoteReplacesBundledOnlyForItsPlatform() {
        let remote = [packageVersion("remote-tgo", amount: "70")]
        let catalog = TariffCatalog.merged(bundled: BundledTariffs.all, remote: remote, user: [])
        XCTAssertFalse(catalog.versions.contains { $0.id == "trendyol_go-esnaf-v1" })
        XCTAssertTrue(catalog.versions.contains { $0.id == "getir-esnaf-motorcycle-v1" })
        // Sunucuda yalnizca taslak varsa gomulu yedek korunur
        let draftOnly = TariffCatalog.merged(bundled: BundledTariffs.all,
                                             remote: [packageVersion("d", amount: "1", status: .draft)], user: [])
        XCTAssertTrue(draftOnly.versions.contains { $0.id == "trendyol_go-esnaf-v1" })
    }

    func testUserDraftTariffNotUsedUntilActivated() {
        var user = packageVersion("mine", amount: "80", status: .draft, origin: .user)
        let catalog = TariffCatalog.merged(bundled: [packageVersion("official", amount: "60")], remote: [], user: [user])
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 1
        XCTAssertEqual(TariffFixtures.calc(input, engine: PayEngine(catalog: catalog)).tariffVersionID, "official")
        user.approvalStatus = .published
        let active = TariffCatalog.merged(bundled: [packageVersion("official", amount: "60")], remote: [], user: [user])
        XCTAssertEqual(TariffFixtures.calc(input, engine: PayEngine(catalog: active)).tariffVersionID, "mine")
    }

    func testNoTariffAndUnsupportedPlatformErrors() {
        var input = TariffFixtures.input("uber")
        input.dayPackages = 1
        XCTAssertEqual(TariffFixtures.engine.calculate(input).failureValue, .noTariff(platform: "uber", day: "2026-10-07"))
        let engine = TariffFixtures.engine([packageVersion("u", platform: "uber", amount: "10")])
        XCTAssertEqual(engine.calculate(input).failureValue, .unsupportedPlatform("uber"))
    }

    func testVersionJSONRoundTripKeepsDecimalPrecision() throws {
        let version = TariffFixtures.bundled("trendyol_go-esnaf-v1")
        let data = try JSONEncoder().encode(version)
        let decoded = try JSONDecoder().decode(TariffVersion.self, from: data)
        XCTAssertEqual(decoded.items, version.items)
        XCTAssertEqual(decoded.items.first { $0.key == "package.combined" }?.amountUpper, money("41.50"))
    }

    func testDecodesPostgrestNumbersAndTimestamps() throws {
        let json = """
        [{"tariff_version_id":"x","platform_id":"getir","work_model":"esnaf","vehicle_type":"motorcycle","version_number":2,
          "revision":1,"effective_from":"2026-11-01","created_at":"2026-10-11T10:00:00+00:00","source_type":"official_announcement",
          "verification_status":"verified","approval_status":"published","settings":{},
          "items":[{"tariff_item_id":"i","tariff_version_id":"x","item_key":"hourly","item_type":"hourly","label":"Saatlik",
          "amount":52.5,"unit":"hour","calculation_method":"per_unit","confidence_status":"verified","is_cash":true,
          "effective_from":"2026-11-01","effective_until":null,"withdrawn":false,"lower_threshold":null}]}]
        """
        let versions = try JSONDecoder().decode([TariffVersion].self, from: Data(json.utf8))
        XCTAssertEqual(versions[0].items[0].amount, money("52.50"))
        XCTAssertEqual(versions[0].label, "v2.1")
        XCTAssertEqual(versions[0].origin, .remote)
    }
}
