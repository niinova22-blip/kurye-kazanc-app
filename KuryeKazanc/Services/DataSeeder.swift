import Foundation
import SwiftData

/// Ilk acilista varsayilan platformlari ekler. Tekrar calistirilmasi guvenlidir (idempotent).
enum DataSeeder {
    @MainActor
    static func seedPlatformsIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Platform>())) ?? []
        let existingCodes = Set(existing.map(\.code))

        for (index, item) in Platform.defaults.enumerated() where !existingCodes.contains(item.code) {
            context.insert(Platform(name: item.name, code: item.code, sortOrder: index))
        }
        try? context.save()
    }
}
