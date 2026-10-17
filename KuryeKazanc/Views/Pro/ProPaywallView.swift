import SwiftUI
import StoreKit

/// 1.14 Kurye Kazanc Pro satin alma ekrani: neden acildi (ozellik), Pro'nun getirdikleri, uc secenek (yillik one cikar),
/// deneme, geri yukleme ve Apple'in istedigi abonelik bilgileri (yenileme, iptal, kosullar, gizlilik).
struct ProPaywallView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let feature: ProFeature
    @State private var selection: ProProduct = .yearly

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    featureList
                    plans
                    freeNote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Theme.groupedBackground)
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .accessibilityIdentifier("paywall.close")
                }
            }
            .alert("Kurye Kazanç Pro", isPresented: messageBinding) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(pro.message ?? "")
            }
        }
        .accessibilityIdentifier("paywall.view")
        .task { await pro.loadProducts() }
        .onChange(of: pro.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: - Bolumler

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.amberOnDark)
                .frame(width: 84, height: 84)
                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Theme.brandDeep.opacity(0.35), radius: 14, y: 8)
                .accessibilityHidden(true)
            Text("Kurye Kazanç Pro")
                .font(.largeTitle.bold())
            Text(headline)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Paketini canlı say, gün bitmeden net kazancını bil.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var headline: String {
        "\(feature.title) Pro'da"
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ProFeature.allCases) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.systemImage)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        if !pro.hasPrices {
            VStack(spacing: 10) {
                if pro.isLoadingProducts {
                    ProgressView("Fiyatlar yükleniyor…")
                } else {
                    Text("Fiyatlar yüklenemedi.").foregroundStyle(.secondary)
                    Button("Yeniden dene") { Task { await pro.loadProducts() } }
                        .accessibilityIdentifier("paywall.retry")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 10) {
                ForEach(ProProduct.displayOrder.filter { pro.priceText($0) != nil }, id: \.self) { item in
                    planRow(item)
                }
            }
        }
    }

    private func planRow(_ item: ProProduct) -> some View {
        let isSelected: Bool = selection == item
        return Button {
            Haptics.light()
            selection = item
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title).font(.headline)
                        if let badge = badge(for: item) {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .foregroundStyle(Theme.brandDeep)
                                .background(Theme.amberOnDark, in: Capsule())
                        }
                    }
                    Text(subtitle(for: item)).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(pro.priceText(item) ?? "")
                        .font(.headline)
                        .monospacedDigit()
                    Text(item.periodText).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.plan.\(item.rawValue.split(separator: ".").last ?? "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func badge(for item: ProProduct) -> String? {
        switch item {
        case .yearly:
            guard let saving = yearlySaving else { return "EN AVANTAJLI" }
            return "%\(saving) TASARRUF"
        case .lifetime: return "TEK SEFER"
        case .monthly: return nil
        }
    }

    /// Yillik, 12 aylik odemeye gore yuzde kac ucuz.
    private var yearlySaving: Int? {
        guard let monthly = pro.price(.monthly), let yearly = pro.price(.yearly), monthly > 0 else { return nil }
        let full: Double = NSDecimalNumber(decimal: monthly * 12).doubleValue
        let paid: Double = NSDecimalNumber(decimal: yearly).doubleValue
        let percent: Int = Int(((full - paid) / full * 100).rounded())
        return percent > 0 ? percent : nil
    }

    private func subtitle(for item: ProProduct) -> String {
        if let trial = pro.trialText(for: item) { return "\(trial), sonra otomatik yenilenir" }
        switch item {
        case .monthly: return "Her ay yenilenir, istediğin an iptal et"
        case .yearly: return "Her yıl yenilenir, istediğin an iptal et"
        case .lifetime: return "Bir kez öde, hep senin olsun"
        }
    }

    private var freeNote: some View {
        Label("Elle kayıt, hakediş ve tarife hesabı, gider ve plan ücretsiz kalır.", systemImage: "checkmark.seal")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Satin alma

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            Button {
                Task { await pro.purchase(selection) }
            } label: {
                if pro.purchaseInFlight != nil {
                    ProgressView().tint(.white)
                } else {
                    Text(ctaTitle)
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(pro.priceText(selection) == nil || pro.purchaseInFlight != nil)
            .accessibilityIdentifier("paywall.purchase")

            Text(legalText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Button(pro.isRestoring ? "Geri yükleniyor…" : "Satın alımları geri yükle") {
                    Task { await pro.restore() }
                }
                .disabled(pro.isRestoring)
                .accessibilityIdentifier("paywall.restore")
                Link("Kullanım koşulları", destination: Self.termsURL)
                Link("Gizlilik", destination: PrivacyView.policyURL)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var ctaTitle: String {
        if let trial = pro.trialText(for: selection) { return "\(trial) dene" }
        return selection == .lifetime ? "Ömür boyu Pro al" : "Pro'ya geç"
    }

    private var legalText: String {
        if selection == .lifetime {
            return "Tek seferlik ödeme Apple hesabından alınır; abonelik değildir, yenilenmez."
        }
        var text: String = "Ödeme Apple hesabından alınır. Abonelik, dönem bitmeden en az 24 saat önce iptal edilmezse aynı fiyattan otomatik yenilenir. Ayarlar > Apple Hesabı > Abonelikler'den yönetebilir ya da iptal edebilirsin."
        if pro.trialText(for: selection) != nil {
            text += " Deneme bitmeden iptal edersen ücret alınmaz."
        }
        return text
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { pro.message != nil }, set: { if !$0 { pro.message = nil } })
    }
}

/// Profil > Kurye Kazanc Pro: durum, satin alma / yonetim, geri yukleme.
struct ProSection: View {
    @Environment(ProStore.self) private var pro
    @State private var showsManage = false

    var body: some View {
        Section {
            if pro.isPro {
                LabeledContent {
                    Text(statusText)
                } label: {
                    Label("Kurye Kazanç Pro", systemImage: "bolt.shield.fill")
                }
                .accessibilityIdentifier("profile.pro.status")
                if pro.entitlement.product?.isSubscription ?? false {
                    // Liste icinde Section degistiricisi her satira uygulanabilir: sayfa dugmenin kendisinde
                    Button("Aboneliği yönet") { showsManage = true }
                        .accessibilityIdentifier("profile.pro.manage")
                        .manageSubscriptionsSheet(isPresented: $showsManage)
                }
            } else {
                Button {
                    pro.paywallRequest = .liveShift
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.amberOnDark)
                            .frame(width: 36, height: 36)
                            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kurye Kazanç Pro'ya geç").font(.headline)
                            Text("Canlı vardiya, kilit ekranından +1, otomatik vardiya").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("profile.pro.upgrade")
                Button(pro.isRestoring ? "Geri yükleniyor…" : "Satın alımları geri yükle") {
                    Task { await pro.restore() }
                }
                .disabled(pro.isRestoring)
                .accessibilityIdentifier("profile.pro.restore")
            }
        } header: {
            Text("Pro")
        }
    }

    private var statusText: String {
        switch pro.entitlement.product {
        case .some(.lifetime): return "Ömür boyu"
        case .some(let product):
            guard let expires = pro.entitlement.expiresAt else { return product.title }
            return "\(product.title) · \(expires.formatted(.dateTime.day().month(.wide).year().locale(Formatters.locale))) tarihine kadar"
        case .none: return "Açık"
        }
    }
}
