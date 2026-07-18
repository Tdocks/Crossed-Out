import SwiftUI

/// Shown to a church account that signed up IN THE APP and is awaiting a
/// system-admin verification. It has no access to the rest of the app until
/// verified. "Check status" re-runs bootstrap (which re-reads the account
/// status); once a system admin approves, the gate in RootView clears.
struct PendingVerificationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isChecking = false

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                COIcon(.mapPin, size: 44, color: .coCrossRed)
                    .padding(.bottom, 24)

                Text("Almost there.")
                    .font(.coDisplay(26, weight: .semibold))
                    .foregroundColor(.coInk)

                Text("Your church account is pending review. We verify each church by hand so the community stays trustworthy — this usually takes a day or two. We'll open things up as soon as you're approved.")
                    .font(.coUI(15))
                    .foregroundColor(.coInkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .padding(.top, 14)

                if let email = SupabaseService.shared.currentUserEmail {
                    Text(email)
                        .font(.coUI(13))
                        .foregroundColor(.coInkTertiary)
                        .padding(.top, 18)
                }

                Spacer()

                VStack(spacing: 6) {
                    COPrimaryButton(title: isChecking ? "Checking…" : "Check status") {
                        Task {
                            isChecking = true
                            await appState.bootstrap()
                            isChecking = false
                        }
                    }
                    .disabled(isChecking)
                    .opacity(isChecking ? 0.5 : 1)

                    COSecondaryButton(title: "Sign Out") {
                        appState.signOutAndReset()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

#Preview {
    PendingVerificationView().environmentObject(AppState())
}
