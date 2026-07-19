import Foundation

/// Static sample content used until Supabase wiring lands.
enum MockData {

    // MARK: - Profile

    static let profile = UserProfile(
        firstName: "Tyler",
        focusAreas: ["Financial Wisdom"],
        need: "I need wisdom about money and direction.",
        translation: "BSB",
        dayNumber: 16
    )

    // MARK: - Scripture

    static let proverbs3WEB = Passage(
        ref: VerseRef(book: "Proverbs", chapter: 3, verseStart: 5, verseEnd: 6),
        translation: "WEB",
        text: "Trust in Yahweh with all your heart, and don't lean on your own understanding. In all your ways acknowledge him, and he will make your paths straight.",
        topics: ["trust", "anxiety", "guidance", "finance"]
    )

    static let proverbs3BSB = Passage(
        ref: VerseRef(book: "Proverbs", chapter: 3, verseStart: 5, verseEnd: 6),
        translation: "BSB",
        text: "Trust in the LORD with all your heart, and lean not on your own understanding; in all your ways acknowledge Him, and He will make your paths straight.",
        topics: ["trust", "anxiety", "guidance", "finance"]
    )

    static let psalm23 = Passage(
        ref: VerseRef(book: "Psalm", chapter: 23, verseStart: 1, verseEnd: 3),
        translation: "BSB",
        text: "A Psalm of David. The LORD is my shepherd; I shall not want. He makes me lie down in green pastures; He leads me beside quiet waters. He restores my soul; He guides me in the paths of righteousness for the sake of His name.",
        topics: ["peace", "rest", "trust"]
    )

    static let philippians4 = Passage(
        ref: VerseRef(book: "Philippians", chapter: 4, verseStart: 6, verseEnd: 7),
        translation: "BSB",
        text: "Be anxious for nothing, but in everything, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which surpasses all understanding, will guard your hearts and your minds in Christ Jesus.",
        topics: ["anxiety", "peace", "prayer"]
    )

    // MARK: - Today

    static var todayEntry: DailyEntry {
        DailyEntry(
            date: Date(),
            greetingName: "Tyler",
            carryingPrompt: "What are you carrying today?",
            userNeed: "I need wisdom about money and direction.",
            verse: proverbs3BSB,
            focusTitle: "Financial Wisdom",
            focusWhy: "You've been focusing on financial wisdom and trusting God's plan.",
            dayNumber: 16
        )
    }

