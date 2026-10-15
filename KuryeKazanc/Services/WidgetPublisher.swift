import Foundation
import WidgetKit

/// 1.12: widget ozetini (WidgetSnapshot) App Group'a yazar ve degistiyse widget'lari yeniler. UI testlerinde kapali.
enum WidgetPublisher {
    @MainActor
    static func publish(_ change: (inout WidgetSnapshot) -> Void) {
        guard !LaunchOptions.current.isUITesting else { return }
        if WidgetSnapshot.update(change) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// "Kadıköy · 1. bölge": once konumdan bilinen yer, sonra tarife bolgesi.
    static func regionText(place: String?, tier: String?) -> String {
        var parts: [String] = []
        if let place, !place.isEmpty { parts.append(place) }
        if let tier, !tier.isEmpty { parts.append(TariffQuestions.regionName(tier)) }
        return parts.joined(separator: " · ")
    }
}
