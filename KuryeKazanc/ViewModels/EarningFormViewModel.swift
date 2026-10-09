import Foundation
import Observation
import SwiftData
import UIKit

/// Kazanc ekleme/duzenleme formu. Manuel giris, "Calisiyorum" oturumundan on doldurma ve
/// ekran goruntusu OCR'i ayni formu kullanir; OCR sonucu her zaman kullaniciya onaylatilir.
@MainActor
@Observable
final class EarningFormViewModel {
    enum Field: String, Hashable, CaseIterable {
        case platform, date, hours, gross, bonus, packages, distance

        var title: String {
            switch self {
            case .platform: "Platform"
            case .date: "Tarih"
            case .hours: "Çalışma saatleri"
            case .gross: "Kazanç"
            case .bonus: "Bonus"
            case .packages: "Paket sayısı"
            case .distance: "Mesafe"
            }
        }
    }

    enum OCRState: Equatable {
        case idle
        case processing
        case finished
        case failed(String)
    }

    var platform: Platform?
    var date: Date
    var startTime: Date
    var endTime: Date
    var grossText = ""
    var bonusText = ""
    var distanceText = ""
    var packageText = ""
    var province = ""
    var district = ""
    var neighborhood = ""
    var source: EarningSource = .manual

    /// "Bu alanlari kontrol et" ile vurgulanan alanlar.
    var fieldsToReview: Set<Field> = []
    var ocrState: OCRState = .idle
    /// Son ekran goruntusu ice aktarimi (kanit + degerlendirme).
    private(set) var imported: ImportedScreenshot?
    /// Ice aktarilan ekranin metin ozeti kayitli bir kanitla ayni: kayit en fazla `ocrEdited` olur (spec 10).
    private(set) var isDuplicateScreenshot = false
    /// Ekrandan okunan degerlerin karsilastirma tabani (kullanici degistirdi mi?).
    @ObservationIgnored private var readBaseline: ReadValues?
    var isResolvingRegion = false

    private(set) var editingRecord: EarningRecord?
    @ObservationIgnored private let calendar: Calendar

    var isEditing: Bool { editingRecord != nil }

    /// Ekrandan okunan (saatler haric) degerler.
    struct ReadValues: Equatable {
        var platformCode: String?
        var day: Date
        var gross: Double
        var bonus: Double
        var packages: Int?
    }

    /// Tek vardiya icin en uzun sure; uzunu haftalik/hatali okuma sayilir.
    static let maxShiftDuration: TimeInterval = 16 * 3600

    /// Sablon tutarlarin KDV haric oldugunu soyluyorsa bilgi notu.
    var amountNote: String? {
        imported?.parsed.amountsExcludeVAT == true ? "Bu ekrandaki tutarlar KDV hariç gösteriliyor." : nil
    }

    static let duplicateScreenshotIssue = "Bu ekran görüntüsü daha önce kaydedilmiş."

    var assessmentIssues: [String] {
        var issues: [String] = imported?.assessment.issues ?? []
        if isDuplicateScreenshot {
            issues.append(Self.duplicateScreenshotIssue)
        }
        return issues
    }

    /// Kaydedilince alinacak seviye.
    var pendingVerification: VerificationLevel {
        if let editingRecord, imported == nil {
            // Duzenleme: okunan degerler degistiyse ocrEdited, yoksa mevcut seviye
            guard editingRecord.source == .ocr else { return .manual }
            return userEditedReadValues ? .ocrEdited : editingRecord.verification
        }
        if imported != nil, isDuplicateScreenshot {
            // Daha once kullanilmis ekran: asla topluluga girmez
            return .ocrEdited
        }
        return VerificationLevel.resolve(
            isFromScreenshot: imported != nil,
            userEditedReadValues: userEditedReadValues,
            candidate: imported?.assessment.candidate ?? .manual
        )
    }

    private var currentReadValues: ReadValues {
        ReadValues(
            platformCode: platform?.code,
            day: calendar.startOfDay(for: date),
            gross: TurkishNumberParser.parseDecimal(grossText) ?? -1,
            bonus: TurkishNumberParser.parseDecimal(bonusText) ?? 0,
            packages: TurkishNumberParser.parseInt(packageText)
        )
    }

    private var userEditedReadValues: Bool {
        guard let readBaseline else { return false }
        let current = currentReadValues
        return current.platformCode != readBaseline.platformCode
            || current.day != readBaseline.day
            || abs(current.gross - readBaseline.gross) > 0.005
            || abs(current.bonus - readBaseline.bonus) > 0.005
            || (current.packages ?? 0) != (readBaseline.packages ?? 0)
    }

