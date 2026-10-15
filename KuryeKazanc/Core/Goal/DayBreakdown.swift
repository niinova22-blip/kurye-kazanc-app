import Foundation

/// Bugun ekranindaki kartin tam ekran dokumu (1.11): kazanc kalem kalem, sonra toplam, gider ve net;
/// ardindan bu tempoyla hedefin ilerisinde mi gerisinde mi kalindigi.
struct DayBreakdown: Equatable {
    /// Kazanc kalemleri (ayni kalem birden cok vardiyada ise toplanir). Yan haklar girmez.
    var rows: [PayDetailRow]
    var gross: Money { rows.map(\.periodAmount).sum() }

    /// Tarife kaydi olmayan kazanc kayitlari ve kaydi elle degistirilmis vardiyalarin farki ayri satirdir.
    /// - Parameters:
    ///   - logs: Bugunun gunluk hakedis dokumleri ve bagli kazanc kaydinin tutari (kayit duzenlendiyse fark satiri cikar).
    ///   - unlinkedRecords: Tarife hesabi olmayan kayitlarin toplami (eski ekran goruntusu / elle kazanc).
    ///   - liveShift: Suren vardiyanin su ana kadarki tahmini.
    ///   - fixedShare: Aylik sabit ucretin bugune dusen payi (dokumlerde sabit ucret satiri yoksa eklenir).
    static func make(logs: [(detail: PayDetail, recordTotal: Money?)], unlinkedRecords: Money, liveShift: Money,
                     fixedShare: [PayDetailRow]) -> DayBreakdown {
        var merged: [PayDetailRow] = []
        var adjustment: Money = .zero
        for log in logs {
            let cash: [PayDetailRow] = log.detail.rows.filter { $0.category != .side }
            for row in cash {
                if let index = merged.firstIndex(where: { $0.category == row.category && $0.label == row.label }) {
                    merged[index].periodAmount = merged[index].periodAmount + row.periodAmount
                    merged[index].perDay = merged[index].periodAmount
                    merged[index].quantityText = nil
                } else {
                    var copy = row
                    copy.perDay = copy.periodAmount
                    merged.append(copy)
                }
            }
            if let recordTotal = log.recordTotal {
                let difference: Money = recordTotal - cash.map(\.periodAmount).sum()
                if abs(difference.doubleValue) >= 1 { adjustment = adjustment + difference }
            }
        }
        if !merged.contains(where: { $0.category == .fixed }) {
            merged += fixedShare.map { row in
                var copy = row
                copy.periodAmount = row.perDay
                return copy
            }
        }
        if !adjustment.isZero {
            merged.append(PayDetailRow(id: "day.adjustment", category: .other, label: "Kayıtta elle düzeltme",
                                       quantityText: nil, periodAmount: adjustment, perDay: adjustment))
        }
        if !unlinkedRecords.isZero {
            merged.append(PayDetailRow(id: "day.records", category: .other, label: "Diğer kazanç kayıtları",
                                       quantityText: nil, periodAmount: unlinkedRecords, perDay: unlinkedRecords))
        }
        if !liveShift.isZero {
            merged.append(PayDetailRow(id: "day.live", category: .other, label: "Süren vardiya (şu ana kadar)",
                                       quantityText: nil, periodAmount: liveShift, perDay: liveShift, isEstimate: true))
        }
        // Gun paylasiminda ust kademeye gecilince alt kademe satiri eksiyle dusulur: toplami sifir kalan satir gosterilmez
        merged.removeAll { $0.periodAmount.isZero && $0.category != .fixed }
        let order: [PayDetailCategory] = PayDetailCategory.allCases
        merged.sort { (order.firstIndex(of: $0.category) ?? 0) < (order.firstIndex(of: $1.category) ?? 0) }
        return DayBreakdown(rows: merged)
    }
}

/// Bu tempoyla hedef doneminin sonunda nerede olunur.
struct GoalPace: Equatable {
    var period: GoalPeriod
    var goal: Money
    /// Calisilan gunlerin ortalama netiyle donemin is gunleri tamamlaninca beklenen net.
    var projected: Money
    /// Projeksiyonun dayandigi calisilan gun sayisi.
    var workedDays: Int

    var difference: Money { projected - goal }
    var isAhead: Bool { difference.value >= 0 }

    /// - Parameter dailyNets: Donemde calisilan her gunun neti (bugun dahil; calisilmayan gunler yok).
    static func project(goal: GoalSpec, dailyNets: [Money]) -> GoalPace? {
        let worked: [Money] = dailyNets.filter { !$0.isZero }
        guard !worked.isEmpty else { return nil }
        let average: Decimal = worked.map(\.value).reduce(0, +) / Decimal(worked.count)
        let days: Int = goal.periodWorkDays()
        return GoalPace(period: goal.period, goal: goal.amount, projected: Money(Money.round(average * Decimal(days), scale: 0)),
                        workedDays: worked.count)
    }
}
