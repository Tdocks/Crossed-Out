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

    @Published var passages: [Passage] = []
    @Published var prayers: [PrayerRequest] = []
    @Published var posts: [CommunityPost] = []
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
        prayers = MockData.prayerRequests
        posts = MockData.communityPosts
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
        }
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
        let newProfile = UserProfile(
            firstName: trimmedName.isEmpty ? "Friend" : trimmedName,
            focusAreas: focus,
            need: need,
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
