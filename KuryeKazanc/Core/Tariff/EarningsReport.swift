import Foundation

/// 1.12.2 Kazanç raporu: geriye donuk gunluk / haftalik / aylik ayrintili kazanc ve disa aktarim (CSV / PDF).
///
/// Tutarlar donem hesabindan (PeriodAggregator) gelir: gunluk kalemler kayitlarin gun paylasimli sonuclarindan,
/// haftalik bonus haftanin toplamindan, aylik kalemler (sabit ucret + aylik bonus) yalnizca ay raporunda.
/// Gun / hafta raporunda sabit ucret istenirse calisilan gunlere dusen pay olarak (tahmini) eklenir.
struct EarningsReport: Equatable {
    enum Span: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }

        var title: String {
            switch self {
            case .day: "Günlük"
            case .week: "Haftalık"
            case .month: "Aylık"
            }
        }
    }

    struct Row: Equatable, Identifiable {
        var id: String
        var label: String
        var amount: Money
        var note: String? = nil
    }

    struct Day: Equatable, Identifiable {
        var day: String
        var packages: Int
        var hours: Decimal
        var km: Decimal
        var gross: Money
        var id: String { day }
    }

    var platformName: String
    var span: Span
    var start: String
    var end: String
    var packages: Int
    var hours: Decimal
    var km: Decimal
    /// Kalem kalem kazanc (firmadan).
    var rows: [Row]
    var fuel: Money
    var otherExpenses: Money
    var days: [Day]
    var notes: [String]

    var gross: Money { rows.map(\.amount).sum() }
    var expenses: Money { fuel + otherExpenses }
    var net: Money { gross - expenses }
    var isEmpty: Bool { packages == 0 && gross.isZero && days.isEmpty }

    /// Excel / Numbers icin noktali virgullu CSV (Turkce ondalik virgul).
    func csv() -> String {
        func money(_ value: Money) -> String {
            String(format: "%.2f", value.doubleValue).replacingOccurrences(of: ".", with: ",")
        }
        func number(_ value: Decimal) -> String {
            String(format: "%.1f", NSDecimalNumber(decimal: value).doubleValue).replacingOccurrences(of: ".", with: ",")
        }
        var lines: [String] = []
        lines.append("Kurye Kazanç - \(span.title) rapor;\(platformName)")
        lines.append("Dönem;\(start) - \(end)")
        lines.append("")
        lines.append("Kalem;Tutar (TL)")
        for row in rows { lines.append("\(row.label.replacingOccurrences(of: ";", with: ","));\(money(row.amount))") }
        lines.append("Firmadan (brüt);\(money(gross))")
        lines.append("Yakıt;-\(money(fuel))")
        lines.append("Diğer giderler;-\(money(otherExpenses))")
        lines.append("Net;\(money(net))")
        lines.append("")
        lines.append("Gün;Paket;Saat;Km;Brüt (TL)")
        for day in days {
            lines.append("\(day.day);\(day.packages);\(number(day.hours));\(number(day.km));\(money(day.gross))")
        }
        lines.append("Toplam;\(packages);\(number(hours));\(number(km));\(money(gross))")
        return lines.joined(separator: "\n") + "\n"
    }
}

enum EarningsReportBuilder {
    /// - Parameters:
    ///   - result: Donemin hesabi (`PayrollModel.period`).
    ///   - logs: Donemin gunluk kayitlari (gun listesi ve kalem dokumu icin).
    ///   - fixedSharePerDay: Gun / hafta raporunda calisilan gun basina sabit ucret payi (nil: eklenmez).
    ///   - fuel: Yakit gideri (elle yakit gideri yoksa km'den).
    static func make(platformName: String, span: EarningsReport.Span, start: String, end: String, result: PeriodResult,
                     logs: [WorkLog], fixedSharePerDay: Money?, fuel: Money, otherExpenses: Money) -> EarningsReport {
        let daily: [WorkLog] = logs.filter { $0.isDaily && $0.startDay >= start && $0.startDay <= end }
        var rows: [EarningsReport.Row] = []
        // Gunluk kalemler: ayni etiketli satirlar toplanir (paket ucreti, km, gunluk prim...)
        var order: [String] = []
        var sums: [String: Money] = [:]
        for log in daily {
            for line in log.result.lines where line.included && line.isCash && line.scope == .daily && !line.provisional
                && line.type != .tip && line.type != .deduction {
                let key: String = line.label
                if sums[key] == nil { order.append(key) }
                sums[key, default: .zero] += line.low
            }
        }
        for key in order where !(sums[key] ?? .zero).isZero {
            rows.append(EarningsReport.Row(id: "daily." + key, label: key, amount: sums[key] ?? .zero))
        }
        let adjustments: Money = daily.compactMap(\.manualAdjustment).sum()
        if !adjustments.isZero { rows.append(EarningsReport.Row(id: "adjust", label: "Elle düzeltmeler", amount: adjustments)) }
        if !result.periodLogPart.isZero {
            rows.append(EarningsReport.Row(id: "periodLogs", label: "Dönem özeti kayıtları", amount: result.periodLogPart))
        }
        if !result.weeklyPart.isZero {
            rows.append(EarningsReport.Row(id: "weekly", label: "Haftalık bonus", amount: result.weeklyPart,
                                           note: "Haftanın (Pzt–Paz) toplam paketine göre"))
        }
        if !result.monthlyPart.isZero {
            rows.append(EarningsReport.Row(id: "monthly", label: "Aylık kalemler (sabit ücret, aylık bonus)", amount: result.monthlyPart,
                                           note: "Ayın toplam paketine göre; ay sonunda ödenir"))
        }
        if result.monthlyPart.isZero, let share = fixedSharePerDay, !share.isZero, result.daysWithLogs > 0 {
            rows.append(EarningsReport.Row(id: "fixedShare", label: "Sabit ücretin çalışılan günlere düşen payı",
                                           amount: Money(share.value * Decimal(result.daysWithLogs)),
                                           note: "Tahmini; sabit ücret ay sonunda ödenir"))
        }
        if !result.provisionalPart.isZero, !result.provisionalReplaced {
            rows.append(EarningsReport.Row(id: "provisional", label: "Ay sonunda kesinleşecek tahminler", amount: result.provisionalPart))
        }
        if !result.tips.isZero { rows.append(EarningsReport.Row(id: "tips", label: "Bahşiş", amount: result.tips)) }
        if !result.extraPayments.isZero {
            rows.append(EarningsReport.Row(id: "extra", label: "Ek ödemeler", amount: result.extraPayments))
        }
        if !result.deductions.isZero {
            rows.append(EarningsReport.Row(id: "deductions", label: "Kesintiler", amount: Money.zero - result.deductions))
        }

        var byDay: [String: EarningsReport.Day] = [:]
        for log in daily {
            var day = byDay[log.startDay] ?? EarningsReport.Day(day: log.startDay, packages: 0, hours: 0, km: 0, gross: .zero)
            day.packages += log.input.totalPackages
            day.hours += log.input.hours
            day.km += log.input.distanceKm
            day.gross += log.gross
            byDay[log.startDay] = day
        }
        var notes: [String] = []
        if span != .month, result.platformCode != "yemeksepeti" {
            notes.append("Aylık bonus ayın toplam paketine göre ay sonunda hesaplanır; aylık raporda görünür.")
        }
        return EarningsReport(platformName: platformName, span: span, start: start, end: end, packages: result.packages,
                              hours: result.hours, km: result.km, rows: rows, fuel: fuel, otherExpenses: otherExpenses,
                              days: byDay.values.sorted { $0.day < $1.day }, notes: notes)
    }
}
