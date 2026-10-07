import Foundation
import SwiftData

/// Bir kazanc kaydinin dayandigi ekran goruntusu kaniti. Gorselin kendisi SAKLANMAZ
/// (isim, kurye no, IBAN icerebilir); yalnizca OCR satirlari, kutular ve okunan degerler tutulur.
@Model
final class ScreenshotEvidence {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Ekran goruntusunun cekildigi an (PhotoKit/EXIF; bilinmiyorsa nil).
    var capturedAt: Date?
    /// PhotoKit yerel kimligi: ayni goruntu ikinci kez onerilmesin diye.
    var assetIdentifier: String?
    var platformCode: String?
    var templateID: String?
    var templateVersion: Int?
    var periodRaw: String
    var isGenuineScreenshot: Bool
    var linesData: Data
    var parsedTotal: Double
    var parsedBonus: Double
    var parsedPackages: Int
    var parsedDate: Date
    /// Normalize OCR metninin ozeti (bkz. `TextHash`): ayni ekran goruntusu ikinci kez kaydedilmesin.
    var textHash: String = ""

    @Relationship(deleteRule: .nullify, inverse: \EarningRecord.evidence)
    var records: [EarningRecord] = []

    var lines: [RecognizedLine] { RecognizedLine.decode(linesData) }
    var period: OCRTemplate.Period { OCRTemplate.Period(rawValue: periodRaw) ?? .unknown }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        capturedAt: Date?,
        assetIdentifier: String?,
        parsed: ParsedEarning,
        lines: [RecognizedLine],
        isGenuineScreenshot: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.capturedAt = capturedAt
        self.assetIdentifier = assetIdentifier
        self.platformCode = parsed.platformCode
        self.templateID = parsed.templateID
        self.templateVersion = parsed.templateVersion
        self.periodRaw = parsed.period.rawValue
        self.isGenuineScreenshot = isGenuineScreenshot
        self.linesData = RecognizedLine.encode(lines)
        self.textHash = TextHash.of(lines.map(\.text))
        self.parsedTotal = parsed.totalEarning
        self.parsedBonus = parsed.bonus
        self.parsedPackages = parsed.packageCount
        self.parsedDate = parsed.date
    }
}
