import SwiftUI
import SwiftData

/// Profil > Hesap ve yedek: Apple ile Giris, yedekle / geri yukle, cikis, "Hesabımı ve verilerimi sil" (1.13: hesap da silinir, App Store 5.1.1v).
struct AccountSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AccountService.self) private var account

    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]

    @State private var showRestoreConfirmation = false
    @State private var showFirstBackupConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String?

    var body: some View {
        Section {
            // Sunucu istemcisi yoksa hesap ozellikleri kapali.
            if account.isServerAvailable {
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
            Text("Hesap")
        } footer: {
            if account.isServerAvailable {
                footerText
            }
        }
    }

    private var footerText: some View {
        Text("Apple ile giriş yaparsan kayıtların ve ayarların yedeklenir; telefon değiştirince geri yüklersin. Ad ve e-posta istenmez. Giriş yapmazsan uygulama aynen çalışır.")
    }

    // MARK: - Satirlar

    private var signInButton: some View {
        AppleSignInButton(onFailure: showFailure)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private var signedInRows: some View {
        Label("Apple hesabınla giriş yaptın", systemImage: "checkmark.seal.fill")
            .foregroundStyle(Theme.positive)
            .accessibilityIdentifier("profile.signedIn")
        Button("Şimdi yedekle", action: backupTapped)
            .disabled(account.isBusy)
            .accessibilityIdentifier("profile.backupNow")
            .confirmationDialog(
                "Sunucuda bu hesaba ait bir yedek varsa bu cihazdakiyle değiştirilecek. Önce geri yüklemek ister misin?",
                isPresented: $showFirstBackupConfirmation,
                titleVisibility: .visible
            ) {
                Button("Önce geri yükle", action: restore)
                Button("Yine de yedekle", role: .destructive, action: backupNow)
                Button("Vazgeç", role: .cancel) {}
            }

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
        Button("Hesabımı ve verilerimi sil", role: .destructive) { showDeleteConfirmation = true }
            .disabled(account.isBusy)
            .accessibilityIdentifier("profile.deleteMyData")
            .confirmationDialog(
                "Hesabın ve sunucudaki tüm verilerin kalıcı olarak silinir: yedeğin, gönderilmiş vardiyaların ve bu cihazın kullandığı tüm kimlikler (Apple hesabına bağlı hesap dahil). Geri alınamaz. Telefondaki kayıtların silinmez; uygulamayı misafir olarak kullanmaya devam edebilirsin.",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Hesabımı sil", role: .destructive, action: deleteMyData)
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

    /// Yedek tabani yoksa (yeni telefon / ilk yedek) once sunucudaki yedegi ezme uyarisi.
    private func backupTapped() {
        if account.hasBaseline {
            backupNow()
        } else {
            showFirstBackupConfirmation = true
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
                showResult("Hesabın ve sunucudaki verilerin silindi.")
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
        showFailure(error.localizedDescription)
    }

    private func showFailure(_ message: String) {
        alertTitle = "İşlem tamamlanamadı"
        alertMessage = message
    }
}
