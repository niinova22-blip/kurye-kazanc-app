import Foundation

/// Tarama sirasinda kabul edilen bir ekranin okunmus hali.
struct ScanInput {
    var parsed: ParsedEarning
    var lines: [RecognizedLine]
    var capturedAt: Date
}

/// Onay ekraninda gosterilen tek kalem.
struct ScanItem: Identifiable, Equatable {
    enum Kind: Equatable { case daily, weekly, orderGroup(count: Int), unknown }
    var id: String
    var kind: Kind
    var parsed: ParsedEarning
    var lines: [RecognizedLine]
    var capturedAt: Date
    var textHash: String
}

/// Kabul edilen kareleri kalemlere cevirir: ayni anahtar bir kez, siparis kartlari gun+platform bazinda tek kalem.
struct ScanResultBuilder {
    var calendar: Calendar

    func build(_ inputs: [ScanInput]) -> [ScanItem] {
        var seen = Set<CaptureKey>()
        var singles: [ScanItem] = []
        var groupOrder: [String] = []
        var groups: [String: [ScanInput]] = [:]

        for input in inputs {
            guard let key = CaptureKey(parsed: input.parsed, calendar: calendar),
                  seen.insert(key).inserted else { continue }
            if input.parsed.period == .order {
                let platform = input.parsed.platformCode ?? key.templateID
                let id = "orders-\(platform)-\(Int(key.day.timeIntervalSince1970))"
                if groups[id] == nil { groupOrder.append(id) }
                groups[id, default: []].append(input)
            } else {
                let id = "\(key.templateID)-\(Int(key.day.timeIntervalSince1970))-\(key.totalCents)-\(key.period.rawValue)"
                singles.append(ScanItem(id: id, kind: kind(for: input.parsed.period), parsed: input.parsed,
                                        lines: input.lines, capturedAt: input.capturedAt,
                                        textHash: TextHash.of(input.lines.map(\.text))))
            }
        }

        let merged = groupOrder.compactMap { id in groups[id].map { merge(id: id, cards: $0) } }
        return (singles + merged).enumerated()
            .sorted { ($0.element.capturedAt, $0.offset) < ($1.element.capturedAt, $1.offset) }
            .map(\.element)
    }

    private func kind(for period: OCRTemplate.Period) -> ScanItem.Kind {
        switch period {
        case .day: return .daily
        case .week: return .weekly
        case .order: return .unknown // siparis kartlari merge() ile gruplanir
        case .unknown: return .unknown
        }
    }

    private func merge(id: String, cards: [ScanInput]) -> ScanItem {
        var parsed = cards[0].parsed
        parsed.totalEarning = cards.reduce(0) { $0 + $1.parsed.totalEarning }
        parsed.bonus = cards.reduce(0) { $0 + $1.parsed.bonus }
        parsed.packageCount = cards.count
        parsed.fieldsToReview = cards.reduce(into: Set<ParsedEarning.Field>()) { $0.formUnion($1.parsed.fieldsToReview) }
        parsed.period = .order
        let lines = cards.flatMap(\.lines)
        return ScanItem(id: id, kind: .orderGroup(count: cards.count), parsed: parsed, lines: lines,
                        capturedAt: cards.map(\.capturedAt).max() ?? cards[0].capturedAt,
                        textHash: TextHash.of(lines.map(\.text)))
    }
}
