import Foundation
import Observation
import StoreKit

/// 1.14 Kurye Kazanc Pro (StoreKit 2): urunler, 7 gunluk deneme, satin alma, geri yukleme ve hak. Hak ve deneme
/// baslangici cihazda onbellege alinir (cevrimdisi acilista da dogru), StoreKit her acilista ve her islem guncellemesinde
/// yeniden okunur. UI testlerinde StoreKit'e gidilmez: `override` sabit erisim verir (bkz. LaunchOptions.proAccess).
@MainActor
@Observable
final class ProStore {
    private(set) var entitlement: ProEntitlement
    /// Deneme baslangici (0 TL'lik deneme urununun satin alma tarihi); hic baslamadiysa nil.
    private(set) var trialStart: Date?
    /// Erisimin degerlendirildigi an: on plana donuste ve deneme bitiminde ilerler (sure gozlenebilsin diye).
    private(set) var now = Date()
    private(set) var products: [ProProduct: Product] = [:]
    private(set) var trialProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight: ProProduct?
    private(set) var isRestoring = false
    private(set) var isStartingTrial = false
    /// Abonelikte App Store tanitim teklifine hak kazaniyor mu; ilk kez abone olanlarda true.
    private(set) var isEligibleForTrial = true
    var message: String?
    /// Kilitli bir ozellige dokunuldu: kok gorunum satin alma ekranini acar.
    var paywallRequest: ProFeature?

