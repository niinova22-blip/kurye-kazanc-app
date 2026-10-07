import Foundation
import SwiftData

/// Silme kurallari: ekran goruntusu kaniti (OCR metni isim, kurye no, IBAN icerebilir) kayitla birlikte silinir.
extension ModelContext {
    /// Kazanc kaydini siler; kaniti baska kayitta kullanilmiyorsa onu da siler.
    func deleteEarning(_ record: EarningRecord) throws {
        let evidence = record.evidence
        delete(record)
        if let evidence, evidence.records.allSatisfy({ $0.id == record.id }) {
            delete(evidence)
        }
        try save()
    }

    /// "Tum kayitlari sil": kazanc, gider ve tum ekran goruntusu kanitlari.
    /// Not: Kazanc kayitlari tek tek silinir; `evidence` iliskisinin nullify tersi yuzunden
    /// SwiftData toplu silmeyi (`delete(model:)`) reddeder.
    func deleteAllRecords() throws {
        for record in try fetch(FetchDescriptor<EarningRecord>()) {
            delete(record)
        }
        for evidence in try fetch(FetchDescriptor<ScreenshotEvidence>()) {
            delete(evidence)
        }
        try delete(model: ExpenseRecord.self)
        try save()
    }
}
