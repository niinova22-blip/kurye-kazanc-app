import SwiftUI
import SwiftData
import AuthenticationServices

/// Profil > Hesap ve yedek: Apple ile Giris, yedekle / geri yukle, cikis, "Verilerimi sil".
struct AccountSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountService.self) private var account

    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    /// Apple istegine `hashed` gider; tamamlaninca `raw` Supabase'e gonderilir.
    @State private var rawNonce: String?
    @State private var showRestoreConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String?

    /// Sunucu ayari yoksa hesap ozellikleri kapali.
    private let isServerConfigured: Bool = SupabaseConfig.fromBundle != nil

    var body: some View {
        Section {
            if isServerConfigured {
                if account.isSignedInWithApple {
                    signedInRows
                } else {
                    signInButton
                }
                deleteRow
            } else {
                Text("Sunucu bu sürümde kapalı")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.serverUnavailable")
            }
        } header: {
            Text("Hesap ve yedek")
        } footer: {
            Text("Apple ile giriş yaparsan kayıtların ve ayarların sunucuya yedeklenir; yeni telefonda geri yükleyebilirsin. Otomatik yedek, ilk “Şimdi yedekle”den veya geri yüklemeden sonra başlar. Giriş yapmazsan uygulama aynen çalışır.")
        }
    }

    // MARK: - Satirlar

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce: (raw: String, hashed: String) = account.makeNonce()
            rawNonce = nonce.raw
            // Ad / e-posta istenmez: yedek icin kimlik yeterli
            request.requestedScopes = []
            request.nonce = nonce.hashed
        } onCompletion: { result in
            handleSignIn(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 44)
        .accessibilityIdentifier("profile.appleSignIn")
    }

    @ViewBuilder
    private var signedInRows: some View {
        Button("Şimdi yedekle", action: backupNow)
            .disabled(account.isBusy)
            .accessibilityIdentifier("profile.backupNow")

        Button("Yedekten geri yükle") { showRestoreConfirmation = true }
            .disabled(account.isBusy)
            .accessibilityIdentifier("profile.restore")
            .confirmationDialog(
                "Yedekteki kayıtlar bu cihaza eklenir. Cihazda zaten olan kayıtlar değişmez; ayarlar yedektekiyle değiştirilir.",
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Geri yükle", action: restore)
                Button("Vazgeç", role: .cancel) {}
            }

        LabeledContent("Son yedek", value: lastBackupText)
            .accessibilityIdentifier("profile.lastBackup")

        if account.isBusy {
            HStack {
                ProgressView()
                Text("İşlem sürüyor…").foregroundStyle(.secondary)
            }
        }

        Button("Çıkış yap") { account.signOut() }
            .disabled(account.isBusy)
            .accessibilityIdentifier("profile.signOut")
    }

    /// Liste icinde Section'a eklenen degistiriciler her satira uygulanabilir: sonuc uyarisi
    /// her zaman var olan bu satirda durur (giris/cikista satir kimligi degismez).
    private var deleteRow: some View {
        Button("Verilerimi sil", role: .destructive) { showDeleteConfirmation = true }
            .disabled(account.isBusy)
            .accessibilityIdentifier("profile.deleteMyData")
            .confirmationDialog(
                "Sunucudaki gönderilmiş vardiyaların, kalibrasyon örneklerin ve yedeğin silinir; paylaşım kapanır. Telefondaki kayıtların silinmez.",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Verilerimi sil", role: .destructive, action: deleteMyData)
                Button("Vazgeç", role: .cancel) {}
            }
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
    }

    private var lastBackupText: String {
        guard let date = account.lastBackupDate else { return "Henüz yok" }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Formatters.locale))
    }

    // MARK: - Eylemler

    /// Iptal ya da basarisiz giris sessizdir (spec 5): anonim oturum surer.
    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = rawNonce else {
            rawNonce = nil
            return
        }
        rawNonce = nil
        let service: AccountService = account
        Task {
            try? await service.completeAppleSignIn(idToken: idToken, rawNonce: nonce)
        }
    }

    private func backupNow() {
        let service: AccountService = account
        let context: ModelContext = modelContext
        Task {
            do {
                try await service.backupNow(context: context)
            } catch {
                showError(error)
            }
        }
    }

    private func restore() {
        let service: AccountService = account
        let context: ModelContext = modelContext
        let current: [Platform] = platforms
        Task {
            do {
                let result: (added: Int, skipped: Int) = try await service.restore(context: context, platforms: current)
                showResult("\(result.added) kayıt eklendi")
            } catch {
                showError(error)
            }
        }
    }

    private func deleteMyData() {
        let service: AccountService = account
        let context: ModelContext = modelContext
        Task {
            do {
                try await service.deleteMyData(context: context)
                showResult("Sunucudaki verilerin silindi.")
            } catch {
                showError(error)
            }
        }
    }

    private func showResult(_ message: String) {
        alertTitle = "Tamamlandı"
        alertMessage = message
    }

    private func showError(_ error: Error) {
        alertTitle = "İşlem tamamlanamadı"
        alertMessage = error.localizedDescription
    }
}
