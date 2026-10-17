import SwiftUI
import SwiftData

/// 1.11 ilk ekran: "Nasıl devam etmek istersin?" — Apple ile giris (yedekli) ya da misafir. Ardindan firma secimi gelir.
/// Apple ile giriste daha once alinmis yedek varsa kayitlar hemen geri yuklenir.
struct AccountWelcomeView: View {
    let onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AccountService.self) private var account
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var message: String?
    @State private var isRestoring = false

    var body: some View {
        ZStack {
            AnimatedBrandBackground()
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 48)
                Spacer(minLength: 24)
                VStack(spacing: 14) {
                    if account.isServerAvailable { appleCard }
                    guestCard
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85).delay(0.15), value: appeared)
                Text("İstediğin zaman Profil > Hesap'tan giriş yapabilir ya da çıkabilirsin.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
        }
        .onAppear { appeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .scaleEffect(appeared ? 1 : 0.6)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: appeared)
            Text("Kurye Kazanç'a hoş geldin")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text("Nasıl devam etmek istersin?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("account.title")
            Text("Kazancını, hedefini ve vardiyalarını takip etmek için hesap şart değil.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var appleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            option(symbol: "apple.logo", title: "Apple ile giriş",
                   detail: "Kayıtların ve ayarların yedeklenir; telefon değiştirince geri gelir. Ad ve e-posta istenmez.")
            if account.isSignedInWithApple {
                Label(message ?? "Giriş yapıldı", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.positive)
                    .accessibilityIdentifier("account.signedIn")
                continueButton(title: "Devam", identifier: "account.continue")
            } else {
                AppleSignInButton(style: .black, onSignedIn: restoreBackup, onFailure: { message = $0 })
                if let message {
                    Text(message).font(.caption).foregroundStyle(Theme.negative)
                }
            }
            if isRestoring {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Yedeğin aranıyor…").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder private var guestCard: some View {
        if !account.isSignedInWithApple {
            VStack(alignment: .leading, spacing: 12) {
                option(symbol: "person.crop.circle.badge.questionmark", title: "Misafir olarak devam et",
                       detail: "Kayıtların yalnızca bu telefonda kalır; uygulamayı silersen kaybolur.")
                continueButton(title: "Misafir olarak devam et", identifier: "welcome.guest")
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func option(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func continueButton(title: String, identifier: String) -> some View {
        Button {
            Haptics.success()
            onContinue()
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white)
                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
    }

    /// Girisli kullanicinin yedegi varsa kayitlar bu cihaza eklenir; yedek yoksa sessizce devam edilir.
    private func restoreBackup() {
        let service: AccountService = account
        let context: ModelContext = modelContext
        isRestoring = true
        Task { @MainActor in
            defer { isRestoring = false }
            let platforms: [Platform] = (try? context.fetch(FetchDescriptor<Platform>())) ?? []
            do {
                let result: (added: Int, skipped: Int) = try await service.restore(context: context, platforms: platforms)
                message = result.added > 0 ? "Giriş yapıldı · \(result.added) kayıt geri yüklendi" : "Giriş yapıldı"
            } catch {
                message = "Giriş yapıldı · yedek bulunamadı, yeni başlıyorsun"
            }
        }
    }
}
