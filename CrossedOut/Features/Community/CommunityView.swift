import SwiftUI
import UIKit

struct CommunityView: View {
    private let segments = ["My Circle", "Church", "Prayer", "Micro"]
    @EnvironmentObject private var appState: AppState
    @State private var selectedSegment: String = "My Circle"
    @Namespace private var segmentAnimation
    @State private var showNewPost = false
    @State private var prayedIDs: Set<UUID> = []
    @State private var encouragedIDs: Set<UUID> = []
    @State private var blockedAuthors: Set<String> = []
    @State private var justReportedIDs: Set<UUID> = []
    // Prayer filter (0041) + church membership (0039)
    @State private var prayerScope: PrayerScope = .everyone
    @State private var scopedPrayers: [PrayerRequest] = []
    @State private var prayerScopeLoading = false
    // Bumped on every load request so a slow, superseded fetch (from a fast
    // scope switch) can detect it's stale and skip writing its result —
    // otherwise it could overwrite scopedPrayers with the wrong scope's data
    // or leave prayerScopeLoading stuck on.
    @State private var prayerScopeGeneration = 0
    @State private var myPrimaryChurchID: UUID? = nil
    @State private var churchMembershipIDs: [UUID] = []

    private var currentPrayerList: [PrayerRequest] {
        prayerScope == .everyone ? appState.prayers : scopedPrayers
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.coPaper.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        segmentRow
                        if appState.communityLoading {
                            feedLoadingState
                        } else if appState.communityLoadFailed && appState.prayers.isEmpty && appState.posts.isEmpty {
                            feedErrorState
                        } else {
                            segmentContent
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 90)
                }
                .refreshable { await appState.reloadCommunity() }
                .simultaneousGesture(segmentSwipe)

                if selectedSegment == "My Circle" {
                    bridgeBlock
                }

