import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var hasOnboarded: Bool = false
    @Published var profile: UserProfile = MockData.profile
    @Published var todayEntry: DailyEntry = MockData.todayEntry
    @Published var streak: StreakState = MockData.streak
    @Published var selectedTab: COTab = .today
    @Published var checkInMood: Mood?

    @Published var passages: [Passage] = []
    @Published var prayers: [PrayerRequest] = []
    @Published var posts: [CommunityPost] = []
    @Published var churches: [Church] = []
    @Published var services: [LiveService] = []
    @Published var projects: [GiveProject] = []
    @Published var isSupabaseLive = false

    // MARK: - Lifecycle

    /// Loads initial state. Mock defaults show instantly; Supabase data
    /// replaces individual pieces as each fetch succeeds, independently.
    func bootstrap() async {
        profile = MockData.profile
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
            let signedIn = await service.signInAnonymouslyIfNeeded()

            if let fetched = try? await service.fetchPassages(topics: nil), !fetched.isEmpty {
                passages = fetched
                isSupabaseLive = true
            }
            if let fetched = try? await service.fetchPrayerRequests() {
                prayers = fetched
                isSupabaseLive = true
            }
            if let fetched = try? await service.fetchCommunityPosts() {
                posts = fetched
                isSupabaseLive = true
            }
            if let fetched = try? await service.fetchChurches(), !fetched.isEmpty {
                churches = fetched
                isSupabaseLive = true
            }
            if let fetched = try? await service.fetchLiveServices(), !fetched.isEmpty {
                services = fetched
                isSupabaseLive = true
            }
            if let fetched = try? await service.fetchGiveProjects(), !fetched.isEmpty {
                projects = fetched
                isSupabaseLive = true
            }

            guard signedIn else { return }
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
        Task {
            await SupabaseService.shared.saveCheckIn(mood: mood.rawValue, note: nil)
            await SupabaseService.shared.touchStreak()
        }
    }

    // MARK: - Onboarding

    func completeOnboarding(name: String, focus: [String], need: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newProfile = UserProfile(
            firstName: trimmedName.isEmpty ? "Friend" : trimmedName,
            focusAreas: focus,
            need: need,
            translation: MockData.profile.translation,
            dayNumber: 1
        )
        profile = newProfile
        hasOnboarded = true
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
}
