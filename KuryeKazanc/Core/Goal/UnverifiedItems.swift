import Foundation

/// Sayfa altindaki tek "dogrulanmadi" notunun kalemleri.
struct UnverifiedItem: Hashable, Identifiable {
    var label: String
    var detail: String
    var id: String { detail + "|" + label }
}

enum UnverifiedItems {
    static func from(_ breakdown: PayBreakdown, platformName: String, includeSide: Bool = true) -> [UnverifiedItem] {
        var lines: [PayLine] = breakdown.lines.filter(\.included)
        if includeSide { lines += breakdown.sideBenefits }
        var result: [UnverifiedItem] = lines.filter { !$0.confidence.isTrusted }.map {
            UnverifiedItem(label: $0.label, detail: "\(platformName) · tarife \(breakdown.tariffVersionLabel)")
        }
        if breakdown.tariffVerification != .verified, result.isEmpty {
            result.append(UnverifiedItem(label: "Tarife sürümü \(breakdown.tariffVersionLabel)",
                                         detail: "\(platformName) · \(breakdown.tariffVerification.displayName)"))
        }
        return merge([result])
    }

    static func from(version: TariffVersion, platformName: String) -> [UnverifiedItem] {
        let items: [UnverifiedItem] = version.items.filter { !$0.withdrawn && !$0.confidence.isTrusted }.map {
            UnverifiedItem(label: $0.label, detail: "\(platformName) · tarife \(version.label)")
        }
        return merge([items])
    }

    /// Sirayi koruyarak tekrarlari atar.
    static func merge(_ lists: [[UnverifiedItem]]) -> [UnverifiedItem] {
        var seen: Set<UnverifiedItem> = []
        var result: [UnverifiedItem] = []
        for item in lists.flatMap({ $0 }) where seen.insert(item).inserted { result.append(item) }
        return result
    }
}
