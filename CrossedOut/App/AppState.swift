import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var hasOnboarded: Bool = false
    /// True when there is a persisted, active Supabase session. The app has
    /// no anonymous fallback — a real account is required to use it.
    @Published var isAuthenticated: Bool = false
    @Published var profile: UserProfile = MockData.profile
    @Published var todayEntry: DailyEntry = MockData.todayEntry
    @Published var streak: StreakState = MockData.streak
    @Published var selectedTab: COTab = .today
    @Published var checkInMood: Mood?
    @Published var tabBarHidden = false

    /// True when the signed-in user has NOT yet accepted the current Terms
    /// version (migration 0023). RootView blocks the app behind
    /// LegalAcceptanceGateView while this is set. Fails open on network
    /// errors — we never lock a user out because a check couldn't run.
    @Published var needsLegalAcceptance = false

    // MARK: - Role & verification (migration 0021)
    @Published var role: UserRole = .user
    @Published var accountStatus: AccountStatus = .active
    @Published var churchId: UUID?

    /// Tyler / other allow-listed accounts. Can verify churches + mint invites.
    var isSystemAdmin: Bool { role == .systemAdmin }
    /// Manages a church (edit its info, interact with community).
    var isChurchAdmin: Bool { role == .churchAdmin }
    /// A church that self-signed-up in the app and has no access until a
    /// system admin verifies it. Gated at RootView.
    var isPendingVerification: Bool { accountStatus == .pendingVerification }

    /// Quiet "why this verse" line from the deterministic personalization
    /// engine (recommend_today_verse RPC). Nil whenever that engine hasn't
    /// produced a result — Today's screen simply omits the reason line then.
    @Published var todayVerseReason: String?
    /// The curated_verse_id backing the current recommendation, if it has
    /// one — nil for an AI-tagged verse with no matching curated_verses
    /// row (migration 0013). No longer used to attribute feedback (see
    /// book/chapter/verse below); kept for anything else that wants it.
    @Published var todayVerseCuratedID: String?
    /// Verse reference identity of the current recommendation. Feedback
    /// signals (spoke / not_today) are attributed by this, not by
    /// curated_verse_id, so feedback works for ANY recommended verse.
    @Published var todayVerseBook: String?
    @Published var todayVerseChapter: Int?
    @Published var todayVerseVerse: Int?

    /// The "understand" step: curated pastoral context for today's verse
    /// (curated_verses.theme_summary via the recommend engine). Nil for an
    /// AI-tagged verse with no curated row — Today falls back to a
    /// focus-based line, never a placeholder.
    @Published var todayVerseContext: String?
    /// The "act" step: today's deterministic practical action
    /// (today_practice_action RPC, migration 0025). Nil hides the card.
    @Published var todayAction: PracticeAction?

    @Published var passages: [Passage] = []
    @Published var prayers: [PrayerRequest] = []
    @Published var posts: [CommunityPost] = []
    /// Community feed load state. The feed NEVER shows mock content — fake
    /// user posts are worse than an honest empty/error state.
    @Published var communityLoading = true
    @Published var communityLoadFailed = false
    @Published var churches: [Church] = []
    @Published var services: [LiveService] = []
    @Published var projects: [GiveProject] = []
    @Published var isSupabaseLive = false
    @Published var isOffline = false
    @Published var workingItems: [WorkingItem] = MockData.streak.workingThrough
    @Published var weekRhythm: [String: Int] = [:]

    // MARK: - Persistence Keys

    private enum DefaultsKey {
        static let hasOnboarded = "co.hasOnboarded"
        static let profile = "co.profile"
        static let firstOpenDate = "co.firstOpenDate"
        static let lastCheckInDate = "co.lastCheckInDate"
        static let todayMoodPrefix = "co.todayMood."
        static let seededWorkingItems = "co.seededWorkingItems"
        static let role = "co.role"
        static let accountStatus = "co.accountStatus"
        static let churchId = "co.churchId"
        static let legalAcceptedVersion = "co.legalAcceptedVersion"
    }

    // MARK: - Init

    /// Restores persisted onboarding/profile state before bootstrap() runs
    /// so mock defaults only ever fill in what's still missing.
    init() {
        let defaults = UserDefaults.standard
        hasOnboarded = defaults.bool(forKey: DefaultsKey.hasOnboarded)
        if let data = defaults.data(forKey: DefaultsKey.profile),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        }
        if let moodRaw = defaults.string(forKey: DefaultsKey.todayMoodPrefix + Self.dayKey()),
           let mood = Mood(rawValue: moodRaw) {
            checkInMood = mood
        }
        // Restore role/status so the launch-time gate (RootView) is correct
        // before the network profile fetch lands — avoids briefly showing app
        // content to a church account that's still pending verification.
        role = UserRole(rawValue: defaults.string(forKey: DefaultsKey.role) ?? "") ?? .user
        accountStatus = AccountStatus(rawValue: defaults.string(forKey: DefaultsKey.accountStatus) ?? "") ?? .active
        if let cid = defaults.string(forKey: DefaultsKey.churchId) { churchId = UUID(uuidString: cid) }
    }

    // MARK: - Lifecycle

    /// Loads initial state. Mock defaults show instantly; Supabase data
    /// replaces individual pieces as each fetch succeeds, independently.
    func bootstrap() async {
        refreshAuthState()

        // Mock fills only what's missing — a restored (persisted) profile
        // from a completed onboarding is left in place.
        if !hasOnboarded {
            profile = MockData.profile
        }
        todayEntry = MockData.todayEntry
        streak = MockData.streak
        passages = [MockData.proverbs3BSB, MockData.psalm23, MockData.philippians4]
        // Community intentionally NOT mock-seeded: an empty or honest error
        // state beats fake user content (see CommunityView's states).
        churches = MockData.churches
        services = MockData.startingSoon + MockData.tomorrowServices
        projects = MockData.giveProjects

        Task {
            let service = SupabaseService.shared

            let passagesResult = try? await service.fetchPassages(topics: nil)
            if let fetched = passagesResult, !fetched.isEmpty {
                passages = fetched
                isSupabaseLive = true
            }
            let prayersResult = try? await service.fetchPrayerRequests()
            if let fetched = prayersResult {
                prayers = fetched
                isSupabaseLive = true
            }
            let postsResult = try? await service.fetchCommunityPosts()
            if let fetched = postsResult {
                posts = fetched
                isSupabaseLive = true
            }
            communityLoading = false
            communityLoadFailed = prayersResult == nil && postsResult == nil
            let churchesResult = try? await service.fetchChurches()
            if let fetched = churchesResult, !fetched.isEmpty {
                churches = fetched
                isSupabaseLive = true
            }
            let servicesResult = try? await service.fetchLiveServices()
            if let fetched = servicesResult, !fetched.isEmpty {
                services = fetched
                isSupabaseLive = true
            }
            let projectsResult = try? await service.fetchGiveProjects()
            if let fetched = projectsResult, !fetched.isEmpty {
                projects = fetched
                isSupabaseLive = true
            }

            // Quiet offline signal: only trip when every single bootstrap
            // fetch failed outright (not merely "returned empty").
            isOffline = passagesResult == nil
                && prayersResult == nil
                && postsResult == nil
                && churchesResult == nil
                && servicesResult == nil
                && projectsResult == nil

            // Day number is always derived locally from firstOpenDate, then
            // refined by remote profile data (if signed in and one exists).
            let computedDayNumber = currentDayNumber()
            profile.dayNumber = computedDayNumber
            persistProfile()

            guard isAuthenticated else { return }

            await refreshLegalAcceptance()

            weekRhythm = (try? await service.fetchWeekCompletions()) ?? [:]

            // Streak read-back: server values win for counters, local week view kept.
            if let remote = try? await service.fetchStreak().flatMap({ $0 }) {
                streak = StreakState(
                    current: max(remote.current, streak.current),
                    longest: max(remote.longest, streak.longest),
                    graceUsed: remote.graceUsed,
                    graceTotal: remote.graceTotal,
                    weekStates: streak.weekStates,
                    weekWithGodDays: streak.weekWithGodDays,
                    weekWithGodTotal: streak.weekWithGodTotal,
                    workingThrough: streak.workingThrough
                )
            }

            // Working items: seed once from local defaults, then read back.
            if let items = try? await service.fetchWorkingItems() {
                if items.isEmpty, hasOnboarded,
                   !UserDefaults.standard.bool(forKey: DefaultsKey.seededWorkingItems) {
                    UserDefaults.standard.set(true, forKey: DefaultsKey.seededWorkingItems)
                    await service.seedWorkingItems(workingItems.map(\.text))
                    if let seeded = try? await service.fetchWorkingItems(), !seeded.isEmpty {
                        workingItems = seeded
                    }
                } else if !items.isEmpty {
                    workingItems = items
                }
            }

            if let remote = try? await service.fetchProfile() {
                profile = UserProfile(
                    id: profile.id,
                    firstName: remote.firstName ?? profile.firstName,
                    focusAreas: remote.focusAreas ?? profile.focusAreas,
                    need: remote.need ?? profile.need,
                    translation: remote.translation ?? profile.translation,
                    dayNumber: remote.dayNumber ?? computedDayNumber
                )
                persistProfile()
                applyRoleState(role: UserRole(dbValue: remote.role),
                               status: AccountStatus(dbValue: remote.accountStatus),
                               churchId: remote.churchId)
            } else if hasOnboarded {
                await service.upsertProfile(
                    firstName: profile.firstName,
                    need: profile.need,
                    translation: profile.translation,
                    dayNumber: profile.dayNumber,
                    focusAreas: profile.focusAreas
                )
            }

            if let recommended = await service.recommendPassage(
                focus: profile.focusAreas,
                mood: checkInMood?.rawValue
            ) {
                todayEntry = DailyEntry(
                    id: todayEntry.id,
                    date: todayEntry.date,
                    greetingName: todayEntry.greetingName,
                    carryingPrompt: todayEntry.carryingPrompt,
                    userNeed: todayEntry.userNeed,
                    verse: recommended,
                    focusTitle: todayEntry.focusTitle,
                    focusWhy: todayEntry.focusWhy,
                    dayNumber: todayEntry.dayNumber
                )
            }

            // Deterministic personalization engine (recommend_today_verse
            // RPC) — purely additive. If it succeeds it takes priority over
            // whatever verse is currently set above; if it's unavailable
            // (e.g. migration 0009 not yet deployed) this silently no-ops
            // and today's existing verse/behavior is left untouched.
            await applyRecommendedVerseIfAvailable(mood: checkInMood?.rawValue)

            // The "act" step: today's deterministic practical action.
            await refreshTodayAction(mood: checkInMood?.rawValue)
        }
    }

    /// Attempts the new deterministic personalization engine and, only on
    /// success, overrides Today's verse + exposes a reason line. Any
    /// failure (RPC not deployed, no match, verse text lookup failure) is
    /// swallowed — never surfaces an error, never blanks the verse.
    private func applyRecommendedVerseIfAvailable(mood: String?) async {
        let slugs = FocusAreaSlugMap.slugs(for: profile.focusAreas)
        guard let recommended = (try? await SupabaseService.shared.recommendTodayVerse(
            focusSlugs: slugs, mood: mood, tone: nil, maturity: nil
        )) ?? nil else { return }

        todayEntry = DailyEntry(
            id: todayEntry.id,
            date: todayEntry.date,
            greetingName: todayEntry.greetingName,
            carryingPrompt: todayEntry.carryingPrompt,
            userNeed: todayEntry.userNeed,
            verse: recommended.passage,
            focusTitle: todayEntry.focusTitle,
            focusWhy: todayEntry.focusWhy,
            dayNumber: todayEntry.dayNumber
        )
        todayVerseReason = recommended.reason
        todayVerseCuratedID = recommended.curatedVerseId
        todayVerseBook = recommended.book
        todayVerseChapter = recommended.chapter
        todayVerseVerse = recommended.verse
        todayVerseContext = recommended.themeSummary
    }

    /// Loads/refreshes today's deterministic practical action ("one small
    /// step"). Stable within the day server-side; re-run after a mood
    /// check-in so a mood-matched practice can win the tiebreak.
    func refreshTodayAction(mood: String?) async {
        let slugs = FocusAreaSlugMap.slugs(for: profile.focusAreas)
        todayAction = await SupabaseService.shared.fetchTodayPracticeAction(
            focusSlugs: slugs, mood: mood
        )
    }

    /// Refreshes the community feed. Used by pull-to-refresh, after
    /// composing, and after a block (so server-side RLS filtering takes
    /// effect immediately).
    func reloadCommunity() async {
        let service = SupabaseService.shared
        let prayersResult = try? await service.fetchPrayerRequests()
        let postsResult = try? await service.fetchCommunityPosts()
        if let fetched = prayersResult { prayers = fetched }
        if let fetched = postsResult { posts = fetched }
        communityLoadFailed = prayersResult == nil && postsResult == nil
        communityLoading = false
    }

    // MARK: - Legal acceptance (migration 0023)

    /// Determines whether the signed-in user must accept the current Terms
    /// version. Local cache wins (and is re-synced to the server in the
    /// background); otherwise the server record is checked. Network failure
    /// fails open — the gate only ever shows on a definitive "not accepted".
    func refreshLegalAcceptance() async {
        guard isAuthenticated else {
            needsLegalAcceptance = false
            return
        }
        let current = LegalDocuments.termsVersion
        if UserDefaults.standard.string(forKey: DefaultsKey.legalAcceptedVersion) == current {
            // Accepted on this device — make sure the server record exists
            // (covers an acceptance that happened while offline).
            Task { await SupabaseService.shared.recordLegalAcceptance(version: current) }
            needsLegalAcceptance = false
            return
        }
        do {
            let accepted = try await SupabaseService.shared.hasAcceptedLegal(version: current)
            if accepted {
                UserDefaults.standard.set(current, forKey: DefaultsKey.legalAcceptedVersion)
            }
            needsLegalAcceptance = !accepted
        } catch {
            // Couldn't check (offline, migration not applied yet) — never
            // lock the user out over that.
            needsLegalAcceptance = false
        }
    }

    /// Called by LegalAcceptanceGateView's "I Agree": records acceptance
    /// (local cache + idempotent server insert) and clears the gate.
    func acceptCurrentLegal() {
        needsLegalAcceptance = false
        Task { await SupabaseService.shared.recordLegalAcceptance(version: LegalDocuments.termsVersion) }
    }

    /// Tier 2 (G19 §9): deterministic re-roll of Today's verse. Penalizes +
    /// clears today's pick server-side, then re-runs the SAME deterministic
    /// engine — no AI. No-ops silently if the engine isn't available.
    func rerollTodayVerse() async {
        await SupabaseService.shared.prepareVerseReroll()
        await applyRecommendedVerseIfAvailable(mood: checkInMood?.rawValue)
    }

    // MARK: - Check-In

    func saveCheckIn(mood: Mood) async {
        checkInMood = mood
        UserDefaults.standard.set(mood.rawValue, forKey: DefaultsKey.todayMoodPrefix + Self.dayKey())

        if let recommended = await SupabaseService.shared.recommendPassage(
            focus: profile.focusAreas,
            mood: mood.rawValue
        ), recommended != todayEntry.verse {
            withAnimation(.easeInOut(duration: 0.35)) {
                todayEntry = DailyEntry(
                    id: todayEntry.id,
                    date: todayEntry.date,
                    greetingName: todayEntry.greetingName,
                    carryingPrompt: todayEntry.carryingPrompt,
                    userNeed: todayEntry.userNeed,
                    verse: recommended,
                    focusTitle: todayEntry.focusTitle,
                    focusWhy: todayEntry.focusWhy,
                    dayNumber: todayEntry.dayNumber
                )
            }
        }

        // Deterministic personalization engine, re-run with the freshly
        // picked mood. Purely additive — falls back silently if unavailable.
        await applyRecommendedVerseIfAvailable(mood: mood.rawValue)

        // Refresh the practical action too: a mood-matched practice can now
        // win the deterministic tiebreak.
        await refreshTodayAction(mood: mood.rawValue)

        bumpStreakForCheckInIfNeeded()

        Task {
            await SupabaseService.shared.saveCheckIn(mood: mood.rawValue, note: nil)
            await SupabaseService.shared.touchStreak()
            await SupabaseService.shared.recordCompletion(kind: "scripture")
        }
    }

    /// Bumps the streak locally the first time the user checks in on a given
    /// day, so the UI feels instant even before touchStreak() round-trips.
    private func bumpStreakForCheckInIfNeeded() {
        let defaults = UserDefaults.standard
        let today = Self.dayKey()
        guard defaults.string(forKey: DefaultsKey.lastCheckInDate) != today else { return }
        defaults.set(today, forKey: DefaultsKey.lastCheckInDate)

        var newWeekStates = streak.weekStates
        if let idx = newWeekStates.firstIndex(of: .today) {
            newWeekStates[idx] = .done
        }
        let newCurrent = streak.current + 1
        streak = StreakState(
            current: newCurrent,
            longest: max(streak.longest, newCurrent),
            graceUsed: streak.graceUsed,
            graceTotal: streak.graceTotal,
            weekStates: newWeekStates,
            weekWithGodDays: streak.weekWithGodDays,
            weekWithGodTotal: streak.weekWithGodTotal,
            workingThrough: streak.workingThrough
        )
    }

    // MARK: - Onboarding

    func completeOnboarding(name: String, focus: [String], need: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNeed = need.trimmingCharacters(in: .whitespacesAndNewlines)
        let newProfile = UserProfile(
            firstName: trimmedName.isEmpty ? "Friend" : trimmedName,
            focusAreas: focus,
            need: trimmedNeed.isEmpty ? "I want to grow closer to God." : trimmedNeed,
            translation: MockData.profile.translation,
            dayNumber: currentDayNumber()
        )
        profile = newProfile
        hasOnboarded = true
        refreshAuthState()
        persistHasOnboarded()
        persistProfile()
        Task {
            await SupabaseService.shared.upsertProfile(
                firstName: newProfile.firstName,
                need: newProfile.need,
                translation: newProfile.translation,
                dayNumber: newProfile.dayNumber,
                focusAreas: newProfile.focusAreas
            )
        }
    }

    // MARK: - Church application

    /// Finalizes an in-app church signup: marks onboarding complete (so the
    /// user clears the OnboardingView gate) and records the church_admin /
    /// pending_verification state so RootView shows the pending screen.
    func completeChurchApplication(churchId: UUID) {
        hasOnboarded = true
        persistHasOnboarded()
        refreshAuthState()
        applyRoleState(role: .churchAdmin, status: .pendingVerification, churchId: churchId)
    }

    // MARK: - Auth

    /// Refreshes `isAuthenticated` from the current Supabase session state.
    /// Call this after any sign-in or sign-out so the auth gate in RootView
    /// stays in sync with the real session.
    func refreshAuthState() {
        isAuthenticated = SupabaseService.shared.isAuthenticated
    }

    /// Called after a successful sign-in from AuthSheet: marks onboarding
    /// complete, refreshes auth state, and re-runs bootstrap so remote data
    /// merges in.
    func refreshAfterAuth() {
        hasOnboarded = true
        refreshAuthState()
        persistHasOnboarded()
        Task { await bootstrap() }
    }

    /// Signs out. `hasOnboarded` is intentionally left untouched so a
    /// returning user who signs out lands on the mandatory auth gate
    /// (RootView) rather than being sent back through onboarding.
    func signOutAndReset() {
        isAuthenticated = false
        clearRoleState()
        // Legal acceptance is per-account: a different account signing in on
        // this device must not inherit the previous account's acceptance.
        UserDefaults.standard.removeObject(forKey: DefaultsKey.legalAcceptedVersion)
        needsLegalAcceptance = false
        Task {
            await SupabaseService.shared.signOut()
            refreshAuthState()
        }
    }

    /// Crosses out a working item locally and syncs to Supabase.
    func crossWorkingItem(id: UUID) {
        guard let idx = workingItems.firstIndex(where: { $0.id == id }),
              !workingItems[idx].crossed else { return }
        withAnimation(.easeOut(duration: 0.35)) {
            workingItems[idx].crossed = true
        }
        let itemID = workingItems[idx].id
        Task { await SupabaseService.shared.setWorkingItemCrossed(id: itemID, crossed: true) }
    }

    // MARK: - Profile Updates

    /// Updates only the fields provided, persists locally, and syncs to
    /// Supabase. Used by SettingsView for both the profile "Save" action and
    /// standalone preference changes (like translation).
    func updateProfile(firstName: String? = nil, need: String? = nil, focus: [String]? = nil, translation: String? = nil) {
        let newProfile = UserProfile(
            id: profile.id,
            firstName: firstName ?? profile.firstName,
            focusAreas: focus ?? profile.focusAreas,
            need: need ?? profile.need,
            translation: translation ?? profile.translation,
            dayNumber: profile.dayNumber
        )
        profile = newProfile
        persistProfile()
        Task {
            await SupabaseService.shared.upsertProfile(
                firstName: newProfile.firstName,
                need: newProfile.need,
                translation: newProfile.translation,
                dayNumber: newProfile.dayNumber,
                focusAreas: newProfile.focusAreas
            )
        }
    }

    // MARK: - Persistence Helpers

    private func persistProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.profile)
    }

    /// Applies + persists role/status/churchId from a remote profile fetch.
    func applyRoleState(role: UserRole, status: AccountStatus, churchId: UUID?) {
        self.role = role
        self.accountStatus = status
        self.churchId = churchId
        let defaults = UserDefaults.standard
        defaults.set(role.rawValue, forKey: DefaultsKey.role)
        defaults.set(status.rawValue, forKey: DefaultsKey.accountStatus)
        if let churchId { defaults.set(churchId.uuidString, forKey: DefaultsKey.churchId) }
        else { defaults.removeObject(forKey: DefaultsKey.churchId) }
    }

    /// Resets role/status to defaults (used on sign-out).
    private func clearRoleState() {
        applyRoleState(role: .user, status: .active, churchId: nil)
    }

    private func persistHasOnboarded() {
        UserDefaults.standard.set(hasOnboarded, forKey: DefaultsKey.hasOnboarded)
    }

    /// Days since firstOpenDate (persisted on first launch) + 1.
    private func currentDayNumber() -> Int {
        let defaults = UserDefaults.standard
        let firstOpen: Date
        if let existing = defaults.object(forKey: DefaultsKey.firstOpenDate) as? Date {
            firstOpen = existing
        } else {
            firstOpen = Date()
            defaults.set(firstOpen, forKey: DefaultsKey.firstOpenDate)
        }
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: firstOpen)
        let today = cal.startOfDay(for: Date())
        let days = cal.dateComponents([.day], from: start, to: today).day ?? 0
        return max(1, days + 1)
    }

    private static func dayKey() -> String {
        SupabaseService.dayString(Date())
    }
}
