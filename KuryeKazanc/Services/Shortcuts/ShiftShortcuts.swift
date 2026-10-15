import AppIntents
import Foundation

/// 1.10 Kisayollar / Siri: ekran goruntusu gonderme yerine vardiya eylemleri.
/// "Kurye Kazanç'ta vardiya başlat" uygulamayi acar ve vardiyayi baslatir; "Paket bıraktım" uygulamayi acmadan sayar.
struct StartShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Vardiya başlat"
    static var description = IntentDescription("Kurye Kazanç'ta canlı vardiyayı başlatır.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let liveShift: LiveShiftController = AppEnvironment.shared.liveShift
        if liveShift.isActive {
            return .result(dialog: "Vardiyan zaten sürüyor · \(liveShift.packageCount) paket.")
        }
        liveShift.start()
        guard liveShift.isActive else {
            return .result(dialog: "Önce uygulamada firmanı seç.")
        }
        return .result(dialog: "Vardiya başladı. Her paketi bırakınca dokun.")
    }
}

struct RecordDeliveryIntent: AppIntent {
    static var title: LocalizedStringResource = "Paket bıraktım"
    static var description = IntentDescription("Süren vardiyaya bir paket ekler; vardiya yoksa başlatır.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let liveShift: LiveShiftController = AppEnvironment.shared.liveShift
        guard let count = liveShift.addPackageFromOutside() else {
            return .result(dialog: "Önce uygulamada firmanı seç.")
        }
        return .result(dialog: "\(count). paket eklendi.")
    }
}

struct KuryeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartShiftIntent(),
            phrases: ["\(.applicationName) vardiya başlat", "\(.applicationName) ile vardiyaya başla"],
            shortTitle: "Vardiya başlat",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: RecordDeliveryIntent(),
            phrases: ["\(.applicationName) paket bıraktım", "\(.applicationName) paket ekle"],
            shortTitle: "Paket bıraktım",
            systemImageName: "shippingbox"
        )
    }
}
