import SwiftUI
import UIKit

struct JourneyProgressView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showGraceSheet = false
    @State private var showPathPicker = false
    @State private var showPathDetail = false
    @State private var showAddWorking = false
    @State private var showBridgeInvite = false
    @State private var pathDetailDay: Int?

    private var workingThrough: [WorkingItem] { appState.workingItems }
    private var streak: StreakState { appState.streak }

    private static let rhythmKinds: [(key: String, label: String)] = [
        ("scripture", "Scripture"),
        ("prayer", "Prayer"),
        ("reflection", "Reflection"),
        ("community", "Community"),
        ("encouragement", "Encouragement"),
        ("devotional", "Devotional"),
        ("rest", "Rest"),
        ("church", "Church")
    ]

    private var weekRhythmValues: [CGFloat] {
        // Bars for the original six + rest/church if present
        let keys = ["scripture", "prayer", "reflection", "community", "encouragement", "devotional"]
        return keys.map { key in
            let count = appState.weekRhythm[key] ?? 0
            return min(1.0, CGFloat(count) / 7.0)
        }
    }

    private var activeRhythmBreakdown: [(key: String, label: String, count: Int)] {
        Self.rhythmKinds.compactMap { entry in
            let count = appState.weekRhythm[entry.key] ?? 0
            return count > 0 ? (entry.key, entry.label, count) : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Your Journey")
                    .font(.coDisplay(28, weight: .semibold))
                    .foregroundColor(.coInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                streakHero

                StreakWeekRow(states: streak.weekStates)

                if let badge = appState.newlyEarnedBadge {
                    badgeUnlockBanner(badge)
                }

                pathHero

                if let title = appState.justCompletedPathTitle {
                    milestoneBanner(title)
                }

                graceRibbon

                badgesSection

                withOthersSection

                workingThroughSection

                thisWeekCard

                rhythmBreakdown

                Text("Your progress is still here. Today is another opportunity.")
                    .font(.coUIItalic(12))
                    .foregroundColor(.coInkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 90)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .refreshable { await appState.reloadJourney() }
        .sheet(isPresented: $showGraceSheet) {
            GraceDaysSheet(
                graceUsed: streak.graceUsed,
                graceTotal: streak.graceTotal,
                heldYesterday: appState.graceStatus?.heldYesterday == true
            ) {
                Task {
                    _ = await appState.useGraceDay()
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPathPicker) {
            PathPickerSheet { slug in
                Task {
                    _ = try? await SupabaseService.shared.enrollJourney(slug: slug)
                    await appState.reloadJourney()
                    showPathDetail = true
                }
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $showPathDetail) {
            if let enrollment = appState.activePath {
                PathDetailView(
                    enrollment: enrollment,
                    initialDay: pathDetailDay
                ) {
                    await appState.reloadJourney()
                }
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showAddWorking) {
            AddWorkingItemSheet { text, slug in
                Task {
                    if let item = await SupabaseService.shared.addWorkingItem(text: text, focusSlug: slug) {
                        appState.workingItems.append(item)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBridgeInvite) {
            NavigationStack {
                BridgeComposerView(
                    prefills: BridgeComposerPrefill(
                        situation: .curiosity,
                        forceJourneyResponse: true,
                        pathTitle: appState.activePath?.title,
                        enrollmentId: appState.activePath?.id
                    ),
                    onSent: { await appState.reloadJourney() }
                )
                .environmentObject(appState)
            }
        }
        .task { await appState.reloadJourney() }
    }

    // MARK: - Streak fire

    private var streakHero: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                COIcon(.flame, size: 28, color: streak.current > 0 ? .coCrossRed : .coInkTertiary)
                Text("\(streak.current)")
                    .font(.coDisplay(48, weight: .semibold))
                    .foregroundColor(.coInk)
                    .contentTransition(.numericText())
            }
            Text("Day Streak")
                .font(.coUI(14, weight: .medium))
                .foregroundColor(.coInkSecondary)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    COIcon(.flame, size: 12, color: .coGold)
                    Text("Best \(streak.longest)")
                        .font(.coUI(12, weight: .medium))
                        .foregroundColor(.coGold)
                }
                Text("·")
                    .foregroundColor(.coInkTertiary)
                Text("\(streak.weekWithGodDays)/7 days this week")
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Path hero

    private var pathHero: some View {
        Group {
            if let path = appState.activePath {
                Button {
                    pathDetailDay = path.completedDays.contains(path.currentDay)
                        ? path.currentDay
                        : path.currentDay
                    showPathDetail = true
                } label: {
                    COCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ACTIVE PATH")
                                .font(.coUI(11, weight: .semibold))
                                .tracking(1.3)
                                .foregroundColor(.coInkTertiary)
                            Text(path.title)
                                .font(.coDisplay(22, weight: .semibold))
                                .foregroundColor(.coInk)
                                .multilineTextAlignment(.leading)
                            if let sub = path.subtitle, !sub.isEmpty {
                                Text(sub)
                                    .font(.coUI(13))
                                    .foregroundColor(.coInkSecondary)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack {
                                Text(path.progressLabel)
                                    .font(.coUI(13, weight: .medium))
                                    .foregroundColor(.coOlive)
                                Spacer()
                                Text(path.isComplete ? "Review" : "Continue Day \(min(path.currentDay, path.totalDays))")
                                    .font(.coUI(13, weight: .semibold))
                                    .foregroundColor(.coCrossRed)
                            }
                            pathProgressBar(path)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                COCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YOUR PATH")
                            .font(.coUI(11, weight: .semibold))
                            .tracking(1.3)
                            .foregroundColor(.coInkTertiary)
                        Text("Walk a short path of Scripture — one honest day at a time.")
                            .font(.coUI(14))
                            .foregroundColor(.coInkSecondary)
                            .lineSpacing(4)
                        COPrimaryButton(title: "Choose a Path") {
                            showPathPicker = true
                        }
                    }
                }
            }
        }
    }

    private func pathProgressBar(_ path: JourneyEnrollment) -> some View {
        let done = CGFloat(path.completedDays.count)
        let total = CGFloat(max(path.totalDays, 1))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.coDivider).frame(height: 4)
                Capsule()
                    .fill(Color.coOlive)
                    .frame(width: geo.size.width * min(1, done / total), height: 4)
            }
        }
        .frame(height: 4)
    }

    private func milestoneBanner(_ title: String) -> some View {
        COCard {
            HStack(spacing: 12) {
                COIcon(.flame, size: 20, color: .coGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Path complete")
                        .font(.coUI(14, weight: .semibold))
                        .foregroundColor(.coInk)
                    Text("You finished \(title). Grace carried you here — take a breath.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    appState.justCompletedPathTitle = nil
                } label: {
                    Text("✕")
                        .font(.coUI(13))
                        .foregroundColor(.coInkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Grace

    private var graceRibbon: some View {
        Button { showGraceSheet = true } label: {
            COCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        COIcon(.leaf, size: 22, color: .coOlive)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grace Days")
                                .font(.coUI(15, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text("\(max(0, streak.graceTotal - streak.graceUsed)) of \(streak.graceTotal) remaining this month")
                                .font(.coUI(13))
                                .foregroundColor(.coInkSecondary)
                        }
                        Spacer()
                        COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                    }
                    if appState.graceStatus?.heldYesterday == true || appState.graceStatus?.applied == true {
                        Text("Grace held your streak.")
                            .font(.coUIItalic(13))
                            .foregroundColor(.coOlive)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            let earned = appState.badges.filter(\.isEarned).count
            HStack(alignment: .firstTextBaseline) {
                Text("Badges")
                    .font(.coDisplay(20, weight: .semibold))
                    .foregroundColor(.coInk)
                Spacer()
                Text("\(earned)/\(appState.badges.count)")
                    .font(.coUI(13, weight: .semibold))
                    .foregroundColor(.coGold)
            }
            Text("Earn fires for streaks and marks for the practices that form you.")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(appState.badges) { badge in
                    badgeTile(badge)
                }
            }
        }
    }

    private func badgeTile(_ badge: FormationBadge) -> some View {
        let color = badgeTint(badge.tint)
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isEarned ? color.opacity(0.14) : Color.coPaperSecondary)
                    .frame(width: 44, height: 44)
                if badge.isEarned {
                    Circle()
                        .strokeBorder(color.opacity(0.45), lineWidth: 1.2)
                        .frame(width: 44, height: 44)
                }
                COIcon(badge.icon, size: 20, color: badge.isEarned ? color : .coInkTertiary)
            }
            Text(badge.title)
                .font(.coUI(11, weight: .semibold))
                .foregroundColor(badge.isEarned ? .coInk : .coInkTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 28)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(Color.coCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(badge.isEarned ? color.opacity(0.35) : Color.coDivider, lineWidth: 1)
        )
        .opacity(badge.isEarned ? 1 : 0.72)
        .accessibilityLabel("\(badge.title). \(badge.isEarned ? "Earned. \(badge.subtitle)" : "Locked. \(badge.subtitle)")")
    }

    private func badgeTint(_ tint: FormationBadge.BadgeTint) -> Color {
        switch tint {
        case .flame: return .coCrossRed
        case .gold: return .coGold
        case .olive: return .coOlive
        case .ink: return .coInkSecondary
        }
    }

    private func badgeUnlockBanner(_ badge: FormationBadge) -> some View {
        COCard {
            HStack(spacing: 12) {
                COIcon(badge.icon, size: 22, color: badgeTint(badge.tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Badge unlocked")
                        .font(.coUI(12, weight: .semibold))
                        .foregroundColor(.coGold)
                    Text(badge.title)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                    Text(badge.subtitle)
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    appState.newlyEarnedBadge = nil
                } label: {
                    Text("✕")
                        .font(.coUI(13))
                        .foregroundColor(.coInkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - With others

    private var withOthersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            COSectionHeader(title: "With others")
            if let path = appState.activePath, let name = path.companionName, !name.isEmpty {
                COCard {
                    HStack(spacing: 12) {
                        COAvatar(initials: String(name.prefix(1)).uppercased())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Walking with \(name)")
                                .font(.coUI(14, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text(path.progressLabel)
                                .font(.coUI(12))
                                .foregroundColor(.coInkSecondary)
                        }
                        Spacer()
                    }
                }
            } else if appState.activePath != nil {
                Button { showBridgeInvite = true } label: {
                    COCard {
                        HStack(spacing: 12) {
                            BridgeMotif(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Invite someone onto this path")
                                    .font(.coUI(14, weight: .semibold))
                                    .foregroundColor(.coInk)
                                Text("Build a Bridge — they walk it without installing the app.")
                                    .font(.coUI(12))
                                    .foregroundColor(.coInkSecondary)
                            }
                            Spacer()
                            COIcon(.chevronRight, size: 14, color: .coInkTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("Choose a path first — then you can invite someone to walk it with you.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Working through

    private var workingThroughSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "What you're working through", actionTitle: "Add") {
                showAddWorking = true
            }

            if workingThrough.isEmpty {
                COCard {
                    Text("Name what you're carrying — it gently shapes today's Scripture.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(4)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workingThrough.enumerated()), id: \.element.id) { index, item in
                        workingRow(index: index, item: item)
                        if index < workingThrough.count - 1 { CODivider() }
                    }
                }
                .padding(.horizontal, 4)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
                .coShadow(cornerRadius: 14)
            }
        }
    }

    private func workingRow(index: Int, item: WorkingItem) -> some View {
        HStack(spacing: 12) {
            CrossOutText(item.text, crossed: item.crossed)
            Spacer()
            if let slug = item.focusSlug, let label = FocusAreaSlugMap.slugToName[slug] {
                Text(label)
                    .font(.coUI(11))
                    .foregroundColor(.coOlive)
                    .lineLimit(1)
            }
            if !item.crossed {
                COIcon(.checkCircle, size: 18, color: .coInkTertiary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { crossOut(index) }
    }

    private func crossOut(_ index: Int) {
        guard workingThrough.indices.contains(index), !workingThrough[index].crossed else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        appState.crossWorkingItem(id: workingThrough[index].id)
    }

    private var thisWeekCard: some View {
        COCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("This Week")
                        .font(.coUI(11, weight: .medium))
                        .foregroundColor(.coInkTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text("\(streak.weekWithGodDays)/\(streak.weekWithGodTotal) Days with God")
                        .font(.coUI(14, weight: .semibold))
                        .foregroundColor(.coInk)
                }
                Spacer()
                RhythmBars(values: weekRhythmValues)
            }
        }
    }

    @ViewBuilder
    private var rhythmBreakdown: some View {
        let active = activeRhythmBreakdown
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(active, id: \.key) { entry in
                    HStack(spacing: 10) {
                        COIcon(.checkCircle, size: 14, color: .coOlive)
                        Text("\(entry.label) \(entry.count) of 7")
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Grace Days Sheet

private struct GraceDaysSheet: View {
    let graceUsed: Int
    let graceTotal: Int
    let heldYesterday: Bool
    var onUseGrace: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var using = false
    @State private var note: String?

    private var remaining: Int { max(0, graceTotal - graceUsed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                COIcon(.leaf, size: 22, color: .coOlive)
                Text("Grace Days")
                    .font(.coDisplay(22, weight: .semibold))
                    .foregroundColor(.coInk)
                Spacer()
            }
            Text("Life happens. Grace days let you miss a day without breaking your streak — and they apply automatically when you need them.")
                .font(.coUI(14))
                .foregroundColor(.coInkSecondary)
                .lineSpacing(4)

            if heldYesterday {
                Text("Grace held your streak yesterday.")
                    .font(.coUIItalic(14))
                    .foregroundColor(.coOlive)
            }

            VStack(spacing: 0) {
                row("Used this month", "\(graceUsed)")
                CODivider()
                row("Remaining", "\(remaining) of \(graceTotal)")
            }
            .padding(.horizontal, 14)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )

            if let note {
                Text(note)
                    .font(.coUI(12))
                    .foregroundColor(.coInkTertiary)
            }

            Spacer()

            if remaining > 0 {
                COPrimaryButton(title: using ? "Using grace…" : "Use a Grace Day today", tint: .coOlive) {
                    using = true
                    onUseGrace()
                    note = "Today is covered. Rest counts — your streak stays."
                    using = false
                }
            }

            COSecondaryButton(title: "Close") { dismiss() }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.coPaper.ignoresSafeArea())
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
            Spacer()
            Text(value)
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(.coInk)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Add working item

private struct AddWorkingItemSheet: View {
    var onAdd: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var focusSlug: String?

    private var focusOptions: [(slug: String, label: String)] {
        FocusAreaSlugMap.nameToSlug.map { (slug: $0.value, label: $0.key) }
            .sorted { $0.label < $1.label }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("What are you working through?")
                    .font(.coUI(14))
                    .foregroundColor(.coInkSecondary)
                TextField("e.g. Anxiety about work", text: $text)
                    .font(.coUI(16))
                    .padding(12)
                    .background(Color.coCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Link a focus (optional)")
                    .font(.coUI(12, weight: .medium))
                    .foregroundColor(.coInkTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(focusOptions.prefix(12), id: \.slug) { opt in
                            COChip(text: opt.label, selected: focusSlug == opt.slug) {
                                focusSlug = focusSlug == opt.slug ? nil : opt.slug
                            }
                        }
                    }
                }

                COPrimaryButton(title: "Add") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onAdd(trimmed, focusSlug)
                    dismiss()
                }
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
            }
            .padding(22)
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("Working through")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    JourneyProgressView()
        .environmentObject(AppState())
}
