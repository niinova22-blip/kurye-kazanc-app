import Foundation

/// Grup x alan dogruluk sayimi (spec 1.4a §4.3). Yuzde, bir ondalik.
struct ScenarioTally {
    private var counts: [String: (ok: Int, total: Int)] = [:]

    mutating func add(platform: String, results: [ScenarioField: Bool]) {
        for (field, ok) in results {
            let key = "\(platform)/\(field.rawValue)"
            var entry = counts[key] ?? (0, 0)
            entry.total += 1
            if ok { entry.ok += 1 }
            counts[key] = entry
        }
    }

    func accuracy() -> [String: Double] {
        counts.mapValues { ($0.total == 0 ? 0 : Double($0.ok) / Double($0.total) * 1000).rounded() / 10 }
    }

    /// Tabandan `tolerance` puandan fazla dusen hucreler ("anahtar: taban -> simdi").
    func drops(from baseline: [String: Double], tolerance: Double) -> [String] {
        let now = accuracy()
        return baseline.keys.sorted().compactMap { key in
            guard let base = baseline[key], let current = now[key], base - current > tolerance else { return nil }
            return "\(key): \(String(format: "%.1f", base)) -> \(String(format: "%.1f", current))"
        }
    }

    /// Satirlar grup (sablon kimligi ya da klasor adi), sutunlar alan.
    func markdown(title: String) -> String {
        let acc = accuracy()
        let platforms = Set(acc.keys.map { String($0.split(separator: "/")[0]) }).sorted()
        let fields = ScenarioField.allCases.map(\.rawValue)
        var lines = ["### \(title)", "", "| grup | " + fields.joined(separator: " | ") + " |",
                     "|---|" + fields.map { _ in "---" }.joined(separator: "|") + "|"]
        for platform in platforms {
            let cells = fields.map { field in acc["\(platform)/\(field)"].map { String(format: "%.1f", $0) } ?? "–" }
            lines.append("| \(platform) | " + cells.joined(separator: " | ") + " |")
        }
        return lines.joined(separator: "\n")
    }

    func baselineJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(accuracy())).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
