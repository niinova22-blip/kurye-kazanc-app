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
    /// Ekrandaki calisma suresi (or. "Cevrimici 23 sa 32 dk"); okunamazsa nil. Kontrol alani degildir.
    var workDuration: TimeInterval? = nil
    var layout: OCRTemplate.Layout = .summary
    /// Sablona gore ekrandaki tutarlar KDV haric (bilgi).
    var amountsExcludeVAT: Bool = false

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

        // 2-4) Toplam, bonus, adet: ekran tipine gore
        var total: Double?
        var bonus: Double
        var packages: Int
        switch template.layout {
        case .summary:
            let excludedForTotal = template.bonusLabels + template.packageLabels
            total = findAmount(labels: template.totalLabels, excluding: excludedForTotal, in: normalized)
            if total == nil {
                total = largestAmount(in: normalized)
                review.insert(.totalEarning)
            }
            if let found = findAmount(labels: template.bonusLabels, excluding: [], in: normalized) {
                bonus = found
            } else {
                bonus = 0
                review.insert(.bonus)
            }
            if let found = findCount(labels: template.packageLabels, in: normalized) {
                packages = found
            } else {
                packages = 0
                review.insert(.packageCount)
            }
        case .list:
            let rows = listRowAmounts(labels: template.rowLabels, in: normalized)
            bonus = 0
            if rows.isEmpty {
                total = findAmount(labels: template.totalLabels, excluding: [], in: normalized) ?? largestAmount(in: normalized)
                packages = 0
                review.formUnion([.totalEarning, .packageCount])
            } else {
                let sum = rows.reduce(0, +)
                total = sum
                packages = rows.count
                if let shown = findAmount(labels: template.totalLabels, excluding: template.rowLabels, in: normalized),
                   abs(shown - sum) > max(shown, 1) * 0.01 {
                    review.insert(.totalEarning)
                }
            }
        case .orderCard:
            total = findAmount(labels: template.totalLabels, excluding: template.bonusLabels, in: normalized)
                ?? largestCurrencyAmount(in: normalized)
            if total == nil { review.insert(.totalEarning) }
            bonus = firstAmountInLine(containing: template.bonusLabels, in: normalized) ?? 0
            packages = 1
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
            packageCount: packages,
            totalEarning: total ?? 0,
            bonus: bonus,
            totalIncludesBonus: template.totalIncludesBonus,
            fieldsToReview: review,
            templateID: detected?.id,
            templateVersion: detected?.version,
            templateStatus: detected?.status,
            fingerprintMatches: detected?.fingerprintMatches(in: fullText) ?? 0,
            period: template.layout == .orderCard ? .order : template.period(in: fullText),
            workDuration: findDuration(labels: template.durationLabels, in: normalized),
            layout: template.layout,
            amountsExcludeVAT: template.amountsExcludeVAT
        )
    }

    // MARK: - Platform

    /// 1) Platform adi (esitlikte parmak izi), 2) ad yoksa guclu parmak izi, 3) nil (generic).
    func detectTemplate(in lines: [String]) -> OCRTemplate? {
        let text = lines.joined(separator: " ")
        var best: (template: OCRTemplate, score: Int, fingerprint: Int)?
        for template in templates {
            let score = template.detectionKeywords.reduce(0) { count, keyword in
                count + (TextPatterns.containsWord(keyword, in: text) ? 1 : 0)
            }
            guard score > 0 else { continue }
            let fingerprint = template.fingerprintMatches(in: text)
            if let current = best, (score, fingerprint) <= (current.score, current.fingerprint) { continue }
            best = (template, score, fingerprint)
        }
        if let best { return best.template }

        var byFingerprint: (template: OCRTemplate, matches: Int)?
        for template in templates where template.minFingerprintMatches >= OCRTemplate.fingerprintOnlyThreshold {
            let matches = template.fingerprintMatches(in: text)
            guard matches >= template.minFingerprintMatches else { continue }
            if let current = byFingerprint {
                if matches < current.matches { continue }
                if matches == current.matches, template.fingerprint.count <= current.template.fingerprint.count { continue }
            }
            byFingerprint = (template, matches)
        }
        return byFingerprint?.template
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

    /// Para birimi isaretli tutarlarin en buyugu (siparis karti: km/dk/yuzde sayilmaz).
    func largestCurrencyAmount(in lines: [String]) -> Double? {
        lines.filter(TextPatterns.hasCurrencyMarker).flatMap(TextPatterns.allAmounts).max()
    }

    func firstAmountInLine(containing labels: [String], in lines: [String]) -> Double? {
        for label in labels {
            if let line = lines.first(where: { TextPatterns.containsWord(label, in: $0) }),
               let value = TextPatterns.firstAmount(in: line) {
                return value
            }
        }
        return nil
    }

    /// Liste ekrani: her etiket satirinin para birimli tutari (Review Focus 2: is numaralari tutar degildir).
    func listRowAmounts(labels: [String], in lines: [String]) -> [Double] {
        let cleaned = lines.map(TextPatterns.strippingReferenceNumbers)
        var amounts: [Double] = []
        for (index, line) in cleaned.enumerated() {
            guard let label = labels.first(where: { line.contains($0) }), let range = line.range(of: label) else { continue }
            let rest = String(line[range.upperBound...])
            if TextPatterns.hasCurrencyMarker(rest), let value = TextPatterns.firstAmount(in: rest) {
                amounts.append(value)
                continue
            }
            for offset in [1, 2, -1] {
                let neighbor = index + offset
                guard cleaned.indices.contains(neighbor) else { continue }
                let candidate = cleaned[neighbor]
                if labels.contains(where: { candidate.contains($0) }) { break }
                guard TextPatterns.hasCurrencyMarker(candidate),
                      !TextPatterns.containsLetters(candidate, minimum: 4),
                      let value = TextPatterns.firstAmount(in: candidate) else { continue }
                amounts.append(value)
                break
            }
        }
        return amounts
    }

    // MARK: - Sure

    func findDuration(labels: [String], in lines: [String]) -> TimeInterval? {
        for label in labels {
            for (index, line) in lines.enumerated() where TextPatterns.containsWord(label, in: line) {
                if let range = line.range(of: label),
                   let value = TextPatterns.duration(in: String(line[range.upperBound...])) {
                    return value
                }
                for offset in [1, -1, 2] {
                    let neighbor = index + offset
                    guard lines.indices.contains(neighbor) else { continue }
                    if let value = TextPatterns.duration(in: lines[neighbor]) { return value }
                }
            }
        }
        return nil
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
