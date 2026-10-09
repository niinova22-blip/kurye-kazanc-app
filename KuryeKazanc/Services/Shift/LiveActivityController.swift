import Foundation
import ActivityKit

@MainActor
protocol LiveActivityControlling {
    func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState)
    func update(_ state: ShiftActivityAttributes.ContentState)
    func finish(_ state: ShiftActivityAttributes.ContentState)
    /// Iptal edilen veya kisa sayilip atilan vardiya: ozet gostermeden hemen kapatir.
    func dismiss()
}

/// ActivityKit: vardiya basinda acar, guncellemeleri iletir, bitince 5 dk ozetle kapatir.
/// Kullanici Canli Etkinlikleri kapattiysa sessizce hicbir sey yapmaz.
@MainActor
final class LiveActivityController: LiveActivityControlling {
    private var activity: Activity<ShiftActivityAttributes>?

    init() {
        // Uygulama yeniden acildiginda yalnizca suren (aktif) etkinligi sahiplen; bitmis olanlar ekranda kalabilir
        activity = Activity<ShiftActivityAttributes>.activities.first { $0.activityState == .active }
    }

    func begin(start: Date, isAuto: Bool, state: ShiftActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let old = activity {
            if old.activityState == .active, old.attributes.start == start, old.attributes.isAuto == isAuto {
                update(state)
                return
            }
            // Bitmis ya da baska vardiyaya ait etkinligi hemen kapat, yenisini ac
            activity = nil
            Task { await old.end(nil, dismissalPolicy: .immediate) }
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

    func dismiss() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
