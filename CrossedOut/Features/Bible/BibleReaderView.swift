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

    @State private var currentTranslation: BibleTranslation = .bsb
    @State private var currentBook: String = "John"
    @State private var currentChapterNum: Int = 14
    @State private var chapterData: BibleChapter = MockData.john14

    var body: some View {
        Group {
            if isPushed {
                content
            } else {
                NavigationStack { content }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                readingBody
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
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
            NotesListSheet(book: currentBook, chapterNum: currentChapterNum, notes: Array(notes.values)) { verseNumber in
                if let verse = chapterData.verses.first(where: { $0.number == verseNumber }) {
                    noteSheetVerse = verse
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            if isPushed {
                Button { dismiss() } label: {
                    COIcon(.chevronRight, size: 20, color: .coInkSecondary)
                        .rotationEffect(.degrees(180))
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
            Button { } label: {
                COIcon(.more, size: 20, color: .coInkSecondary)
            }
            .buttonStyle(.plain)
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
            if let first = chapterData.verses.first {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(currentChapterNum)")
                        .font(.coDisplay(44, weight: .semibold))
                        .foregroundColor(.coInk)
                        .fixedSize()
                    verseParagraph(first)
                }
                ForEach(Array(chapterData.verses.dropFirst())) { verse in
                    verseParagraph(verse)
                }
            }
            chapterNavRow
        }
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
        return verseText(verse)
            .lineSpacing(9)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, isOn ? 8 : 0)
            .padding(.vertical, isOn ? 4 : 0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? Color.coGold.opacity(0.15) : Color.clear)
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
                toolbarItem(.study, "Study") { }
                toolbarItem(.note, "Notes") { showNotesList = true }
                toolbarItem(.highlight, "Highlight") { }
                toolbarItem(.share, "Share") { }
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

    private func selectChapter(book: String, chapterNum: Int) {
        currentBook = book
        currentChapterNum = chapterNum
        highlighted = []
        notes = [:]
        bookmarked = []
        Task {
            await loadChapter(translation: currentTranslation, book: book, chapterNum: chapterNum)
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
        }
        if let fetchedHighlights = try? await SupabaseService.shared.fetchHighlights(
            book: book, chapter: chapterNum
        ) {
            highlighted = fetchedHighlights
        }
        if let fetchedNotes = try? await SupabaseService.shared.fetchNotes(book: book, chapter: chapterNum) {
            notes = Dictionary(uniqueKeysWithValues: fetchedNotes.map { ($0.verse, $0) })
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
            notes = Dictionary(uniqueKeysWithValues: fetchedNotes.map { ($0.verse, $0) })
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
    let current: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(BibleBooks.all, id: \.self) { name in
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

private struct NotesListSheet: View {
    let book: String
    let chapterNum: Int
    let notes: [VerseNote]
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTES — \(book) \(chapterNum)")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.6)
                .foregroundColor(.coInkTertiary)
            if notes.isEmpty {
                Text("No notes yet for this chapter.")
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(notes.sorted(by: { $0.verse < $1.verse })) { note in
                            Button {
                                dismiss()
                                onSelect(note.verse)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Verse \(note.verse)")
                                        .font(.coUI(12, weight: .semibold))
                                        .foregroundColor(.coInkTertiary)
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
    }
}

// MARK: - Preview

#Preview {
    BibleReaderView()
        .environmentObject(AppState())
}