    init(
        record: EarningRecord? = nil,
        session: WorkSessionSummary? = nil,
        defaultPlatform: Platform? = nil,
        imported: ImportedScreenshot? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        if let record {
            editingRecord = record
            platform = record.platform
            date = record.date
            startTime = record.startTime
            endTime = record.endTime
            grossText = TurkishNumberParser.format(record.grossEarning)
            bonusText = record.bonus == 0 ? "" : TurkishNumberParser.format(record.bonus)
            distanceText = record.distanceKm == 0 ? "" : TurkishNumberParser.format(record.distanceKm)
            packageText = record.packageCount.map(String.init) ?? ""
            province = record.province ?? ""
            district = record.district ?? ""
            neighborhood = record.neighborhood ?? ""
            source = record.source
        } else if let session {
            platform = defaultPlatform
            date = calendar.startOfDay(for: session.start)
            startTime = session.start
            endTime = session.end
            distanceText = session.distanceKm > 0 ? TurkishNumberParser.format((session.distanceKm * 10).rounded() / 10) : ""
        } else {
            platform = defaultPlatform
            date = calendar.startOfDay(for: now)
            endTime = now
            startTime = calendar.date(byAdding: .hour, value: -4, to: now) ?? now
        }
        // OCR kaynakli kayit duzenlenirken okunan degerler taban alinir
        if let record, record.source == .ocr {
            readBaseline = currentReadValues
        }
        if let imported {
            apply(imported, platforms: defaultPlatform.map { [$0] } ?? [])
        }
    }

    // MARK: - Alan guncelleme (kullanici etkilesimi -> vurgu kalkar)

    func markReviewed(_ field: Field) {
        fieldsToReview.remove(field)
    }

    var reviewMessage: String? {
        guard !fieldsToReview.isEmpty else { return nil }
        let names = Field.allCases.filter(fieldsToReview.contains).map(\.title)
        return "Bu alanları kontrol et: " + names.joined(separator: ", ")
    }

    // MARK: - OCR

    /// - Parameters:
    ///   - capturedAt: Gorselin cekildigi an (PhotoKit); EXIF yoksa kullanilir.
    ///   - knownTextHashes: Kayitli kanitlarin metin ozetleri (tekrar kontrolu).
    func importScreenshot(
        data: Data,
        assetIdentifier: String?,
        capturedAt: Date? = nil,
        importer: ScreenshotImporter = ScreenshotImporter(),
        platforms: [Platform],
        knownTextHashes: Set<String> = [],
        referenceDate: Date = .now
    ) async {
        ocrState = .processing
        do {
            let result = try await importer.importImage(
                data: data, assetIdentifier: assetIdentifier,
                capturedAt: capturedAt, referenceDate: referenceDate
            )
            apply(result, platforms: platforms, knownTextHashes: knownTextHashes)
            ocrState = .finished
        } catch {
            ocrState = .failed(error.localizedDescription)
        }
    }

    func apply(_ imported: ImportedScreenshot, platforms: [Platform], knownTextHashes: Set<String> = []) {
        self.imported = imported
        isDuplicateScreenshot = !imported.textHash.isEmpty && knownTextHashes.contains(imported.textHash)
        apply(imported.parsed, platforms: platforms)
        if imported.parsed.period == .week || imported.parsed.period == .order {
            // Haftalik toplam / tek siparis tek vardiya gibi sessizce kaydedilmesin: "Kontrol ettim" onayi zorunlu
            fieldsToReview.formUnion([.gross, .date])
        }
        readBaseline = currentReadValues
        // Paylasim / oneri ile acilan formda da degerlendirme ve rozet gorunsun
        ocrState = .finished
    }

    /// OCR sonucunu forma yazar. Hicbir alan bos birakilmaz; emin olunamayanlar vurgulanir.
    func apply(_ parsed: ParsedEarning, platforms: [Platform]) {
        source = .ocr

        var review = Set<Field>()
        if let code = parsed.platformCode, let match = platforms.first(where: { $0.code == code }) {
            platform = match
        } else {
            review.insert(.platform)
        }

        // Tarihi degistir, saatleri ayni gune tasi
        let newDay = calendar.startOfDay(for: parsed.date)
        startTime = combine(day: newDay, time: startTime)
        endTime = combine(day: newDay, time: endTime)
        date = newDay

        grossText = TurkishNumberParser.format(parsed.grossEarning)
        bonusText = TurkishNumberParser.format(parsed.bonus)
        packageText = String(parsed.packageCount)

        for field in parsed.fieldsToReview {
            switch field {
            case .platform: review.insert(.platform)
            case .date: review.insert(.date)
            case .packageCount: review.insert(.packages)
            case .totalEarning: review.insert(.gross)
            case .bonus: review.insert(.bonus)
            }
        }
        // Ekranda gunluk calisma suresi varsa vardiya saatini ondan kur; yoksa varsayilan saatler kontrol edilmeli.
        if let duration = parsed.workDuration, parsed.period != .week, duration <= Self.maxShiftDuration {
            startTime = endTime.addingTimeInterval(-duration)
        } else {
            review.insert(.hours)
        }
        fieldsToReview = review
    }

