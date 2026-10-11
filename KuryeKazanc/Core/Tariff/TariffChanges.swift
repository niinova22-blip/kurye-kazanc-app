import Foundation

/// Bir kalemin eski / yeni degeri.
struct TariffItemChange: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case changed, added, removed
    }

    var kind: Kind
    var itemKey: String
    var label: String
    var oldAmount: Money?
    var newAmount: Money?
    var oldUpper: Money? = nil
    var newUpper: Money? = nil
    var oldLower: Decimal? = nil
    var newLower: Decimal? = nil

    var id: String { itemKey }

    enum CodingKeys: String, CodingKey {
        case kind, label
        case itemKey = "item_key"
        case oldAmount = "old_amount"
        case newAmount = "new_amount"
        case oldUpper = "old_amount_upper"
        case newUpper = "new_amount_upper"
        case oldLower = "old_lower_threshold"
        case newLower = "new_lower_threshold"
    }

    var absolute: Money? {
        guard let oldAmount, let newAmount else { return nil }
        return newAmount - oldAmount
    }

    var percent: Decimal? {
        guard let oldAmount, let newAmount else { return nil }
        return Money.percentChange(from: oldAmount, to: newAmount)
    }

    /// "Paket başı ücret: 38,00 → 40,00 TL (+%5,26)".
    var summary: String {
        switch kind {
        case .added: return "\(label): yeni kalem \(newAmount?.description ?? "-") TL"
        case .removed: return "\(label): kaldırıldı (önceki \(oldAmount?.description ?? "-") TL)"
        case .changed:
            var text: String = "\(label): \(oldAmount?.description ?? "-") → \(newAmount?.description ?? "-") TL"
            if let percent {
                let sign: String = percent > 0 ? "+" : ""
                text += " (\(sign)%\(percent))"
            }
            if oldLower != newLower {
                text += "; eşik \(oldLower.map { "\($0)" } ?? "-") → \(newLower.map { "\($0)" } ?? "-")"
            }
            return text
        }
    }
}

/// Yapilandirilmis kalem karsilastirmasi: yalnizca ucreti etkileyen alanlar (tutar, aralik, esik, kosul).
/// Etiket / not / tasarim degisikligi tarife degisikligi sayilmaz.
enum TariffDiff {
    static func changes(old: [TariffItem], new: [TariffItem]) -> [TariffItemChange] {
        var oldByKey: [String: TariffItem] = [:]
        for item in old where !item.withdrawn { oldByKey[item.key] = item }
        var newByKey: [String: TariffItem] = [:]
        for item in new where !item.withdrawn { newByKey[item.key] = item }
        var result: [TariffItemChange] = []
        for key in Set(oldByKey.keys).union(newByKey.keys).sorted() {
            switch (oldByKey[key], newByKey[key]) {
            case let (o?, n?):
                let financial: Bool = o.amount != n.amount || o.amountUpper != n.amountUpper
                    || o.lowerThreshold != n.lowerThreshold || o.upperThreshold != n.upperThreshold
                    || o.conditions != n.conditions || o.method != n.method || o.isCash != n.isCash
                guard financial else { continue }
                result.append(TariffItemChange(kind: .changed, itemKey: key, label: n.label, oldAmount: o.amount,
                                               newAmount: n.amount, oldUpper: o.amountUpper, newUpper: n.amountUpper,
                                               oldLower: o.lowerThreshold, newLower: n.lowerThreshold))
            case let (nil, n?):
                result.append(TariffItemChange(kind: .added, itemKey: key, label: n.label, oldAmount: nil, newAmount: n.amount,
                                               newUpper: n.amountUpper, newLower: n.lowerThreshold))
            case let (o?, nil):
                result.append(TariffItemChange(kind: .removed, itemKey: key, label: o.label, oldAmount: o.amount, newAmount: nil,
                                               oldUpper: o.amountUpper, oldLower: o.lowerThreshold))
            case (nil, nil):
                continue
            }
        }
        return result
    }
}

