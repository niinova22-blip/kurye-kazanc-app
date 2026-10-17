import Foundation
import Observation
import StoreKit

/// 1.14 Kurye Kazanc Pro (StoreKit 2): urunler, satin alma, geri yukleme ve hak. Hak cihazda onbellege alinir
/// (cevrimdisi acilista da dogru), StoreKit her acilista ve her islem guncellemesinde yeniden okunur.
/// UI testlerinde StoreKit'e gidilmez: `override` sabit cevap verir ("-free" ile ucretsiz, yoksa Pro).
@MainActor
@Observable
final class ProStore {
    private(set) var entitlement: ProEntitlement
    private(set) var products: [ProProduct: Product] = [:]
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight: ProProduct?
    private(set) var isRestoring = false
    /// Abonelik denemesine (7 gun) hak kazaniyor mu; ilk kez abone olanlarda true.
    private(set) var isEligibleForTrial = true
    var message: String?
    /// Kilitli bir ozellige dokunuldu: kok gorunum satin alma ekranini acar.
    var paywallRequest: ProFeature?

    /// Hak degisti (true: Pro). Ortam otomatik vardiyayi kapatmak icin baglar.
    @ObservationIgnored var onChange: ((Bool) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let override: Bool?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    static let entitlementKey = "pro.entitlement.v1"
    /// Yalnizca UI testi "-store-demo": StoreKit olmadan satin alma ekraninin magaza / inceleme goruntusu (ASC fiyatlari).
    @ObservationIgnored private var demoPrices: [ProProduct: Decimal] = [:]

    init(defaults: UserDefaults = .standard, override: Bool? = nil, demo: Bool = false) {
        self.defaults = defaults
        self.override = override
        if override != nil, demo {
            demoPrices = [.monthly: Decimal(string: "79.99")!, .yearly: Decimal(string: "599.99")!,
                          .lifetime: Decimal(string: "1499.99")!]
        }
        if let data = defaults.data(forKey: Self.entitlementKey),
           let saved = try? JSONDecoder().decode(ProEntitlement.self, from: data) {
            entitlement = saved
        } else {
            entitlement = .none
        }
        guard override == nil else { return }
        // Baska cihazda alinan, yenilenen, iade edilen ya da Aile Paylasimi'yla gelen islemler
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refreshEntitlement()
            }
        }
    }

    var isPro: Bool { override ?? entitlement.isActive() }

    /// Kilitli ozellik: Pro ise true; degilse satin alma ekranini ister.
    @discardableResult
    func require(_ feature: ProFeature) -> Bool {
        if isPro { return true }
        paywallRequest = feature
        return false
    }

    // MARK: - Hak

    func refreshEntitlement() async {
        guard override == nil else { return }
        var infos: [ProTransactionInfo] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            infos.append(ProTransactionInfo(productID: transaction.productID,
                                            expirationDate: transaction.expirationDate,
                                            revocationDate: transaction.revocationDate))
        }
        apply(ProEntitlement.resolve(infos))
    }

    private func apply(_ new: ProEntitlement) {
        if new != entitlement {
            entitlement = new
            if let data = try? JSONEncoder().encode(new) { defaults.set(data, forKey: Self.entitlementKey) }
        }
        let active: Bool = isPro
        WidgetPublisher.publish { $0.shiftLocked = !active }
        onChange?(active)
    }

    /// Acilista: onbellekteki durum widget'a yazilir, StoreKit'ten taze hak okunur.
    func start() async {
        if override != nil {
            let active: Bool = isPro
            WidgetPublisher.publish { $0.shiftLocked = !active }
            return
        }
        await refreshEntitlement()
    }

    // MARK: - Urunler

    func loadProducts() async {
        guard override == nil, products.count < ProProduct.allCases.count, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let list: [Product] = try await Product.products(for: ProProduct.allCases.map(\.id))
            var map: [ProProduct: Product] = [:]
            for product in list {
                if let key = ProProduct(rawValue: product.id) { map[key] = product }
            }
            products = map
            if let subscription = (map[.yearly] ?? map[.monthly])?.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
            if map.isEmpty { message = "Fiyatlar şu an yüklenemedi. Biraz sonra yeniden dene." }
        } catch {
            message = "Fiyatlar yüklenemedi. İnternet bağlantını kontrol et."
        }
    }

    var hasPrices: Bool { !products.isEmpty || !demoPrices.isEmpty }

    func price(_ item: ProProduct) -> Decimal? { products[item]?.price ?? demoPrices[item] }

    func priceText(_ item: ProProduct) -> String? {
        if let product = products[item] { return product.displayPrice }
        guard let demo = demoPrices[item] else { return nil }
        return demo.formatted(.currency(code: "TRY").locale(Formatters.locale))
    }

    /// "7 gün ücretsiz" (deneme hakki varsa ve urunde tanimliysa).
    func trialText(for item: ProProduct) -> String? {
        if demoPrices[item] != nil { return item.isSubscription ? "1 hafta ücretsiz" : nil }
        guard isEligibleForTrial, let offer = products[item]?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return "\(Self.periodText(offer.period)) ücretsiz"
    }

    static func periodText(_ period: Product.SubscriptionPeriod) -> String {
        let value: Int = period.value
        switch period.unit {
        case .day: return value == 7 ? "1 hafta" : "\(value) gün"
        case .week: return "\(value) hafta"
        case .month: return "\(value) ay"
        case .year: return "\(value) yıl"
        @unknown default: return "\(value)"
        }
    }

    // MARK: - Satin alma

    func purchase(_ item: ProProduct) async {
        guard let product = products[item], purchaseInFlight == nil else { return }
        purchaseInFlight = item
        defer { purchaseInFlight = nil }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "Satın alma doğrulanamadı. Satın alımları geri yüklemeyi dene."
                    return
                }
                await transaction.finish()
                await refreshEntitlement()
            case .pending:
                message = "Satın alma onay bekliyor. Onaylanınca Pro kendiliğinden açılır."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "Satın alma tamamlanamadı. Biraz sonra yeniden dene."
        }
    }

    func restore() async {
        guard override == nil, !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch {
            // Kullanici Apple girisini iptal ettiyse de yerel islemler okunur
        }
        await refreshEntitlement()
        message = isPro ? "Pro geri yüklendi." : "Bu Apple hesabında geri yüklenecek bir satın alma bulunamadı."
    }
}
