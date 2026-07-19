import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

enum AuthMode {
    case signIn
    case createAccount

    var title: String {
        switch self {
        case .signIn: return "Welcome back."
        case .createAccount: return "Keep your journey."
        }
    }

    var subtitle: String {
        switch self {
        case .signIn: return "Sign in to pick up where you left off."
        case .createAccount: return "Create an account so your progress, highlights, and prayers are never lost."
        }
    }

    var buttonTitle: String {
        switch self {
        case .signIn: return "Sign In"
        case .createAccount: return "Create Account"
        }
    }
}

struct AuthSheet: View {
    var mode: AuthMode
    /// Called after a successful sign-in/sign-up. Passes the Apple-provided
    /// given name when the user authenticated via Sign in with Apple and
    /// Apple returned one (only available the first time a user authorizes
    /// this app) — nil for email/password or when Apple withheld it.
    var onSuccess: (String?) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var currentNonce: String?
    /// Required agreement to the Terms/EULA before an account can be created
    /// (App Review 1.2 — UGC apps need explicit consent to zero-tolerance
    /// terms). Sign-in mode doesn't show it; legacy accounts are handled by
    /// LegalAcceptanceGateView instead.
    @State private var agreedToTerms = false
    @State private var presentedLegalDoc: LegalDoc?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mode.title)
                .font(.coDisplay(24, weight: .semibold))
                .foregroundColor(.coInk)
                .padding(.top, 34)

            Text(mode.subtitle)
                .font(.coUI(14))
                .foregroundColor(.coInkSecondary)
                .lineSpacing(3)
                .padding(.top, 8)

            appleButton
                .padding(.top, 28)

            orDivider
                .padding(.top, 20)

            authField("Email", text: $email, secure: false)
                .padding(.top, 20)
            authField("Password", text: $password, secure: true)
                .padding(.top, 12)

            if mode == .createAccount {
                LegalConsentRow(agreed: $agreedToTerms, presentedDoc: $presentedLegalDoc)
                    .padding(.top, 18)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.coUI(13))
                    .foregroundColor(.coCrossRed)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            COPrimaryButton(title: mode.buttonTitle, action: submit)
                .opacity(isLoading || !isValid ? 0.5 : 1)
                .disabled(isLoading || !isValid)
                .padding(.top, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .sheet(item: $presentedLegalDoc) { LegalDocView(doc: $0) }
    }

    private var isValid: Bool {
        email.contains("@") && password.count >= 6 && consentSatisfied
    }

    /// Creating an account requires the Terms agreement; signing back in
    /// does not (the in-app acceptance gate covers legacy accounts).
    private var consentSatisfied: Bool {
        mode == .signIn || agreedToTerms
    }

    private var appleButtonLabel: SignInWithAppleButton.Label {
        mode == .signIn ? .signIn : .continue
    }

    private var appleButton: some View {
        SignInWithAppleButton(appleButtonLabel, onRequest: configureAppleRequest, onCompletion: handleAppleCompletion)
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(consentSatisfied ? 1 : 0.5)
            .overlay {
                // SignInWithAppleButton has no .disabled-friendly styling;
                // intercept taps until the Terms are agreed to and explain
                // why, instead of silently doing nothing.
                if !consentSatisfied {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                errorMessage = "Please agree to the Terms below first."
                            }
                        }
                }
            }
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            CODivider()
            Text("or")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
            CODivider()
        }
    }

    private func authField(_ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(.coUI(15))
        .foregroundColor(.coInk)
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.coCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.coDivider, lineWidth: 1)
                )
        )
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                switch mode {
                case .signIn:
                    try await SupabaseService.shared.signIn(email: email, password: password)
                case .createAccount:
                    try await SupabaseService.shared.signUp(email: email, password: password)
                    recordConsent()
                }
                isLoading = false
                onSuccess(nil)
                dismiss()
            } catch {
                isLoading = false
                withAnimation(.easeOut(duration: 0.2)) {
                    errorMessage = friendlyError(error)
                }
            }
        }
    }

    /// Fire-and-forget record of the Terms acceptance the user just gave on
    /// this screen (migration 0023). Idempotent; also cached locally so the
    /// acceptance gate never re-prompts this account on this device.
    private func recordConsent() {
        Task {
            await SupabaseService.shared.recordLegalAcceptance(version: LegalDocuments.termsVersion)
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("invalid login") {
            return "That email and password don't match. Try again."
        }
        if raw.localizedCaseInsensitiveContains("already registered") {
            return "An account with that email already exists. Try signing in."
        }
        return "Something went wrong. Please try again."
    }

    // MARK: - Sign in with Apple

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                withAnimation(.easeOut(duration: 0.2)) {
                    errorMessage = "Apple sign-in isn't available yet. Use email for now."
                }
                return
            }

            let givenName = credential.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let appleGivenName = (givenName?.isEmpty ?? true) ? nil : givenName

            errorMessage = nil
            isLoading = true
            Task {
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                    if mode == .createAccount { recordConsent() }
                    isLoading = false
                    onSuccess(appleGivenName)
                    dismiss()
                } catch {
                    isLoading = false
                    withAnimation(.easeOut(duration: 0.2)) {
                        errorMessage = "Apple sign-in isn't available yet. Use email for now."
                    }
                }
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            withAnimation(.easeOut(duration: 0.2)) {
                errorMessage = "Apple sign-in isn't available yet. Use email for now."
            }
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            // Extremely unlikely; fall back to a UUID-derived nonce rather than crash.
            return UUID().uuidString + UUID().uuidString
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    AuthSheet(mode: .createAccount)
}
