import Foundation
import SwiftData

/// V1 sema surumu. Modeller degistiginde SchemaV2 eklenip `KuryeMigrationPlan.stages`'e goc adimi yazilir;
/// boylece TestFlight/App Store kullanicilarinin verisi guncellemelerde kaybolmaz.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Courier.self, Platform.self, EarningRecord.self, ExpenseRecord.self]
    }
}

enum KuryeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum ModelContainerFactory {
    static let schema = Schema(versionedSchema: SchemaV1.self)

    /// - Parameter inMemory: UI testleri ve SwiftUI onizlemeleri icin diske yazmayan depo.
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: KuryeMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }
}
