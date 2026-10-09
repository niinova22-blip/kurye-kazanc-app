import Foundation

/// Gomulu ve sunucudan gelen sablonlari birlestirir (spec 4.4). Ayni id icin yuksek surum kazanir.
enum TemplateMerger {
    static func merge(bundled: [OCRTemplate], remote: [OCRTemplate]) -> [OCRTemplate] {
        var best: [String: OCRTemplate] = [:]
        for template in remote {
            if let existing = best[template.id], existing.version >= template.version { continue }
            best[template.id] = template
        }
        var result: [OCRTemplate] = []
        var used: Set<String> = []
        for template in bundled {
            if let candidate = best[template.id], candidate.version > template.version {
                result.append(candidate)
            } else {
                result.append(template)
            }
            used.insert(template.id)
        }
        for template in remote where !used.contains(template.id) {
            if let chosen = best[template.id], chosen == template {
                result.append(template)
                used.insert(template.id)
            }
        }
        return result
    }
}