/// Sunucunun yayimladigi tarife olayi (`tariff_change_events`, herkese acik okunur).
struct TariffChangeEvent: Codable, Equatable, Identifiable {
    var id: String
    var platformCode: String
    var tariffVersionID: String
    /// "published", "withdrawn".
    var kind: String
    var effectiveFrom: String?
    /// "verified" / "needs_verification".
    var verification: String
    var sourceType: String?
    var sourceURL: String?
    var changes: [TariffItemChange]
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "event_id"
        case platformCode = "platform_id"
        case tariffVersionID = "tariff_version_id"
        case kind, verification, changes
        case effectiveFrom = "effective_from"
        case sourceType = "source_type"
        case sourceURL = "source_url"
        case createdAt = "created_at"
    }

    init(id: String, platformCode: String, tariffVersionID: String, kind: String, effectiveFrom: String?, verification: String,
         sourceType: String?, sourceURL: String?, changes: [TariffItemChange], createdAt: String) {
        self.id = id
        self.platformCode = platformCode
        self.tariffVersionID = tariffVersionID
        self.kind = kind
        self.effectiveFrom = effectiveFrom
        self.verification = verification
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.changes = changes
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawID: String
        if let text = try? c.decode(String.self, forKey: .id) {
            rawID = text
        } else {
            rawID = String(try c.decode(Int.self, forKey: .id))
        }
        id = rawID
        platformCode = try c.decode(String.self, forKey: .platformCode)
        tariffVersionID = try c.decode(String.self, forKey: .tariffVersionID)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "published"
        effectiveFrom = try c.decodeIfPresent(String.self, forKey: .effectiveFrom).map { String($0.prefix(10)) }
        verification = try c.decodeIfPresent(String.self, forKey: .verification) ?? "needs_verification"
        sourceType = try c.decodeIfPresent(String.self, forKey: .sourceType)
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL)
        changes = (try? c.decodeIfPresent([TariffItemChange].self, forKey: .changes)) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

/// Tarife olaylarindan uygulama ici bildirim. Kullanici yalnizca kendi (aktif) platformunun bildirimlerini alir;
/// dogrulanmamis degisiklik icin kesin zam dili kullanilmaz.
enum TariffNotifier {
    static func notices(from events: [TariffChangeEvent], activePlatform: String?, seen: Set<String>, now: Date) -> [TariffNotice] {
        guard let activePlatform else { return [] }
        return events
            .filter { $0.platformCode == activePlatform && !seen.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
            .map { event in
                let text = message(for: event)
                return TariffNotice(id: event.id, platformCode: event.platformCode, title: text.title, body: text.body,
                                    effectiveFrom: event.effectiveFrom, isVerified: event.verification == "verified", createdAt: now)
            }
    }

    static func message(for event: TariffChangeEvent) -> (title: String, body: String) {
        let name: String = PayPlatform.named(event.platformCode)?.name ?? event.platformCode
        let verified: Bool = event.verification == "verified"
        let date: String = event.effectiveFrom.map { longDate($0) } ?? "tarihi belirsiz"
        let changes: String = event.changes.map(\.summary).joined(separator: "\n")
        var source: String = ""
        if let type = event.sourceType {
            source = "\nKaynak: \(TariffSourceType(rawValue: type)?.displayName ?? type)"
        }
        let status: String = verified ? "Doğrulama: doğrulanmış kaynak" : "Doğrulama: doğrulama bekliyor"
        if event.kind == "withdrawn" {
            return ("\(name): tarife değişikliği geri çekildi",
                    "Daha önce bildirilen değişiklik geri çekildi; önceki tarife geçerli.\n\(changes)\(source)")
        }
        if verified {
            return ("\(name) için yeni tarife sürümü yayımlandı",
                    "\(date) itibarıyla yürürlüğe giriyor.\n\(changes)\(source)\n\(status)")
        }
        return ("\(name): tarife değişikliği (doğrulama bekliyor)",
                "Olası değişiklik \(date) için bildirildi; kesinleşmedi.\n\(changes)\(source)\n\(status)")
    }

    private static let months: [String] = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos",
                                            "Eylül", "Ekim", "Kasım", "Aralık"]

    /// "2026-11-01" -> "1 Kasım 2026".
    static func longDate(_ day: String) -> String {
        let parts: [Int] = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]) else { return day }
        return "\(parts[2]) \(months[parts[1] - 1]) \(parts[0])"
    }
}
