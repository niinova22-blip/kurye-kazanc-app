import Foundation
import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([
        Courier.self,
        Platform.self,
        EarningRecord.self,
        ExpenseRecord.self,
    ])

    /// - Parameter inMemory: UI testleri ve SwiftUI onizlemeleri icin diske yazmayan depo.
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }
}
