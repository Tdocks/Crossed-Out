import SwiftUI
import UIKit

struct CommunityView: View {
    private let segments = ["My Circle", "Church", "Prayer", "Local"]
    @EnvironmentObject private var appState: AppState
    @State private var selectedSegment = 0
    @State private var showNewPost = false
    @State private var prayedIDs: Set<UUID> = []
    @State private var encouragedIDs: Set<UUID> = []

    private var displayedPrayer: PrayerRequest? {
        appState.prayers.first
    }

    private var displayedPost: CommunityPost? {
        appState.posts.first(where: { $0.kind == .verseShare }) ?? appState.posts.first
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.coPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        segmentRow
                        COSectionHeader(title: "Prayer Requests", actionTitle: "See all", action: {})
                        if let request = displayedPrayer {
                            prayerCard(request)
                        }
                        if let post = displayedPost {
                            verseCard(post)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 90)
                }

                fab
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewPost) { PrayerRequestComposerSheet() }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
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

    private func prayerCard(_ request: PrayerRequest) -> some View {
        let isPrayed = prayedIDs.contains(request.id)
        return COCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    COAvatar(initials: initials(for: request.authorName))
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
                        Text("\(request.prayedCount)")
                            .font(.coUI(13))
                            .foregroundColor(.coInkTertiary)
                    }
                    prayButton(for: request, isPrayed: isPrayed)
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

    private func prayButton(for request: PrayerRequest, isPrayed: Bool) -> some View {
        Button {
            guard !isPrayed else { return }
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            withAnimation(.easeOut(duration: 0.25)) {
                prayedIDs.insert(request.id)
                if let idx = appState.prayers.firstIndex(where: { $0.id == request.id }) {
                    appState.prayers[idx].prayedCount += 1
                }
            }
            let requestID = request.id
            Task {
                _ = await SupabaseService.shared.prayFor(requestID: requestID)
            }
        } label: {
            Text(isPrayed ? "Prayed" : "Pray")
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(isPrayed ? .white : .coCrossRed)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(isPrayed ? Color.coCrossRed : Color.clear))
                .overlay(Capsule().strokeBorder(Color.coCrossRed, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func verseCard(_ post: CommunityPost) -> some View {
        let isEncouraged = encouragedIDs.contains(post.id)
        return COCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    COAvatar(initials: initials(for: post.authorName))
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
                    encourageHeart(for: post, isEncouraged: isEncouraged)
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

    private func encourageHeart(for post: CommunityPost, isEncouraged: Bool) -> some View {
        Button {
            guard !isEncouraged else { return }
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
            withAnimation(.easeOut(duration: 0.25)) {
                encouragedIDs.insert(post.id)
                if let idx = appState.posts.firstIndex(where: { $0.id == post.id }) {
                    appState.posts[idx].heartCount += 1
                }
            }
            let postID = post.id
            Task {
                _ = await SupabaseService.shared.encouragePost(postID: postID)
            }
        } label: {
            HStack(spacing: 6) {
                COIcon(.heart, size: 16, color: isEncouraged ? .coCrossRed : .coInkTertiary)
                Text("\(post.heartCount)")
                    .font(.coUI(13))
                    .foregroundColor(isEncouraged ? .coCrossRed : .coInkTertiary)
            }
        }
        .buttonStyle(.plain)
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

private struct PrayerRequestComposerSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("PRAYER REQUEST")
                    .font(.coUI(12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(.coInkTertiary)

                TextField("Share what you'd like prayer for...", text: $text, axis: .vertical)
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
                    .lineLimit(5...12)
                    .padding(12)
                    .frame(minHeight: 120, alignment: .top)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.coDivider, lineWidth: 1)
                    )

                Spacer()

                COPrimaryButton(title: "Share Request") { share() }
                    .opacity(isEmpty ? 0.5 : 1)
                    .disabled(isEmpty)
            }
            .padding(20)
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("New Prayer Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func share() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let authorName = appState.profile.firstName
        let newRequest = PrayerRequest(authorName: authorName, timeAgo: "Just now", text: body, prayedCount: 0)
        appState.prayers.insert(newRequest, at: 0)
        Task {
            await SupabaseService.shared.insertPrayerRequest(authorName: authorName, body: body)
        }
        dismiss()
    }
}

#Preview {
    CommunityView()
        .environmentObject(AppState())
}
