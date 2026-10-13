import XCTest
#if canImport(KuryeCore)
@testable import KuryeCore
#else
@testable import KuryeKazanc
#endif

/// Kontrollu ornek tarifeler: gercek sirket verisine bagli degil; gomulu ornek JSON ve elle kurulan surumler.
enum TariffFixtures {
    /// Hesap mekanigi testleri icin ilk (v1) ornek surumler: kademeli paket ucreti, kidem, garanti gibi kurallari
    /// kapsar. Guncel tarifeler (v2) `BundledTariffs.all` ile ayri testlerde.
    static var bundled: [TariffVersion] { all.filter { $0.versionNumber == 1 } }

    /// Uygulamanin gomulu tarifeleri + yalnizca testte tutulan eski firmalar (Trendyol GO, Getir; bkz. LegacyFirms).
    static var all: [TariffVersion] { BundledTariffs.all + LegacyFirms.versions }

    static let calculators: [PayCalculator] = PayEngine.standardCalculators + LegacyFirms.calculators

    static func engine(catalog: TariffCatalog, clock: @escaping () -> Date = { Date(timeIntervalSince1970: 1_790_000_000) }) -> PayEngine {
        PayEngine(catalog: catalog, calculators: calculators, clock: clock)
    }

    static func bundled(_ id: String) -> TariffVersion {
        guard let version = all.first(where: { $0.id == id }) else {
            fatalError("gomulu surum yok: \(id)")
        }
        return version
    }

    static var engine: PayEngine {
        engine(catalog: TariffCatalog(versions: bundled))
    }

    static func engine(_ versions: [TariffVersion]) -> PayEngine {
        engine(catalog: TariffCatalog(versions: versions))
    }

    static func item(_ key: String, _ type: TariffItemType, _ amount: String, version: String = "v",
                     method: CalculationMethod = .perUnit, unit: TariffUnit = .package, lower: String? = nil,
                     upper: String? = nil, confidence: ConfidenceStatus = .verified, from: String? = nil,
                     until: String? = nil) -> TariffItem {
        var item = TariffItem(id: "\(version)-\(key)", versionID: version, key: key, type: type, label: key,
                              amount: Money(text: amount)!, unit: unit, lowerThreshold: lower.flatMap { Decimal.parse($0) },
                              upperThreshold: upper.flatMap { Decimal.parse($0) }, method: method, confidence: confidence)
        item.effectiveFrom = from
        item.effectiveUntil = until
        return item
    }

    static func version(_ id: String, platform: String, items: [TariffItem], status: ApprovalStatus = .published,
                        from: String = "2026-01-01", until: String? = nil, number: Int = 1, vehicle: String? = nil,
                        region: String? = nil, origin: TariffOrigin = .remote, settings: TariffSettings = TariffSettings(),
                        verification: VerificationState = .verified) -> TariffVersion {
        TariffVersion(id: id, platformCode: platform, workModel: "esnaf", regionID: region, vehicleType: vehicle,
                      versionNumber: number, effectiveFrom: from, effectiveUntil: until, createdAt: "2026-01-01",
                      sourceType: .officialAnnouncement, verificationStatus: verification, approvalStatus: status,
                      settings: settings, items: items.map { var i = $0; i.versionID = id; return i }, origin: origin)
    }

    static func input(_ platform: String, day: String = "2026-10-07", span: PaySpan = .day, end: String? = nil) -> PayInput {
        PayInput(platformCode: platform, span: span, startDay: day, endDay: end)
    }

    static func calc(_ input: PayInput, engine: PayEngine = TariffFixtures.engine, file: StaticString = #filePath,
                     line: UInt = #line) -> PayBreakdown {
        switch engine.calculate(input) {
        case let .success(breakdown): return breakdown
        case let .failure(error):
            XCTFail("hesaplama basarisiz: \(error)", file: file, line: line)
            return PayBreakdown(platformCode: input.platformCode, tariffVersionID: "", tariffVersionLabel: "", tariffOrigin: .bundled,
                                tariffVerification: .unverified, span: input.span, startDay: input.startDay, endDay: input.endDay,
                                computedAt: Date(), lines: [], sideBenefits: [], notices: [], progress: [], extraPayments: .zero,
                                deductions: .zero, advances: .zero)
        }
    }
}

func money(_ text: String) -> Money { Money(text: text)! }

extension PayBreakdown {
    func line(_ key: String) -> PayLine? { lines.first { $0.itemKey == key } }
}
