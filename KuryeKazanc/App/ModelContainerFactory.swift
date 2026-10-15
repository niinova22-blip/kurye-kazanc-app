import Foundation
import SwiftData

/// 1.1.0 semasi: dogrulama seviyesi + ekran goruntusu kaniti.
/// Yeni model degisikliginde SchemaV3 eklenir, SchemaV2 modelleri SchemaV1 gibi dondurulur.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Courier.self, Platform.self, EarningRecord.self, ExpenseRecord.self, ScreenshotEvidence.self]
    }
}

enum KuryeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [v1ToV2] }

    /// Yeni alanlar varsayilanli (hafif goc); ardindan OCR kaynakli eski kayitlar `ocrUnverified` yapilir
    /// (kanitlari olmadigi icin `verified` olamazlar).
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let ocr = EarningSource.ocr.rawValue
            let records = try context.fetch(FetchDescriptor<EarningRecord>(
                predicate: #Predicate { $0.sourceRaw == ocr }
            ))
            for record in records {
                record.verification = .ocrUnverified
            }
            try context.save()
        }
    )
}

enum ModelContainerFactory {
    static let schema = Schema(versionedSchema: SchemaV2.self)

    /// Kalici depo acilamadi, gecici (bellek) depo kullaniliyor. Ornek: cihaz yeniden basladiktan sonra kilit hic
    /// acilmadan iOS uygulamayi konum olayiyla arka planda baslatti (dosya korumasi). Eskiden burada `fatalError` vardi:
    /// uygulama cokuyordu. Simdi cokmez; on plana gelince kullaniciya yeniden acmasi soylenir (bkz. RootView).
    static private(set) var isUsingFallbackStore = false

    /// - Parameters:
    ///   - inMemory: UI testleri ve SwiftUI onizlemeleri icin diske yazmayan depo.
    ///   - url: Goc testleri icin ozel dosya konumu.
    static func make(inMemory: Bool = false, url: URL? = nil) -> ModelContainer {
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: KuryeMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            // Gecici hata (dosya kilidi / koruma): bir kez daha denenir
            if let container = try? ModelContainer(for: schema, migrationPlan: KuryeMigrationPlan.self,
                                                   configurations: [configuration]) {
                return container
            }
            isUsingFallbackStore = !inMemory
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: [memory]) {
                return container
            }
            fatalError("ModelContainer oluşturulamadı: \(error)")
        }
    }
}
