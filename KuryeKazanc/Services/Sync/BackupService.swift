import Foundation
import SwiftData

/// Yedekteki kazanc kaydi. Ekran goruntusu kaniti (OCR metni: isim, kurye no, IBAN olabilir)
/// bilerek YOK; cihaz kimligi ve sunucu esitleme alanlari da tasinmaz.
struct EarningDTO: Codable, Equatable {
    var id: UUID
    var start: Date
    var end: Date
    var platformCode: String?
    var province: String?
    var district: String?
    var neighborhood: String?
    var gross: Double
    var bonus: Double
    var distanceKm: Double
    var packageCount: Int?
    var sourceRaw: String
    var verificationRaw: String
    var createdAt: Date
}

/// Yedekteki gider kaydi.
struct ExpenseDTO: Codable, Equatable {
    var id: UUID
    var date: Date
    var typeRaw: String
    var amount: Double
    var note: String?
    var createdAt: Date
}

/// Sunucudaki `backups.payload` (jsonb) icerigi.
struct BackupPayload: Codable, Equatable {
    var version: Int
    var earnings: [EarningDTO]
    var expenses: [ExpenseDTO]
    /// Yalnizca `BackupService.preferenceKeys`; cihazda ayarlanmamis anahtar yuke girmez.
    var preferences: [String: Double]
    var createdAt: Date
}

/// Yedek okunamadi / bu surum tanimiyor.
enum BackupError: Error, Equatable {
    case unsupportedVersion(Int)
    case unreadable
}

extension BackupError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return "Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Uygulamayı güncelleyip tekrar dene."
        case .unreadable:
            return "Yedek okunamadı."
        }
    }
}

/// Yedek yukunu SwiftData'dan olusturur ve geri yukler (spec 4).
///
/// Geri yukleme birlestirir: id'si cihazda zaten olan kayit atlanir (yerel hal korunur),
/// cihazda ayarlanmis tercih ezilmez.
@MainActor
enum BackupService {
    static let currentVersion: Int = 1

    /// Yedege giren tercihler (hepsi Double).
    static let preferenceKeys: [String] = [
        AppPreferences.costPerKmKey,
        AppPreferences.weeklyGoalKey,
        AppPreferences.dailyGoalKey,
    ]

    // MARK: - Olusturma

    static func makePayload(context: ModelContext, defaults: UserDefaults, now: Date = Date()) throws -> BackupPayload {
        let earningDescriptor = FetchDescriptor<EarningRecord>(sortBy: [SortDescriptor(\.startTime)])
        let expenseDescriptor = FetchDescriptor<ExpenseRecord>(sortBy: [SortDescriptor(\.date)])
        let earnings: [EarningDTO] = try context.fetch(earningDescriptor).map { dto(for: $0) }
        let expenses: [ExpenseDTO] = try context.fetch(expenseDescriptor).map { dto(for: $0) }
        return BackupPayload(
            version: currentVersion,
            earnings: earnings,
            expenses: expenses,
            preferences: preferences(from: defaults),
            createdAt: now
        )
    }

    private static func dto(for record: EarningRecord) -> EarningDTO {
        EarningDTO(
            id: record.id,
            start: record.startTime,
            end: record.endTime,
            platformCode: record.platform?.code,
            province: record.province,
            district: record.district,
            neighborhood: record.neighborhood,
            gross: record.grossEarning,
            bonus: record.bonus,
            distanceKm: record.distanceKm,
            packageCount: record.packageCount,
            sourceRaw: record.sourceRaw,
            verificationRaw: record.verificationRaw,
            createdAt: record.createdAt
        )
    }

    private static func dto(for record: ExpenseRecord) -> ExpenseDTO {
        ExpenseDTO(
            id: record.id,
            date: record.date,
            typeRaw: record.typeRaw,
            amount: record.amount,
            note: record.note,
            createdAt: record.createdAt
        )
    }

