import SwiftUI

// MARK: - Bible Reader

struct BibleReaderView: View {
    var isPushed: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var showChapters = false
    @State private var highlighted: Set<Int> = []

    private let chapter = MockData.john14

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
        .sheet(isPresented: $showChapters) {
            ChapterPickerSheet(book: chapter.book, current: chapter.chapter)
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
                    Text("\(chapter.book) \(chapter.chapter)")
                        .font(.coUI(16, weight: .semibold))
                        .foregroundColor(.coInk)
                    Text(chapter.translation)
                        .font(.coUI(9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(.coInkTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
                }
            }
            .buttonStyle(.plain)
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

    // MARK: Reading Body

    private var readingBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading
            HStack(alignment: .top, spacing: 12) {
                Text("\(chapter.chapter)")
                    .font(.coDisplay(44, weight: .semibold))
                    .foregroundColor(.coInk)
                    .fixedSize()
                verseParagraph(chapter.verses[0])
            }
            ForEach(Array(chapter.verses.dropFirst())) { verse in
                verseParagraph(verse)
            }
        }
    }

    private var sectionHeading: some View {
        HStack(spacing: 6) {
            COIcon(.bible, size: 13, color: .coCrossRed)
            Text(chapter.heading)
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(.coCrossRed)
        }
    }

    private func verseText(_ verse: BibleVerse) -> Text {
        Text("\(verse.number) ")
            .font(.coUI(11, weight: .semibold))
            .foregroundColor(.coInkTertiary)
            .baselineOffset(6)
        + Text(verse.text)
            .font(.coScripture(19))
            .foregroundColor(.coInk)
    }

    private func verseParagraph(_ verse: BibleVerse) -> some View {
        let isOn = highlighted.contains(verse.number)
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
            .contentShape(Rectangle())
            .onLongPressGesture {
                withAnimation(.easeOut(duration: 0.2)) {
                    if isOn { highlighted.remove(verse.number) }
                    else { highlighted.insert(verse.number) }
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
    }

    // MARK: Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            CODivider()
            HStack(spacing: 0) {
                toolbarItem(.study, "Study")
                toolbarItem(.note, "Notes")
                toolbarItem(.highlight, "Highlight")
                toolbarItem(.share, "Share")
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(Color.coPaper)
    }

    private func toolbarItem(_ icon: COIconName, _ label: String) -> some View {
        Button { } label: {
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
}

// MARK: - Chapter Picker Sheet

private struct ChapterPickerSheet: View {
    let book: String
    let current: Int
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(book)
                .font(.coDisplay(24, weight: .semibold))
                .foregroundColor(.coInk)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(1...21, id: \.self) { n in
                    Button { dismiss() } label: {
                        Text("\(n)")
                            .font(.coUI(15, weight: n == current ? .semibold : .regular))
                            .foregroundColor(n == current ? .coCrossRed : .coInk)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(n == current ? Color.coCrossRed.opacity(0.08) : Color.clear))
                            .overlay(Circle().strokeBorder(
                                n == current ? Color.coCrossRed : Color.coDivider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
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
