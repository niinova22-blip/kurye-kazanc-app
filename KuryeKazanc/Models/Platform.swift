import Foundation
import SwiftData

/// Kurye platformu (Yemeksepeti Express, Paket Taxi kollari).
@Model
final class Platform {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Sabit, dile bagimsiz anahtar (or. "yemeksepeti"). OCR sablon eslestirmesi ve
    /// ileride anonim havuzda platform bazli toplama icin isim yerine bu kullanilir.
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

extension Platform {
    /// Ilk acilista eklenen varsayilan platformlar.
    /// 1.9: yalnizca iki firma (Paket Taxi'nin uc kolu ayri).
    static let defaults: [(code: String, name: String)] = [
        ("yemeksepeti", "Yemeksepeti Express"),
        ("pt_restoran", "Paket Taxi Restoran"),
        ("pt_migros", "Paket Taxi Migros"),
        ("migros_hemen", "Paket Taxi Migros Hemen"),
    ]
}
