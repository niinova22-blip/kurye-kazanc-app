import Foundation
import SwiftData

/// 1.0.0 ile yayinlanan sema. DEGISTIRMEYIN: gocun kaynak surumudur.
/// Canli modeller (Courier, EarningRecord...) SchemaV2'yi temsil eder.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Courier.self, Platform.self, EarningRecord.self, ExpenseRecord.self]
    }

    @Model
    final class Courier {
        @Attribute(.unique) var id: UUID
        var name: String
        var vehicleTypeRaw: String
        var createdAt: Date
        @Relationship(deleteRule: .nullify, inverse: \Platform.couriers)
        var defaultPlatforms: [Platform] = []

        init(id: UUID = UUID(), name: String, vehicleTypeRaw: String, createdAt: Date = .now) {
            self.id = id
            self.name = name
            self.vehicleTypeRaw = vehicleTypeRaw
            self.createdAt = createdAt
        }
    }

    @Model
    final class Platform {
        @Attribute(.unique) var id: UUID
        var name: String
        @Attribute(.unique) var code: String
        var sortOrder: Int
        @Relationship(deleteRule: .nullify, inverse: \EarningRecord.platform)
        var earnings: [EarningRecord] = []
        var couriers: [Courier] = []

        init(id: UUID = UUID(), name: String, code: String, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.code = code
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class EarningRecord {
        @Attribute(.unique) var id: UUID
        var anonymousDeviceID: UUID
        var date: Date
        var startTime: Date
        var endTime: Date
        var platform: Platform?
        var province: String?
        var district: String?
        var neighborhood: String?
        var grossEarning: Double
        var bonus: Double
        var distanceKm: Double
        var packageCount: Int?
        var sourceRaw: String
        var createdAt: Date

        init(id: UUID = UUID(), anonymousDeviceID: UUID, date: Date, startTime: Date, endTime: Date,
             grossEarning: Double, bonus: Double = 0, distanceKm: Double = 0, packageCount: Int? = nil,
             sourceRaw: String, createdAt: Date = .now) {
            self.id = id
            self.anonymousDeviceID = anonymousDeviceID
            self.date = date
            self.startTime = startTime
            self.endTime = endTime
            self.grossEarning = grossEarning
            self.bonus = bonus
            self.distanceKm = distanceKm
            self.packageCount = packageCount
            self.sourceRaw = sourceRaw
            self.createdAt = createdAt
        }
    }

    @Model
    final class ExpenseRecord {
        @Attribute(.unique) var id: UUID
        var anonymousDeviceID: UUID
        var date: Date
        var typeRaw: String
        var amount: Double
        var note: String?
        var createdAt: Date

        init(id: UUID = UUID(), anonymousDeviceID: UUID, date: Date, typeRaw: String, amount: Double,
             note: String? = nil, createdAt: Date = .now) {
            self.id = id
            self.anonymousDeviceID = anonymousDeviceID
            self.date = date
            self.typeRaw = typeRaw
            self.amount = amount
            self.note = note
            self.createdAt = createdAt
        }
    }
}
