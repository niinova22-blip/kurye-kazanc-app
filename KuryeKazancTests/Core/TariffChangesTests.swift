import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Degisiklik karsilastirmasi, bildirim dili, kullanici tarifesi ice aktarimi, ekonomik gosterge ve para aritmetigi.
final class TariffChangesTests: XCTestCase {
    func testDiffIgnoresLabelAndNoteChanges() {
        let old = [TariffFixtures.item("package.day", .singlePackage, "64.50")]
        var relabeled = old
        relabeled[0].label = "Yeni başlık"
        relabeled[0].note = "Tasarım değişti"
        XCTAssertTrue(TariffDiff.changes(old: old, new: relabeled).isEmpty)
    }

    func testDiffDetectsAmountThresholdAddedRemoved() {
        let old = [
            TariffFixtures.item("package.day", .singlePackage, "64.50"),
            TariffFixtures.item("bonus.42", .dailyBonus, "1610", method: .tier, unit: .day, lower: "42"),
            TariffFixtures.item("km", .perKm, "6.50"),
        ]
        let new = [
            TariffFixtures.item("package.day", .singlePackage, "70"),
            TariffFixtures.item("bonus.42", .dailyBonus, "1610", method: .tier, unit: .day, lower: "45"),
            TariffFixtures.item("night", .singlePackage, "95"),
        ]
        let changes = TariffDiff.changes(old: old, new: new)
        XCTAssertEqual(changes.map(\.itemKey), ["bonus.42", "km", "night", "package.day"])
        XCTAssertEqual(changes.map(\.kind), [.changed, .removed, .added, .changed])
        let package = changes.first { $0.itemKey == "package.day" }
        XCTAssertEqual(package?.absolute, money("5.50"))
        XCTAssertEqual(package?.percent, Decimal(string: "8.53"))
        XCTAssertEqual(changes.first { $0.itemKey == "bonus.42" }?.newLower, 45)
        XCTAssertEqual(changes.first { $0.itemKey == "km" }?.kind, .removed)
        XCTAssertEqual(changes.first { $0.itemKey == "night" }?.kind, .added)
    }

    private func event(_ id: String, platform: String, verification: String, kind: String = "published") -> TariffChangeEvent {
        TariffChangeEvent(id: id, platformCode: platform, tariffVersionID: "v", kind: kind, effectiveFrom: "2026-11-01",
                          verification: verification, sourceType: "official_announcement", sourceURL: nil,
                          changes: [TariffItemChange(kind: .changed, itemKey: "package.performance.0", label: "Paket başı ücret",
                                                     oldAmount: money("38"), newAmount: money("40"))],
                          createdAt: "2026-10-11")
    }

    func testNotificationsOnlyForActivePlatformAndOnlyOnce() {
        let events = [event("1", platform: "migros_hemen", verification: "verified"),
                      event("2", platform: "getir", verification: "verified")]
        let notices = TariffNotifier.notices(from: events, activePlatform: "migros_hemen", seen: [], now: Date())
        XCTAssertEqual(notices.map(\.id), ["1"])
        XCTAssertEqual(notices[0].title, "Paket Taxi Migros Hemen için yeni tarife sürümü yayımlandı")
        XCTAssertTrue(notices[0].body.contains("1 Kasım 2026"))
        XCTAssertTrue(notices[0].body.contains("38.00 → 40.00 TL (+%5.26)"))
        XCTAssertTrue(TariffNotifier.notices(from: events, activePlatform: "migros_hemen", seen: ["1"], now: Date()).isEmpty)
        XCTAssertTrue(TariffNotifier.notices(from: events, activePlatform: nil, seen: [], now: Date()).isEmpty)
    }

    func testUnverifiedChangeNeverAnnouncedAsRaise() {
        let notice = TariffNotifier.notices(from: [event("3", platform: "getir", verification: "needs_verification")],
                                            activePlatform: "getir", seen: [], now: Date())[0]
        XCTAssertTrue(notice.title.contains("doğrulama bekliyor"))
        XCTAssertFalse(notice.title.contains("yayımlandı"))
        XCTAssertFalse(notice.isVerified)
        let withdrawn = TariffNotifier.message(for: event("4", platform: "getir", verification: "verified", kind: "withdrawn"))
        XCTAssertTrue(withdrawn.title.contains("geri çekildi"))
    }

