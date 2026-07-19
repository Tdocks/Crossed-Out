import SwiftUI

/// Real verse selection for the Bridge composer — keyword full-text search
/// and semantic "search by meaning" over the actual Bible corpus (the same
/// paths the Bible tab uses). Replaces the old VersePickerStub.
struct BridgeVersePicker: View {

    struct Selection: Hashable {
        let ref: String
        let text: String
        let book: String
        let chapter: Int
        let verse: Int
    }

    var onSelect: (Selection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var byMeaning = true
    @State private var results: [BibleSearchResult] = []
    @State private var searching = false
    @State private var searchFailed = false
    @State private var hasSearched = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Find a verse that says what you mean. Try describing the situation — like \u{201C}comfort after losing someone\u{201D}.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(3)

                HStack(spacing: 8) {
                    COIcon(.search, size: 16, color: .coInkTertiary)
                    TextField("Search Scripture…", text: $query)
                        .font(.coUI(15))
                        .foregroundColor(.coInk)
                        .focused($searchFocused)
                        .onSubmit { runSearch() }
                    if searching { ProgressView() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )

                HStack(spacing: 10) {
                    COChip(text: "By meaning", selected: byMeaning) { byMeaning = true }
                    COChip(text: "Exact words", selected: !byMeaning) { byMeaning = false }
                    Spacer()
                }

                if searchFailed {
                    Text("Search didn't go through. Check your connection and try again.")
                        .font(.coUI(12))
                        .foregroundColor(.coCrossRed)
                }

                ScrollView {
                    VStack(spacing: 10) {
                        if results.isEmpty && hasSearched && !searching && !searchFailed {
                            Text("Nothing found — try different words.")
                                .font(.coUI(13))
                                .foregroundColor(.coInkTertiary)
                                .padding(.top, 12)
                        }
                        ForEach(results) { result in
                            resultRow(result)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(20)
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("Choose a Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { searchFocused = true }
        }
    }

    private func resultRow(_ result: BibleSearchResult) -> some View {
        Button {
            onSelect(Selection(
                ref: "\(result.book) \(result.chapter):\(result.verse)",
                text: result.text,
                book: result.book,
                chapter: result.chapter,
                verse: result.verse
            ))
            dismiss()
        } label: {
            COCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(result.book) \(result.chapter):\(result.verse)")
                        .font(.coUI(12, weight: .semibold))
                        .foregroundColor(.coCrossRed)
                    Text(result.text)
                        .font(.coScripture(15))
                        .foregroundColor(.coInk)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !searching else { return }
        searching = true
        searchFailed = false
        let semantic = byMeaning
        Task {
            do {
                if semantic {
                    results = try await SupabaseService.shared.searchBibleSemantic(query: trimmed, translation: "BSB")
                } else {
                    results = try await SupabaseService.shared.searchBible(query: trimmed, translation: "BSB")
                }
                hasSearched = true
            } catch {
                searchFailed = true
            }
            searching = false
        }
    }
}
