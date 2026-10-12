import SwiftUI
import SwiftData

/// Salt okunur veritabani goruntuleyici (yalnizca test surumu): tablolar, satir sayisi, satir ayrintisi.
struct DatabaseInspectorView: View {
    enum Table: String, CaseIterable, Identifiable {
        case earnings = "Kazançlar"
        case expenses = "Giderler"
        case payroll = "Hakediş"
        case fuel = "Yakıt"
        case settings = "Ayarlar"
        case tariff = "Tarife"
        var id: String { rawValue }
    }

    struct Row: Identifiable {
        var id: String
        var title: String
        var subtitle: String
        var fields: [Field]
    }

    struct Field: Identifiable {
        var name: String
        var value: String
        var id: String { name }
    }

    @Environment(PayrollModel.self) private var payroll
    @Query(sort: \EarningRecord.startTime, order: .reverse) private var earnings: [EarningRecord]
    @Query(sort: \ExpenseRecord.date, order: .reverse) private var expenses: [ExpenseRecord]
    @State private var table: Table = .earnings

    var body: some View {
        let rows: [Row] = rows(for: table)
        List {
            Picker("Tablo", selection: $table) {
                ForEach(Table.allCases) { Text($0.rawValue).tag($0) }
            }
            .accessibilityIdentifier("db.table")
            Section {
                ForEach(rows) { row in
                    NavigationLink {
                        List(row.fields) { field in
                            LabeledContent(field.name, value: field.value)
                        }
                        .navigationTitle(row.title)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title).font(.subheadline)
                            Text(row.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("\(rows.count) satır").accessibilityIdentifier("db.count")
            }
        }
        .navigationTitle("Veritabanı")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rows(for table: Table) -> [Row] {
        switch table {
        case .earnings: earningRows
        case .expenses: expenseRows
        case .payroll: payrollRows
        case .fuel: fuelRows
        case .settings: settingsRows
        case .tariff: tariffRows
        }
    }

    private var earningRows: [Row] {
        let demo: Set<UUID> = Set(payroll.state.demoRecordIDs)
        return earnings.map { r in
            Row(id: r.id.uuidString,
                title: "\(r.platform?.name ?? "—") · \(Formatters.currency(r.totalEarning))",
                subtitle: r.startTime.formatted(date: .abbreviated, time: .shortened),
                fields: [
                    Field(name: "id", value: r.id.uuidString),
                    Field(name: "Başlangıç", value: r.startTime.formatted()),
                    Field(name: "Bitiş", value: r.endTime.formatted()),
                    Field(name: "Brüt", value: "\(r.grossEarning)"),
                    Field(name: "Bonus", value: "\(r.bonus)"),
                    Field(name: "Km", value: "\(r.distanceKm)"),
                    Field(name: "Paket", value: r.packageCount.map(String.init) ?? "—"),
                    Field(name: "İlçe", value: r.district ?? "—"),
                    Field(name: "Kaynak", value: r.sourceRaw),
                    Field(name: "Doğrulama", value: r.verificationRaw),
                    Field(name: "Senaryo", value: demo.contains(r.id) ? "evet" : "hayır"),
                ])
        }
    }

    private var expenseRows: [Row] {
        expenses.map { e in
            Row(id: e.id.uuidString,
                title: "\(e.type.displayName) · \(Formatters.currency(e.amount))",
                subtitle: e.date.formatted(date: .abbreviated, time: .omitted),
                fields: [
                    Field(name: "id", value: e.id.uuidString),
                    Field(name: "Tür", value: e.typeRaw),
                    Field(name: "Tutar", value: "\(e.amount)"),
                    Field(name: "Not", value: e.note ?? ""),
                ])
        }
    }

    private var payrollRows: [Row] {
        payroll.state.logs.map { l in
            Row(id: l.id.uuidString,
                title: "\(PayrollModel.platformName(l.platformCode)) · \(PayFormat.tl(l.gross))",
                subtitle: l.startDay,
                fields: [
                    Field(name: "id", value: l.id.uuidString),
                    Field(name: "Yöntem", value: l.method.displayName),
                    Field(name: "Paket", value: "\(l.input.totalPackages)"),
                    Field(name: "Saat", value: PayFormat.number(l.input.hours)),
                    Field(name: "Km", value: PayFormat.number(l.input.distanceKm)),
                    Field(name: "Brüt", value: PayFormat.tl(l.gross)),
                    Field(name: "Tarife", value: l.tariffVersionID),
                ])
        }
    }

    private var fuelRows: [Row] {
        payroll.state.fuel.entries.map { f in
            Row(id: f.id.uuidString,
                title: "\(PayFormat.tl(f.pricePerUnit))/\(f.type.unitName)",
                subtitle: f.day,
                fields: [
                    Field(name: "id", value: f.id.uuidString),
                    Field(name: "Gün", value: f.day),
                    Field(name: "Tür", value: f.type.displayName),
                    Field(name: "Kaynak", value: f.source.rawValue),
                ])
        }
    }

    private var settingsRows: [Row] {
        let s: PayrollState = payroll.state
        let goal: String = s.goal.map { "\($0.period.displayName) \(PayFormat.tl($0.amount)), haftada \($0.daysPerWeek) gün" } ?? "—"
        return [Row(id: "settings", title: "Firma, hedef ve yakıt", subtitle: s.activePlatform ?? "—", fields: [
            Field(name: "Firma", value: s.activePlatform ?? "—"),
            Field(name: "Bölge", value: s.regionTier ?? "—"),
            Field(name: "Kıdem", value: s.seniorityYears.map(String.init) ?? "—"),
            Field(name: "Araç", value: s.vehicleType ?? "—"),
            Field(name: "İşaretler", value: s.flags.isEmpty ? "—" : s.flags.joined(separator: ", ")),
            Field(name: "Hedef", value: goal),
            Field(name: "Tüketim", value: s.fuel.consumptionPer100Km.map { PayFormat.number($0) } ?? "varsayılan"),
            Field(name: "Kullanıcı tarifeleri", value: "\(s.userTariffs.count)"),
        ])]
    }

    private var tariffRows: [Row] {
        guard let version = payroll.currentVersion() else { return [] }
        return version.items.map { i in
            Row(id: i.id,
                title: i.label,
                subtitle: PayFormat.tl(i.amount) + i.unit.suffix,
                fields: [
                    Field(name: "id", value: i.id),
                    Field(name: "Sürüm", value: version.label),
                    Field(name: "Tür", value: i.type.rawValue),
                    Field(name: "Tutar", value: i.amount.description),
                    Field(name: "Doğrulama", value: i.confidence.rawValue),
                ])
        }
    }
}