    /// A friendly long-form date like "Tuesday, May 14".
    static func displayDate(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    // MARK: - Bible Reader

    static let john14 = BibleChapter(
        book: "John",
        chapter: 14,
        translation: "BSB",
        heading: "Jesus Comforts His Disciples",
        verses: [
            BibleVerse(number: 1, text: "“Do not let your hearts be troubled. You believe in God; believe in Me as well."),
            BibleVerse(number: 2, text: "In My Father’s house are many rooms. If it were not so, would I have told you that I am going there to prepare a place for you?"),
            BibleVerse(number: 3, text: "And if I go and prepare a place for you, I will come back and welcome you into My presence, so that you also may be where I am."),
            BibleVerse(number: 4, text: "You know the way to the place where I am going.”")
        ]
    )

    // MARK: - Kyra

    static let kyraConversation: [ChatMessage] = [
        ChatMessage(role: .user, text: "Help me understand this verse in the context of my life right now."),
        ChatMessage(role: .kyra, text: "Of course, Tyler. John 14 is Jesus speaking to His disciples before the cross. He's assuring them of His presence, His Father's house, and His promise to return.\n\nIt sounds like you're carrying some uncertainty about the future. Jesus is inviting you to trust that He's preparing something good, even when you can't see it yet.\n\nWould you like a prayer for trust and peace today?"),
        ChatMessage(role: .user, text: "Yes, please.")
    ]

    // MARK: - Streak

    static var streak: StreakState {
        StreakState(
            current: 18,
            longest: 24,
            graceUsed: 2,
            graceTotal: 3,
            weekStates: [.done, .done, .done, .done, .done, .today, .future],
            weekWithGodDays: 5,
            weekWithGodTotal: 7,
            workingThrough: [
                WorkingItem(text: "I have to carry this alone", crossed: true),
                WorkingItem(text: "I am too far behind", crossed: true),
                WorkingItem(text: "Learning patience", crossed: false),
                WorkingItem(text: "Building financial wisdom", crossed: false),
                WorkingItem(text: "Reconnecting with community", crossed: false)
            ]
        )
    }

    // MARK: - Community

    static let prayerRequests: [PrayerRequest] = [
        PrayerRequest(authorName: "Jessica L.", timeAgo: "2h ago",
                      text: "Please pray for my dad's surgery on Friday. Thank you!",
                      prayedCount: 12)
    ]

    static let communityPosts: [CommunityPost] = [
        CommunityPost(authorName: "Jessica L.", timeAgo: "2h ago", kind: .prayer,
                      text: "Please pray for my dad's surgery on Friday. Thank you!",
                      heartCount: 12),
        CommunityPost(authorName: "Mark D.", timeAgo: "5h ago", kind: .verseShare,
                      text: "This got me through today.",
                      verseRef: "John 16:33",
                      verseText: "I have told you these things so that in Me you may have peace. In the world you will have tribulation. But take courage; I have overcome the world!",
                      heartCount: 18)
    ]

    // MARK: - Attend

    static let elevationChurch = Church(
        name: "Elevation Church", city: "Charlotte, NC", rating: 4.8,
        style: "Contemporary", distanceMiles: 1.2, isLive: true, viewers: 2100, accent: "coBlue"
    )

    static let liveNow = LiveService(
        church: elevationChurch, title: "Sunday Service",
        startsIn: "Live now", isLive: true, time: nil
    )

    static let startingSoon: [LiveService] = [
        LiveService(church: Church(name: "Bethel Church", city: "Redding, CA", rating: 4.7,
                                   style: "Worship", distanceMiles: 2.1, accent: "coOlive"),
                    title: "Worship Night", startsIn: "18m", isLive: false, time: nil),
        LiveService(church: Church(name: "Saddleback Church", city: "Lake Forest, CA", rating: 4.6,
                                   style: "Bible Teaching", distanceMiles: 3.3, accent: "coGold"),
                    title: "Weekend Service", startsIn: "45m", isLive: false, time: nil)
    ]

    static let tomorrowServices: [LiveService] = [
        LiveService(church: Church(name: "Hillsong Church Global", city: "Global", rating: 4.7,
                                   style: "Contemporary", distanceMiles: 0, accent: "coBlue"),
                    title: "Global Service", startsIn: "Tomorrow", isLive: false, time: "9:00 AM")
    ]

    static let churches: [Church] = [
        Church(name: "Elevation Church", city: "Charlotte, NC", rating: 4.8,
               style: "Contemporary", distanceMiles: 1.2, accent: "coBlue"),
        Church(name: "The Belonging Co", city: "Nashville, TN", rating: 4.7,
               style: "Worship", distanceMiles: 2.1, accent: "coOlive"),
        Church(name: "Freedom Church", city: "Charlotte, NC", rating: 4.6,
               style: "Contemporary", distanceMiles: 3.3, accent: "coGold"),
        Church(name: "City Church", city: "Charlotte, NC", rating: 4.5,
               style: "Bible Teaching", distanceMiles: 4.8, accent: "coBlue")
    ]

    // MARK: - Give

    static let giveProjects: [GiveProject] = [
        GiveProject(title: "Feed the Homeless", org: "Charlotte, NC",
                    raised: 4820, goal: 10000, dateRange: nil),
        GiveProject(title: "Mission Trip to Kenya", org: "Global Missions",
                    raised: 3150, goal: 5000, dateRange: "Jul 12 – Jul 24")
    ]

    // MARK: - Explore

    static let exploreRecommended: [String] = [
        "Devotional: Overcoming Anxiety",
        "Rest in Him — Worship Playlist"
    ]

    static let musicForYou: [String] = [
        "Peace in the Storm",
        "Gratitude",
        "Sunday Morning"
    ]

    // MARK: - Focus Areas

    static let focusAreas: [FocusArea] = [
        FocusArea(name: "Anxiety", iconHint: "flame"),
        FocusArea(name: "Purpose", iconHint: "today"),
        FocusArea(name: "Relationships", iconHint: "community"),
        FocusArea(name: "Financial Wisdom", iconHint: "give"),
        FocusArea(name: "Forgiveness", iconHint: "heart"),
        FocusArea(name: "Grief", iconHint: "leaf"),
        FocusArea(name: "Discipline", iconHint: "checkCircle"),
        FocusArea(name: "Loneliness", iconHint: "prayer"),
        FocusArea(name: "Marriage", iconHint: "heart"),
        FocusArea(name: "Parenting", iconHint: "community"),
        FocusArea(name: "Temptation", iconHint: "flame"),
        FocusArea(name: "Career", iconHint: "study"),
        FocusArea(name: "Confidence", iconHint: "today"),
        FocusArea(name: "Understanding God", iconHint: "bible"),
        FocusArea(name: "Returning to Faith", iconHint: "church"),
        FocusArea(name: "Learning to Pray", iconHint: "prayer"),
        FocusArea(name: "Depression & Hope", iconHint: "heart"),
        FocusArea(name: "Motivation", iconHint: "flame"),
        FocusArea(name: "Addiction", iconHint: "checkCircle"),
        FocusArea(name: "Anger", iconHint: "flame"),
        FocusArea(name: "Leadership", iconHint: "study"),
        FocusArea(name: "New to Christianity", iconHint: "bible"),
        FocusArea(name: "Understanding the Bible", iconHint: "bible"),
        FocusArea(name: "Rest & Peace", iconHint: "leaf")
    ]

    // MARK: - Mood tones

    static let moodTones: [Mood] = [
        .peaceful, .anxious, .hopeful, .overwhelmed, .grateful, .discouraged
    ]
}
