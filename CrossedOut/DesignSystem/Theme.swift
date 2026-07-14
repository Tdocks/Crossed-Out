import SwiftUI

// MARK: - Hex Color Helper

extension Color {
    /// Create a Color from a hex string like "#F7F3EC" or "F7F3EC".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Adaptive Color Provider

private extension UIColor {
    /// Build a dynamic UIColor from light/dark hex strings.
    static func co(_ light: String, _ dark: String) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        }
    }
}

// MARK: - Crossed Out Palette

extension Color {
    static let coPaper          = Color(UIColor.co("F7F3EC", "121311"))
    static let coPaperSecondary = Color(UIColor.co("FCFAF6", "1A1B19"))
    static let coCard           = Color(UIColor.co("FFFFFF", "20211F"))
    static let coInk            = Color(UIColor.co("171717", "EEE7DA"))
    static let coInkSecondary   = Color(UIColor.co("55514A", "B7B1A5"))
    static let coInkTertiary    = Color(UIColor.co("8B857B", "8E897D"))
    static let coDivider        = Color(UIColor.co("E7E1D6", "2E2F2B"))
    static let coCrossRed       = Color(UIColor.co("B5412C", "C14D37"))
    static let coOlive          = Color(UIColor.co("69744D", "78845C"))
    static let coBlue           = Color(UIColor.co("2D566A", "527892"))
    static let coGold           = Color(UIColor.co("C89B52", "D1A35B"))
}

// MARK: - COShadow (extremely subtle card elevation)

/// Near-invisible elevation for light mode; a 1px divider border stands in for
/// elevation in dark mode where soft shadows read as muddy.
struct COShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        if scheme == .dark {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
        } else {
            content
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
        }
    }
}

extension View {
    /// Applies the Crossed Out card elevation treatment.
    func coShadow(cornerRadius: CGFloat = 14) -> some View {
        modifier(COShadowModifier(cornerRadius: cornerRadius))
    }
}
