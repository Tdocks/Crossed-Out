import SwiftUI
import UIKit

// MARK: - Font Name Resolution

/// Returns the first candidate PostScript/family name that UIKit can actually
/// instantiate, or nil if none resolve (so callers can fall back to system).
func resolvedFontName(_ candidates: [String]) -> String? {
    for name in candidates {
        if UIFont(name: name, size: 12) != nil {
            return name
        }
    }
    return nil
}

private enum FontCandidates {
    static let scripture = ["PlayfairDisplay-Regular", "Playfair Display", "PlayfairDisplay"]
    static let scriptureItalic = ["PlayfairDisplay-Italic", "Playfair Display Italic", "PlayfairDisplay-Regular", "Playfair Display"]
    static let displaySemibold = ["PlayfairDisplay-SemiBold", "PlayfairDisplay-Bold", "PlayfairDisplay-Regular", "Playfair Display"]
    static let ui = ["Inter-Regular", "Inter", "InterVariable"]
    static let uiItalic = ["Inter-Italic", "Inter", "Inter-Regular"]
}

// MARK: - Crossed Out Typefaces

extension Font {
    /// Playfair Display for Scripture and long reading passages.
    static func coScripture(_ size: CGFloat, italic: Bool = false) -> Font {
        let candidates = italic ? FontCandidates.scriptureItalic : FontCandidates.scripture
        if let name = resolvedFontName(candidates) {
            return .custom(name, size: size)
        }
        let base = Font.system(size: size, design: .serif)
        return italic ? base.italic() : base
    }

    /// Playfair Display for display headlines. Applies a weight because the
    /// bundled Playfair is a variable font without discrete named PostScript faces.
    static func coDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if let name = resolvedFontName(FontCandidates.displaySemibold) {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, design: .serif).weight(weight)
    }

    /// Inter for all UI chrome and body copy.
    static func coUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = resolvedFontName(FontCandidates.ui) {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, design: .default).weight(weight)
    }

    /// Inter italic for quiet emphasis in UI copy.
    static func coUIItalic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = resolvedFontName(FontCandidates.uiItalic) {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, design: .default).weight(weight).italic()
    }
}

// MARK: - Debug

enum Typography {
    /// Prints every registered font family and face. Call guarded by #if DEBUG.
    static func debugPrintFonts() {
        #if DEBUG
        print("=== Crossed Out — Registered Fonts ===")
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family).sorted() {
                print("   • \(name)")
            }
        }
        print("======================================")
        #endif
    }
}
