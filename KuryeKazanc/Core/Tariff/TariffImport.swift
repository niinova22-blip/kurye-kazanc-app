import Foundation

/// Ekran goruntusu / belge metninden ya da CSV'den okunan taslak kalem. Taslak, kullanici onayi olmadan
/// aktif tarifeye donusmez (bkz. PayrollStore.saveUserTariff).
struct DraftTariffItem: Equatable, Identifiable {
    var item: TariffItem
    /// 0...1 okuma guveni (OCR/metin cikarimi). CSV satirlari 1.
    var score: Double
    var sourceLine: String

    var id: String { item.id }
}

struct TariffImportResult: Equatable {
    var drafts: [DraftTariffItem]
    var errors: [String]
}

enum TariffImport {
    // MARK: - CSV

    /// Baslik satiri zorunlu, sutun sirasi serbest. Ayirac `;` (onerilen; Turkce ondalik virgulle cakismaz) ya da `,`.
    /// Sutunlar: kalem, tur, etiket, tutar, ust_tutar, birim, alt_esik, ust_esik, yontem, baslangic, bitis.
    static func csv(_ text: String, platform: String, versionID: String) -> TariffImportResult {
        let rows: [String] = text.split(whereSeparator: \.isNewline).map(String.init).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard let header = rows.first else { return TariffImportResult(drafts: [], errors: ["Dosya boş."]) }
        let delimiter: Character = header.contains(";") ? ";" : ","
        let columns: [String] = header.split(separator: delimiter, omittingEmptySubsequences: false)
            .map { normalizeHeader(String($0)) }
        func index(_ names: String...) -> Int? { columns.firstIndex { names.contains($0) } }
        guard let amountIndex = index("tutar", "amount"), let typeIndex = index("tur", "item_type", "type") else {
            return TariffImportResult(drafts: [], errors: ["Başlıkta en az 'tur' ve 'tutar' sütunları olmalı."])
        }
        let keyIndex: Int? = index("kalem", "item_key", "key")
        let labelIndex: Int? = index("etiket", "label")
        let upperIndex: Int? = index("ust_tutar", "amount_upper")
        let unitIndex: Int? = index("birim", "unit")
        let lowerTIndex: Int? = index("alt_esik", "lower_threshold")
        let upperTIndex: Int? = index("ust_esik", "upper_threshold")
        let methodIndex: Int? = index("yontem", "calculation_method", "method")
        let fromIndex: Int? = index("baslangic", "effective_from")
        let untilIndex: Int? = index("bitis", "effective_until")

        var drafts: [DraftTariffItem] = []
        var errors: [String] = []
        for (lineNumber, row) in rows.dropFirst().enumerated() {
            let cells: [String] = row.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            func cell(_ i: Int?) -> String? {
                guard let i, i < cells.count, !cells[i].isEmpty else { return nil }
                return cells[i]
            }
            let line: Int = lineNumber + 2
            guard let typeText = cell(typeIndex), let type = parseType(typeText) else {
                errors.append("Satır \(line): tür anlaşılamadı.")
                continue
            }
            guard let amountText = cell(amountIndex), let amount = Money(text: amountText) else {
                errors.append("Satır \(line): tutar okunamadı.")
                continue
            }
            let key: String = cell(keyIndex) ?? "\(type.rawValue).\(line)"
            let unit: TariffUnit = cell(unitIndex).flatMap { parseUnit($0) } ?? defaultUnit(type)
            let method: CalculationMethod = cell(methodIndex).flatMap { CalculationMethod(rawValue: $0) } ?? defaultMethod(type)
            var item = TariffItem(
                id: "\(versionID)-\(key)", versionID: versionID, key: key, type: type,
                label: cell(labelIndex) ?? type.displayName, amount: amount,
                amountUpper: cell(upperIndex).flatMap { Money(text: $0) }, unit: unit,
                lowerThreshold: cell(lowerTIndex).flatMap { Decimal.parse($0) },
                upperThreshold: cell(upperTIndex).flatMap { Decimal.parse($0) }, method: method,
                confidence: .userEntered
            )
            item.effectiveFrom = cell(fromIndex)
            item.effectiveUntil = cell(untilIndex)
            if type == .inKindSupport { item.isCash = false }
            drafts.append(DraftTariffItem(item: item, score: 1, sourceLine: row))
        }
        return TariffImportResult(drafts: drafts, errors: errors)
    }

