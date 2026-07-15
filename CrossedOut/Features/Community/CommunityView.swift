import SwiftUI
import UIKit

struct CommunityView: View {
    private let segments = ["My Circle", "Church", "Prayer", "Local"]
    @EnvironmentObject private var appState: AppState
    @State private var selectedSegment: String = "My Circle"
    @Namespace private var segmentAnimation
    @State private var showNewPost = false
    @State private var prayedIDs: Set<UUID> = []
    @State private var encouragedIDs: Set<UUID> = []
    @State private var blockedAuthors: Set<String> = []
    @State private var justReportedIDs: Set<UUID> = []

    private var displayedPrayer: PrayerRequest? {
        appState.prayers.first(where: { !blockedAuthors.contains($0.authorName) })
    }

    private var displayedPost: CommunityPost? {
        appState.posts.first(where: { $0.kind == .verseShare && !blockedAuthors.contains($0.authorName) })
            ?? appState.posts.first(where: { !blockedAuthors.contains($0.authorName) })
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.coPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        segmentRow
                        segmentContent
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 90)
                }

                fab
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewPost) { PrayerRequestComposerSheet() }
            .task {
                if let fetched = try? await SupabaseService.shared.fetchBlockedAuthors() {
                    blockedAuthors = fetched
                }
            }
        }
    }

    // MARK: - Report & Block

    private func reportContent(kind: String, contentID: UUID, reason: String) {
        Task {
            await SupabaseService.shared.reportContent(kind: kind, contentID: contentID, reason: reason, detail: nil)
        }
        withAnimation(.easeOut(duration: 0.2)) {
            _ = justReportedIDs.insert(contentID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                _ = justReportedIDs.remove(contentID)
            }
        }
    }

    private func block(authorName: String) {
        withAnimation(.easeOut(duration: 0.25)) {
            _ = blockedAuthors.insert(authorName)
        }
        Task {
            await SupabaseService.shared.blockAuthor(name: authorName, userID: nil)
        }
    }

    @ViewBuilder
    private func reportBlockMenu(contentKind: String, contentID: UUID, authorName: String) -> some View {
        Menu {
            Button("Spam") { reportContent(kind: contentKind, contentID: contentID, reason: "Spam") }
            Button("Harmful or abusive") { reportContent(kind: contentKind, contentID: contentID, reason: "Harmful or abusive") }
            Button("Inappropriate") { reportContent(kind: contentKind, contentID: contentID, reason: "Inappropriate") }
            Button("Other") { reportContent(kind: contentKind, contentID: contentID, reason: "Other") }
        } label: {
            Label("Report Content", systemImage: "flag")
        }
        Button(role: .destructive) {
            block(authorName: authorName)
        } label: {
            Label("Block \(authorName)", systemImage: "person.slash")
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private var segmentRow: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.self) { segment in
                VStack(spacing: 8) {
                    Text(segment)
                        .font(.coUI(14, weight: segment == selectedSegment ? .semibold : .regular))
                        .foregroundColor(segment == selectedSegment ? .coInk : .coInkTertiary)
                    ZStack {
                        Rectangle().fill(Color.clear).frame(height: 2)
                        if segment == selectedSegment {
                            Rectangle()
                                .fill(Color.coCrossRed)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "segmentUnderline", in: segmentAnimation)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { selectedSegment = segment } }
            }
        }
    }

    // MARK: - Segment Content

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case "Church": churchContent
        case "Prayer": prayerContent
        case "Local": localContent
        default: myCircleContent
        }
    }

    private var myCircleContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            COSectionHeader(title: "Prayer Requests", actionTitle: "See all") {
                withAnimation(.easeOut(duration: 0.2)) { selectedSegment = "Prayer" }
            }
            if let request = displayedPrayer {
                prayerCard(request)
            } else {
                COEmptyState(
                    icon: .prayer,
                    title: "No prayer requests yet",
                    message: "Be the first to share what you're carrying — your circle is here for you.",
                    actionTitle: "Share a request"
                ) {
                    showNewPost = true
                }
            }
            if let post = displayedPost {
                verseCard(post)
            }
        }
    }

    private var churchContent: some View {
        let churchPosts = appState.posts.filter { !blockedAuthors.contains($0.authorName) }
        return VStack(alignment: .leading, spacing: 16) {
            COSectionHeader(title: "From Your Church")
            if churchPosts.isEmpty {
                COEmptyState(
                    icon: .church,
                    title: "Nothing from your church yet",
                    message: "Follow a church in Attend to see its posts here."
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(churchPosts) { post in
                        verseCard(post)
                    }
                }
            }
        }
    }

    private var prayerContent: some View {
        let list = appState.prayers.filter { !blockedAuthors.contains($0.authorName) }
        return VStack(alignment: .leading, spacing: 16) {
            COSectionHeader(title: "Prayer Requests")
            if list.isEmpty {
                COEmptyState(
                    icon: .prayer,
                    title: "No prayer requests yet",
                    message: "Be the first to share what you're carrying — your circle is here for you.",
                    actionTitle: "Share a request"
                ) {
                    showNewPost = true
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(list) { request in
                        prayerCard(request)
                    }
                }
            }
        }
    }

    private var localContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            COSectionHeader(title: "Local")
            Text("Churches near you")
                .font(.coUI(12))
                .foregroundColor(.coInkTertiary)
            if appState.churches.isEmpty {
                COEmptyState(
                    icon: .mapPin,
                    title: "No churches nearby",
                    message: "We couldn't find churches near you yet."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.churches.enumerated()), id: \.element.id) { index, church in
                        localChurchRow(church)
                        if index < appState.churches.count - 1 {
                            CODivider()
                        }
                    }
                }
            }
        }
    }

    private func localChurchRow(_ church: Church) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(church.name)
                    .font(.coUI(15, weight: .medium))
                    .foregroundColor(.coInk)
                Text("\(church.city) · \(church.style)")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
            }
            Spacer()
            Text(String(format: "%.1f mi", church.distanceMiles))
                .font(.coUI(12))
                .foregroundColor(.coInkSecondary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
                if justReportedIDs.contains(request.id) {
                    Text("Reported — thank you.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .transition(.opacity)
                }
            }
        }
        .contextMenu {
            reportBlockMenu(contentKind: "prayer_request", contentID: request.id, authorName: request.authorName)
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
                if justReportedIDs.contains(post.id) {
                    Text("Reported — thank you.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .transition(.opacity)
                }
            }
        }
        .contextMenu {
            reportBlockMenu(contentKind: "community_post", contentID: post.id, authorName: post.authorName)
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
