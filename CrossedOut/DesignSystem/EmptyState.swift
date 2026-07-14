import SwiftUI

// MARK: - Empty State

/// A quiet, centered placeholder shown in place of a list or section that
/// currently has no content. No alarm, no color beyond ink tones.
struct COEmptyState: View {
    let icon: COIconName
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    init(icon: COIconName, title: String, message: String,
         actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            COIcon(icon, size: 32, color: .coInkTertiary)

            Text(title)
                .font(.coDisplay(18, weight: .semibold))
                .foregroundColor(.coInk)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 260)

            if let actionTitle, let action {
                COSecondaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 200)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    COEmptyState(
        icon: .prayer,
        title: "No prayer requests yet",
        message: "Be the first to share what you're carrying — your circle is here for you.",
        actionTitle: "Share a request",
        action: {}
    )
}