    func testCSVImportUserEnteredDrafts() {
        let csv = """
        kalem;tur;etiket;tutar;ust_tutar;alt_esik
        package.day;single_package;Gündüz paket;66,00;;
        bonus.weekly.100;haftalık bonus;Haftalık 100 paket;1.000;;100
        x;bilinmeyen;;5;;
        y;km;;abc;;
        """
        let result = TariffImport.csv(csv, platform: "yemeksepeti", versionID: "u1")
        XCTAssertEqual(result.drafts.count, 2)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.drafts[0].item.amount, money("66"))
        XCTAssertEqual(result.drafts[1].item.type, .weeklyBonus)
        XCTAssertEqual(result.drafts[1].item.amount, money("1000"))
        XCTAssertEqual(result.drafts[1].item.lowerThreshold, 100)
        XCTAssertEqual(result.drafts[1].item.method, .tier)
        XCTAssertTrue(result.drafts.allSatisfy { $0.item.confidence == .userEntered })
    }

    func testOCRTextBecomesNeedsVerificationDraftWithScore() {
        let lines = ["Kurye Kazanç Duyurusu", "Gece paket ücreti 95,00 TL", "Birleşen paket: 35 TL",
                     "Günlük 42 paket bonusu 1.700 TL", "Bahşiş 20 TL", "Km başı 7,25 TL"]
        let result = TariffImport.text(lines, platform: "trendyol_go", versionID: "u2", lineConfidence: [1, 0.9, 0.5, 1, 1, 1])
        let keys = result.drafts.map(\.item.key)
        XCTAssertEqual(keys, ["package.night", "package.combined", "bonus.daily.42", "km"])
        XCTAssertTrue(result.drafts.allSatisfy { $0.item.confidence == .needsVerification })
        XCTAssertEqual(result.drafts[0].item.amount, money("95"))
        XCTAssertEqual(result.drafts[0].score, 0.72)
        XCTAssertEqual(result.drafts[1].score, 0.4)
        XCTAssertEqual(result.drafts[2].item.lowerThreshold, 42)
        XCTAssertEqual(result.drafts[2].item.amount, money("1700"))
    }

    func testOCRDraftNeverActiveWithoutUserApproval() throws {
        let drafts = TariffImport.text(["Gündüz paket 70 TL"], platform: "trendyol_go", versionID: "u3").drafts
        let version = TariffImport.userVersion(platform: "trendyol_go", drafts: drafts,
                                               base: TariffFixtures.bundled("trendyol_go-esnaf-v1"), sourceNote: "Ekran görüntüsü",
                                               effectiveFrom: "2026-10-01", today: "2026-10-11", id: "u3")
        XCTAssertEqual(version.approvalStatus, .draft)
        let catalog = TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: [version])
        var input = TariffFixtures.input("trendyol_go")
        input.dayPackages = 1
        XCTAssertEqual(TariffFixtures.calc(input, engine: TariffFixtures.engine(catalog: catalog)).gross, money("64.50"))
        XCTAssertEqual(version.items.first { $0.key == "package.day" }?.amount, money("70"))
        XCTAssertTrue(version.items.contains { $0.key == "bonus.daily.82" }, "taban surumun diger kalemleri korunur")
    }

    func testEconomicIndicatorOnlyWarns() {
        let tariff = TariffFixtures.bundled("trendyol_go-esnaf-v1")
        let before = tariff
        let result = CostCoverage.evaluate(perPackagePay: money("64.50"), kmPerPackage: 3, litersPer100Km: 3,
                                           fuelPricePerLiter: money("50"), previousRatio: 20, indicatorDate: nil)
        XCTAssertEqual(result.ratio, Decimal(string: "14.33"))
        XCTAssertTrue(result.warnings.contains { $0.contains("düştü") })
        XCTAssertTrue(result.warnings.contains { $0.contains("güncel sayılmaz") })
        XCTAssertEqual(tariff, before, "gosterge tarifeyi degistirmez")
    }

    func testMoneyParsingAndRounding() {
        XCTAssertEqual(Money(text: "1.610")?.value, 1610)
        XCTAssertEqual(Money(text: "64,50")?.value, Decimal(string: "64.5"))
        XCTAssertEqual(Money(text: "1.234,56 TL")?.value, Decimal(string: "1234.56"))
        XCTAssertEqual(Money(text: "₺ 92")?.value, 92)
        XCTAssertNil(Money(text: "abc"))
        XCTAssertEqual((money("0.10") + money("0.20")).value, Decimal(string: "0.3"))
        XCTAssertEqual((money("10") * Decimal(string: "0.3333")!).description, "3.33")
        XCTAssertEqual(money("41.5").description, "41.50")
    }
}
