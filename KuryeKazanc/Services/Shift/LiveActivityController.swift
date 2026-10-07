import Foundation
import ActivityKit

@MainActor
protocol LiveActivityControlling {
    func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState)
    func update(_ state: ShiftActivityAttributes.ContentState)
    func finish(_ state: ShiftActivityAttributes.ContentState)
}

/// ActivityKit: vardiya basinda acar, guncellemeleri iletir, bitince 5 dk ozetle kapatir.
/// Kullanici Canli Etkinlikleri kapattiysa sessizce hicbir sey yapmaz.
@MainActor
final class LiveActivityController: LiveActivityControlling {
    private var activity: Activity<ShiftActivityAttributes>?

    init() {
        // Uygulama yeniden acildiginda suren etkinligi sahiplen
        activity = Activity<ShiftActivityAttributes>.activities.first
    }

    func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity != nil {
            update(state)
            return
        }
        let attributes = ShiftActivityAttributes(start: start, isAuto: isAuto)
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
    }

    func update(_ state: ShiftActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func finish(_ state: ShiftActivityAttributes.ContentState) {
        guard let activity else { return }
        self.activity = nil
        let dismissal = Date().addingTimeInterval(300)
        Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(dismissal)) }
    }
}
