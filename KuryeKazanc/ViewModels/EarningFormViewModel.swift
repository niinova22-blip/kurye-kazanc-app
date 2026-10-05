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
    var isResolvingRegion = false

    private(set) var editingRecord: EarningRecord?
    @ObservationIgnored private let calendar: Calendar

    var isEditing: Bool { editingRecord != nil }

    init(
        record: EarningRecord? = nil,
        session: WorkSessionSummary? = nil,
        defaultPlatform: Platform? = nil,
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

    func importScreenshot(
        _ image: UIImage,
        recognizer: TextRecognizing,
        parser: EarningsScreenshotParser = EarningsScreenshotParser(),
        platforms: [Platform],
        referenceDate: Date = .now
    ) async {
        ocrState = .processing
        do {
            let lines = try await recognizer.recognizeLines(in: image)
            let parsed = parser.parse(lines: lines, referenceDate: referenceDate)
            apply(parsed, platforms: platforms)
            ocrState = .finished
        } catch {
            ocrState = .failed(error.localizedDescription)
        }
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
        // Ekran goruntusunde calisma saati yoktur; varsayilan saatler mutlaka kontrol edilmeli
        review.insert(.hours)
        fieldsToReview = review
    }

    // MARK: - Bolge

    func resolveRegionIfNeeded(using location: LocationService, from session: WorkSessionSummary?) async {
        guard !isEditing, district.isEmpty, location.isEnabled else { return }
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