    /// Erisim degisti (true: Pro ya da deneme). Ortam otomatik vardiyayi kapatmak icin baglar.
    @ObservationIgnored var onChange: ((Bool) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    /// UI testi erisimi; gozlenir ki test modunda deneme baslayinca kapi kalksin.
    private var override: ProAccess?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var trialEndTask: Task<Void, Never>?

    static let entitlementKey = "pro.entitlement.v1"
    static let trialStartKey = "pro.trialStart.v1"
    /// Yalnizca UI testi "-store-demo": StoreKit olmadan satin alma ekraninin magaza / inceleme goruntusu (ASC fiyatlari).
    @ObservationIgnored private var demoPrices: [ProProduct: Decimal] = [:]

    init(defaults: UserDefaults = .standard, override: ProAccess? = nil, demo: Bool = false) {
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
        let savedTrial: Double = defaults.double(forKey: Self.trialStartKey)
        trialStart = savedTrial > 0 ? Date(timeIntervalSince1970: savedTrial) : nil
        guard override == nil else { return }
        // Baska cihazda alinan, yenilenen, iade edilen ya da Aile Paylasimi'yla gelen islemler
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refreshEntitlement()
            }
        }
    }

    var access: ProAccess { override ?? ProAccess.resolve(entitlement: entitlement, trialStart: trialStart, now: now) }

    /// Uygulama acik mi: Pro ya da 7 gunluk deneme suruyor. Kilitli ozellikler bunu sorar.
    var isPro: Bool { access.hasAccess }

    /// Ucretli Pro (abonelik / omur boyu); deneme sayilmaz.
    var isPaid: Bool { access == .pro }

    /// Deneme hic baslamadi ya da bitti: uygulama yerine kapi (deneme / satin alma) ekrani.
    var blocksApp: Bool { !access.hasAccess }

    /// Kilitli ozellik: Pro ise true; degilse satin alma ekranini ister.
    @discardableResult
    func require(_ feature: ProFeature) -> Bool {
        if isPro { return true }
        paywallRequest = feature
        return false
    }

    /// Kilitliyken Siri / Kisayollar cevabi: deneme hic baslamadiysa baslatmaya, bittiyse Pro'ya yonlendirir.
    var lockedMessage: String {
        if access == .trialAvailable {
            return "Önce uygulamayı açıp \(ProTrial.days) günlük ücretsiz denemeyi başlat."
        }
        return "Ücretsiz deneme süren doldu. Devam etmek için uygulamayı açıp Pro'ya geçebilirsin."
    }

    /// On plana donus: deneme suresi bu arada bittiyse kapi gelir.
    func tick() {
        now = Date()
        publishAccess()
    }

    // MARK: - Hak

    func refreshEntitlement() async {
        guard override == nil else { return }
        var infos: [ProTransactionInfo] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            infos.append(ProTransactionInfo(productID: transaction.productID,
                                            expirationDate: transaction.expirationDate,
                                            revocationDate: transaction.revocationDate,
                                            purchaseDate: transaction.purchaseDate))
        }
        // Deneme bir kez baslar: onbellekteki daha erken baslangic korunur
        let starts: [Date] = [ProTrial.startDate(in: infos), trialStart].compactMap { $0 }
        apply(ProEntitlement.resolve(infos), trialStart: starts.min())
    }

    private func apply(_ new: ProEntitlement, trialStart newTrial: Date?) {
        if new != entitlement {
            entitlement = new
            if let data = try? JSONEncoder().encode(new) { defaults.set(data, forKey: Self.entitlementKey) }
        }
        if newTrial != trialStart {
            trialStart = newTrial
            defaults.set(newTrial?.timeIntervalSince1970 ?? 0, forKey: Self.trialStartKey)
        }
        now = Date()
        publishAccess()
        scheduleTrialEnd()
    }

    private func publishAccess() {
        let active: Bool = isPro
        WidgetPublisher.publish { $0.shiftLocked = !active }
        onChange?(active)
    }

    /// Uygulama acikken deneme biterse kapi o an gelsin.
    private func scheduleTrialEnd() {
        trialEndTask?.cancel()
        guard case .trial(let end) = access else { return }
        let seconds: TimeInterval = min(max(1, end.timeIntervalSinceNow + 1), TimeInterval(ProTrial.days + 1) * 86_400)
        trialEndTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.tick()
        }
    }

    /// Acilista: onbellekteki durum widget'a yazilir, StoreKit'ten taze hak okunur.
    func start() async {
        if override != nil {
            publishAccess()
            return
        }
        await refreshEntitlement()
    }

    // MARK: - Urunler

    func loadProducts() async {
        guard override == nil, products.count < ProProduct.allCases.count || trialProduct == nil,
              !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let ids: [String] = ProProduct.allCases.map(\.id) + [ProTrial.productID]
            let list: [Product] = try await Product.products(for: ids)
            var map: [ProProduct: Product] = [:]
            for product in list {
                if let key = ProProduct(rawValue: product.id) { map[key] = product }
                if product.id == ProTrial.productID { trialProduct = product }
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

    /// App Store tanitim teklifi ("1 hafta ücretsiz"), urunde tanimliysa ve hak varsa. 7 gunluk deneme ayridir.
    func trialText(for item: ProProduct) -> String? {
        if demoPrices[item] != nil { return nil }
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

    // MARK: - Deneme

    /// 7 gunluk ucretsiz denemeyi baslatir: Apple onayi istenir, ucret alinmaz; bitince kendiliginden ucret alinmaz.
    func startTrial() async {
        guard !isStartingTrial, purchaseInFlight == nil else { return }
        if override != nil {
            override = .trial(endsAt: ProTrial.endDate(start: Date()))
            tick()
            return
        }
        isStartingTrial = true
        defer { isStartingTrial = false }
        if trialProduct == nil { await loadProducts() }
        guard let product = trialProduct else {
            message = "Deneme şu an başlatılamadı. İnternet bağlantını kontrol edip yeniden dene."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "Deneme doğrulanamadı. Satın alımları geri yüklemeyi dene."
                    return
                }
                await transaction.finish()
                await refreshEntitlement()
            case .pending:
                message = "Deneme onay bekliyor. Onaylanınca kendiliğinden açılır."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "Deneme başlatılamadı. Biraz sonra yeniden dene."
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
        switch access {
        case .pro: message = "Pro geri yüklendi."
        case .trial: message = "Ücretsiz denemen geri yüklendi."
        case .trialAvailable, .expired: message = "Bu Apple hesabında geri yüklenecek bir satın alma bulunamadı."
        }
    }
}
