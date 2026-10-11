import Foundation

/// Beklenen hakedis ile gercek odemenin karsilastirmasi. Fark dogrudan hata demek degildir:
/// sistem farki gosterir ve kontrol edilmesi gereken kalemleri isaretler.
struct Reconciliation: Equatable {
    enum Status: String, Equatable {
        /// |fark| ≤ tolerans.
        case matches
        /// Gercek odeme beklenen araligin icinde (aralikli kalemler).
        case withinRange
        /// Odeme beklenenden az.
        case lower
        /// Odeme beklenenden fazla.
        case higher

        var displayName: String {
            switch self {
            case .matches: "Beklenenle uyumlu"
            case .withinRange: "Beklenen aralıkta"
            case .lower: "Beklenenden az"
            case .higher: "Beklenenden fazla"
            }
        }
    }

    var expected: Money
    var expectedUpper: Money
    var actual: Money
    /// Gercek − beklenen (avans ve kesinti dusulmus).
    var difference: Money
    var percent: Decimal?
    var status: Status
    /// Kontrol edilmesi gereken kalemler.
    var checks: [String]
}

enum PaymentReconciler {
    static let tolerance = Money(1)

    /// - Parameters:
    ///   - period: Donem ozeti (beklenen = odeme oncesi tutar).
    ///   - actual: Platformdan gelen odeme.
    ///   - advances, deductions: Odeme belgesindeki avans ve kesintiler (beklenenden dusulur).
    ///   - periodDays: Donemdeki gun sayisi (kaydi olmayan gunleri isaretlemek icin).
    static func reconcile(period: PeriodResult, actual: Money, advances: Money = .zero, deductions: Money = .zero,
                          periodDays: Int? = nil) -> Reconciliation {
        let expected: Money = period.prePayment - advances - deductions
        let expectedUpper: Money = period.prePaymentUpper - advances - deductions
        let difference: Money = actual - expected
        let percent: Decimal? = Money.percentChange(from: expected, to: actual)
        let status: Reconciliation.Status
        let absolute: Money = difference.isNegative ? -difference : difference
        if absolute <= tolerance {
            status = .matches
        } else if expectedUpper > expected, actual >= expected, actual <= expectedUpper {
            status = .withinRange
        } else {
            status = difference.isNegative ? .lower : .higher
        }

        var checks: [String] = []
        if status != .matches {
            if expectedUpper > expected {
                checks.append("Aralıklı kalemler (birleşen paket vb.) alt sınırla hesaplandı; üst sınırla beklenen \(expectedUpper) TL.")
            }
            if period.provisionalPart > .zero, !period.provisionalReplaced {
                checks.append("Ay sonunda kesinleşen kalemler henüz tahmin (\(period.provisionalPart) TL taban ücretle).")
            }
            if period.tips > .zero {
                checks.append("Bahşişler (\(period.tips) TL) platform ödemesinde ayrı ya da hiç görünmeyebilir.")
            }
            if let periodDays, period.daysWithLogs < periodDays, period.logCount > 0 {
                checks.append("Dönemde \(periodDays - period.daysWithLogs) gün için kayıt yok; eksik gün varsa beklenen düşük kalır.")
            }
            if period.logCount == 0 {
                checks.append("Bu dönemde kayıt yok; beklenen tutar hesaplanamadı.")
            }
            for notice in period.notices where notice.kind == .needsVerification || notice.kind == .ambiguity {
                checks.append(notice.message)
            }
            if period.needsVerification {
                checks.append("Hesaplamada doğrulanmamış tarife kalemleri var; platform tarifesini kontrol et.")
            }
            if difference.isNegative {
                checks.append("Ödeme belgesindeki kesinti ve avansları girdiğinden emin ol.")
            } else {
                checks.append("Bonus ya da kampanya ödemesi tarifede olmayabilir; ödeme dökümünü kontrol et.")
            }
        }
        var unique: [String] = []
        for check in checks where !unique.contains(check) { unique.append(check) }
        return Reconciliation(expected: expected, expectedUpper: expectedUpper, actual: actual, difference: difference,
                              percent: percent, status: status, checks: unique)
    }
}
