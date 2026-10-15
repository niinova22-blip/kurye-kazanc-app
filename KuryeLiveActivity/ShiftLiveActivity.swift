import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

/// Kilit ekrani + Dynamic Island. Sure `Text(timerInterval:)` ile kendiliginden akar.
/// 1.12: paket sayilan vardiyada "+1 paket" ve "Geri al" dugmeleri: uygulamayi acmadan sayilir.
struct ShiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShiftActivityAttributes.self) { context in
            ShiftLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(WidgetBrand.deep)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let packages = context.state.packages {
                        Label("\(packages) paket", systemImage: "shippingbox.fill")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    } else {
                        ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                            .font(.title3.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.packages != nil {
                        ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                            .font(.title3.weight(.semibold))
                    } else {
                        Text(Formatters.distance(context.state.distanceKm))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.packages != nil, context.state.endedAt == nil {
                        PackageButtons(state: context.state)
                    } else {
                        ShiftDetailRow(state: context.state)
                    }
                }
            } compactLeading: {
                if let packages = context.state.packages {
                    Label("\(packages)", systemImage: "shippingbox.fill")
                        .monospacedDigit()
                } else {
                    ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                        .frame(maxWidth: 52)
                }
            } compactTrailing: {
                if context.state.packages != nil {
                    ShiftTimerText(start: context.attributes.start, endedAt: context.state.endedAt)
                        .frame(maxWidth: 52)
                } else {
                    Text(Formatters.distance(context.state.distanceKm))
                        .monospacedDigit()
                }
            } minimal: {
                if let packages = context.state.packages {
                    Text("\(packages)").monospacedDigit()
                } else {
                    Image(systemName: "scooter")
                }
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
        if let perHour = state.netPerHour, perHour.isFinite {
            parts.append("~\(Formatters.currency(perHour.rounded()))/saat")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        if state.confirmingEnd == true {
            ConfirmEndRow()
        } else {
            row
        }
    }

    private var row: some View {
        HStack {
            Text(verbatim: detail)
                .font(.subheadline)
                .opacity(0.8)
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

/// 1.12.1: "Bitir"e basilinca: hesaplanip kaydedilecegi soylenir, "Evet, bitir" / "Vazgeç".
private struct ConfirmEndRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vardiya bitirilip hesaplanacak ve kaydedilecek. Emin misin?")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(intent: CancelEndShiftIntent()) {
                    Text("Vazgeç").frame(maxWidth: .infinity, minHeight: 34)
                }
                .tint(.gray)
                Button(intent: ConfirmEndShiftIntent()) {
                    Text("Evet, bitir").bold().frame(maxWidth: .infinity, minHeight: 34)
                }
                .tint(.red)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// "+1 paket" (buyuk), "Geri al" ve "Bitir": kilit ekraninda tek elle.
private struct PackageButtons: View {
    let state: ShiftActivityAttributes.ContentState

    var body: some View {
        if state.confirmingEnd == true {
            ConfirmEndRow()
        } else {
            buttons
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(intent: UndoPackageIntent()) {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 36, height: 36)
            }
            .tint(.gray)
            .disabled((state.packages ?? 0) == 0)
            .accessibilityLabel("Son paketi geri al")
            Button(intent: AddPackageIntent()) {
                Label("Paket bıraktım", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .tint(WidgetBrand.bright)
            Button(intent: EndShiftIntent()) {
                Text("Bitir")
                    .frame(minHeight: 36)
            }
            .tint(.red)
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct ShiftLockScreenView: View {
    let attributes: ShiftActivityAttributes
    let state: ShiftActivityAttributes.ContentState

    private var title: String {
        if state.endedAt != nil { return "Vardiya bitti" }
        if let packages = state.packages { return "Vardiya · \(packages) paket" }
        return attributes.isAuto ? "Vardiya · otomatik" : "Vardiya · elle"
    }

    private var subtitle: String {
        var parts: [String] = []
        if let region = state.region, !region.isEmpty { parts.append(region) }
        if let gross = state.shiftGross, gross > 0, gross.isFinite {
            parts.append("~\(Formatters.currency(gross.rounded())) brüt")
        }
        parts.append(Formatters.distance(state.distanceKm))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: title)
                    .font(.headline)
                    .foregroundStyle(WidgetBrand.glow)
                    .monospacedDigit()
                Spacer()
                ShiftTimerText(start: attributes.start, endedAt: state.endedAt)
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
            if state.packages != nil {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .monospacedDigit()
                if state.endedAt == nil {
                    PackageButtons(state: state)
                }
            } else {
                HStack {
                    Spacer()
                    Text(Formatters.distance(state.distanceKm))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                ShiftDetailRow(state: state)
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}
