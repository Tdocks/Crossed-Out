import SwiftUI

/// A labeled single-line text field styled to match the onboarding/auth look.
/// Shared by the church application + church management forms.
struct ChurchTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .sentences
    var keyboard: UIKeyboardType = .default
    var autocorrect: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.coUI(11, weight: .medium))
                .foregroundColor(.coInkTertiary)
                .tracking(1.1)
            TextField(placeholder, text: $text)
                .font(.coUI(15))
                .foregroundColor(.coInk)
                .textInputAutocapitalization(autocapitalization)
                .keyboardType(keyboard)
                .autocorrectionDisabled(!autocorrect)
                .padding(14)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
        }
    }
}
