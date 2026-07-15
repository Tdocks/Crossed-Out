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
    var onSuccess: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var currentNonce: String?

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

            if mode == .createAccount {
                Text("Your anonymous progress transfers automatically.")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                COSecondaryButton(title: "Maybe later") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private var isValid: Bool {
        email.contains("@") && password.count >= 6
    }

    private var appleButtonLabel: SignInWithAppleButton.Label {
        mode == .signIn ? .signIn : .continue
    }

    private var appleButton: some View {
        SignInWithAppleButton(appleButtonLabel, onRequest: configureAppleRequest, onCompletion: handleAppleCompletion)
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                }
                isLoading = false
                onSuccess()
                dismiss()
            } catch {
                isLoading = false
                withAnimation(.easeOut(duration: 0.2)) {
                    errorMessage = friendlyError(error)
                }
            }
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

            errorMessage = nil
            isLoading = true
            Task {
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                    isLoading = false
                    onSuccess()
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
