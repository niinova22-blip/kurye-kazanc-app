import Foundation

// 1.14 Kurye Kazanc Pro: uygulamanin tamami Pro'dur. Ilk 7 gun ucretsiz deneme (App Store'da 0 TL'lik tuketilmeyen
// "deneme" urunu, Apple kurali 3.1.1); deneme bitince Pro'ya gecmeden uygulama acilmaz. Urunler App Store Connect'te
// tanimlanir (kodda fiyat yok, StoreKit'in gosterdigi fiyat kullanilir).

/// App Store urunleri. Abonelikler ayni grupta ("Kurye Kazanç Pro"); omur boyu tuketilmeyen tek seferlik urun.
enum ProProduct: String, CaseIterable, Codable {
    case monthly = "com.kuryekazanc.app.pro.monthly"
    case yearly = "com.kuryekazanc.app.pro.yearly"
    case lifetime = "com.kuryekazanc.app.pro.lifetime"

    var id: String { rawValue }

    var isSubscription: Bool { self != .lifetime }

    /// Satin alma ekranindaki sira: yillik one cikar.
    static let displayOrder: [ProProduct] = [.yearly, .monthly, .lifetime]

    var title: String {
        switch self {
        case .monthly: "Aylık"
        case .yearly: "Yıllık"
        case .lifetime: "Ömür boyu"
        }
    }

    var periodText: String {
        switch self {
        case .monthly: "/ ay"
        case .yearly: "/ yıl"
        case .lifetime: "tek sefer"
        }
    }
}

/// StoreKit islemlerinin hak icin gereken ozeti (StoreKit'ten bagimsiz; Windows'ta test edilir).
struct ProTransactionInfo: Equatable {
    var productID: String
    var expirationDate: Date?
    var revocationDate: Date?
    var purchaseDate: Date? = nil
}

/// 7 gunluk ucretsiz deneme: Apple hesabina bagli 0 TL'lik urun. Baslangic islemin satin alma tarihidir; uygulamayi
/// silip yuklemek, misafir kalmak ya da baska telefona gecmek denemeyi yenilemez.
enum ProTrial {
    static let productID = "com.kuryekazanc.app.pro.trial7"
    static let days = 7

    /// Deneme islemlerinden en erken baslangic (iade edilse de deneme kullanilmis sayilir).
    static func startDate(in transactions: [ProTransactionInfo]) -> Date? {
        transactions.filter { $0.productID == productID }.compactMap(\.purchaseDate).min()
    }

    static func endDate(start: Date) -> Date {
        start.addingTimeInterval(TimeInterval(days) * 86_400)
    }
}

/// Uygulamaya erisim: Pro (ucretli), deneme suruyor, deneme hic baslamadi ya da deneme bitti (kapi).
enum ProAccess: Equatable {
    case pro
    case trial(endsAt: Date)
    case trialAvailable
    case expired

    static func resolve(entitlement: ProEntitlement, trialStart: Date?, now: Date = Date()) -> ProAccess {
        if entitlement.isActive(now: now) { return .pro }
        guard let trialStart else { return .trialAvailable }
        let end: Date = ProTrial.endDate(start: trialStart)
        return end > now ? .trial(endsAt: end) : .expired
    }

    /// Uygulama acik mi (Pro ya da deneme).
    var hasAccess: Bool {
        switch self {
        case .pro, .trial: true
        case .trialAvailable, .expired: false
        }
    }

    /// Denemede kalan gun (son gun 1 gorunur); deneme yoksa nil.
    func trialDaysLeft(now: Date = Date()) -> Int? {
        guard case .trial(let end) = self else { return nil }
        return max(1, Int((end.timeIntervalSince(now) / 86_400).rounded(.up)))
    }
}

/// Kullanicinin Pro durumu. Cihazda saklanir: StoreKit cevap vermeden (cevrimdisi acilis) de dogru gorunsun.
struct ProEntitlement: Codable, Equatable {
    var product: ProProduct?
    /// Abonelikte donem sonu; omur boyunda nil.
    var expiresAt: Date?

    static let none = ProEntitlement(product: nil, expiresAt: nil)

    func isActive(now: Date = Date()) -> Bool {
        guard let product else { return false }
        if product == .lifetime { return true }
        guard let expiresAt else { return false }
        return expiresAt > now
    }

    /// Gecerli islemlerden en iyi hak: omur boyu > en gec biten abonelik. Iade edilen (revocation) ve suresi
    /// dolan islemler sayilmaz; tanimadigimiz urun kimlikleri yok sayilir.
    static func resolve(_ transactions: [ProTransactionInfo], now: Date = Date()) -> ProEntitlement {
        var best: ProEntitlement = .none
        for transaction in transactions where transaction.revocationDate == nil {
            guard let product = ProProduct(rawValue: transaction.productID) else { continue }
            if product == .lifetime { return ProEntitlement(product: .lifetime, expiresAt: nil) }
            guard let expires = transaction.expirationDate, expires > now else { continue }
            if best.expiresAt.map({ expires > $0 }) ?? true {
                best = ProEntitlement(product: product, expiresAt: expires)
            }
        }
        return best
    }
}

/// Pro gerektiren ozellikler (satin alma ekraninin basligi ve kilit nedenini gosterir).
enum ProFeature: String, CaseIterable, Identifiable {
    case liveShift
    case lockScreen
    case autoShift
    case shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liveShift: "Canlı vardiya"
        case .lockScreen: "Kilit ekranı ve widget'tan +1"
        case .autoShift: "Otomatik vardiya ve km"
        case .shortcuts: "Siri ve Kısayollar"
        }
    }

    var detail: String {
        switch self {
        case .liveShift: "Her paketi tek dokunuşla say; saat bandı, km bandı ve prim kendiliğinden hesaplansın."
        case .lockScreen: "Telefonun kilidini açmadan paket ekle, bugünkü sayını gör."
        case .autoShift: "Yola çıkınca vardiya başlasın, km sayılsın, durunca bitsin."
        case .shortcuts: "“Paket bıraktım” de, paket eklensin."
        }
    }

    var systemImage: String {
        switch self {
        case .liveShift: "hand.tap.fill"
        case .lockScreen: "lock.iphone"
        case .autoShift: "scooter"
        case .shortcuts: "mic.fill"
        }
    }
}
