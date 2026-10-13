import Foundation
import SwiftData
@testable import KuryeKazanc

/// 1.9'da uygulamadan kaldirilan firma kayitlari. Uygulama bunlari eklemez; ekran goruntusu / form testleri eski
/// platform kodlariyla calismaya devam etsin diye yalnizca testte eklenir.
enum LegacyPlatforms {
    static let all: [(code: String, name: String)] = [
        ("trendyol_go", "Trendyol GO"), ("getir", "Getir"), ("uber", "Uber"), ("thekurye", "TheKurye"),
        ("banabikurye", "Banabikurye"), ("other", "Diğer"),
    ]

    @MainActor
    static func insert(into context: ModelContext) {
        let existing: Set<String> = Set(((try? context.fetch(FetchDescriptor<Platform>())) ?? []).map(\.code))
        for (index, item) in all.enumerated() where !existing.contains(item.code) {
            context.insert(Platform(name: item.name, code: item.code, sortOrder: 10 + index))
        }
        try? context.save()
    }
}
