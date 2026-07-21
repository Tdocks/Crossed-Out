import SwiftUI

// MARK: - Bible Books

private enum BibleBooks {
    static let all: [String] = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
        "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
        "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
        "Zephaniah", "Haggai", "Zechariah", "Malachi",
        "Matthew", "Mark", "Luke", "John", "Acts",
        "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy",
        "2 Timothy", "Titus", "Philemon", "Hebrews", "James",
        "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
        "Jude", "Revelation"
    ]

    /// First 39 books (Genesis–Malachi) and last 27 (Matthew–Revelation).
    static let oldTestament: [String] = Array(all.prefix(39))
    static let newTestament: [String] = Array(all.suffix(27))

    /// Canonical position of a book, for sorting saved notes/highlights.
    static func canonicalIndex(_ book: String) -> Int {
        all.firstIndex(of: book) ?? Int.max
    }

    static let chapterCounts: [String: Int] = [
        "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36, "Deuteronomy": 34,
        "Joshua": 24, "Judges": 21, "Ruth": 4, "1 Samuel": 31, "2 Samuel": 24,
        "1 Kings": 22, "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36, "Ezra": 10,
        "Nehemiah": 13, "Esther": 10, "Job": 42, "Psalms": 150, "Proverbs": 31,
        "Ecclesiastes": 12, "Song of Solomon": 8, "Isaiah": 66, "Jeremiah": 52, "Lamentations": 5,
        "Ezekiel": 48, "Daniel": 12, "Hosea": 14, "Joel": 3, "Amos": 9,
        "Obadiah": 1, "Jonah": 4, "Micah": 7, "Nahum": 3, "Habakkuk": 3,
        "Zephaniah": 3, "Haggai": 2, "Zechariah": 14, "Malachi": 4,
        "Matthew": 28, "Mark": 16, "Luke": 24, "John": 21, "Acts": 28,
        "Romans": 16, "1 Corinthians": 16, "2 Corinthians": 13, "Galatians": 6, "Ephesians": 6,
        "Philippians": 4, "Colossians": 4, "1 Thessalonians": 5, "2 Thessalonians": 3, "1 Timothy": 6,
        "2 Timothy": 4, "Titus": 3, "Philemon": 1, "Hebrews": 13, "James": 5,
        "1 Peter": 5, "2 Peter": 3, "1 John": 5, "2 John": 1, "3 John": 1,
        "Jude": 1, "Revelation": 22
    ]
}

// MARK: - Bible Reader

struct BibleReaderView: View {
    var isPushed: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var showChapters = false
    @State private var highlighted: Set<Int> = []
    @State private var notes: [Int: VerseNote] = [:]
    @State private var bookmarked: Set<Int> = []
    @State private var noteSheetVerse: BibleVerse? = nil
    @State private var showNotesList = false
    @State private var showHighlightsList = false
    @State private var showSearch = false
    @State private var pendingScrollVerse: Int? = nil
    @State private var emphasizedVerse: Int? = nil

    @State private var currentTranslation: BibleTranslation = .bsb
    @State private var currentBook: String = "John"
    @State private var currentChapterNum: Int = 14
    @State private var chapterData: BibleChapter = MockData.john14
    /// True once a fetch has ever returned real chapter content. While this
    /// is false, `chapterData` is still `MockData.john14` — the bundled
    /// offline stub — so the reader shows a "limited preview" notice rather
    /// than silently passing off 4 verses as the whole chapter.
    @State private var hasFetchedSuccessfully = false

    /// True when the header (`currentBook`/`currentChapterNum`) no longer
    /// matches the book/chapter `chapterData` actually holds — i.e. a
    /// chapter switch was requested but the fetch for it failed or came
    /// back empty, leaving the previous chapter's verses on screen. Real
    /// scripture under the wrong heading is worse than an honest error, so
    /// this drives an inline retry state instead of silently keeping the
    /// stale verses.
    private var chapterMismatch: Bool {
        chapterData.book != currentBook || chapterData.chapter != currentChapterNum
    }

