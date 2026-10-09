import Foundation

/// Senaryo testleri (spec 1.4a §4): taklit kazanc ekraninin tarifi ve beklenen okuma.
/// Ayni senaryo satir katmaninda (Core) ve goruntu katmaninda (SwiftUI + Vision) kullanilir.
struct ScenarioRow: Equatable {
    var label: String
    var value: String
    /// "54 Teslimat" gibi deger etiketten once.
    var valueFirst: Bool = false
    /// Cesitlemede etiket ve deger ayri satirlara bolunebilir mi?
    var splittable: Bool = true
}

enum ScenarioField: String, CaseIterable, Codable {
    case template, total, bonus, packages, duration, period
}

struct ScenarioExpectation: Equatable, Codable {
    var templateID: String?
    var total: Double
    var bonus: Double?
    var packages: Int?
    var duration: TimeInterval?
    var period: OCRTemplate.Period?

    /// Beklenen (nil olmayan) her alan icin dogru/yanlis.
    func check(_ parsed: ParsedEarning) -> [ScenarioField: Bool] {
        var result: [ScenarioField: Bool] = [:]
        result[.template] = parsed.templateID == templateID
        result[.total] = abs(parsed.totalEarning - total) < 0.01
        if let bonus { result[.bonus] = abs(parsed.bonus - bonus) < 0.01 }
        if let packages { result[.packages] = parsed.packageCount == packages }
        if let duration { result[.duration] = parsed.workDuration.map { abs($0 - duration) < 1 } ?? false }
        if let period { result[.period] = parsed.period == period }
        return result
    }
}

struct ScreenScenario: Equatable, Identifiable {
    enum Theme: String, CaseIterable { case light, dark }
    enum Device: String, CaseIterable {
        case se, standard, proMax
        var points: (width: Double, height: Double) {
            switch self {
            case .se: (375, 667)
            case .standard: (393, 852)
            case .proMax: (430, 932)
            }
        }
    }
    enum TextStyle: String, CaseIterable { case turkish, ascii, upper }

    var id: String
    var templateID: String
    var platformCode: String
    var header: [String]
    var rows: [ScenarioRow]
    var footer: [String]
    var theme: Theme
    var device: Device
    var textStyle: TextStyle
    var splitRows: Bool
    var noise: Bool
    var expected: ScenarioExpectation

    static func == (lhs: ScreenScenario, rhs: ScreenScenario) -> Bool {
        lhs.id == rhs.id && lhs.header == rhs.header && lhs.rows == rhs.rows && lhs.footer == rhs.footer
            && lhs.theme == rhs.theme && lhs.device == rhs.device && lhs.textStyle == rhs.textStyle
            && lhs.splitRows == rhs.splitRows && lhs.noise == rhs.noise && lhs.expected == rhs.expected
    }

    private static let asciiFold: [Character: Character] = [
        "ı": "i", "ğ": "g", "ü": "u", "ş": "s", "ö": "o", "ç": "c",
        "İ": "I", "Ğ": "G", "Ü": "U", "Ş": "S", "Ö": "O", "Ç": "C",
    ]

    func styled(_ text: String) -> String {
        switch textStyle {
        case .turkish: text
        case .ascii: String(text.map { Self.asciiFold[$0] ?? $0 })
        case .upper: text.uppercased(with: Locale(identifier: "tr_TR"))
        }
    }

    static let topNoise = ["9:41", "Menü"]
    static let bottomNoise = ["Ana Sayfa", "Profil"]

    /// Vision'in yukaridan asagi okuma sirasina benzer satirlar.
    func ocrLines() -> [String] {
        var lines: [String] = noise ? Self.topNoise : []
        lines += header.map(styled)
        for row in rows {
            let label = styled(row.label)
            if row.label.isEmpty {
                lines.append(row.value)
            } else if splitRows && row.splittable {
                lines += row.valueFirst ? [row.value, label] : [label, row.value]
            } else {
                lines.append(row.valueFirst ? "\(row.value) \(label)" : "\(label) \(row.value)")
            }
        }
        lines += footer.map(styled)
        if noise { lines += Self.bottomNoise }
        return lines
    }
}
