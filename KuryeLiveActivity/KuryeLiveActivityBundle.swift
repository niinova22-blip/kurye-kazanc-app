import SwiftUI
import WidgetKit

@main
struct KuryeLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        ShiftLiveActivity()
        QuickShiftWidget()
        if #available(iOS 18.0, *) {
            AddPackageControl()
        }
    }
}
