import SwiftUI
import WidgetKit
import AppIntents

/// Uygulamanin marka renkleri (Theme.brandDeep / brandMid / brandBright; eklenti Theme'i derlemez).
enum WidgetBrand {
    static let deep = Color(red: 0x0B / 255, green: 0x2A / 255, blue: 0x6B / 255)
    static let mid = Color(red: 0x1E / 255, green: 0x5B / 255, blue: 0xD8 / 255)
    static let bright = Color(red: 0x2F / 255, green: 0x8C / 255, blue: 0xFF / 255)
    static let glow = Color(red: 0x8C / 255, green: 0xC4 / 255, blue: 0xFF / 255)
    static let mint = Color(red: 0x6E / 255, green: 0xE7 / 255, blue: 0xB7 / 255)
    static let gradient = LinearGradient(colors: [deep, mid, bright], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// 1.12 ana ekran / kilit ekrani widget'i: bugunku paket sayisi, bolge, hedef ilerlemesi; "+1 paket" (uygulama acilmadan
/// sayar, vardiya yoksa baslatir) ve "Vardiya" (canli vardiya ekrani). Veri App Group'taki WidgetSnapshot'tan.
struct QuickShiftWidget: Widget {
    static let kind = "com.kuryekazanc.app.quickShift"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickShiftProvider()) { entry in
            QuickShiftWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBrand.gradient }
        }
        .configurationDisplayName("Paket say")
        .description("Bugünkü paketin ve bölgen; paketi bırakınca dokun, vardiya yoksa başlar.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct QuickShiftEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
}

struct QuickShiftProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickShiftEntry {
        var sample = WidgetSnapshot()
        sample.day = WidgetSnapshot.dayKey(.now)
        sample.savedPackages = 18
        sample.targetPackages = 30
        sample.region = "Kadıköy · 1. bölge"
        sample.firm = "Paket Taxi"
        return QuickShiftEntry(date: .now, snapshot: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickShiftEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : QuickShiftEntry(date: .now, snapshot: .load()))
    }

    /// Uygulama her degisiklikte yeniler; gece yarisi da gun sifirlansin diye bir giris daha.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickShiftEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.load()
        var entries = [QuickShiftEntry(date: now, snapshot: snapshot)]
        if let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) {
            entries.append(QuickShiftEntry(date: midnight, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct QuickShiftWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuickShiftEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var packages: Int { snapshot.packages(now: entry.date) }
    private var regionText: String { snapshot.region.isEmpty ? "Bölge seçilmedi" : snapshot.region }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline:
            Label("\(packages) paket · \(regionText)", systemImage: "shippingbox.fill")
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: - Kilit ekrani

    private var circular: some View {
        Button(intent: AddPackageIntent()) {
            ZStack {
                AccessoryWidgetBackground()
                if snapshot.targetPackages > 0 {
                    Gauge(value: snapshot.fraction(now: entry.date)) { EmptyView() }
                        .gaugeStyle(.accessoryCircularCapacity)
                }
                VStack(spacing: 0) {
                    Text("\(packages)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Image(systemName: "plus").font(.caption2.weight(.bold))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(packages) paket. Dokun: bir paket ekle")
    }

    private var rectangular: some View {
        Button(intent: AddPackageIntent()) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: snapshot.isShiftActive ? "record.circle" : "shippingbox.fill")
                    Text(targetText).font(.headline).monospacedDigit()
                }
                Text(regionText).font(.caption).lineLimit(1)
                Text("Dokun: +1 paket").font(.caption2).opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ana ekran

    private var targetText: String {
        snapshot.targetPackages > 0 ? "\(packages) / \(snapshot.targetPackages) paket" : "\(packages) paket"
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: snapshot.isShiftActive ? "dot.radiowaves.left.and.right" : "mappin.and.ellipse")
                .font(.caption2.weight(.bold))
                .foregroundStyle(snapshot.isShiftActive ? WidgetBrand.mint : WidgetBrand.glow)
            Text(snapshot.isShiftActive ? "Vardiya sürüyor" : regionText)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var countBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(packages)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(snapshot.targetPackages > 0 ? "/ \(snapshot.targetPackages) paket bugün" : "paket bugün")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            if snapshot.targetPackages > 0 {
                ProgressView(value: snapshot.fraction(now: entry.date))
                    .tint(WidgetBrand.mint)
                    .padding(.top, 2)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            countBlock
            Spacer(minLength: 0)
            addButton(compact: true)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer(minLength: 0)
                countBlock
                if snapshot.isShiftActive {
                    Text(regionText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            VStack(spacing: 8) {
                addButton(compact: false)
                Button(intent: OpenShiftIntent()) {
                    Label("Vardiya", systemImage: "hand.tap.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 128)
        }
    }

    private func addButton(compact: Bool) -> some View {
        Button(intent: AddPackageIntent()) {
            Label(compact ? "+1 paket" : "Paket bıraktım", systemImage: "plus")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: compact ? 30 : nil, maxHeight: compact ? 30 : CGFloat.infinity)
                .foregroundStyle(WidgetBrand.deep)
                .background(.white, in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
