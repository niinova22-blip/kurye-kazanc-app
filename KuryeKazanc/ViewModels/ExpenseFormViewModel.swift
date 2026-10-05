import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ExpenseFormViewModel {
    var type: ExpenseType = .fuel
    var date: Date
    var amountText = ""
    var note = ""

    private(set) var editingRecord: ExpenseRecord?
    @ObservationIgnored private let calendar: Calendar

    var isEditing: Bool { editingRecord != nil }

    init(record: ExpenseRecord? = nil, now: Date = .now, calendar: Calendar = .current) {
        self.calendar = calendar
        if let record {
            editingRecord = record
            type = record.type
            date = record.date
            amountText = TurkishNumberParser.format(record.amount)
            note = record.note ?? ""
        } else {
            date = calendar.startOfDay(for: now)
        }
    }

    var validationErrors: [String] {
        guard let amount = TurkishNumberParser.parseDecimal(amountText) else {
            return ["Tutarı gir (ör. 250 veya 1.250,50)."]
        }
        return amount > 0 ? [] : ["Tutar sıfırdan büyük olmalı."]
    }

    var canSave: Bool { validationErrors.isEmpty }

    /// Yakit/bakim girilince o gunun km basina tahmini devre disi kalir (cift sayim olmaz).
    var replacesEstimate: Bool { type.isCoveredByPerKmEstimate }

    @discardableResult
    func save(in context: ModelContext) throws -> ExpenseRecord {
        let amount = TurkishNumberParser.parseDecimal(amountText) ?? 0
        let record: ExpenseRecord
        if let editingRecord {
            record = editingRecord
            record.type = type
            record.amount = amount
            record.updateDate(date, calendar: calendar)
        } else {
            record = ExpenseRecord(date: date, type: type, amount: amount, calendar: calendar)
            context.insert(record)
        }
        record.note = note.nilIfBlank
        try context.save()
        return record
    }
}