    var body: some View {
        Group {
            if isPushed {
                content.hidesTabBar()
            } else {
                NavigationStack { content }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBar
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    readingBody
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
                .onChange(of: pendingScrollVerse) { _, verseNum in
                    guard let verseNum else { return }
                    withAnimation(.easeOut(duration: 0.4)) {
                        proxy.scrollTo(verseNum, anchor: .center)
                    }
                    emphasizedVerse = verseNum
                    pendingScrollVerse = nil
                    Task {
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        withAnimation(.easeOut(duration: 0.5)) {
                            if emphasizedVerse == verseNum { emphasizedVerse = nil }
                        }
                    }
                }
            }
            bottomToolbar
                .padding(.bottom, isPushed ? 0 : 58)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task {
            await loadChapter(translation: currentTranslation, book: currentBook, chapterNum: currentChapterNum)
        }
        .sheet(isPresented: $showChapters) {
            ChapterPickerSheet(currentBook: currentBook, currentChapter: currentChapterNum) { book, chapterNum in
                selectChapter(book: book, chapterNum: chapterNum)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $noteSheetVerse) { verse in
            NoteSheet(
                book: currentBook,
                chapterNum: currentChapterNum,
                verse: verse,
                existingNote: notes[verse.number],
                onSave: { text in
                    Task { await saveNoteAction(verse: verse, text: text) }
                },
                onDelete: {
                    Task { await deleteNoteAction(verse: verse) }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNotesList) {
            NotesListSheet(currentBook: currentBook) { book, chapterNum, verse in
                selectChapter(book: book, chapterNum: chapterNum, scrollToVerse: verse)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHighlightsList) {
            HighlightsListSheet(currentBook: currentBook) { book, chapterNum, verse in
                selectChapter(book: book, chapterNum: chapterNum, scrollToVerse: verse)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSearch) {
            BibleSearchSheet(translation: currentTranslation) { book, chapterNum, verseNum in
                selectChapter(book: book, chapterNum: chapterNum, scrollToVerse: verseNum)
            }
            .presentationDetents([.large])
        }
    }

    private var highlightedVerses: [BibleVerse] {
        chapterData.verses.filter { highlighted.contains($0.number) }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            if isPushed {
                Button { dismiss() } label: {
                    COIcon(.chevronRight, size: 20, color: .coInkSecondary)
                        .rotationEffect(.degrees(180))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 20, height: 20)
            }
            Spacer()
            Button { showChapters = true } label: {
                HStack(spacing: 8) {
                    Text("\(currentBook) \(currentChapterNum)")
                        .font(.coUI(16, weight: .semibold))
                        .foregroundColor(.coInk)
                }
            }
            .buttonStyle(.plain)
            translationChip
            Spacer()
            Button { showSearch = true } label: {
                COIcon(.search, size: 19, color: .coInkSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu {
                Button { showNotesList = true } label: {
                    Label("Notes", systemImage: "note.text")
                }
                Button { showHighlightsList = true } label: {
                    Label("Highlights", systemImage: "highlighter")
                }
                Button { showChapters = true } label: {
                    Label("Jump to Chapter", systemImage: "book")
                }
                ShareLink(item: chapterShareText) {
                    Label("Share Chapter", systemImage: "square.and.arrow.up")
                }
            } label: {
                COIcon(.more, size: 20, color: .coInkSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { CODivider() }
    }

    private var translationChip: some View {
        Menu {
            ForEach(BibleTranslation.allCases, id: \.self) { t in
                Button {
                    selectTranslation(t)
                } label: {
                    if t == currentTranslation {
                        Label(t.rawValue, systemImage: "checkmark")
                    } else {
                        Text(t.rawValue)
                    }
                }
            }
        } label: {
            Text(currentTranslation.rawValue)
                .font(.coUI(9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(.coInkTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
        }
    }

    // MARK: Reading Body

    private var readingBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading
            if chapterMismatch {
                chapterErrorState
            } else {
                if !hasFetchedSuccessfully {
                    offlinePreviewBanner
                }
                if let first = chapterData.verses.first {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(currentChapterNum)")
                            .font(.coDisplay(44, weight: .semibold))
                            .foregroundColor(.coInk)
                            .fixedSize()
                        verseParagraph(first)
                            .id(first.number)
                    }
                    ForEach(Array(chapterData.verses.dropFirst())) { verse in
                        verseParagraph(verse)
                            .id(verse.number)
                    }
                }
            }
            chapterNavRow
        }
    }

    /// Shown in place of stale verses when the currently-selected chapter
    /// failed to load — see `chapterMismatch`. Mirrors the existing
    /// "Couldn't load services" / "Try Again" pattern used in AttendView.
    private var chapterErrorState: some View {
        COEmptyState(
            icon: .bible,
            title: "Couldn't load this chapter",
            message: "Check your connection and try again.",
            actionTitle: "Try Again",
            action: {
                Task {
                    await loadChapter(translation: currentTranslation, book: currentBook, chapterNum: currentChapterNum)
                }
            }
        )
    }

    /// A quiet notice shown when the reader is displaying the bundled
    /// offline stub (`MockData.john14`) because no fetch has succeeded yet —
    /// so the user isn't misled into thinking a 4-verse stub is the whole
    /// chapter.
    private var offlinePreviewBanner: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.coInkTertiary)
                .frame(width: 5, height: 5)
            Text("Offline — limited preview")
                .font(.coUI(11, weight: .semibold))
                .foregroundColor(.coInkTertiary)
        }
        .padding(.bottom, 2)
    }

    private var chapterNavRow: some View {
        let maxChapter = BibleBooks.chapterCounts[currentBook] ?? 1
        return HStack {
            if currentChapterNum > 1 {
                Button { goToPreviousChapter() } label: {
                    Text("← Previous")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if currentChapterNum < maxChapter {
                Button { goToNextChapter() } label: {
                    Text("Next →")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 24)
    }

    private var sectionHeading: some View {
        Group {
            if currentBook == "John" && currentChapterNum == 14 {
                HStack(spacing: 6) {
                    COIcon(.bible, size: 13, color: .coCrossRed)
                    Text("Jesus Comforts His Disciples")
                        .font(.coUI(13, weight: .semibold))
                        .foregroundColor(.coCrossRed)
                }
            } else {
                HStack(spacing: 6) {
                    COIcon(.bible, size: 13, color: .coInkTertiary)
                    Text("\(currentBook) \(currentChapterNum)")
                        .font(.coUI(13, weight: .semibold))
                        .foregroundColor(.coInkTertiary)
                }
            }
        }
    }

    private func verseText(_ verse: BibleVerse) -> Text {
        var line = Text("\(verse.number) ")
            .font(.coUI(11, weight: .semibold))
            .foregroundColor(.coInkTertiary)
            .baselineOffset(6)
        if notes[verse.number] != nil {
            line = line
                + Text(Image(systemName: "note.text"))
                    .font(.system(size: 12))
                    .foregroundColor(.coGold)
                    .baselineOffset(2)
                + Text(" ")
                    .font(.coUI(11))
        }
        return line
            + Text(verse.text)
                .font(.coScripture(19))
                .foregroundColor(.coInk)
    }

    private func verseParagraph(_ verse: BibleVerse) -> some View {
        let isOn = highlighted.contains(verse.number)
        let isBookmarked = bookmarked.contains(verse.number)
        let isEmphasized = emphasizedVerse == verse.number
        return verseText(verse)
            .lineSpacing(9)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, (isOn || isEmphasized) ? 8 : 0)
            .padding(.vertical, (isOn || isEmphasized) ? 4 : 0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isEmphasized ? Color.coCrossRed.opacity(0.1)
                            : (isOn ? Color.coGold.opacity(0.15) : Color.clear)
                    )
            )
            .overlay(alignment: .leading) {
                if isBookmarked {
                    Rectangle()
                        .fill(Color.coGold)
                        .frame(width: 3)
                        .padding(.vertical, 2)
                        .offset(x: -14)
                }
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    toggleHighlight(verse)
                } label: {
                    Label(isOn ? "Remove Highlight" : "Highlight", systemImage: "highlighter")
                }
                Button {
                    openNoteSheet(for: verse)
                } label: {
                    Label("Add Note...", systemImage: "note.text")
                }
                Button {
                    toggleBookmark(verse)
                } label: {
                    Label(isBookmarked ? "Remove Bookmark" : "Bookmark",
                          systemImage: isBookmarked ? "bookmark.slash" : "bookmark")
                }
                ShareLink(item: shareText(for: verse)) {
                    Label("Share Verse", systemImage: "square.and.arrow.up")
                }
            }
    }

    // MARK: Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            CODivider()
            HStack(spacing: 0) {
                toolbarItem(.study, "Study") { showChapters = true }
                toolbarItem(.note, "Notes") { showNotesList = true }
                toolbarItem(.highlight, "Highlight") { showHighlightsList = true }
                shareToolbarItem
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(Color.coPaper)
    }

    private func toolbarItem(_ icon: COIconName, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                COIcon(icon, size: 20, color: .coInkSecondary)
                Text(label)
                    .font(.coUI(10))
                    .foregroundColor(.coInkSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var shareToolbarItem: some View {
        ShareLink(item: chapterShareText) {
            VStack(spacing: 5) {
                COIcon(.share, size: 20, color: .coInkSecondary)
                Text("Share")
                    .font(.coUI(10))
                    .foregroundColor(.coInkSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var chapterShareText: String {
        let firstTwo = chapterData.verses.prefix(2)
            .map { "\($0.number) \($0.text)" }
            .joined(separator: " ")
        return "\(currentBook) \(currentChapterNum)\n\n\(firstTwo)\n\n— Crossed Out"
    }

    // MARK: Actions

    private func selectTranslation(_ translation: BibleTranslation) {
        guard translation != currentTranslation else { return }
        currentTranslation = translation
        highlighted = []
        notes = [:]
        bookmarked = []
        Task {
            await loadChapter(translation: translation, book: currentBook, chapterNum: currentChapterNum)
        }
    }

    private func selectChapter(book: String, chapterNum: Int, scrollToVerse: Int? = nil) {
        currentBook = book
        currentChapterNum = chapterNum
        highlighted = []
        notes = [:]
        bookmarked = []
        Task {
            await loadChapter(translation: currentTranslation, book: book, chapterNum: chapterNum)
            if let scrollToVerse {
                // Give SwiftUI a beat to render the freshly loaded chapter
                // before asking the ScrollViewReader to jump to a verse id.
                try? await Task.sleep(nanoseconds: 300_000_000)
                pendingScrollVerse = scrollToVerse
            }
        }
    }

    private func goToPreviousChapter() {
        guard currentChapterNum > 1 else { return }
        selectChapter(book: currentBook, chapterNum: currentChapterNum - 1)
    }

    private func goToNextChapter() {
        let maxChapter = BibleBooks.chapterCounts[currentBook] ?? 1
        guard currentChapterNum < maxChapter else { return }
        selectChapter(book: currentBook, chapterNum: currentChapterNum + 1)
    }

    private func loadChapter(translation: BibleTranslation, book: String, chapterNum: Int) async {
        if let fetched = try? await SupabaseService.shared.fetchChapter(
            translation: translation.rawValue, book: book, chapter: chapterNum
        ), !fetched.verses.isEmpty {
            chapterData = fetched
            hasFetchedSuccessfully = true
        }
        // On failure/empty we deliberately leave `chapterData` untouched.
        // `chapterMismatch` (computed from chapterData vs. currentBook/
        // currentChapterNum, which the caller already updated) picks up
        // the resulting desync and swaps the reading body to an inline
        // retry state instead of showing stale verses under a new heading.
        if let fetchedHighlights = try? await SupabaseService.shared.fetchHighlights(
            book: book, chapter: chapterNum
        ) {
            highlighted = fetchedHighlights
        }
        if let fetchedNotes = try? await SupabaseService.shared.fetchNotes(book: book, chapter: chapterNum) {
            // `uniquingKeysWith:` rather than `uniqueKeysWithValues:` so a
            // stray duplicate row (e.g. from a pre-migration insert that
            // predates the user_notes unique index) can never trap here —
            // the most recently fetched note for a verse wins.
            notes = Dictionary(fetchedNotes.map { ($0.verse, $0) }, uniquingKeysWith: { _, latest in latest })
        } else {
            notes = [:]
        }
        if let fetchedBookmarks = try? await SupabaseService.shared.fetchBookmarks() {
            bookmarked = Set(
                fetchedBookmarks
                    .filter { $0.book == book && $0.chapter == chapterNum }
                    .compactMap { $0.verse }
            )
        } else {
            bookmarked = []
        }
    }

    private func toggleHighlight(_ verse: BibleVerse) {
        let isOn = highlighted.contains(verse.number)
        let turningOn = !isOn
        withAnimation(.easeOut(duration: 0.2)) {
            if isOn { highlighted.remove(verse.number) }
            else { highlighted.insert(verse.number) }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let book = currentBook
        let chapterNum = currentChapterNum
        Task {
            await SupabaseService.shared.setHighlight(
                book: book, chapter: chapterNum, verse: verse.number, on: turningOn
            )
        }
    }

    private func toggleBookmark(_ verse: BibleVerse) {
        let isOn = bookmarked.contains(verse.number)
        let turningOn = !isOn
        withAnimation(.easeOut(duration: 0.2)) {
            if isOn { bookmarked.remove(verse.number) }
            else { bookmarked.insert(verse.number) }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let book = currentBook
        let chapterNum = currentChapterNum
        Task {
            await SupabaseService.shared.setBookmark(
                book: book, chapter: chapterNum, verse: verse.number, on: turningOn
            )
        }
    }

    private func openNoteSheet(for verse: BibleVerse) {
        noteSheetVerse = verse
    }

    private func saveNoteAction(verse: BibleVerse, text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let book = currentBook
        let chapterNum = currentChapterNum
        await SupabaseService.shared.saveNote(book: book, chapter: chapterNum, verse: verse.number, note: trimmed)
        if let fetchedNotes = try? await SupabaseService.shared.fetchNotes(book: book, chapter: chapterNum) {
            // `uniquingKeysWith:` rather than `uniqueKeysWithValues:` so a
            // stray duplicate row (e.g. from a pre-migration insert that
            // predates the user_notes unique index) can never trap here —
            // the most recently fetched note for a verse wins.
            notes = Dictionary(fetchedNotes.map { ($0.verse, $0) }, uniquingKeysWith: { _, latest in latest })
        }
    }

    private func deleteNoteAction(verse: BibleVerse) async {
        guard let id = notes[verse.number]?.id else { return }
        await SupabaseService.shared.deleteNote(id: id)
        notes[verse.number] = nil
    }

    private func shareText(for verse: BibleVerse) -> String {
        "\"\(verse.text)\" — \(currentBook) \(currentChapterNum):\(verse.number) (\(currentTranslation.rawValue))"
    }
}

// MARK: - Chapter Picker Sheet

private struct ChapterPickerSheet: View {
    let currentBook: String
    let currentChapter: Int
    let onSelect: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var book: String
    @State private var showBooks = false

    init(currentBook: String, currentChapter: Int, onSelect: @escaping (String, Int) -> Void) {
        self.currentBook = currentBook
        self.currentChapter = currentChapter
        self.onSelect = onSelect
        _book = State(initialValue: currentBook)
    }

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)

    private var chapterCount: Int {
        BibleBooks.chapterCounts[book] ?? 1
    }

    private var highlightChapter: Int {
        book == currentBook ? currentChapter : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(book)
                    .font(.coDisplay(24, weight: .semibold))
                    .foregroundColor(.coInk)
                Spacer()
                Button {
                    showBooks = true
                } label: {
                    Text("Books")
                        .font(.coUI(13, weight: .semibold))
                        .foregroundColor(.coCrossRed)
                }
                .buttonStyle(.plain)
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(1...chapterCount, id: \.self) { n in
                        Button {
                            onSelect(book, n)
                            dismiss()
                        } label: {
                            Text("\(n)")
                                .font(.coUI(15, weight: n == highlightChapter ? .semibold : .regular))
                                .foregroundColor(n == highlightChapter ? .coCrossRed : .coInk)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(n == highlightChapter ? Color.coCrossRed.opacity(0.08) : Color.clear))
                                .overlay(Circle().strokeBorder(
                                    n == highlightChapter ? Color.coCrossRed : Color.coDivider, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
        .sheet(isPresented: $showBooks) {
            BookPickerSheet(current: book) { selected in
                book = selected
                onSelect(selected, 1)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Book Picker Sheet

private struct BookPickerSheet: View {
    private enum Testament: String, CaseIterable { case old = "Old Testament", new = "New Testament" }

    let current: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var testament: Testament

    init(current: String, onSelect: @escaping (String) -> Void) {
        self.current = current
        self.onSelect = onSelect
        _testament = State(initialValue: BibleBooks.newTestament.contains(current) ? .new : .old)
    }

    private var books: [String] {
        testament == .old ? BibleBooks.oldTestament : BibleBooks.newTestament
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $testament) {
                ForEach(Testament.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(books, id: \.self) { name in
                        Button {
                            onSelect(name)
                            dismiss()
                        } label: {
                            HStack {
                                Text(name)
                                    .font(.coUI(15, weight: name == current ? .semibold : .regular))
                                    .foregroundColor(name == current ? .coCrossRed : .coInk)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        CODivider()
                    }
                }
            }
        }
        .background(Color.coPaper.ignoresSafeArea())
    }
}

// MARK: - Note Sheet

private struct NoteSheet: View {
    let book: String
    let chapterNum: Int
    let verse: BibleVerse
    let existingNote: VerseNote?
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(book: String, chapterNum: Int, verse: BibleVerse, existingNote: VerseNote?,
         onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.book = book
        self.chapterNum = chapterNum
        self.verse = verse
        self.existingNote = existingNote
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: existingNote?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTE — \(book) \(chapterNum):\(verse.number)")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(.coInkTertiary)
            TextField("Write your note...", text: $text, axis: .vertical)
                .font(.coUI(14))
                .foregroundColor(.coInk)
                .lineLimit(5...10)
                .padding(12)
                .frame(minHeight: 120, alignment: .topLeading)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
            COPrimaryButton(title: "Save Note") {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSave(trimmed)
                dismiss()
            }
            if existingNote != nil {
                COSecondaryButton(title: "Delete Note", tint: .coCrossRed) {
                    onDelete()
                    dismiss()
                }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
    }
}

// MARK: - Notes List Sheet

/// Scope for the saved notes / highlights lists.
private enum SavedScope: String, CaseIterable { case all = "All", book = "This Book" }

private struct NotesListSheet: View {
    let currentBook: String
    /// (book, chapter, verse) of the note to jump to.
    let onOpen: (String, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scope: SavedScope = .all
    @State private var allNotes: [SavedNote] = []
    @State private var loading = true

    private var filtered: [SavedNote] {
        allNotes
            .filter { scope == .all || $0.book == currentBook }
            .sorted { a, b in
                let ia = BibleBooks.canonicalIndex(a.book)
                let ib = BibleBooks.canonicalIndex(b.book)
                if ia != ib { return ia < ib }
                if a.chapter != b.chapter { return a.chapter < b.chapter }
                return a.verse < b.verse
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTES")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(.coInkTertiary)

            Picker("", selection: $scope) {
                ForEach(SavedScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                Spacer()
            } else if filtered.isEmpty {
                COEmptyState(
                    icon: .note,
                    title: scope == .all ? "No notes yet" : "No notes in \(currentBook)",
                    message: "Long-press any verse to add one."
                )
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { note in
                            Button {
                                onOpen(note.book, note.chapter, note.verse)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(note.book) \(note.chapter):\(note.verse)")
                                        .font(.coUI(12, weight: .semibold))
                                        .foregroundColor(.coCrossRed)
                                    Text(note.note)
                                        .font(.coUI(14))
                                        .foregroundColor(.coInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            CODivider()
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
        .task {
            allNotes = (try? await SupabaseService.shared.fetchAllNotes()) ?? []
            loading = false
        }
    }
}

// MARK: - Highlights List Sheet

private struct HighlightsListSheet: View {
    let currentBook: String
    /// (book, chapter, verse) of the highlight to jump to.
    let onOpen: (String, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scope: SavedScope = .all
    @State private var allHighlights: [SavedHighlight] = []
    @State private var loading = true

    private var filtered: [SavedHighlight] {
        allHighlights
            .filter { scope == .all || $0.book == currentBook }
            .sorted { a, b in
                let ia = BibleBooks.canonicalIndex(a.book)
                let ib = BibleBooks.canonicalIndex(b.book)
                if ia != ib { return ia < ib }
                if a.chapter != b.chapter { return a.chapter < b.chapter }
                return a.verse < b.verse
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HIGHLIGHTS")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(.coInkTertiary)

            Picker("", selection: $scope) {
                ForEach(SavedScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                Spacer()
            } else if filtered.isEmpty {
                COEmptyState(
                    icon: .highlight,
                    title: scope == .all ? "No highlights yet" : "No highlights in \(currentBook)",
                    message: "Long-press any verse to highlight it."
                )
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { h in
                            HStack(alignment: .center, spacing: 12) {
                                Button {
                                    onOpen(h.book, h.chapter, h.verse)
                                    dismiss()
                                } label: {
                                    Text("\(h.book) \(h.chapter):\(h.verse)")
                                        .font(.coUI(14, weight: .medium))
                                        .foregroundColor(.coInk)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button {
                                    let target = h
                                    allHighlights.removeAll { $0.id == target.id }
                                    Task {
                                        await SupabaseService.shared.setHighlight(
                                            book: target.book, chapter: target.chapter,
                                            verse: target.verse, on: false
                                        )
                                    }
                                } label: {
                                    Text("Remove")
                                        .font(.coUI(12, weight: .semibold))
                                        .foregroundColor(.coCrossRed)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 12)
                            CODivider()
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
        .task {
            allHighlights = (try? await SupabaseService.shared.fetchAllHighlights()) ?? []
            loading = false
        }
    }
}

// MARK: - Bible Search Sheet

/// Keyword search (`search_bible` RPC, migration 0011) vs. Meaning search
/// ("search by meaning" — the `semantic_search` edge function, migration
/// 0014). Kept as a plain enum rather than a Bool so a third mode can be
/// added later without a signature change.
private enum BibleSearchMode: String, CaseIterable {
    case keyword = "Keyword"
    case meaning = "Meaning"
}

/// Search across Scripture — either by exact words/phrase or "by meaning."
/// A quiet study tool, not a search-engine results page: a single field,
/// reference + serif verse snippet per hit, calm empty states, errors
/// swallowed rather than surfaced. Meaning search falls back to keyword
/// search silently if the semantic call fails (no key configured, network
/// error, etc.) — the user never sees an error banner.
private struct BibleSearchSheet: View {
    let translation: BibleTranslation
    let onSelect: (String, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool
    @State private var query: String = ""
    @State private var results: [BibleSearchResult] = []
    @State private var hasSearched = false
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchMode: BibleSearchMode = .keyword

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SEARCH SCRIPTURE")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(.coInkTertiary)

            searchModeToggle

            HStack(spacing: 10) {
                COIcon(.search, size: 15, color: .coInkTertiary)
                TextField(fieldPlaceholder, text: $query)
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
                    .submitLabel(.search)
                    .focused($fieldFocused)
                    .onSubmit { runSearch() }
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        hasSearched = false
                    } label: {
                        Text("Clear")
                            .font(.coUI(12, weight: .semibold))
                            .foregroundColor(.coInkTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(fieldFocused ? Color.coCrossRed : Color.coDivider, lineWidth: 1)
            )

            resultsArea
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
        .onAppear { fieldFocused = true }
    }

    private var fieldPlaceholder: String {
        switch searchMode {
        case .keyword: return "Search words or a phrase..."
        case .meaning: return "Describe what you're carrying..."
        }
    }

    /// A quiet, editorial two-way toggle — deliberately not a native
    /// `.segmented` picker (too chrome-forward for the reader) and not a
    /// pill button pair (DESIGN_LANGUAGE reserves pills for filters/status).
    /// Underline + color shift on the active label, hairline divider below.
    private var searchModeToggle: some View {
        HStack(spacing: 20) {
            ForEach(BibleSearchMode.allCases, id: \.self) { mode in
                let isOn = mode == searchMode
                Button {
                    guard mode != searchMode else { return }
                    searchMode = mode
                    if hasSearched { runSearch() }
                } label: {
                    VStack(spacing: 6) {
                        Text(mode.rawValue)
                            .font(.coUI(13, weight: isOn ? .semibold : .regular))
                            .foregroundColor(isOn ? .coCrossRed : .coInkTertiary)
                        Rectangle()
                            .fill(isOn ? Color.coCrossRed : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var resultsArea: some View {
        if isSearching {
            Spacer()
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            Spacer()
        } else if !hasSearched {
            Spacer()
            COEmptyState(
                icon: .search,
                title: "Search the Bible",
                message: emptyStateMessage
            )
            Spacer()
        } else if results.isEmpty {
            Spacer()
            COEmptyState(
                icon: .search,
                title: "No verses found",
                message: "Try different words or check your spelling."
            )
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { result in
                        Button {
                            dismiss()
                            onSelect(result.book, result.chapter, result.verse)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(result.book) \(result.chapter):\(result.verse)")
                                    .font(.coUI(12, weight: .semibold))
                                    .foregroundColor(.coInkTertiary)
                                Text(result.text)
                                    .font(.coScripture(16))
                                    .foregroundColor(.coInk)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        CODivider()
                    }
                }
            }
        }
    }

    private var emptyStateMessage: String {
        switch searchMode {
        case .keyword:
            return "Find a word, name, or phrase across every verse in \(translation.rawValue)."
        case .meaning:
            return "Describe a feeling or situation, and find verses that speak to it — even without the exact words."
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            hasSearched = false
            return
        }
        searchTask?.cancel()
        isSearching = true
        hasSearched = true
        let mode = searchMode
        let translationValue = translation.rawValue
        searchTask = Task {
            let found = await Self.performSearch(query: trimmed, translation: translationValue, mode: mode)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }

    /// Runs the search for the given mode. Meaning search falls back to
    /// keyword search silently if the semantic call throws (missing
    /// deployment, network error, etc.) — no error banner, matching the
    /// existing "swallow errors into a calm empty state" pattern.
    private static func performSearch(
        query: String, translation: String, mode: BibleSearchMode
    ) async -> [BibleSearchResult] {
        switch mode {
        case .keyword:
            return (try? await SupabaseService.shared.searchBible(
                query: query, translation: translation
            )) ?? []
        case .meaning:
            if let semantic = try? await SupabaseService.shared.searchBibleSemantic(
                query: query, translation: translation
            ) {
                return semantic
            }
            return (try? await SupabaseService.shared.searchBible(
                query: query, translation: translation
            )) ?? []
        }
    }
}

// MARK: - Preview

#Preview {
    BibleReaderView()
        .environmentObject(AppState())
}
