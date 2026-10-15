import Foundation
import AppIntents

/// Uygulama, acilista vardiya islevlerini buraya baglar. Eklentide nil kalir
/// (LiveActivityIntent uygulama surecinde calisir; gerekirse iOS uygulamayi arka planda baslatir).
enum ShiftIntentBridge {
    @MainActor static var endShift: (@MainActor () -> Void)?
    /// 1.12.1 kilit ekrani "Bitir": once onay istenir (Canli Etkinlik "Emin misin?" gorunumune gecer).
    @MainActor static var requestEnd: (@MainActor () -> Void)?
    @MainActor static var cancelEnd: (@MainActor () -> Void)?
    /// 1.12: kilit ekrani / widget / Denetim Merkezi "+1 paket". Donus: eklendikten sonraki paket sayisi (vardiya
    /// baslatilamadiysa nil, or. firma secilmemis).
    @MainActor static var addPackage: (@MainActor () -> Int?)?
    @MainActor static var undoPackage: (@MainActor () -> Void)?
    /// Widget "Vardiya": uygulama acilir, canli vardiya ekrani gosterilir (yoksa baslatilir).
    @MainActor static var openShift: (@MainActor () -> Void)?
}

/// Widget'tan vardiya ekranini acar. Uygulama on plana gelir.
struct OpenShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Vardiya ekranını aç"
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ShiftIntentBridge.openShift?()
        return .result()
    }
}

/// Canli Etkinlikteki "Vardiyayi bitir" dugmesi. 1.12.1: hemen bitirmez, onay ister.
struct EndShiftIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Vardiyayı bitir"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        if let request = ShiftIntentBridge.requestEnd {
            request()
        } else {
            ShiftIntentBridge.endShift?()
        }
        return .result()
    }
}

/// "Emin misin?" -> "Evet, bitir": vardiya hesaplanip kaydedilir.
struct ConfirmEndShiftIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Vardiyayı bitir ve hesapla"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ShiftIntentBridge.endShift?()
        return .result()
    }
}

/// "Emin misin?" -> "Vazgeç": vardiya surer.
struct CancelEndShiftIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Vardiyaya devam et"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ShiftIntentBridge.cancelEnd?()
        return .result()
    }
}

/// 1.12: kilit ekranindan, widget'tan ve Denetim Merkezi'nden paket sayma. Uygulama acilmaz; vardiya yoksa baslatir.
struct AddPackageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Paket bıraktım"
    static var description = IntentDescription("Süren vardiyaya bir paket ekler; vardiya yoksa başlatır.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = ShiftIntentBridge.addPackage?()
        return .result()
    }
}

/// Kilit ekranindaki "Geri al": yanlislikla eklenen son paketi siler.
struct UndoPackageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Son paketi geri al"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ShiftIntentBridge.undoPackage?()
        return .result()
    }
}
