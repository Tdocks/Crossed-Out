import SwiftUI

/// Real verse selection for the Bridge composer — curated starters for the
/// chosen situation, pastoral query expansion for semantic search, optional
/// Kyra re-rank over real corpus hits (grounded: only refs from the DB),
/// plus keyword full-text search. Replaces the old VersePickerStub.
struct BridgeVersePicker: View {

    struct Selection: Hashable {
        let ref: String
        let text: String
        let book: String
        let chapter: Int
        let verse: Int
    }

    /// Situation from the composer, if the sender picked one — drives
    /// curated starters and a better default search query.
    var situation: BridgeSituation? = nil
    var onSelect: (Selection) -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var byMeaning = true
    @State private var results: [BibleSearchResult] = []
    @State private var curated: [BibleSearchResult] = []
    @State private var searching = false
    @State private var kyraRanking = false
    @State private var searchFailed = false
    @State private var hasSearched = false
    @State private var kyraNote: String?
    @State private var sectionLabel: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(headerCopy)
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(3)

                HStack(spacing: 8) {
                    COIcon(.search, size: 16, color: .coInkTertiary)
                    TextField("Search Scripture…", text: $query)
                        .font(.coUI(15))
                        .foregroundColor(.coInk)
                        .focused($searchFocused)
                        .onSubmit { runSearch(useKyra: false) }
                    if searching || kyraRanking { ProgressView() }
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
                    COChip(text: "By meaning", selected: byMeaning) {
                        byMeaning = true
                    }
                    COChip(text: "Exact words", selected: !byMeaning) {
                        byMeaning = false
                    }
                    Spacer()
                }

                kyraRow

                if let kyraNote {
                    Text(kyraNote)
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                }

                if searchFailed {
                    Text("Search didn't go through. Check your connection and try again.")
                        .font(.coUI(12))
                        .foregroundColor(.coCrossRed)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !curated.isEmpty && !hasSearched {
                            sectionHeader("Suggested for \(situation?.rawValue ?? "this")")
                            ForEach(curated) { result in
                                resultRow(result)
                            }
                        }

                        if let sectionLabel, !results.isEmpty {
                            sectionHeader(sectionLabel)
                        }

                        if results.isEmpty && hasSearched && !searching && !searchFailed && !kyraRanking {
                            Text("Nothing found — try different words, or ask Kyra to refine.")
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
            .task { await bootstrap() }
        }
    }

    private var headerCopy: String {
        if let situation {
            return "Pick a verse that meets someone who is \(situation.promptClause). Start with a suggestion below, search by meaning, or ask Kyra to refine."
        }
        return "Find a verse that says what you mean. Try describing the situation — like \u{201C}comfort after losing someone\u{201D}."
    }

