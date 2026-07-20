import SwiftUI
import UIKit

// MARK: - Circle segment (Community → My Circle)
//
// Private prayer circles (migration 0040). Create one and share its code, or
// join with a friend's code. Below, a preview of prayer requests from people
// who share a circle with you (the "My Circle" prayer feed).

struct CircleSegmentView: View {
    @EnvironmentObject private var appState: AppState
    /// Jump to the Prayer segment scoped to circles.
    var onOpenPrayers: () -> Void = {}

    @State private var circles: [PrayerCircle] = []
    @State private var loading = true
    @State private var loadFailed = false
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var circlePrayers: [PrayerRequest] = []
    @State private var prayersLoading = false
    @State private var circleToLeave: PrayerCircle?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            circlesSection
            if !circles.isEmpty {
                circlePrayersSection
            }
        }
        .sheet(isPresented: $showCreate) { CreateCircleSheet { await reload() } }
        .sheet(isPresented: $showJoin) { JoinCircleSheet { await reload() } }
        .confirmationDialog(
            "Leave \(circleToLeave?.name ?? "this circle")? You'll need the invite code to rejoin.",
            isPresented: Binding(
                get: { circleToLeave != nil },
                set: { if !$0 { circleToLeave = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Leave Circle", role: .destructive) {
                if let circle = circleToLeave { leave(circle) }
                circleToLeave = nil
            }
            Button("Cancel", role: .cancel) { circleToLeave = nil }
        }
        .task { await reload() }
    }

    private func reload() async {
        #if DEBUG
        // Screenshot/QA harness: seed a circle so the leave-circle
        // confirmation flow is reachable without a network session
        // (launched via CO_SEED=circle). Never runs in release builds.
        if ProcessInfo.processInfo.environment["CO_SEED"]?.contains("circle") == true {
            circles = [PrayerCircle(id: UUID(), name: "Men's Tuesday Group", joinCode: "AB12CD", memberCount: 4)]
            loadFailed = false
            loading = false
            return
        }
        #endif
        do {
            circles = try await SupabaseService.shared.fetchMyCircles()
            loadFailed = false
        } catch {
            loadFailed = true
        }
        loading = false
        if !circles.isEmpty { await loadCirclePrayers() }
    }

    private func loadCirclePrayers() async {
        prayersLoading = true
        circlePrayers = (try? await SupabaseService.shared.fetchPrayerRequests(scope: .circle, churchID: nil)) ?? []
        prayersLoading = false
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: Your circles

    private var circlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                COSectionHeader(title: "Your Circles")
                Spacer()
                if appState.accountStatus == .active {
                    Button { showCreate = true } label: {
                        HStack(spacing: 4) {
                            COIcon(.community, size: 14, color: .coOlive)
                            Text("New")
                                .font(.coUI(13, weight: .semibold))
                                .foregroundColor(.coOlive)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if loading {
                loadingCard("Finding your circles…")
            } else if loadFailed {
                errorCard { loading = true; Task { await reload() } }
            } else if circles.isEmpty {
                COEmptyState(
                    icon: .community,
                    title: "No circles yet",
                    message: "A circle is a private space for close friends or family to pray together. Create one and share the code, or join with a friend's code."
                )
                actionRow
            } else {
                VStack(spacing: 10) {
                    ForEach(circles) { circle in circleCard(circle) }
                }
                actionRow
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if appState.accountStatus == .active {
                COSecondaryButton(title: "Create a Circle") { showCreate = true }
            }
            COSecondaryButton(title: "Join with a Code") { showJoin = true }
        }
    }

    private func circleCard(_ circle: PrayerCircle) -> some View {
        COCard {
            HStack(spacing: 12) {
                COAvatar(initials: String(circle.name.prefix(1)).uppercased(), size: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text(circle.name)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                        .lineLimit(1)
                    Text("\(circle.memberCount) member\(circle.memberCount == 1 ? "" : "s") · Code \(circle.joinCode)")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .lineLimit(1)
                }
                Spacer()
                ShareLink(item: shareText(circle)) {
                    COIcon(.share, size: 18, color: .coInkSecondary)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) { circleToLeave = circle } label: {
                Label("Leave Circle", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private func shareText(_ circle: PrayerCircle) -> String {
        "Join my circle \"\(circle.name)\" on Crossed Out — open the app, go to Community → My Circle → Join with a Code, and enter: \(circle.joinCode)"
    }

    private func leave(_ circle: PrayerCircle) {
        Task {
            if await SupabaseService.shared.leaveCircle(id: circle.id) { await reload() }
        }
    }

    // MARK: Circle prayers preview

    @ViewBuilder
    private var circlePrayersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if circlePrayers.isEmpty {
                COSectionHeader(title: "From Your Circles")
            } else {
                COSectionHeader(title: "From Your Circles", actionTitle: "See all") { onOpenPrayers() }
            }
            if prayersLoading {
                loadingCard("Loading prayers…")
            } else if circlePrayers.isEmpty {
                COCard {
                    Text("No prayer requests from your circles yet. When someone in your circle shares one, it'll show here.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(circlePrayers.prefix(3)) { request in miniPrayerCard(request) }
                }
            }
        }
    }

    private func miniPrayerCard(_ request: PrayerRequest) -> some View {
        COCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    COAvatar(initials: initials(request.authorName), size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.authorName)
                            .font(.coUI(13, weight: .semibold))
                            .foregroundColor(.coInk)
                        Text(request.timeAgo)
                            .font(.coUI(11))
                            .foregroundColor(.coInkTertiary)
                    }
                    Spacer()
                }
                Text(request.text)
                    .font(.coUI(14))
                    .foregroundColor(.coInk)
                    .lineSpacing(3)
                    .lineLimit(4)
            }
        }
    }

    // MARK: Small shared cards

    private func loadingCard(_ text: String) -> some View {
        COCard {
            HStack(spacing: 10) {
                ProgressView()
                Text(text)
                    .font(.coUI(13))
                    .foregroundColor(.coInkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func errorCard(_ retry: @escaping () -> Void) -> some View {
        COCard {
            HStack {
                Text("Couldn't load your circles.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                Spacer()
                Button(action: retry) {
                    Text("Retry")
                        .font(.coUI(13, weight: .medium))
                        .foregroundColor(.coCrossRed)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Create Circle sheet

private struct CreateCircleSheet: View {
    var onCreated: () async -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var creating = false
    @State private var errorText: String?

    private var canCreate: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !creating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create a private circle for people close to you to pray together. You'll get a code to share so they can join.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(4)
                    circleField("Circle name", text: $name, placeholder: "e.g. Family, Small Group")
                    if let errorText {
                        Text(errorText).font(.coUI(13)).foregroundColor(.coCrossRed)
                    }
                    COPrimaryButton(title: creating ? "Creating…" : "Create Circle") { create() }
                        .opacity(canCreate ? 1 : 0.5)
                        .disabled(!canCreate)
                }
                .padding(20)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("New Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func create() {
        guard canCreate else { return }
        creating = true
        errorText = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await SupabaseService.shared.createCircle(name: trimmed)
                await onCreated()
                creating = false
                dismiss()
            } catch {
                creating = false
                errorText = "Couldn't create it right now. Check your connection and try again."
            }
        }
    }
}

// MARK: - Join Circle sheet

private struct JoinCircleSheet: View {
    var onJoined: () async -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var joining = false
    @State private var errorText: String?

    private var canJoin: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 && !joining
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter the code someone shared with you to join their circle.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(4)
                    circleField("Invite code", text: $code, placeholder: "e.g. A1B2C3")
                        .textInputAutocapitalization(.characters)
                    if let errorText {
                        Text(errorText).font(.coUI(13)).foregroundColor(.coCrossRed)
                    }
                    COPrimaryButton(title: joining ? "Joining…" : "Join Circle") { join() }
                        .opacity(canJoin ? 1 : 0.5)
                        .disabled(!canJoin)
                }
                .padding(20)
            }
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("Join a Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func join() {
        guard canJoin else { return }
        joining = true
        errorText = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                _ = try await SupabaseService.shared.joinCircle(code: trimmed)
                await onJoined()
                joining = false
                dismiss()
            } catch {
                joining = false
                errorText = "That code didn't match a circle. Double-check it and try again."
            }
        }
    }
}

// MARK: - Shared field

private func circleField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(label)
            .font(.coUI(13, weight: .medium))
            .foregroundColor(.coInkTertiary)
        TextField(placeholder, text: text)
            .font(.coUI(15))
            .foregroundColor(.coInk)
            .autocorrectionDisabled()
            .padding(12)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )
    }
}
