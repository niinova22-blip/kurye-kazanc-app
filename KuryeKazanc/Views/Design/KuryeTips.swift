import SwiftUI
import TipKit

/// Fikir balonlari (TipKit): ozelliklerin yerini bir kez gosterir; dokununca ya da kapatilinca bir daha cikmaz.
/// UI testlerinde gizlenir (bkz. `KuryeTips.configure`).
enum KuryeTips {
    static func configure(isUITesting: Bool) {
        if isUITesting { Tips.hideAllTipsForTesting() }
        try? Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])
    }
}

/// Bugun > hedef halkasinin altindaki "Plan oluştur".
struct PlanTip: Tip {
    var title: Text { Text("Hedefini planla") }
    var message: Text? { Text("Aylık hedefine göre günde kaç paket ve kaç saat gerektiğini buradan hesapla; istediğin zaman değiştir.") }
    var image: Image? { Image(systemName: "target") }
}

/// Bugun > "Elle hesapla".
struct ManualCalcTip: Tip {
    var title: Text { Text("Vardiyayı başlatmayı mı unuttun?") }
    var message: Text? { Text("Paket, km ve saati gir; hakedişini firmanın tarifesiyle hesapla. Bugüne eklemek isteyip istemediğini sonra sorarız.") }
    var image: Image? { Image(systemName: "square.and.pencil") }
}

/// Tarife ekranindaki kalem dugmesi.
struct TariffEditTip: Tip {
    var title: Text { Text("Değerler farklı mı?") }
    var message: Text? { Text("Kalemle tarifedeki tutarları kendi sözleşmene göre değiştir; istediğinde firma değerlerine dönersin.") }
    var image: Image? { Image(systemName: "pencil") }
}

/// Bugun > "Vardiya başlat".
struct ShiftTip: Tip {
    var title: Text { Text("Her paketi tek dokunuşla say") }
    var message: Text? { Text("Vardiyayı başlat, paketi bırakınca ekrana dokun. Saat, km ve ücret kendiliğinden hesaplanır.") }
    var image: Image? { Image(systemName: "hand.tap") }
}