    private var kyraRow: some View {
        Button {
            runSearch(useKyra: true)
        } label: {
            HStack(spacing: 6) {
                COIcon(.prayer, size: 14, color: .coOlive)
                Text(kyraRanking ? "Kyra is choosing…" : "Ask Kyra to refine picks")
                    .font(.coUI(13, weight: .medium))
                    .foregroundColor(.coOlive)
            }
        }
        .buttonStyle(.plain)
        .disabled(searching || kyraRanking || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.coUI(11, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(.coInkTertiary)
            .padding(.top, 4)
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

    // MARK: - Load curated + seed query

    private func bootstrap() async {
        if let situation {
            query = situation.verseSearchSeed
            curated = await loadCurated(for: situation)
            // Auto-run a pastoral semantic search so the first screen isn't empty.
            await performSearch(useKyra: false)
        } else {
            searchFocused = true
        }
    }

    private func loadCurated(for situation: BridgeSituation) async -> [BibleSearchResult] {
        var out: [BibleSearchResult] = []
        for ref in situation.curatedVerseRefs {
            if let hit = try? await SupabaseService.shared.fetchBibleVerse(
                book: ref.book, chapter: ref.chapter, verse: ref.verse, translation: "BSB"
            ) {
                out.append(hit)
            }
        }
        return out
    }

    // MARK: - Search

    private func runSearch(useKyra: Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !searching, !kyraRanking else { return }
        Task { await performSearch(useKyra: useKyra) }
    }

    private func performSearch(useKyra: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if useKyra {
            kyraRanking = true
        } else {
            searching = true
        }
        searchFailed = false
        kyraNote = nil

        do {
            let candidates: [BibleSearchResult]
            if byMeaning {
                let expanded = BridgeVerseSearch.expandedQuery(trimmed, situation: situation)
                candidates = try await SupabaseService.shared.searchBibleSemantic(
                    query: expanded, translation: "BSB"
                )
            } else {
                candidates = try await SupabaseService.shared.searchBible(
                    query: trimmed, translation: "BSB"
                )
            }

            if useKyra {
                let ranked = await BridgeVerseSearch.rankWithKyra(
                    query: trimmed,
                    situation: situation,
                    candidates: candidates,
                    firstName: appState.profile.firstName
                )
                switch ranked {
                case .ranked(let picks):
                    results = picks
                    sectionLabel = "Kyra’s picks (from real Scripture)"
                    kyraNote = "Kyra only chose from verses already in the Bible — nothing invented."
                case .limitReached:
                    results = Array(candidates.prefix(8))
                    sectionLabel = "By meaning"
                    kyraNote = "You've reached today's Kyra limit — showing the pastoral search results instead."
                case .failed:
                    results = Array(candidates.prefix(8))
                    sectionLabel = "By meaning"
                    kyraNote = "Kyra couldn't refine just now — showing the search results."
                }
            } else {
                let curatedIDs = Set(curated.map(\.id))
                let filtered = candidates.filter { !curatedIDs.contains($0.id) }
                results = Array(filtered.prefix(12))
                sectionLabel = curated.isEmpty
                    ? (byMeaning ? "By meaning" : "Exact words")
                    : "More that may fit"
            }
            hasSearched = true
        } catch {
            searchFailed = true
        }

        searching = false
        kyraRanking = false
    }
}

// MARK: - Pastoral search helpers

enum BridgeVerseSearch {
    /// Expand a short situation phrase into a semantic query that steers
    /// embeddings toward comfort/welcome rather than fear/judgment keyword hits.
    static func expandedQuery(_ raw: String, situation: BridgeSituation?) -> String {
        if let situation {
            return situation.semanticSearchQuery
        }
        let lower = raw.lowercased()
        // Lightweight free-text expansions for common Bridge intents.
        if lower.contains("nervous") || lower.contains("intimidate") || lower.contains("scared of church") {
            return "gentle welcome belonging peace for someone afraid or nervous to walk into church; God's kindness, not fear or judgment"
        }
        if lower.contains("grief") || lower.contains("loss") || lower.contains("died") || lower.contains("mourning") {
            return "comfort for grief and loss; God near the brokenhearted; hope without minimizing pain"
        }
        if lower.contains("lonely") || lower.contains("alone") {
            return "God's nearness in loneliness; you are not forsaken; companionship and belonging"
        }
        if lower.contains("hurt by") || lower.contains("angry at church") || lower.contains("church hurt") {
            return "healing after religious harm; God's gentle heart vs human hypocrisy; rest for the wounded"
        }
        return "a gentle, hopeful Scripture for someone who is \(raw); comfort and presence, not condemnation"
    }

    enum KyraRankResult {
        case ranked([BibleSearchResult])
        case limitReached
        case failed
    }

    /// Ask Kyra to pick up to 5 refs **only** from `candidates`. Grounded:
    /// anything not in the candidate set is dropped.
    static func rankWithKyra(
        query: String,
        situation: BridgeSituation?,
        candidates: [BibleSearchResult],
        firstName: String?
    ) async -> KyraRankResult {
        let pool = Array(candidates.prefix(16))
        guard !pool.isEmpty else { return .failed }

        let catalog = pool.enumerated().map { idx, v in
            "\(idx + 1). \(v.book) \(v.chapter):\(v.verse) — \(v.text)"
        }.joined(separator: "\n")

        let context = situation.map { "They are \($0.promptClause)." } ?? "Situation: \(query)."
        let prompt = """
        I'm sending a personal Scripture bridge to a friend. \(context) \
        My search was: "\(query)".

        Below are REAL Bible verses (Berean Standard Bible). Pick the 3 to 5 that would feel \
        most gentle, hopeful, and non-manipulative for them — never shame, fear, or pressure. \
        Prefer welcome, belonging, God's kindness, and honest comfort.

        Return ONLY a comma-separated list of references exactly as written \
        (e.g. John 14:27, Romans 15:7). No commentary.

        Verses:
        \(catalog)
        """

        do {
            let text = try await SupabaseService.shared.askKyra(
                messages: [ChatMessage(role: .user, text: prompt)],
                firstName: firstName
            )
            let picks = parseRefs(text, from: pool)
            return picks.isEmpty ? .failed : .ranked(picks)
        } catch KyraServiceError.dailyLimitReached {
            return .limitReached
        } catch {
            return .failed
        }
    }

    private static func parseRefs(_ text: String, from pool: [BibleSearchResult]) -> [BibleSearchResult] {
        let byRef = Dictionary(uniqueKeysWithValues: pool.map {
            ("\($0.book) \($0.chapter):\($0.verse)".lowercased(), $0)
        })
        // Also index without spaces around colon / common book aliases.
        var aliases: [String: BibleSearchResult] = byRef
        for v in pool {
            aliases["\(v.book.lowercased())\(v.chapter):\(v.verse)"] = v
            if v.book == "Psalms" {
                aliases["psalm \(v.chapter):\(v.verse)"] = v
                aliases["psalms \(v.chapter):\(v.verse)"] = v
            }
        }

        let tokens = text
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var ordered: [BibleSearchResult] = []
        var seen = Set<String>()
        for token in tokens {
            let key = token.lowercased()
                .replacingOccurrences(of: "  ", with: " ")
            if let hit = aliases[key] ?? fuzzyMatch(token, in: pool), !seen.contains(hit.id) {
                ordered.append(hit)
                seen.insert(hit.id)
            }
        }
        return ordered
    }

    private static func fuzzyMatch(_ token: String, in pool: [BibleSearchResult]) -> BibleSearchResult? {
        let pattern = #"^\s*([1-3]?\s*[A-Za-z]+)\s+(\d+):(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)),
              let bookR = Range(match.range(at: 1), in: token),
              let chR = Range(match.range(at: 2), in: token),
              let vR = Range(match.range(at: 3), in: token),
              let ch = Int(token[chR]),
              let verse = Int(token[vR]) else { return nil }
        let book = String(token[bookR])
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let bookNorm = book.lowercased() == "psalm" ? "Psalms" : book
        return pool.first {
            $0.chapter == ch && $0.verse == verse &&
            ($0.book.caseInsensitiveCompare(bookNorm) == .orderedSame ||
             ($0.book == "Psalms" && bookNorm.lowercased().hasPrefix("psalm")))
        }
    }
}