    private static func preferences(from defaults: UserDefaults) -> [String: Double] {
        var result: [String: Double] = [:]
        for key in preferenceKeys {
            guard let value = defaults.object(forKey: key) as? Double, value.isFinite else { continue }
            result[key] = value
        }
        return result
    }

    // MARK: - Geri yukleme

    /// - Returns: eklenen ve atlanan (id'si mevcut ya da gecersiz) kayit sayisi.
    @discardableResult
    static func restore(
        _ payload: BackupPayload,
        into context: ModelContext,
        platforms: [Platform],
        defaults: UserDefaults = .standard
    ) throws -> (added: Int, skipped: Int) {
        guard payload.version <= currentVersion else {
            throw BackupError.unsupportedVersion(payload.version)
        }
        var platformsByCode: [String: Platform] = [:]
        for platform in platforms {
            platformsByCode[platform.code] = platform
        }
        var earningIDs: Set<UUID> = try Set(context.fetch(FetchDescriptor<EarningRecord>()).map(\.id))
        var expenseIDs: Set<UUID> = try Set(context.fetch(FetchDescriptor<ExpenseRecord>()).map(\.id))
        var added: Int = 0
        var skipped: Int = 0

        for item in payload.earnings {
            // Yuk icinde tekrar eden id de ikinci kez eklenmez (benzersiz kisit cakismasin).
            guard !earningIDs.contains(item.id), isValid(item) else {
                skipped += 1
                continue
            }
            context.insert(record(from: item, platform: item.platformCode.flatMap { platformsByCode[$0] }))
            earningIDs.insert(item.id)
            added += 1
        }
        for item in payload.expenses {
            guard !expenseIDs.contains(item.id), isValid(item) else {
                skipped += 1
                continue
            }
            context.insert(record(from: item))
            expenseIDs.insert(item.id)
            added += 1
        }
        do {
            try context.save()
        } catch {
            // Yarim kalan ekleme bellekte kalmasin.
            context.rollback()
            throw error
        }
        restorePreferences(payload.preferences, into: defaults)
        return (added, skipped)
    }

    private static func record(from item: EarningDTO, platform: Platform?) -> EarningRecord {
        let record = EarningRecord(
            id: item.id,
            startTime: item.start,
            endTime: item.end,
            platform: platform,
            province: item.province,
            district: item.district,
            neighborhood: item.neighborhood,
            grossEarning: item.gross,
            bonus: item.bonus,
            distanceKm: item.distanceKm,
            packageCount: item.packageCount,
            createdAt: item.createdAt
        )
        // Ham degerler aynen korunur (bilinmeyen deger hesaplanan ozellikte yine varsayilana duser).
        record.sourceRaw = item.sourceRaw
        record.verificationRaw = item.verificationRaw
        return record
    }

    private static func record(from item: ExpenseDTO) -> ExpenseRecord {
        let record = ExpenseRecord(
            id: item.id,
            date: item.date,
            type: .other,
            amount: item.amount,
            note: item.note,
            createdAt: item.createdAt
        )
        record.typeRaw = item.typeRaw
        return record
    }

    private static func isValid(_ item: EarningDTO) -> Bool {
        item.gross.isFinite && item.bonus.isFinite && item.distanceKm.isFinite
    }

    private static func isValid(_ item: ExpenseDTO) -> Bool {
        item.amount.isFinite
    }

    /// Yalnizca bilinen anahtarlar ve yalnizca cihazda henuz ayarlanmamislarsa.
    private static func restorePreferences(_ preferences: [String: Double], into defaults: UserDefaults) {
        for key in preferenceKeys {
            guard let value = preferences[key], value.isFinite else { continue }
            guard defaults.object(forKey: key) == nil else { continue }
            defaults.set(value, forKey: key)
        }
    }

    // MARK: - JSON

    /// Tarihler Unix saniyesi (sayi): sunucu jsonb'yi yeniden kodlasa da deger korunur.
    static func encode(_ payload: BackupPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    static func decode(_ data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return try decoder.decode(BackupPayload.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
    }
}
