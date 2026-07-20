import SwiftUI
import UIKit

// MARK: - Micro segment (Community tab)

/// "Micro" — local micro-site groups who meet in person to watch streamed
/// church together. This segment lists the user's micros, offers name
/// search + join for discovery, and a create action. Replaces the old
/// redundant "Local" segment (Church Finder lives under More).
struct MicroSegmentView: View {
    @EnvironmentObject private var appState: AppState

    struct MyMicro: Identifiable {
        var id: UUID { micro.id }
        let micro: Micro
        let role: String
    }

    @State private var mine: [MyMicro] = []
    @State private var loading = true
    @State private var loadFailed = false
    @State private var searchText = ""
    @State private var searchResults: [Micro] = []
    @State private var searching = false
    @State private var joiningID: UUID?
    @State private var showCreate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            mySection
            discoverSection
        }
        .sheet(isPresented: $showCreate) {
            CreateMicroSheet { await reload() }
        }
        .task { await reload() }
    }

    private func reload() async {
        do {
            mine = try await SupabaseService.shared.fetchMyMicros()
                .map { MyMicro(micro: $0.micro, role: $0.role) }
            loadFailed = false
        } catch {
            loadFailed = true
        }
        loading = false
    }

    // MARK: My micros

    private var mySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                COSectionHeader(title: "Your Micros")
                Spacer()
                if appState.accountStatus == .active {
                    Button { showCreate = true } label: {
                        HStack(spacing: 4) {
                            COIcon(.community, size: 14, color: .coOlive)
                            Text("Create")
                                .font(.coUI(13, weight: .semibold))
                                .foregroundColor(.coOlive)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if loading {
                COCard {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding your micros…")
                            .font(.coUI(13))
                            .foregroundColor(.coInkTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if loadFailed {
                COCard {
                    HStack {
                        Text("Couldn't load your micros.")
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                        Spacer()
                        Button {
                            loading = true
                            Task { await reload() }
                        } label: {
                            Text("Retry")
                                .font(.coUI(13, weight: .medium))
                                .foregroundColor(.coCrossRed)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if mine.isEmpty {
                COEmptyState(
                    icon: .community,
                    title: "No micros yet",
                    message: "A Micro is a small local group that watches church together — find one below, or start your own.",
                    actionTitle: appState.accountStatus == .active ? "Create a Micro" : nil
                ) {
                    showCreate = true
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(mine) { item in
                        NavigationLink {
                            MicroDetailView(micro: item.micro) { await reload() }
                        } label: {
                            microRow(item.micro, role: item.role)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func microRow(_ micro: Micro, role: String?) -> some View {
        COCard {
            HStack(spacing: 12) {
                COAvatar(initials: String(micro.name.prefix(1)).uppercased(), size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(micro.name)
                            .font(.coUI(15, weight: .semibold))
                            .foregroundColor(.coInk)
                            .lineLimit(1)
                        if role == "owner" {
                            Text("OWNER")
                                .font(.coUI(9, weight: .semibold))
                                .tracking(1)
                                .foregroundColor(.coGold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(Capsule().strokeBorder(Color.coGold.opacity(0.5), lineWidth: 1))
                        }
                    }
                    Text(subtitle(for: micro))
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .lineLimit(1)
                }
                Spacer()
                COIcon(.chevronRight, size: 15, color: .coInkTertiary)
            }
        }
    }

    private func subtitle(for micro: Micro) -> String {
        if let city = micro.city, !city.isEmpty {
            return micro.description.isEmpty ? city : "\(city) · \(micro.description)"
        }
        return micro.description.isEmpty ? "A local micro" : micro.description
    }

    // MARK: Discover

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            COSectionHeader(title: "Find a Micro")

            HStack(spacing: 8) {
                COIcon(.search, size: 16, color: .coInkTertiary)
                TextField("Search by name…", text: $searchText)
                    .font(.coUI(15))
                    .foregroundColor(.coInk)
                    .autocorrectionDisabled()
                    .onSubmit { runSearch() }
                if searching {
                    ProgressView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )
            .onChange(of: searchText) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults = []
                }
            }

            if !searchResults.isEmpty {
                VStack(spacing: 10) {
                    ForEach(searchResults) { micro in
                        searchResultRow(micro)
                    }
                }
            } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty && !searching {
                Text("Press return to search.")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
            }
        }
    }

    private func searchResultRow(_ micro: Micro) -> some View {
        let alreadyMine = mine.contains { $0.id == micro.id }
        return COCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(micro.name)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                        .lineLimit(1)
                    Text(subtitle(for: micro))
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .lineLimit(2)
                }
                Spacer()
                if alreadyMine {
                    Text("Joined")
                        .font(.coUI(13, weight: .medium))
                        .foregroundColor(.coOlive)
                } else if appState.accountStatus == .active {
                    Button {
                        join(micro)
                    } label: {
                        Text(joiningID == micro.id ? "Joining…" : "Join")
                            .font(.coUI(13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.coCrossRed))
                    }
                    .buttonStyle(.plain)
                    .disabled(joiningID != nil)
                }
            }
        }
    }

    private func runSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !searching else { return }
        searching = true
        Task {
            searchResults = (try? await SupabaseService.shared.searchMicros(query: query)) ?? []
            searching = false
        }
    }

    private func join(_ micro: Micro) {
        guard joiningID == nil else { return }
        joiningID = micro.id
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Task {
            let ok = await SupabaseService.shared.joinMicro(id: micro.id)
            if ok { await reload() }
            joiningID = nil
        }
    }
}

// MARK: - Micro detail

/// One micro's space: pinned announcements up top (owner-posted, with a
/// server-computed pin expiry), then the chronological member feed, with a
/// composer for members. Owner extras: post announcements (24h / 7d /
/// permanent), delete any post, delete the micro.
struct MicroDetailView: View {
    let micro: Micro
    var onMembershipChange: () async -> Void = {}

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var posts: [MicroPost] = []
    @State private var feedLoading = true
    @State private var feedFailed = false
    @State private var isMember = false
    @State private var membershipChecked = false
    @State private var composerText = ""
    @State private var announceMode = false
    @State private var announceTTL: AnnounceTTL = .day
    @State private var posting = false
    @State private var postFailed = false
    @State private var showDeleteMicro = false
    @State private var showLeave = false
    @State private var joining = false
    @State private var blockedAuthors: Set<String> = []
    @State private var justReportedPostIDs: Set<UUID> = []
    @FocusState private var composerFocused: Bool

    enum AnnounceTTL: String, CaseIterable {
        case day = "24 hours"
        case week = "7 days"
        case permanent = "Permanent"

        var expiry: Date? {
            switch self {
            case .day: return Date().addingTimeInterval(24 * 3600)
            case .week: return Date().addingTimeInterval(7 * 24 * 3600)
            case .permanent: return nil
            }
        }
    }

    private var isOwner: Bool {
        SupabaseService.shared.currentUserID == micro.ownerUserId
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    pinnedSection
                    feedSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            if isMember || isOwner {
                composer
            } else if membershipChecked && appState.accountStatus == .active {
                joinBar
            }
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle(micro.name)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if isOwner {
                        Button(role: .destructive) { showDeleteMicro = true } label: {
                            Label("Delete Micro", systemImage: "trash")
                        }
                    } else if isMember {
                        Button(role: .destructive) { showLeave = true } label: {
                            Label("Leave Micro", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    COIcon(.more, size: 18, color: .coInkSecondary)
                }
            }
        }
        .confirmationDialog(
            "Delete \(micro.name)? Its posts and memberships are removed for everyone. This can't be undone.",
            isPresented: $showDeleteMicro, titleVisibility: .visible
        ) {
            Button("Delete Micro", role: .destructive) { deleteMicro() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Leave \(micro.name)?",
            isPresented: $showLeave, titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) { leave() }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await checkMembership()
            await loadFeed()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(micro.name)
                    .font(.coDisplay(24, weight: .semibold))
                    .foregroundColor(.coInk)
                if isOwner {
                    Text("OWNER")
                        .font(.coUI(9, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.coGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color.coGold.opacity(0.5), lineWidth: 1))
                }
            }
            if let city = micro.city, !city.isEmpty {
                Text(city)
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
            }
            if !micro.description.isEmpty {
                Text(micro.description)
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Pinned + feed

    private var visiblePosts: [MicroPost] { posts.filter { !blockedAuthors.contains($0.authorName) } }
    private var pinnedPosts: [MicroPost] { visiblePosts.filter(\.pinned) }
    private var feedPosts: [MicroPost] { visiblePosts.filter { !$0.pinned } }

    @ViewBuilder
    private var pinnedSection: some View {
        if !pinnedPosts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("PINNED")
                ForEach(pinnedPosts) { post in
                    pinnedCard(post)
                }
            }
        }
    }

    private func pinnedCard(_ post: MicroPost) -> some View {
        COCard {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.coGold)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(post.authorName)
                            .font(.coUI(13, weight: .semibold))
                            .foregroundColor(.coInk)
                        Spacer()
                        Text(pinNote(post))
                            .font(.coUI(11))
                            .foregroundColor(.coInkTertiary)
                    }
                    Text(post.body)
                        .font(.coUI(14, weight: .medium))
                        .foregroundColor(.coInk)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if justReportedPostIDs.contains(post.id) {
                        Text("Reported — thank you. Our team reviews reports within 24 hours.")
                            .font(.coUI(12))
                            .foregroundColor(.coInkTertiary)
                            .transition(.opacity)
                    }
                }
            }
        }
        .contextMenu { postMenu(post) }
    }

    private func pinNote(_ post: MicroPost) -> String {
        guard post.expiresAt != nil else { return "Pinned" }
        let expiry = SupabaseService.parseISODate(post.expiresAt)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return "Pinned · ends \(f.localizedString(for: expiry, relativeTo: Date()))"
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("UPDATES")
            if feedLoading {
                COCard {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading updates…")
                            .font(.coUI(13))
                            .foregroundColor(.coInkTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if feedFailed {
                COCard {
                    HStack {
                        Text("Couldn't load this micro's updates.")
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                        Spacer()
                        Button {
                            feedLoading = true
                            Task { await loadFeed() }
                        } label: {
                            Text("Retry")
                                .font(.coUI(13, weight: .medium))
                                .foregroundColor(.coCrossRed)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if posts.isEmpty {
                COCard {
                    Text(isMember || isOwner
                         ? "Quiet so far. Share a service time, a plan, or a hello."
                         : "Quiet so far. Join to be part of the conversation.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(feedPosts) { post in
                        feedRow(post)
                    }
                }
            }
        }
    }

    private func feedRow(_ post: MicroPost) -> some View {
        COCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(post.authorName)
                        .font(.coUI(13, weight: .semibold))
                        .foregroundColor(.coInk)
                    if post.isAnnouncement {
                        Text("Announcement")
                            .font(.coUI(10))
                            .foregroundColor(.coInkTertiary)
                    }
                    Spacer()
                    Text(SupabaseService.relativeTime(from: post.createdAt))
                        .font(.coUI(11))
                        .foregroundColor(.coInkTertiary)
                }
                Text(post.body)
                    .font(.coUI(14))
                    .foregroundColor(.coInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if justReportedPostIDs.contains(post.id) {
                    Text("Reported — thank you. Our team reviews reports within 24 hours.")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .transition(.opacity)
                }
            }
        }
        .contextMenu { postMenu(post) }
    }

    @ViewBuilder
    private func postMenu(_ post: MicroPost) -> some View {
        let mine = post.authorUserId == SupabaseService.shared.currentUserID
        if mine || isOwner {
            Button(role: .destructive) { delete(post) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        if !mine {
            Menu {
                Button("Spam") { report(post, reason: "Spam") }
                Button("Harmful or abusive") { report(post, reason: "Harmful or abusive") }
                Button("Inappropriate") { report(post, reason: "Inappropriate") }
                Button("Other") { report(post, reason: "Other") }
            } label: {
                Label("Report Content", systemImage: "flag")
            }
            Button(role: .destructive) { block(post) } label: {
                Label("Block \(post.authorName)", systemImage: "person.slash")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.coUI(11, weight: .medium))
            .tracking(1.3)
            .foregroundColor(.coInkTertiary)
    }

    // MARK: Composer / join bar

    private var composer: some View {
        VStack(spacing: 0) {
            CODivider()
            VStack(alignment: .leading, spacing: 8) {
                if isOwner {
                    HStack(spacing: 10) {
                        COChip(text: "Update", selected: !announceMode) {
                            withAnimation(.easeOut(duration: 0.15)) { announceMode = false }
                        }
                        COChip(text: "Announcement", selected: announceMode) {
                            withAnimation(.easeOut(duration: 0.15)) { announceMode = true }
                        }
                        Spacer()
                    }
                    if announceMode {
                        HStack(spacing: 8) {
                            Text("Pin for:")
                                .font(.coUI(11))
                                .foregroundColor(.coInkTertiary)
                            ForEach(AnnounceTTL.allCases, id: \.self) { ttl in
                                COChip(text: ttl.rawValue, selected: announceTTL == ttl) {
                                    announceTTL = ttl
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                if postFailed {
                    Text("Couldn't post. Check your connection and try again.")
                        .font(.coUI(12))
                        .foregroundColor(.coCrossRed)
                }
                HStack(spacing: 12) {
                    TextField(announceMode ? "Announce to the micro…" : "Share an update…",
                              text: $composerText, axis: .vertical)
                        .font(.coUI(14))
                        .foregroundColor(.coInk)
                        .lineLimit(1...4)
                        .focused($composerFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .overlay(Capsule().strokeBorder(Color.coDivider, lineWidth: 1))
                    sendButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.coPaper)
        .animation(.easeOut(duration: 0.2), value: announceMode)
    }

    private var sendButton: some View {
        let empty = composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let blocked = empty || posting
        return Button { send() } label: {
            COIcon(.chevronRight, size: 20, color: blocked ? .coInkTertiary : .coCrossRed)
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(
                    blocked ? Color.coDivider : Color.coCrossRed, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(blocked)
    }

    private var joinBar: some View {
        VStack(spacing: 0) {
            CODivider()
            COPrimaryButton(title: joining ? "Joining…" : "Join \(micro.name)") {
                guard !joining else { return }
                joining = true
                Task {
                    let ok = await SupabaseService.shared.joinMicro(id: micro.id)
                    if ok {
                        isMember = true
                        await onMembershipChange()
                    }
                    joining = false
                }
            }
            .disabled(joining)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.coPaper)
    }

    // MARK: Actions

    private func checkMembership() async {
        if let memberships = try? await SupabaseService.shared.fetchMyMicros() {
            isMember = memberships.contains { $0.micro.id == micro.id }
        }
        membershipChecked = true
    }

    private func loadFeed() async {
        do {
            posts = try await SupabaseService.shared.fetchMicroFeed(microID: micro.id)
            feedFailed = false
        } catch {
            feedFailed = true
        }
        feedLoading = false
    }

    private func send() {
        let body = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !posting else { return }
        posting = true
        postFailed = false
        let announcement = isOwner && announceMode
        let expiry = announcement ? announceTTL.expiry : nil
        let authorName = appState.profile.firstName
        Task {
            let ok = await SupabaseService.shared.postMicroMessage(
                microID: micro.id, authorName: authorName, body: body,
                isAnnouncement: announcement, expiresAt: expiry
            )
            posting = false
            if ok {
                composerText = ""
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                await loadFeed()
            } else {
                postFailed = true
            }
        }
    }

    private func delete(_ post: MicroPost) {
        Task {
            if await SupabaseService.shared.deleteMicroPost(id: post.id) {
                await loadFeed()
            }
        }
    }

    private func report(_ post: MicroPost, reason: String) {
        Task {
            await SupabaseService.shared.reportContent(
                kind: "micro_post", contentID: post.id, reason: reason, detail: nil)
        }
        withAnimation(.easeOut(duration: 0.2)) {
            _ = justReportedPostIDs.insert(post.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                _ = justReportedPostIDs.remove(post.id)
            }
        }
    }

    private func block(_ post: MicroPost) {
        withAnimation(.easeOut(duration: 0.25)) {
            _ = blockedAuthors.insert(post.authorName)
        }
        Task {
            await SupabaseService.shared.blockAuthor(name: post.authorName, userID: post.authorUserId)
            // Once migration 0043 lands, micro_posts RLS excludes blocked
            // authors too — refetch so server-side filtering takes over
            // from this local set, same as the Community feed's block flow.
            await loadFeed()
        }
    }

    private func deleteMicro() {
        Task {
            if await SupabaseService.shared.deleteMicro(id: micro.id) {
                await onMembershipChange()
                dismiss()
            }
        }
    }

    private func leave() {
        Task {
            if await SupabaseService.shared.leaveMicro(id: micro.id) {
                await onMembershipChange()
                dismiss()
            }
        }
    }
}

// MARK: - Create Micro sheet

private struct CreateMicroSheet: View {
    var onCreated: () async -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var descriptionText = ""
    @State private var city = ""
    @State private var creating = false
    @State private var errorText: String?

    private var canCreate: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !creating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A Micro is a small local group that meets up to watch church together. Give yours a name people will recognize.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(4)

                    field("Name", text: $name, placeholder: "e.g. Viera Micro")
                    field("What's it about?", text: $descriptionText,
                          placeholder: "We watch the 10am stream together, then lunch.", axis: .vertical)
                    field("City (optional)", text: $city, placeholder: "e.g. Viera, FL")

                    if let errorText {
                        Text(errorText)
                            .font(.coUI(13))
                            .foregroundColor(.coCrossRed)
                    }

                    COPrimaryButton(title: creating ? "Creating…" : "Create Micro") { create() }
                        .opacity(canCreate ? 1 : 0.5)
                        .disabled(!canCreate)
                }
                .padding(20)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("Create a Micro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>,
                       placeholder: String, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.coUI(13, weight: .medium))
                .foregroundColor(.coInkTertiary)
            TextField(placeholder, text: text, axis: axis)
                .font(.coUI(15))
                .foregroundColor(.coInk)
                .lineLimit(axis == .vertical ? 2...5 : 1...1)
                .padding(12)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
        }
    }

    private func create() {
        guard canCreate else { return }
        creating = true
        errorText = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await SupabaseService.shared.createMicro(
                    name: trimmedName,
                    description: trimmedDescription,
                    city: trimmedCity.isEmpty ? nil : trimmedCity
                )
                await onCreated()
                creating = false
                dismiss()
            } catch MicroError.nameTaken {
                creating = false
                errorText = "That name's taken — try another."
            } catch {
                creating = false
                errorText = "Couldn't create it right now. Check your connection and try again."
            }
        }
    }
}
