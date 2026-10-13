import Foundation
import SwiftData

/// Ilk acilista varsayilan platformlari ekler; 1.9'da uygulamadan kalkan firmalar (kaydi yoksa) silinir ve adlar
/// guncellenir. Tekrar calistirilmasi guvenlidir (idempotent).
enum DataSeeder {
    @MainActor
    static func seedPlatformsIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Platform>())) ?? []
        let existingCodes = Set(existing.map(\.code))

        for (index, item) in Platform.defaults.enumerated() where !existingCodes.contains(item.code) {
            context.insert(Platform(name: item.name, code: item.code, sortOrder: index))
        }
        let supported: [String: (Int, String)] = Dictionary(uniqueKeysWithValues: Platform.defaults.enumerated().map {
            ($0.element.code, ($0.offset, $0.element.name))
        })
        for platform in existing {
            if let (order, name) = supported[platform.code] {
                if platform.name != name { platform.name = name }
                if platform.sortOrder != order { platform.sortOrder = order }
            } else if platform.earnings.isEmpty {
                // Eski firmalarin kayitlari durur; kaydi olmayan platform listeden kalkar
                context.delete(platform)
            }
        }
        try? context.save()
    }
}
