import Foundation

// MARK: - Focus & Mood

struct FocusArea: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let iconHint: String
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case peaceful, anxious, discouraged, motivated, angry, lonely
    case confused, grateful, tempted, overwhelmed, hopeful, grieving

    var id: String { rawValue }

    var label: String {
        switch self {
        case .peaceful: return "Peaceful"
        case .anxious: return "Anxious"
        case .discouraged: return "Discouraged"
        case .motivated: return "Motivated"
        case .angry: return "Angry"
        case .lonely: return "Lonely"
        case .confused: return "Confused"
        case .grateful: return "Grateful"
        case .tempted: return "Tempted"
        case .overwhelmed: return "Overwhelmed"
        case .hopeful: return "Hopeful"
        case .grieving: return "Grieving"
        }
    }
}

// MARK: - Scripture

struct VerseRef: Codable, Hashable {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int?

    /// Renders like "Proverbs 3:5-6" or "John 16:33".
    var display: String {
        if let end = verseEnd, end != verseStart {
            return "\(book) \(chapter):\(verseStart)-\(end)"
        }
        return "\(book) \(chapter):\(verseStart)"
    }
}

struct Passage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let ref: VerseRef
    let translation: String
    let text: String
    var topics: [String] = []
}

struct BibleVerse: Identifiable, Codable, Hashable {
    var id: Int { number }
    let number: Int
    let text: String
}

struct BibleChapter: Codable, Hashable {
    let book: String
    let chapter: Int
    let translation: String
    let heading: String
    let verses: [BibleVerse]
}

// MARK: - Daily Entry & Check-In

struct DailyEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let date: Date
    let greetingName: String
    let carryingPrompt: String
    let userNeed: String
    let verse: Passage
    let focusTitle: String
    let focusWhy: String
    let dayNumber: Int
}

struct CheckIn: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let date: Date
    let mood: Mood
    var note: String?
}

// MARK: - Streak

struct WorkingItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let text: String
    var crossed: Bool
}

struct StreakState: Codable, Hashable {
    let current: Int
    let longest: Int
    let graceUsed: Int
    let graceTotal: Int
    let weekStates: [StreakDayState]
    let weekWithGodDays: Int
    let weekWithGodTotal: Int
    var workingThrough: [WorkingItem]
}

// MARK: - Community

struct PrayerRequest: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let authorName: String
    let timeAgo: String
    let text: String
    var prayedCount: Int
    var isAnswered: Bool = false
}

enum PostKind: String, Codable, Hashable {
    case prayer, verseShare, testimony
}

struct CommunityPost: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let authorName: String
    let timeAgo: String
    let kind: PostKind
    let text: String
    var verseRef: String?
    var verseText: String?
    var heartCount: Int
}

// MARK: - Attend & Give

struct Church: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let name: String
    let city: String
    let rating: Double
    let style: String
    let distanceMiles: Double
    var isLive: Bool = false
    var viewers: Int?
    let accent: String

    // Streaming (Attend). All optional so existing callers/mock stay valid.
    var platform: String? = nil          // "youtube" | "hls" | "facebook" | "web"
    var youtubeChannelId: String? = nil
    var hlsURL: String? = nil
    var watchURL: String? = nil
    var thumbnailURL: String? = nil
    var denomination: String? = nil
}

struct LiveService: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let church: Church
    let title: String
    let startsIn: String
    let isLive: Bool
    var time: String?
}

struct GiveProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let title: String
    let org: String
    let raised: Int
    let goal: Int
    var dateRange: String?
    var donateURL: String? = nil

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(raised) / Double(goal))
    }
}

// MARK: - Bridge & Kyra

struct BridgeShare: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let toName: String
    let whyText: String
    let verse: Passage
}

enum ChatRole: String, Codable, Hashable {
    case user, kyra
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let role: ChatRole
    let text: String
}

// MARK: - User

struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let firstName: String
    var focusAreas: [String]
    var need: String
    var translation: String
    var dayNumber: Int
}

// MARK: - Focus Area Slug Mapping
//
// `UserProfile.focusAreas` stores human-readable focus NAMES (as chosen
// during onboarding). The personalization backend (recommend_today_verse
// RPC) speaks in stable slugs. This is the single source of truth mapping
// between the two, in both directions.

enum FocusAreaSlugMap {
    /// Focus display name -> backend slug.
    static let nameToSlug: [String: String] = [
        "Anxiety": "anxiety",
        "Purpose": "purpose",
        "Relationships": "relationships",
        "Financial Wisdom": "financial_wisdom",
        "Forgiveness": "forgiveness",
        "Grief": "grief",
        "Discipline": "discipline",
        "Loneliness": "loneliness",
        "Marriage": "marriage",
        "Parenting": "parenting",
        "Temptation": "temptation",
        "Career": "career",
        "Confidence": "confidence",
        "Understanding God": "understanding_god",
        "Returning to Faith": "returning_to_faith",
        "Learning to Pray": "learning_to_pray",
        "Depression & Hope": "depression_hope",
        "Motivation": "motivation",
        "Addiction": "addiction",
        "Anger": "anger",
        "Leadership": "leadership",
        "New to Christianity": "new_to_christianity",
        "Understanding the Bible": "understanding_the_bible",
        "Rest & Peace": "rest_peace",
    ]

    /// Backend slug -> focus display name (reverse of `nameToSlug`).
    static let slugToName: [String: String] = Dictionary(
        uniqueKeysWithValues: nameToSlug.map { ($0.value, $0.key) }
    )

    /// Maps a list of focus NAMES (as stored on `UserProfile.focusAreas`)
    /// to backend slugs, dropping any names that aren't in the map.
    static func slugs(for names: [String]) -> [String] {
        names.compactMap { nameToSlug[$0] }
    }

    /// Human label for a backend slug, falling back to a title-cased
    /// de-slugified guess if the slug is unrecognized.
    static func label(forSlug slug: String) -> String {
        slugToName[slug] ?? slug.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Devotionals (G19)

/// Which surface a piece of devotional feedback belongs to.
enum DevotionalSource: String, Codable, Hashable {
    case builtin
    case independent
}

/// A built-in, app-authored devotional (public catalog). Decoded directly
/// from the `devotionals` table / `today_devotional()` RPC (snake_case).
struct Devotional: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let verseRef: String
    let book: String?
    let chapter: Int?
    let verse: Int?
    let verseEnd: Int?
    let body: String
    let prompt: String?
    let style: String
    let focusSlug: String?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, book, chapter, verse, body, prompt, style, tags
        case verseRef = "verse_ref"
        case verseEnd = "verse_end"
        case focusSlug = "focus_slug"
    }
}

/// A user's own "independent study" devotional (verse + their notes).
/// Decoded from the `user_devotionals` table (snake_case).
struct UserDevotional: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String?
    let verseRef: String
    let book: String?
    let chapter: Int?
    let verse: Int?
    let verseEnd: Int?
    let notes: String
    let studiedOn: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, book, chapter, verse, notes
        case verseRef = "verse_ref"
        case verseEnd = "verse_end"
        case studiedOn = "studied_on"
        case createdAt = "created_at"
    }
}

/// A gated AI devotional suggestion (Tier 3): a real retrieved verse framed
/// with a short reflection. Returned by the devotional_suggest edge function.
struct AiDevotionalSuggestion: Codable, Hashable, Identifiable {
    var id: String { verseRef }
    let verseRef: String
    let book: String?
    let chapter: Int?
    let verse: Int?
    let text: String
    let title: String
    let body: String
    let prompt: String?
}

/// Outcome of a Tier 3 AI-suggestion request.
enum DevotionalAIError: Error {
    case notSignedIn
    case dailyLimit
    case failed
}
