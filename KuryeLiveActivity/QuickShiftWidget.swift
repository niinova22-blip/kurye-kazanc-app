import SwiftUI
import WidgetKit
import AppIntents

/// 1.12 ana ekran / kilit ekrani widget'i: "Paket bıraktım" (uygulama acilmadan sayar, vardiya yoksa baslatir) ve
/// "Vardiya" (canli vardiya ekranini acar). Veri gostermez: canli sayi ve kazanc Canli Etkinlikte.
struct QuickShiftWidget: Widget {
    static let kind = "com.kuryekazanc.app.quickShift"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickShiftProvider()) { _ in
            QuickShiftWidgetView()
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Paket say")
        .description("Paketi bırakınca dokun; vardiya yoksa başlar. Uygulamayı açmana gerek yok.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct QuickShiftEntry: TimelineEntry {
    var date: Date
}

struct QuickShiftProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickShiftEntry { QuickShiftEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (QuickShiftEntry) -> Void) {
        completion(QuickShiftEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickShiftEntry>) -> Void) {
        completion(Timeline(entries: [QuickShiftEntry(date: .now)], policy: .never))
    }
}

private struct QuickShiftWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: AddPackageIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "shippingbox.fill")
                        .font(.title3)
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .offset(x: 12, y: 12)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paket bıraktım")
        case .accessoryRectangular:
            Button(intent: AddPackageIntent()) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Paket bıraktım", systemImage: "shippingbox.fill")
                        .font(.headline)
                    Text("Dokun: +1 paket")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        case .systemMedium:
            HStack(spacing: 12) {
                addButton
                Button(intent: OpenShiftIntent()) {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill").font(.title2)
                        Text("Vardiya").font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tint(.indigo)
                .buttonStyle(.borderedProminent)
            }
        default:
            addButton
        }
    }

    private var addButton: some View {
        Button(intent: AddPackageIntent()) {
            VStack(spacing: 6) {
                Image(systemName: "shippingbox.fill").font(.title)
                Text("+1 paket").font(.headline)
                Text("Kurye Kazanç").font(.caption2).opacity(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(.blue)
        .buttonStyle(.borderedProminent)
    }
}

/// iOS 18: Denetim Merkezi ve kilit ekrani alt kosesine eklenebilen "Paket bıraktım" kontrolu.
@available(iOS 18.0, *)
struct AddPackageControl: ControlWidget {
    static let kind = "com.kuryekazanc.app.addPackageControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddPackageIntent()) {
                Label("Paket bıraktım", systemImage: "shippingbox.fill")
            }
        }
        .displayName("Paket bıraktım")
        .description("Süren vardiyaya bir paket ekler; vardiya yoksa başlatır.")
    }
}
