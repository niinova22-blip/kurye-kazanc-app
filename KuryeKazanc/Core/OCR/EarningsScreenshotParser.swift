import Foundation

/// OCR ile okunan kazanc ekrani sonucu. Kullaniciya onay icin gosterilir, duzenlenebilir.
struct ParsedEarning: Equatable {
    enum Field: String, CaseIterable, Hashable {
        case platform, date, packageCount, totalEarning, bonus
    }

    var platformCode: String?
    var date: Date
    var packageCount: Int
    var totalEarning: Double
    var bonus: Double
    var totalIncludesBonus: Bool
    /// Guvenle okunamayan ve TAHMINLE doldurulan alanlar -> "bu alanlari kontrol et" uyarisi.
    var fieldsToReview: Set<Field>
    /// Eslesen sablonun kimligi; platform taninamadiysa nil.
    var templateID: String? = nil
    var templateVersion: Int? = nil
    var templateStatus: OCRTemplate.Status? = nil
    /// Ekranda gorulen parmak izi metni sayisi.
    var fingerprintMatches: Int = 0
    /// Ekran gunluk mu haftalik mi?
    var period: OCRTemplate.Period = .unknown

    /// Bizim modelimizdeki brut (bonus haric) kazanc.
    var grossEarning: Double {
        totalIncludesBonus ? max(0, totalEarning - bonus) : totalEarning
    }
}

/// OCR satirlarindan kazanc alanlarini regex ile cikarir. Saf mantik: Vision'dan bagimsiz, birim test edilir.
///
/// Kural: hicbir alan bos birakilmaz. Etiketle bulunamayan alan icin en iyi tahmin yazilir
/// (toplam: en buyuk tutar, bonus: 0, paket: 0, tarih: bugun) ve alan `fieldsToReview`'a eklenir.
struct EarningsScreenshotParser {
    var templates: [OCRTemplate] = BundledTemplates.all
    var calendar: Calendar = .current

    func parse(lines rawLines: [String], referenceDate: Date = .now) -> ParsedEarning {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalized = lines.map(TextNormalizer.normalize)

        var review = Set<ParsedEarning.Field>()

        // 1) Platform
        let template: OCRTemplate
        let detected = detectTemplate(in: normalized)
        if let detected {
            template = detected
        } else {
            template = BundledTemplates.generic
            review.insert(.platform)
        }
        let fullText = normalized.joined(separator: " ")

        // 2) Toplam kazanc
        let excludedForTotal = template.bonusLabels + template.packageLabels
        var total = findAmount(labels: template.totalLabels, excluding: excludedForTotal, in: normalized)
        if total == nil {
            total = largestAmount(in: normalized)
            review.insert(.totalEarning)
        }

        // 3) Bonus
        var bonus = findAmount(labels: template.bonusLabels, excluding: [], in: normalized)
        if bonus == nil {
            bonus = 0
            review.insert(.bonus)
        }

        // 4) Paket / siparis sayisi
        var packages = findCount(labels: template.packageLabels, in: normalized)
        if packages == nil {
            packages = 0
            review.insert(.packageCount)
        }

        // 5) Tarih
        var date = findDate(in: normalized, referenceDate: referenceDate)
        if date == nil {
            date = calendar.startOfDay(for: referenceDate)
            review.insert(.date)
        }

        if total == nil || total == 0 {
            review.insert(.totalEarning)
        }

        return ParsedEarning(
            platformCode: template.platformCode.isEmpty ? nil : template.platformCode,
            date: date!,
            packageCount: packages!,
            totalEarning: total ?? 0,
            bonus: bonus!,
            totalIncludesBonus: template.totalIncludesBonus,
            fieldsToReview: review,
            templateID: detected?.id,
            templateVersion: detected?.version,
            templateStatus: detected?.status,
            fingerprintMatches: detected?.fingerprintMatches(in: fullText) ?? 0,
            period: template.period(in: fullText)
        )
    }

    // MARK: - Platform

    func detectTemplate(in lines: [String]) -> OCRTemplate? {
        let text = lines.joined(separator: " ")
        var best: (template: OCRTemplate, score: Int)?
        for template in templates {
            let score = template.detectionKeywords.reduce(0) { count, keyword in
                count + (TextPatterns.containsWord(keyword, in: text) ? 1 : 0)
            }
            if score > 0, score > (best?.score ?? 0) {
                best = (template, score)
            }
        }
        return best?.template
    }

    // MARK: - Tutar

    /// Etiketi iceren satirda (etiketten sonra), yoksa sonraki, onceki, iki sonraki satirda tutar arar.
    func findAmount(labels: [String], excluding: [String], in lines: [String]) -> Double? {
        for label in labels {
            for (index, line) in lines.enumerated() where line.contains(label) {
                if excluding.contains(where: { $0 != label && line.contains($0) && !$0.contains(label) }) {
                    continue
                }
                if let range = line.range(of: label),
                   let value = TextPatterns.firstAmount(in: String(line[range.upperBound...])) {
                    return value
                }
                for offset in [1, -1, 2] {
                    let neighbor = index + offset
                    guard lines.indices.contains(neighbor) else { continue }
                    let candidate = lines[neighbor]
                    // Komsu satir kendi etiketini tasiyorsa ("Bonus ₺90") o etiketin degeridir, atla
                    if TextPatterns.containsLetters(candidate, minimum: 4) {
                        continue
                    }
                    if let value = TextPatterns.firstAmount(in: candidate) {
                        return value
                    }
                }
            }
        }
        return nil
    }

    func largestAmount(in lines: [String]) -> Double? {
        let withCurrency = lines.filter(TextPatterns.hasCurrencyMarker).flatMap(TextPatterns.allAmounts)
        if let max = withCurrency.max() { return max }
        return lines.flatMap(TextPatterns.allAmounts).filter { $0 >= 10 }.max()
    }

    // MARK: - Adet

    func findCount(labels: [String], in lines: [String]) -> Int? {
        for label in labels {
            for (index, line) in lines.enumerated() where line.contains(label) {
                if let range = line.range(of: label),
                   let value = TextPatterns.firstCount(in: String(line[range.upperBound...])) {
                    return value
                }
                // "18 paket" gibi deger etiketten once gelebilir
                if let range = line.range(of: label),
                   let value = TextPatterns.lastCount(in: String(line[..<range.lowerBound])) {
                    return value
                }
                for offset in [1, -1] {
                    let neighbor = index + offset
                    guard lines.indices.contains(neighbor) else { continue }
                    let candidate = lines[neighbor]
                    guard !TextPatterns.hasCurrencyMarker(candidate),
                          !TextPatterns.containsLetters(candidate, minimum: 4) else { continue }
                    if let value = TextPatterns.firstCount(in: candidate) {
                        return value
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Tarih

    func findDate(in lines: [String], referenceDate: Date) -> Date? {
        for line in lines {
            if let date = TextPatterns.numericDate(in: line, calendar: calendar) {
                return date
            }
            if let date = TextPatterns.monthNameDate(in: line, referenceDate: referenceDate, calendar: calendar) {
                return date
            }
        }
        for line in lines {
            if TextPatterns.containsWord("bugun", in: line) {
                return calendar.startOfDay(for: referenceDate)
            }
            if TextPatterns.containsWord("dun", in: line) {
                return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: referenceDate))
            }
        }
        return nil
    }
}
