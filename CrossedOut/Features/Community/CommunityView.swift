import SwiftUI
import UIKit

struct CommunityView: View {
    private let segments = ["My Circle", "Church", "Prayer", "Local"]
    @State private var selectedSegment = 0
    @State private var showNewPost = false
    @State private var prayedCount = MockData.prayerRequests.first?.prayedCount ?? 12
    @State private var isPraying = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.coPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        segmentRow
                        COSectionHeader(title: "Prayer Requests", actionTitle: "See all", action: {})
                        prayerCard
                        verseCard
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 90)
                }

                fab
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewPost) { NewPostSheet() }
        }
    }

    private var segmentRow: some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { i in
                VStack(spacing: 8) {
                    Text(segments[i])
                        .font(.coUI(14, weight: i == selectedSegment ? .semibold : .regular))
                        .foregroundColor(i == selectedSegment ? .coInk : .coInkTertiary)
                    Rectangle()
                        .fill(i == selectedSegment ? Color.coCrossRed : Color.clear)
                        .frame(height: 2)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { selectedSegment = i } }
            }
        }
    }

    private var prayerCard: some View {
        let request = MockData.prayerRequests[0]
        return COCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    COAvatar(initials: "JL")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.authorName)
                            .font(.coUI(14, weight: .semibold))
                            .foregroundColor(.coInk)
                        Text(request.timeAgo)
                            .font(.coUI(12))
                            .foregroundColor(.coInkTertiary)
                    }
                    Spacer()
                }
                Text(request.text)
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
                    .lineSpacing(4)
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        COIcon(.heart, size: 16, color: .coInkTertiary)
                        Text("\(prayedCount)")
                            .font(.coUI(13))
                            .foregroundColor(.coInkTertiary)
                    }
                    prayButton
                    Spacer()
                    NavigationLink {
                        BridgeShareView()
                    } label: {
                        Text("Encourage")
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                    }
                }
            }
        }
    }

    private var prayButton: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.easeOut(duration: 0.25)) {
                isPraying = true
                prayedCount += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.3)) { isPraying = false }
            }
        } label: {
            Text("Pray")
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(isPraying ? .white : .coCrossRed)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(isPraying ? Color.coCrossRed : Color.clear))
                .overlay(Capsule().strokeBorder(Color.coCrossRed, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var verseCard: some View {
        let post = MockData.communityPosts[1]
        return COCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    COAvatar(initials: "MD")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(post.authorName) shared a verse — \(post.verseRef ?? "")")
                            .font(.coUI(14, weight: .semibold))
                            .foregroundColor(.coInk)
                        Text(post.timeAgo)
                            .font(.coUI(12))
                            .foregroundColor(.coInkTertiary)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(Color.coGold)
                        .frame(width: 2)
                    Text(post.verseText ?? "")
                        .font(.coScripture(17, italic: true))
                        .foregroundColor(.coInk)
                        .lineSpacing(6)
                }
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        COIcon(.heart, size: 16, color: .coInkTertiary)
                        Text("\(post.heartCount)")
                            .font(.coUI(13))
                            .foregroundColor(.coInkTertiary)
                    }
                    Spacer()
                    NavigationLink {
                        BridgeShareView()
                    } label: {
                        Text("Encourage")
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                    }
                }
            }
        }
    }

    private var fab: some View {
        Button {
            showNewPost = true
        } label: {
            ZStack {
                Circle().fill(Color.coCrossRed)
                PlusShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .frame(width: 18, height: 18)
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .coShadow(cornerRadius: 26)
        .padding(.trailing, 22)
        .padding(.bottom, 78)
    }
}

private struct PlusShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

private struct NewPostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind = 0
    @State private var text = ""
    private let kinds = ["Prayer Request", "Testimony", "Verse"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Type", selection: $selectedKind) {
                    ForEach(kinds.indices, id: \.self) { i in
                        Text(kinds[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)

                TextEditor(text: $text)
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 160)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.coDivider, lineWidth: 1)
                    )

                Spacer()

                COPrimaryButton(title: "Share") { dismiss() }
            }
            .padding(20)
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CommunityView()
}
