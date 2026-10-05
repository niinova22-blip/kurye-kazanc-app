import Foundation
import SwiftData

/// Kurye profili.
/// DIKKAT: Isim gibi kisisel bilgiler yalnizca burada tutulur ve anonim paylasima ASLA dahil edilmez.
/// Paylasilabilir kayitlar (EarningRecord, ExpenseRecord) Courier'a iliski kurmaz; sadece anonim cihaz UUID'si tasir.
@Model
final class Courier {
    @Attribute(.unique) var id: UUID
    var name: String
    var vehicleTypeRaw: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Platform.couriers)
    var defaultPlatforms: [Platform] = []

    var vehicleType: VehicleType {
        get { VehicleType(rawValue: vehicleTypeRaw) ?? .motorcycle }
        set { vehicleTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        vehicleType: VehicleType,
        defaultPlatforms: [Platform] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.vehicleTypeRaw = vehicleType.rawValue
        self.defaultPlatforms = defaultPlatforms
        self.createdAt = createdAt
    }
}
