import Foundation
import SwiftData

/// Manuel girilen gider kaydi. Km basina otomatik tahmin edilen giderler veritabanina yazilmaz,
/// hesaplama aninda `EarningsCalculator` tarafindan uretilir.
@Model
final class ExpenseRecord {
    @Attribute(.unique) var id: UUID
    var anonymousDeviceID: UUID

    /// Gun baslangicina normalize edilmis tarih.
    var date: Date
    var typeRaw: String
    var amount: Double
    var note: String?
    var createdAt: Date

    var type: ExpenseType {
        get { ExpenseType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        anonymousDeviceID: UUID = AnonymousDeviceID.current,
        date: Date,
        type: ExpenseType,
        amount: Double,
        note: String? = nil,
        createdAt: Date = .now,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.anonymousDeviceID = anonymousDeviceID
        self.date = calendar.startOfDay(for: date)
        self.typeRaw = type.rawValue
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
    }
}