    /// TestFlight testcilerinin gelistiriciye gonderdigi OCR raporu. Satirlar dogrudan
    /// `EarningsScreenshotParserTests`'e yapistirilabilecek Swift dizisi bicimindedir.
    var ocrDiagnosticReport: String? {
        let recognizedLines = imported?.lines.map(\.text) ?? []
        guard !recognizedLines.isEmpty else { return nil }
        let escaped = recognizedLines.map { line in
            "    \"" + line.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\","
        }
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "-") (\(info?["CFBundleVersion"] as? String ?? "-"))"
        return """
        Kurye Kazanç OCR raporu — sürüm \(version)
        Platform: \(platform?.name ?? "-") · Kazanç: \(grossText) · Bonus: \(bonusText) · Paket: \(packageText)
        Kontrol edilecek: \(fieldsToReview.map(\.title).sorted().joined(separator: ", "))
        Doğru değerler (testçi doldursun): kazanç=… bonus=… paket=… tarih=…

        let lines = [
        \(escaped.joined(separator: "\n"))
        ]
        """
    }

    // MARK: - Bolge

    func resolveRegionIfNeeded(using location: LocationService, from session: WorkSessionSummary?) async {
        guard !isEditing, district.isEmpty, location.isEnabled else { return }
        if let region = session?.region {
            province = region.province ?? ""
            district = region.district ?? ""
            neighborhood = region.neighborhood ?? ""
            return
        }
        isResolvingRegion = true
        defer { isResolvingRegion = false }

        let region: PlaceRegion?
        if let last = session?.lastLocation {
            region = await location.region(for: last)
        } else {
            region = await location.currentRegion()
        }
        guard let region else { return }
        province = region.province ?? ""
        district = region.district ?? ""
        neighborhood = region.neighborhood ?? ""
    }

    // MARK: - Dogrulama ve kayit

    /// Secilen gun + saatler. Bitis baslangictan once ise gece yarisini gecen vardiya sayilir.
    func resolvedInterval() -> (start: Date, end: Date) {
        let day = calendar.startOfDay(for: date)
        let start = combine(day: day, time: startTime)
        var end = combine(day: day, time: endTime)
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return (start, end)
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if platform == nil { errors.append("Platform seç.") }
        if let gross = TurkishNumberParser.parseDecimal(grossText) {
            if gross < 0 { errors.append("Kazanç negatif olamaz.") }
        } else {
            errors.append("Kazancı gir (ör. 850 veya 1.250,50).")
        }
        if !bonusText.isEmpty, (TurkishNumberParser.parseDecimal(bonusText) ?? -1) < 0 {
            errors.append("Bonus geçerli bir tutar olmalı.")
        }
        if !distanceText.isEmpty, (TurkishNumberParser.parseDecimal(distanceText) ?? -1) < 0 {
            errors.append("Mesafe geçerli bir sayı olmalı.")
        }
        if !packageText.isEmpty, TurkishNumberParser.parseInt(packageText) == nil {
            errors.append("Paket sayısı tam sayı olmalı.")
        }
        let interval = resolvedInterval()
        if interval.end.timeIntervalSince(interval.start) > 20 * 3600 {
            errors.append("Çalışma süresi 20 saati geçemez; saatleri kontrol et.")
        }
        return errors
    }

    var canSave: Bool { validationErrors.isEmpty }

    @discardableResult
    func save(in context: ModelContext) throws -> EarningRecord {
        // Seviye kayit alanlari degismeden ONCE hesaplanir
        let level = pendingVerification
        let interval = resolvedInterval()
        let gross = TurkishNumberParser.parseDecimal(grossText) ?? 0
        let bonus = TurkishNumberParser.parseDecimal(bonusText) ?? 0
        let distance = TurkishNumberParser.parseDecimal(distanceText) ?? 0
        let packages = TurkishNumberParser.parseInt(packageText)

        let record: EarningRecord
        if let editingRecord {
            record = editingRecord
            record.updateInterval(start: interval.start, end: interval.end, calendar: calendar)
            record.platform = platform
            record.grossEarning = gross
            record.bonus = bonus
            record.distanceKm = distance
            record.packageCount = packages
            record.source = source
        } else {
            record = EarningRecord(
                startTime: interval.start, endTime: interval.end, platform: platform,
                grossEarning: gross, bonus: bonus, distanceKm: distance,
                packageCount: packages, source: source, calendar: calendar
            )
            context.insert(record)
        }
        record.verification = level
        if let imported, record.evidence == nil {
            let evidence = ScreenshotEvidence(
                capturedAt: imported.capturedAt,
                assetIdentifier: imported.assetIdentifier,
                parsed: imported.parsed,
                lines: imported.lines,
                isGenuineScreenshot: imported.isGenuine
            )
            context.insert(evidence)
            record.evidence = evidence
        }
        record.province = province.nilIfBlank
        record.district = district.nilIfBlank
        record.neighborhood = neighborhood.nilIfBlank
        try context.save()
        return record
    }

    private func combine(day: Date, time: Date) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