    private static func normalizeHeader(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).lowercased(with: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ü", with: "u").replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ı", with: "i").replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "ğ", with: "g").replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: " ", with: "_")
    }

    static func parseType(_ text: String) -> TariffItemType? {
        if let type = TariffItemType(rawValue: text) { return type }
        let t: String = normalizeHeader(text)
        let table: [(String, TariffItemType)] = [
            ("birlesen", .combinedPackage), ("tekli", .singlePackage), ("paket", .singlePackage), ("km", .perKm),
            ("saatlik", .hourly), ("sabit", .fixed), ("gunluk", .dailyBonus), ("haftalik", .weeklyBonus),
            ("aylik", .monthlyBonus), ("yogunluk", .surgeMultiplier), ("yakit", .fuelEquipmentSupport),
            ("ekipman", .fuelEquipmentSupport), ("bahsis", .tip), ("referans", .referralBonus), ("kesinti", .deduction),
            ("ayni", .inKindSupport), ("diger", .otherPayment),
        ]
        return table.first { t.contains($0.0) }?.1
    }

    static func parseUnit(_ text: String) -> TariffUnit? {
        if let unit = TariffUnit(rawValue: text) { return unit }
        switch normalizeHeader(text) {
        case "paket": return .package
        case "saat", "sa": return .hour
        case "gun": return .day
        case "hafta": return .week
        case "ay": return .month
        case "carpan": return .multiplier
        default: return nil
        }
    }

    static func defaultUnit(_ type: TariffItemType) -> TariffUnit {
        switch type {
        case .singlePackage, .combinedPackage: .package
        case .perKm: .km
        case .hourly: .hour
        case .dailyBonus: .day
        case .weeklyBonus: .week
        case .monthlyBonus, .fixed: .month
        case .surgeMultiplier: .multiplier
        default: .flat
        }
    }

    static func defaultMethod(_ type: TariffItemType) -> CalculationMethod {
        switch type {
        case .singlePackage, .combinedPackage, .perKm, .hourly: .perUnit
        case .dailyBonus, .weeklyBonus, .monthlyBonus: .tier
        case .surgeMultiplier: .multiplier
        default: .flat
        }
    }

    // MARK: - Metin (OCR / PDF)

    private static let amountPattern: String = #"(\d{1,3}(?:[.\s]\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(?:TL|₺)"#
    private static let thresholdPattern: String = #"(\d{1,4})\s*\+?\s*paket"#

    /// Satirlarda tutar + anahtar kelime arar. Sonuc her zaman "dogrulama gerekli" taslaktir.
    /// - Parameter lineConfidence: OCR satir guvenleri (yoksa 1).
    static func text(_ lines: [String], platform: String, versionID: String, lineConfidence: [Double]? = nil) -> TariffImportResult {
        var drafts: [DraftTariffItem] = []
        var used: [String: Int] = [:]
        for (index, raw) in lines.enumerated() {
            let lower: String = raw.lowercased(with: Locale(identifier: "tr_TR"))
            guard let amountText = firstMatch(amountPattern, in: raw), let amount = Money(text: amountText) else { continue }
            guard let (type, key, label, strength) = classify(lower) else { continue }
            var item = TariffItem(id: "", versionID: versionID, key: key, type: type, label: label, amount: amount,
                                  unit: defaultUnit(type), method: defaultMethod(type), confidence: .needsVerification)
            if type == .dailyBonus || type == .weeklyBonus || type == .monthlyBonus,
               let threshold = firstMatch(thresholdPattern, in: lower), let value = Decimal.parse(threshold) {
                item.lowerThreshold = value
                item.key = "\(key).\(threshold)"
                item.label = "\(label) (\(threshold) paket)"
            }
            if key == "package.night" { item.conditions.timeBand = .night }
            if key == "package.day" { item.conditions.timeBand = .day }
            let count: Int = used[item.key, default: 0]
            used[item.key] = count + 1
            if count > 0 { item.key += ".\(count + 1)" }
            item.id = "\(versionID)-\(item.key)"
            let ocr: Double = lineConfidence.flatMap { index < $0.count ? $0[index] : nil } ?? 1
            item.note = "Metinden okundu: \"\(raw.trimmingCharacters(in: .whitespaces))\""
            drafts.append(DraftTariffItem(item: item, score: (strength * ocr * 100).rounded() / 100, sourceLine: raw))
        }
        let errors: [String] = drafts.isEmpty ? ["Metinde tarife kalemi bulunamadı."] : []
        return TariffImportResult(drafts: drafts, errors: errors)
    }

    private static func classify(_ t: String) -> (TariffItemType, String, String, Double)? {
        if t.contains("bahşiş") { return nil }
        if t.contains("garanti") { return (.hourly, "guarantee.hourly", "Saatlik garanti", 0.7) }
        if t.contains("kesinti") { return (.deduction, "deduction", "Kesinti", 0.6) }
        if t.contains("birleşen") || t.contains("ikinci paket") || t.contains("ek paket") {
            return (.combinedPackage, "package.combined", "Birleşen paket", 0.8)
        }
        if t.contains("bonus") || t.contains("prim") && t.contains("paket") && !t.contains("km") {
            if t.contains("hafta sonu") || t.contains("haftalık") { return (.weeklyBonus, "bonus.weekly", "Haftalık bonus", 0.6) }
            if t.contains("aylık") { return (.monthlyBonus, "bonus.monthly", "Aylık bonus", 0.6) }
            return (.dailyBonus, "bonus.daily", "Günlük bonus", 0.6)
        }
        if t.contains("km") { return (.perKm, "km", "Km ücreti", 0.7) }
        if t.contains("saatlik") || t.contains("saat başı") { return (.hourly, "hourly", "Saatlik ücret", 0.8) }
        if t.contains("sabit") || t.contains("aylık ücret") { return (.fixed, "fixed", "Sabit ücret", 0.6) }
        if t.contains("gece") && t.contains("paket") { return (.singlePackage, "package.night", "Gece paket", 0.8) }
        if t.contains("gündüz") && t.contains("paket") { return (.singlePackage, "package.day", "Gündüz paket", 0.8) }
        if t.contains("paket") { return (.singlePackage, "package.single", "Paket ücreti", 0.5) }
        return nil
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// Tarife ekranindaki kalem (1.10): kullanicinin degistirdigi tutarlarla taban surumun kopyasi.
    /// Yalnizca farkli olan kalemler "kullanıcı girdi" olur; tutar araligi tek degere iner. Degisiklik yoksa nil.
    /// Yururluk taban surumle ayni: bu donemin gecmis gunleri de kullanicinin degeriyle hesaplanir.
    static func editedVersion(base: TariffVersion, amounts: [String: Money], today: String, id: String) -> TariffVersion? {
        var drafts: [DraftTariffItem] = []
        for item in base.items where !item.withdrawn {
            guard let amount = amounts[item.key], amount != item.amount || (item.amountUpper != nil && item.amountUpper != amount) else {
                continue
            }
            var copy = item
            copy.amount = amount
            copy.amountUpper = nil
            copy.confidence = .userEntered
            drafts.append(DraftTariffItem(item: copy, score: 1, sourceLine: "Kalem"))
        }
        guard !drafts.isEmpty else { return nil }
        return userVersion(platform: base.platformCode, drafts: drafts, base: base, sourceNote: "Kendi değerlerim",
                           effectiveFrom: base.effectiveFrom, today: today, id: id)
    }

    /// Taslak kalemlerden kullanici tarifesi (taslak durumunda; kaynak zorunlu).
    static func userVersion(platform: String, drafts: [DraftTariffItem], base: TariffVersion?, sourceNote: String,
                            effectiveFrom: String, today: String, id: String) -> TariffVersion {
        var items: [TariffItem] = base?.items.filter { !$0.withdrawn }.map { item in
            var copy = item
            copy.id = "\(id)-\(item.key)"
            copy.versionID = id
            return copy
        } ?? []
        for draft in drafts {
            var item = draft.item
            item.versionID = id
            item.id = "\(id)-\(item.key)"
            if item.confidence == .verified { item.confidence = .userEntered }
            if let index = items.firstIndex(where: { $0.key == item.key }) {
                items[index] = item
            } else {
                items.append(item)
            }
        }
        return TariffVersion(
            id: id, platformCode: platform, workModel: base?.workModel ?? "esnaf", regionID: base?.regionID,
            vehicleType: base?.vehicleType, versionNumber: 1, effectiveFrom: effectiveFrom, createdAt: today,
            sourceType: .userEntered, verificationStatus: .unverified, approvalStatus: .draft,
            changeSummary: "Kullanıcı tarifesi", settings: base?.settings ?? TariffSettings(), items: items, origin: .user,
            sourceNote: sourceNote
        )
    }
}
