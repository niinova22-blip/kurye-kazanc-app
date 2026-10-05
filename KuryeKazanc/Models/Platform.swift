import Foundation
import SwiftData

/// Kurye platformu (Trendyol GO, Getir, Yemeksepeti, ...).
@Model
final class Platform {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Sabit, dile bagimsiz anahtar (or. "trendyol_go"). OCR sablon eslestirmesi ve
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
    static let defaults: [(code: String, name: String)] = [
        ("trendyol_go", "Trendyol GO"),
        ("getir", "Getir"),
        ("yemeksepeti", "Yemeksepeti"),
        ("migros_hemen", "Migros Hemen"),
        ("other", "Diğer"),
    ]
}
