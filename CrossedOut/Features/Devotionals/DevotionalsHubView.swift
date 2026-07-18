import SwiftUI

/// Devotionals home: today's built-in devotional (with a deterministic
/// "show me another" re-roll and a gated "ask AI" escape hatch), plus the
/// user's own "independent study" devotionals. Pushed inside an existing
/// NavigationStack (from More), so it uses NavigationLinks directly.
struct DevotionalsHubView: View {
    @State private var today: Devotional?
    @State private var mine: [UserDevotional] = []
    @State private var seen: [UUID] = []
    @State private var loadingToday = true
    @State private var rerollingDevo = false
    @State private var showComposer = false
    @State private var showAi = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                todaySection
                mineSection
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle("Devotionals")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showComposer) {
            IndependentStudyComposerView { saved in
                withAnimation { mine.insert(saved, at: 0) }
            }
        }
        .sheet(isPresented: $showAi) {
            AiSuggestionSheet { saved in
                withAnimation { mine.insert(saved, at: 0) }
            }
        }
        .task { await loadToday() }
        .task { await loadMine() }
    }

    // MARK: Today's built-in devotional

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TODAY")
            if let today {
                NavigationLink { DevotionalDetailView(devotional: today) } label: {
                    todayCard(today)
                }
                .buttonStyle(.plain)
            } else if loadingToday {
                COCard { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12) }
            } else {
                COCard {
                    Text("No devotional available today. Check back soon.")
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if today != nil {
                HStack(spacing: 18) {
                    Button { rerollDevotional() } label: {
                        affordance(.leaf, rerollingDevo ? "Finding…" : "Show me another")
                    }
                    .buttonStyle(.plain)
                    .disabled(rerollingDevo)
                    Button { showAi = true } label: {
                        affordance(.prayer, "Ask AI for one")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }

    private func todayCard(_ d: Devotional) -> some View {
        COCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(d.verseRef.uppercased())
                    .font(.coUI(11, weight: .medium))
                    .tracking(1.3)
                    .foregroundColor(.coCrossRed)
                Text(d.title)
                    .font(.coDisplay(20, weight: .semibold))
                    .foregroundColor(.coInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(d.body)
                    .font(.coScripture(15))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(5)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text("Read devotional")
                        .font(.coUI(12, weight: .medium))
                        .foregroundColor(.coOlive)
                    COIcon(.chevronRight, size: 13, color: .coOlive)
                }
                .padding(.top, 2)
            }
        }
    }

    private func affordance(_ icon: COIconName, _ text: String) -> some View {
        HStack(spacing: 5) {
            COIcon(icon, size: 13, color: .coOlive)
            Text(text)
                .font(.coUI(12, weight: .medium))
                .foregroundColor(.coOlive)
        }
    }

    private func rerollDevotional() {
        guard !rerollingDevo else { return }
        rerollingDevo = true
        Task {
            if let next = await SupabaseService.shared.nextDevotional(excluding: seen) {
                withAnimation { today = next }
                seen.append(next.id)
            }
            rerollingDevo = false
        }
    }

    // MARK: The user's independent-study devotionals

    private var mineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("YOUR STUDIES")
                Spacer()
                Button { showComposer = true } label: {
                    HStack(spacing: 4) {
                        COIcon(.note, size: 14, color: .coOlive)
                        Text("Add")
                            .font(.coUI(13, weight: .semibold))
                            .foregroundColor(.coOlive)
                    }
                }
                .buttonStyle(.plain)
            }

            if mine.isEmpty {
                Button { showComposer = true } label: {
                    COCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Log your own study")
                                .font(.coUI(15, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text("Did a devotional on your own? Save the verse and your notes here.")
                                .font(.coUI(13))
                                .foregroundColor(.coInkSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(mine) { d in
                        NavigationLink { UserDevotionalDetailView(devotional: d) } label: {
                            studyRow(d)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func studyRow(_ d: UserDevotional) -> some View {
        COCard {
            HStack(spacing: 12) {
                COIcon(.study, size: 20, color: .coInkSecondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(d.title?.isEmpty == false ? d.title! : d.verseRef)
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                        .lineLimit(1)
                    Text(d.verseRef)
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                        .lineLimit(1)
                }
                Spacer()
                COIcon(.chevronRight, size: 15, color: .coInkTertiary)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.coUI(11, weight: .medium))
            .tracking(1.3)
            .foregroundColor(.coInkTertiary)
    }

    private func loadToday() async {
        today = await SupabaseService.shared.fetchTodayDevotional()
        if let id = today?.id { seen = [id] }
        loadingToday = false
    }

    private func loadMine() async {
        mine = await SupabaseService.shared.listMyDevotionals()
    }
}
