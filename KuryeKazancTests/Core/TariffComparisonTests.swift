import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

final class TariffComparisonTests: XCTestCase {
    private let day = "2026-10-13"
    private let catalog = TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: [])
    private let fuel = FuelCostModel(settings: FuelSettings(entries: [FuelPriceEntry(day: "2026-10-01", pricePerUnit: Money(45), type: .gasoline)],
                                                            consumptionPer100Km: 3), vehicleType: "motorcycle", fallbackCostPerKm: Money(2))
    private let own = CourierTariffProfile(platformCode: "migros_hemen", regionTier: "r1", seniorityYears: 4, vehicleType: nil,
                                           flags: ["woman_employment"])
    private let workload = WorkloadSpec(packagesPerDay: 38, hoursPerDay: 9, kmPerPackage: Decimal(string: "3.5")!, daysPerMonth: 26)

    func testRowsCurrentFirstThenByNet() {
        let rows = TariffComparison.rows(workload: workload, profile: own, catalog: catalog, fuel: fuel, day: day)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows.first?.platformCode, "migros_hemen")
        XCTAssertTrue(rows.first?.isCurrent ?? false)
        let others = rows.dropFirst().map(\.net.value)
        XCTAssertEqual(others, others.sorted(by: >))
        XCTAssertNil(rows.first?.differenceFromCurrent)
        XCTAssertNotNil(rows.last?.differenceFromCurrent)
        XCTAssertTrue(rows.allSatisfy { $0.netPerHour != nil })
    }

    func testOtherFirmsUseLowestRegionAndNoSeniority() {
        // Yemeksepeti kuryesi Paket Taxi Restoran'a bakarsa: bolge kodu farkli -> en dusuk (4.) bolge, gunde 10 saat, kidemsiz
        let (profile, notes) = TariffComparison.comparisonProfile(for: "pt_restoran",
            own: CourierTariffProfile(platformCode: "yemeksepeti", regionTier: "ys_istanbul", seniorityYears: 5, vehicleType: nil, flags: []),
            catalog: catalog, day: day)
        XCTAssertEqual(profile.seniorityYears, 0)
        XCTAssertEqual(profile.regionTier, "r4")
        XCTAssertEqual(profile.contractHours, 10)
        XCTAssertTrue(notes.contains("kıdem primi olmadan"))
        XCTAssertTrue(notes.contains("en düşük ücretli bölgeyle"))
        // Paket Taxi kollari arasinda bolge ayni kalir
        let (branch, branchNotes) = TariffComparison.comparisonProfile(for: "pt_migros", own: own, catalog: catalog, day: day)
        XCTAssertEqual(branch.regionTier, "r1")
        XCTAssertFalse(branchNotes.contains("en düşük ücretli bölgeyle"))
        // Paket Taxi kuryesi Yemeksepeti'ne bakarsa: haftalik bonusu toplamda en dusuk grup (3. grup iller)
        XCTAssertEqual(TariffComparison.comparisonProfile(for: "yemeksepeti", own: own, catalog: catalog, day: day).0.regionTier, "ys_group3")
    }

    func testOwnFirmKeepsOwnSeniorityAndTier() {
        let (profile, notes) = TariffComparison.comparisonProfile(for: "migros_hemen", own: own, catalog: catalog, day: day)
        XCTAssertEqual(profile.seniorityYears, 4)
        XCTAssertEqual(profile.regionTier, "r1")
        XCTAssertTrue(notes.isEmpty)
    }

    func testSwitchSuggestionThreshold() {
        let template = TariffComparison.rows(workload: workload, profile: own, catalog: catalog, fuel: fuel, day: day)[0]
        func row(_ code: String, _ net: Int, current: Bool) -> FirmComparisonRow {
            var r = template
            r.platformCode = code
            r.net = Money(net)
            r.isCurrent = current
            r.versionID = "\(code)-v1"
            return r
        }
        XCTAssertNil(TariffComparison.switchSuggestion(rows: [row("a", 100, current: true), row("b", 104, current: false)]))
        let s = TariffComparison.switchSuggestion(rows: [row("a", 100, current: true), row("b", 106, current: false)])
        XCTAssertEqual(s?.platformCode, "b")
        XCTAssertEqual(s?.extraNet, Money(6))
        XCTAssertEqual(s?.key, "b-v1|a-v1")
    }

    func testWorkloadFromPace() {
        let pace = PaceEstimate(packagesPerHour: Decimal(string: "4.2")!, kmPerPackage: 3, isAssumed: false, sampleCount: 9)
        let w = WorkloadSpec.from(pace: pace, goal: GoalSpec(amount: Money(1), period: .month, daysPerWeek: 5))
        XCTAssertEqual(w.packagesPerDay, 34)
        XCTAssertEqual(w.hoursPerDay, 8)
        XCTAssertEqual(w.daysPerMonth, 22)
        XCTAssertEqual(w.monthlyPackages, 748)
    }

    func testFuelCorrelation() {
        var old = TariffFixtures.all.first { $0.platformCode == "trendyol_go" }!
        old.id = "u-ty-1"
        old.origin = .user
        old.versionNumber = 10
        old.effectiveFrom = "2026-08-01"
        old.effectiveUntil = "2026-08-31"
        old.items = old.items.map { var i = $0; i.id = "u1-" + i.id; i.versionID = "u-ty-1"; return i }
        var new = old
        new.id = "u-ty-2"
        new.versionNumber = 11
        new.effectiveFrom = "2026-09-01"
        new.effectiveUntil = nil
        new.items = old.items.map {
            var i = $0
            i.id = "u2-" + i.id
            i.versionID = "u-ty-2"
            i.amount = Money(Money.round(i.amount.value * Decimal(string: "1.08")!))
            return i
        }
        let cat = TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: [old, new])
        let rising = FuelCostModel(settings: FuelSettings(entries: [
            FuelPriceEntry(day: "2026-07-20", pricePerUnit: Money(40), type: .gasoline),
            FuelPriceEntry(day: "2026-08-25", pricePerUnit: Money(Decimal(string: "44.4")!), type: .gasoline)]),
            vehicleType: nil, fallbackCostPerKm: Money(2))
        let c = TariffFuelCorrelation.evaluate(platform: "trendyol_go", catalog: cat, fuel: rising, today: day)
        XCTAssertEqual(c?.tariffChange, 8)
        XCTAssertEqual(c?.fuelChange, 11)
        XCTAssertEqual(c?.verdict, .consistent)
        XCTAssertNil(TariffFuelCorrelation.evaluate(platform: "trendyol_go", catalog: cat,
            fuel: FuelCostModel(settings: FuelSettings(), vehicleType: nil, fallbackCostPerKm: Money(2)), today: day))
    }

    func testFuelUpTariffFlatIsCheck() {
        var old = TariffFixtures.all.first { $0.platformCode == "trendyol_go" }!
        old.id = "u-ty-1"; old.origin = .user; old.versionNumber = 10; old.effectiveFrom = "2026-08-01"; old.effectiveUntil = "2026-08-31"
        old.items = old.items.map { var i = $0; i.id = "u1-" + i.id; i.versionID = "u-ty-1"; return i }
        var new = old
        new.id = "u-ty-2"; new.versionNumber = 11; new.effectiveFrom = "2026-09-01"; new.effectiveUntil = nil
        new.items = old.items.map { var i = $0; i.id = "u2-" + i.id; i.versionID = "u-ty-2"; return i }
        let cat = TariffCatalog.merged(bundled: TariffFixtures.all, remote: [], user: [old, new])
        let rising = FuelCostModel(settings: FuelSettings(entries: [
            FuelPriceEntry(day: "2026-07-20", pricePerUnit: Money(40), type: .gasoline),
            FuelPriceEntry(day: "2026-08-25", pricePerUnit: Money(44), type: .gasoline)]),
            vehicleType: nil, fallbackCostPerKm: Money(2))
        XCTAssertEqual(TariffFuelCorrelation.evaluate(platform: "trendyol_go", catalog: cat, fuel: rising, today: day)?.verdict, .check)
    }
}
