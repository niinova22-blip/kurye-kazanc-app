import SwiftUI
import AuthenticationServices

/// Apple ile Giris dugmesi: nonce uretir, Apple'in id_token'ini Supabase'e iletir.
/// Karsilama ekrani ve Profil > Hesap ortak kullanir. Iptal sessizdir; diger hatalar `onFailure` ile doner.
struct AppleSignInButton: View {
    @Environment(AccountService.self) private var account
    @Environment(\.colorScheme) private var colorScheme

    var style: SignInWithAppleButton.Style? = nil
    var onSignedIn: () -> Void = {}
    var onFailure: (String) -> Void = { _ in }

    /// Apple istegine `hashed` gider; tamamlaninca `raw` Supabase'e gonderilir.
    @State private var rawNonce: String?

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce: (raw: String, hashed: String) = account.makeNonce()
            rawNonce = nonce.raw
            // Ad / e-posta istenmez: yedek icin kimlik yeterli
            request.requestedScopes = []
            request.nonce = nonce.hashed
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(style ?? (colorScheme == .dark ? .white : .black))
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("profile.appleSignIn")
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        let pendingNonce: String? = rawNonce
        rawNonce = nil
        let authorization: ASAuthorization
        switch result {
        case .success(let value):
            authorization = value
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled { return }
            onFailure(error.localizedDescription)
            return
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = pendingNonce else {
            onFailure("Apple ile giriş tamamlanamadı, tekrar dene.")
            return
        }
        let service: AccountService = account
        let success: () -> Void = onSignedIn
        let failure: (String) -> Void = onFailure
        Task { @MainActor in
            do {
                try await service.completeAppleSignIn(idToken: idToken, rawNonce: nonce)
                Haptics.success()
                success()
            } catch {
                failure(error.localizedDescription)
            }
        }
    }
}