                if appState.accountStatus == .active {
                    fab
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewPost) { PrayerRequestComposerSheet() }
            .task {
                if let fetched = try? await SupabaseService.shared.fetchBlockedAuthors() {
                    blockedAuthors = fetched
                }
                await loadMemberships()
            }
        }
    }

    // MARK: - Segment swipe (top nav)

    /// Horizontal swipe moves between the top segments. On the Community tab the
    /// RootView tab-swipe is disabled, so this owns horizontal gestures here.
    private var segmentSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                guard let i = segments.firstIndex(of: selectedSegment) else { return }
                if dx < 0 {
                    if i < segments.count - 1 {
                        withAnimation(.easeOut(duration: 0.2)) { selectedSegment = segments[i + 1] }
                    } else {
                        moveTab(1)   // past the last segment → next tab (Attend)
                    }
                } else if dx > 0, value.startLocation.x > 44 {
                    if i > 0 {
                        withAnimation(.easeOut(duration: 0.2)) { selectedSegment = segments[i - 1] }
                    } else {
                        moveTab(-1)  // before the first segment → previous tab (Bible)
                    }
                }
            }
    }

    /// Hands the swipe off to the adjacent app tab when at a segment boundary,
    /// so Micro → (swipe) → Attend, and My Circle → (swipe) → Bible.
    private func moveTab(_ delta: Int) {
        let tabs = COTab.allCases
        guard let i = tabs.firstIndex(of: .community) else { return }
        let j = i + delta
        guard tabs.indices.contains(j) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = tabs[j] }
    }

    private func loadMemberships() async {
        guard let memberships = try? await SupabaseService.shared.fetchChurchMemberships() else { return }
        await MainActor.run {
            churchMembershipIDs = memberships.map { $0.churchID }
            myPrimaryChurchID = memberships.first(where: { $0.isPrimary })?.churchID
                ?? memberships.first?.churchID
        }
    }

    private func loadScopedPrayers() async {
        guard prayerScope != .everyone else { return }
        prayerScopeGeneration += 1
        let generation = prayerScopeGeneration
        let scope = prayerScope
        let churchID = myPrimaryChurchID
        prayerScopeLoading = true
        let fetched = (try? await SupabaseService.shared.fetchPrayerRequests(
            scope: scope, churchID: churchID)) ?? []
        // A newer scope switch started (and thus bumped the generation)
        // while this fetch was in flight — its own completion owns
        // scopedPrayers/prayerScopeLoading now, so don't stomp on it.
        guard generation == prayerScopeGeneration else { return }
        scopedPrayers = fetched
        prayerScopeLoading = false
    }

    // MARK: - Feed load / error states

    private var feedLoadingState: some View {
        COCard {
            HStack(spacing: 10) {
                ProgressView()
                Text("Gathering your community…")
                    .font(.coUI(13))
                    .foregroundColor(.coInkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    private var feedErrorState: some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Couldn't reach the community right now.")
                    .font(.coUI(14, weight: .medium))
                    .foregroundColor(.coInk)
                Text("Check your connection and try again.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                Button {
                    Task { await appState.reloadCommunity() }
                } label: {
                    Text("Try again")
                        .font(.coUI(13, weight: .medium))
                        .foregroundColor(.coCrossRed)
                        .underline()
                }
                .buttonStyle(.plain)
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

    private func block(authorName: String, userID: UUID?) {
        withAnimation(.easeOut(duration: 0.25)) {
            _ = blockedAuthors.insert(authorName)
        }
        Task {
            await SupabaseService.shared.blockAuthor(name: authorName, userID: userID)
            // Server-side RLS now filters this author's content (0029) —
            // refetch so the durable filtering takes over from the local set.
            await appState.reloadCommunity()
        }
    }

    @ViewBuilder
    private func reportBlockMenu(contentKind: String, contentID: UUID,
                                 authorName: String, authorUserID: UUID?) -> some View {
        Menu {
            Button("Spam") { reportContent(kind: contentKind, contentID: contentID, reason: "Spam") }
            Button("Harmful or abusive") { reportContent(kind: contentKind, contentID: contentID, reason: "Harmful or abusive") }
            Button("Inappropriate") { reportContent(kind: contentKind, contentID: contentID, reason: "Inappropriate") }
            Button("Other") { reportContent(kind: contentKind, contentID: contentID, reason: "Other") }
        } label: {
            Label("Report Content", systemImage: "flag")
        }
        Button(role: .destructive) {
            block(authorName: authorName, userID: authorUserID)
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
        case "Micro": MicroSegmentView()
        default: CircleSegmentView(onOpenPrayers: {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedSegment = "Prayer"
                prayerScope = .circle
            }
            Task { await loadScopedPrayers() }
        })
        }
    }

    // MARK: - Church segment (your churches + community)

    private var churchContent: some View {
        let joined = appState.churches.filter { churchMembershipIDs.contains($0.id) }
        let churchPosts = appState.posts.filter { !blockedAuthors.contains($0.authorName) }
        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                COSectionHeader(title: "Your Churches")
                if joined.isEmpty {
                    COCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You haven't joined a church yet.")
                                .font(.coUI(14, weight: .medium))
                                .foregroundColor(.coInk)
                            Text("Join a church to keep it close and follow its community here.")
                                .font(.coUI(13))
                                .foregroundColor(.coInkSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(joined) { joinedChurchRow($0) }
                    }
                }
                NavigationLink { ChurchFinderView() } label: {
                    HStack(spacing: 6) {
                        COIcon(.search, size: 14, color: .coCrossRed)
                        Text(joined.isEmpty ? "Find a church" : "Find another church")
                            .font(.coUI(13, weight: .semibold))
                            .foregroundColor(.coCrossRed)
                    }
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 16) {
                COSectionHeader(title: "From the Community")
                if churchPosts.isEmpty {
                    COEmptyState(
                        icon: .church,
                        title: "Nothing shared yet",
                        message: "Verse shares and testimonies from the community will appear here."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(churchPosts) { post in verseCard(post) }
                    }
                }
            }
        }
    }

    private func joinedChurchRow(_ church: Church) -> some View {
        COCard {
            HStack(spacing: 12) {
                COAvatar(initials: String(church.name.prefix(1)).uppercased(), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(church.name)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                        .lineLimit(1)
                    Text(church.city)
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .lineLimit(1)
                }
                Spacer()
                if church.isLive {
                    Text("LIVE")
                        .font(.coUI(10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.coCrossRed))
                }
            }
        }
    }

    // MARK: - Prayer segment (with scope filter)

    private var prayerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            prayerScopeChips
            prayerList
        }
    }

    private var prayerScopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PrayerScope.allCases) { scope in
                    COChip(text: scope.title, selected: prayerScope == scope) {
                        guard prayerScope != scope else { return }
                        prayerScope = scope
                        Task { await loadScopedPrayers() }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private var prayerList: some View {
        if prayerScopeLoading {
            feedLoadingState
        } else {
            let list = currentPrayerList.filter { !blockedAuthors.contains($0.authorName) }
            if list.isEmpty {
                prayerEmptyState
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(list) { request in prayerCard(request) }
                }
            }
        }
    }

    @ViewBuilder
    private var prayerEmptyState: some View {
        if prayerScope == .myChurch && myPrimaryChurchID == nil {
            COEmptyState(
                icon: .church,
                title: "Join a church first",
                message: "Join a church in the Church tab to see prayer requests from its members."
            )
        } else if prayerScope == .circle {
            COEmptyState(
                icon: .community,
                title: "No circle prayers yet",
                message: "Create or join a circle in My Circle — then prayer requests from your circle show up here."
            )
        } else {
            COEmptyState(
                icon: .prayer,
                title: "No prayer requests yet",
                message: "Be the first to share what you're carrying — your community is here for you.",
                actionTitle: "Share a request"
            ) {
                showNewPost = true
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
                if justReportedIDs.contains(request.id) {
                    Text("Reported — thank you. Our team reviews reports within 24 hours.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .transition(.opacity)
                }
            }
        }
        .contextMenu {
            reportBlockMenu(contentKind: "prayer_request", contentID: request.id,
                            authorName: request.authorName, authorUserID: request.authorUserId)
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
                await appState.recordActivity(kind: "community")
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
                        Text(postHeadline(post))
                            .font(.coUI(14, weight: .semibold))
                            .foregroundColor(.coInk)
                        Text(post.timeAgo)
                            .font(.coUI(12))
                            .foregroundColor(.coInkTertiary)
                    }
                }
                if post.kind == .testimony || (post.verseText == nil && !post.text.isEmpty) {
                    Text(post.text)
                        .font(.coUI(15))
                        .foregroundColor(.coInk)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let verseText = post.verseText, !verseText.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle()
                            .fill(Color.coGold)
                            .frame(width: 2)
                        Text(verseText)
                            .font(.coScripture(17, italic: true))
                            .foregroundColor(.coInk)
                            .lineSpacing(6)
                    }
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
                    Text("Reported — thank you. Our team reviews reports within 24 hours.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .transition(.opacity)
                }
            }
        }
        .contextMenu {
            reportBlockMenu(contentKind: "community_post", contentID: post.id,
                            authorName: post.authorName, authorUserID: post.authorUserId)
        }
    }

    private func postHeadline(_ post: CommunityPost) -> String {
        switch post.kind {
        case .verseShare:
            if let ref = post.verseRef, !ref.isEmpty {
                return "\(post.authorName) shared a verse — \(ref)"
            }
            return "\(post.authorName) shared a verse"
        case .testimony:
            return "\(post.authorName) shared a testimony"
        case .prayer:
            return post.authorName
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

    // MARK: - Bridge Block (My Circle only)

    /// Persistent "Build a Bridge" entry point pinned just above the tab
    /// bar, only while the "My Circle" segment is selected. Full-width but
    /// inset on the trailing edge so it never sits under (or competes with
    /// the tap target of) the floating Kyra "K" button.
    private var bridgeBlock: some View {
        NavigationLink {
            BridgeShareView()
        } label: {
            COCard {
                HStack(spacing: 14) {
                    BridgeMotif(width: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Build a Bridge")
                            .font(.coUI(15, weight: .semibold))
                            .foregroundColor(.coInk)
                        Text("Invite someone into your circle")
                            .font(.coUI(12))
                            .foregroundColor(.coInkSecondary)
                    }
                    Spacer(minLength: 0)
                    COIcon(.chevronRight, size: 16, color: .coInkTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.leading, 22)
        .padding(.trailing, 86)
        .padding(.bottom, 66)
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

    private enum ComposeKind: String, CaseIterable {
        case prayer = "Prayer request"
        case testimony = "Testimony"
    }

    @State private var kind: ComposeKind = .prayer
    @State private var text = ""
    @State private var isPosting = false
    @State private var postFailed = false

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholder: String {
        switch kind {
        case .prayer: return "Share what you'd like prayer for..."
        case .testimony: return "Share what God has done..."
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ForEach(ComposeKind.allCases, id: \.self) { option in
                        COChip(text: option.rawValue, selected: kind == option) {
                            withAnimation(.easeOut(duration: 0.15)) { kind = option }
                        }
                    }
                }

                TextField(placeholder, text: $text, axis: .vertical)
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

                if postFailed {
                    Text("Couldn't post right now. Check your connection and try again.")
                        .font(.coUI(13))
                        .foregroundColor(.coCrossRed)
                }

                Spacer()

                COPrimaryButton(title: isPosting ? "Sharing…" : shareTitle) { share() }
                    .opacity(isEmpty || isPosting ? 0.5 : 1)
                    .disabled(isEmpty || isPosting)
            }
            .padding(20)
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle(kind == .prayer ? "New Prayer Request" : "Share a Testimony")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var shareTitle: String {
        kind == .prayer ? "Share Request" : "Share Testimony"
    }

    private func share() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isPosting else { return }
        isPosting = true
        postFailed = false
        let authorName = appState.profile.firstName
        let composeKind = kind
        Task {
            switch composeKind {
            case .prayer:
                await SupabaseService.shared.insertPrayerRequest(authorName: authorName, body: body)
                await appState.reloadCommunity()
                isPosting = false
                dismiss()
            case .testimony:
                let ok = await SupabaseService.shared.insertCommunityPost(
                    authorName: authorName, kind: "testimony", body: body
                )
                isPosting = false
                if ok {
                    await appState.reloadCommunity()
                    dismiss()
                } else {
                    postFailed = true
                }
            }
        }
    }
}

#Preview {
    CommunityView()
        .environmentObject(AppState())
}
