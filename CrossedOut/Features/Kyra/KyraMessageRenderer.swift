import SwiftUI

// MARK: - Kyra message renderer

/// Renders a completed Kyra message with light markdown support instead of
/// leaking raw characters into the UI:
///   * `*italic*` / `**bold**`  → real inline emphasis (AttributedString)
///   * lines starting with `>`  → an elegant Scripture/quote block: the
///     literal caret is stripped and the text is set in the serif scripture
///     face behind a thin gold accent rule
///   * `- ` / `* ` bullets and `1.` numbered lines → tidy list rows
///   * `#` headings → small semibold headers (no raw hashes)
/// Everything else renders as normal paragraphs. Deterministic string
/// parsing only — no AI, no web view.
struct KyraMessageBody: View {

    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.blocks(from: text).enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
    }

    // MARK: Block model

    enum Block: Equatable {
        case paragraph(String)
        case quote(String)
        case bullet(String)
        case numbered(String, String)   // marker ("1."), content
        case heading(String)
    }

    // MARK: Parsing

    static func blocks(from text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var quote: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph = []
            }
        }
        func flushQuote() {
            if !quote.isEmpty {
                blocks.append(.quote(quote.joined(separator: " ")))
                quote = []
            }
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                flushQuote()
                continue
            }

            if line.hasPrefix(">") {
                flushParagraph()
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flushParagraph()
                flushQuote()
                blocks.append(.bullet(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                continue
            }

            if let match = line.range(of: #"^\d{1,2}\.\s+"#, options: .regularExpression) {
                flushParagraph()
                flushQuote()
                let marker = String(line[..<match.upperBound]).trimmingCharacters(in: .whitespaces)
                blocks.append(.numbered(marker, String(line[match.upperBound...])))
                continue
            }

            if line.hasPrefix("#") {
                flushParagraph()
                flushQuote()
                let heading = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if !heading.isEmpty { blocks.append(.heading(heading)) }
                continue
            }

            flushQuote()
            paragraph.append(line)
        }

        flushParagraph()
        flushQuote()
        return blocks
    }

    /// Inline markdown (`*italic*`, `**bold**`, backticks) → AttributedString.
    /// Falls back to the literal text if parsing ever fails.
    private static func inline(_ string: String) -> AttributedString {
        if let parsed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(string)
    }

    // MARK: Rendering

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .paragraph(let content):
            Text(Self.inline(content))
                .font(.coUI(14.5))
                .foregroundColor(.coInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

        case .quote(let content):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.coGold)
                    .frame(width: 3)
                Text(Self.inline(content))
                    .font(.coScripture(16))
                    .foregroundColor(.coInk)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 2)
            .padding(.vertical, 2)

        case .bullet(let content):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.coUI(14.5))
                    .foregroundColor(.coInkTertiary)
                Text(Self.inline(content))
                    .font(.coUI(14.5))
                    .foregroundColor(.coInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 2)

        case .numbered(let marker, let content):
            HStack(alignment: .top, spacing: 8) {
                Text(marker)
                    .font(.coUI(14.5, weight: .medium))
                    .foregroundColor(.coInkTertiary)
                Text(Self.inline(content))
                    .font(.coUI(14.5))
                    .foregroundColor(.coInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 2)

        case .heading(let content):
            Text(Self.inline(content))
                .font(.coUI(14, weight: .semibold))
                .foregroundColor(.coInk)
                .padding(.top, 2)
        }
    }
}

#Preview {
    ScrollView {
        KyraMessageBody(text: """
        That's a heavy thing to carry, and I'm glad you said it plainly. \
        Many Christians find that **naming the fear** is the first faithful step.

        > "Be anxious for nothing, but in everything, by prayer and petition, \
        with thanksgiving, present your requests to God." — Philippians 4:6 (BSB)

        A few small steps for today:
        - Read the verse slowly, twice
        - *Pray it back* in your own words
        1. Tell one trusted person what you told me
        """)
        .padding(20)
    }
    .background(Color.coPaper)
}
