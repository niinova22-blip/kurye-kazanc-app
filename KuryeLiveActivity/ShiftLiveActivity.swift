import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

/// Kilit ekrani + Dynamic Island. Sure `Text(timerInterval:)` ile kendiliginden akar.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            ShiftLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                        .font(.title3.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Formatters.distance(context.state.distanceKm))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ShiftDetailRow(state: context.state)
                }
            } compactLeading: {
                ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                    .frame(maxWidth: 52)
            } compactTrailing: {
                Text(Formatters.distance(context.state.distanceKm))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "scooter")
            }
        }
    }
}

private struct ShiftTimerText: View {
    let start: Date
    let endedAt: Date?

    var body: some View {
        if let endedAt {
            Text(Formatters.duration(endedAt.timeIntervalSince(start)))
                .monospacedDigit()
        } else {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
                .monospacedDigit()
        }
    }
}

private struct ShiftDetailRow: View {
    let state: ShiftActivityAttributes.ContentState

    private var detail: String {
        var parts: [String] = ["Bugün net \(Formatters.currency(state.todayNet))"]
        if let perHour = state.netPerHour {
            parts.append("~\(Formatters.currency(perHour.rounded()))/saat")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            Text(verbatim: detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if state.endedAt == nil {
                Button(intent: EndShiftIntent()) {
                    Text("Vardiyayı bitir")
                }
                .tint(.red)
            }
        }
    }
}

private struct ShiftLockScreenView: View {
    let attributes: ShiftActivityAttributes
    let state: ShiftActivityAttributes.ContentState

    private var title: String {
        if state.endedAt != nil { return "Vardiya bitti" }
        return attributes.isAuto ? "Vardiya · otomatik" : "Vardiya"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            HStack(alignment: .firstTextBaseline) {
                ShiftTimerText(start: attributes.start, endedAt: state.endedAt)
                    .font(.system(.title, design: .rounded).weight(.bold))
                Spacer()
                Text(Formatters.distance(state.distanceKm))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            ShiftDetailRow(state: state)
        }
        .padding(16)
    }
}
