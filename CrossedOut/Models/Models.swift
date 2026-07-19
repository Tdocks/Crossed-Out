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

// MARK: - Practice Action

/// One small, concrete "act" step for the Today loop, picked
/// deterministically by the `today_practice_action` RPC (migration 0025)
/// from focus areas + today's mood. Stable for the whole day.
struct PracticeAction: Identifiable, Codable, Hashable {
    let id: UUID
    let body: String
    let focusSlug: String?
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
    /// Optional focus-area slug that biases Today's verse/practice when active.
    var focusSlug: String? = nil
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
    /// Author's account id when known — used so blocking targets the
    /// account, not just the display name.
    var authorUserId: UUID? = nil
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
    /// Author's account id when known — used so blocking targets the
    /// account, not just the display name.
    var authorUserId: UUID? = nil
    let timeAgo: String
    let kind: PostKind
    let text: String
    var verseRef: String?
    var verseText: String?
    var heartCount: Int
}

// MARK: - Micros (migration 0030)

/// A local micro-site group: people who meet up in person to watch streamed
/// church together and coordinate in a small shared space.
struct Micro: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let city: String?
    let ownerUserId: UUID
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, city
        case ownerUserId = "owner_user_id"
        case createdAt = "created_at"
    }
}

/// One entry in a micro's feed. `pinned` is computed SERVER-SIDE by the
/// micro_feed RPC (announcement + unexpired); expired announcements fall
/// into the normal chronological feed.
struct MicroPost: Identifiable, Codable, Hashable {
    let id: UUID
    let microId: UUID
    let authorUserId: UUID
    let authorName: String
    let body: String
    let isAnnouncement: Bool
    let expiresAt: String?
    let createdAt: String?
    let pinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, body, pinned
        case microId = "micro_id"
        case authorUserId = "author_user_id"
        case authorName = "author_name"
        case isAnnouncement = "is_announcement"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
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
    var liveVideoId: String? = nil

    // Church-profile fields (migration 0021) — editable by a church_admin.
    var websiteURL: String? = nil
    var contactEmail: String? = nil
    var youtubeHandle: String? = nil
    var isPublished: Bool = true

    // Visit-planning fields (migration 0032) — practical, in-person info
    // for the Plan-a-Visit screen. All optional; only shown when present.
    var address: String? = nil
    var serviceTimes: String? = nil
    var parkingInfo: String? = nil
    var kidsInfo: String? = nil
    var accessibilityInfo: String? = nil
    var newcomerInfo: String? = nil
}

struct LiveService: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let church: Church
    let title: String
    let startsIn: String
    let isLive: Bool
    var time: String?
    /// Scheduled start of the next upcoming broadcast (nil when live or none).
    /// Written by refresh_church_streams (migration 0038).
    var scheduledStartAt: Date? = nil
    /// videoId of the upcoming broadcast, so we can open its watch/notify page.
    var upcomingVideoId: String? = nil
}

// MARK: - Live service scheduling

enum ServiceBucket { case live, soon, later, hidden }

extension LiveService {
    /// Which Attend section this belongs in, computed live so a service that
    /// has no live-or-scheduled info simply disappears instead of rendering a
    /// blank, indicator-less row.
    var bucket: ServiceBucket {
        if isLive { return .live }
        if let start = scheduledStartAt {
            let delta = start.timeIntervalSinceNow
            if delta < -3600 { return .hidden }   // long past; stale
            if delta < 6 * 3600 { return .soon }  // within the next 6 hours
            return .later
        }
        // Legacy seed/mock services carry text-only schedule fields.
        if let t = time, !t.isEmpty { return .later }
        if !startsIn.isEmpty { return .soon }
        return .hidden
    }

    /// Human display of when this service airs, computed live so countdowns
    /// stay fresh: "Live", "Starts in 5m", "Starts 9:00 AM", "Sun 8:50 AM".
    var scheduleLabel: String {
        if isLive { return "Live" }
        if let start = scheduledStartAt {
            let delta = start.timeIntervalSinceNow
            if delta <= 0 { return "Starting now" }
            if delta < 3600 { return "Starts in \(max(1, Int((delta / 60).rounded())))m" }
            let cal = Calendar.current
            let f = DateFormatter()
            if cal.isDateInToday(start) { f.dateFormat = "h:mm a"; return "Starts \(f.string(from: start))" }
            if cal.isDateInTomorrow(start) { f.dateFormat = "h:mm a"; return "Tomorrow \(f.string(from: start))" }
            f.dateFormat = "EEE h:mm a"
            return f.string(from: start)
        }
        if let t = time, !t.isEmpty { return t }
        return startsIn
    }
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

// (BridgeShare's mock model was replaced by the live SentBridge /
// BridgeResponse in SupabaseService+Bridge.swift, migration 0031.)

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

// MARK: - Roles & Account Status (migration 0021)

/// Account role. Raw values mirror the DB check constraint exactly.
enum UserRole: String, Codable, Hashable {
    case user
    case churchAdmin = "church_admin"
    case systemAdmin = "system_admin"

    /// Tolerant parse — unknown/missing values fall back to a plain user.
    init(dbValue: String?) { self = UserRole(rawValue: dbValue ?? "") ?? .user }
}

/// Account verification/access state. Raw values mirror the DB constraint.
enum AccountStatus: String, Codable, Hashable {
    case active
    case pendingVerification = "pending_verification"
    case suspended

    init(dbValue: String?) { self = AccountStatus(rawValue: dbValue ?? "") ?? .active }
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

/// A user's private reflection on a built-in devotional (one per user per
/// devotional; editing updates it). PRIVACY: own-rows RLS only (migration
/// 0028); never sent to Kyra or any AI. `devotional` is the joined catalog
/// row when fetched for the archive.
struct DevotionalReflection: Identifiable, Codable, Hashable {
    let id: UUID
    let devotionalId: UUID
    let body: String
    let reflectedOn: String
    let updatedAt: String?
    let devotional: Devotional?

    enum CodingKeys: String, CodingKey {
        case id, body
        case devotionalId = "devotional_id"
        case reflectedOn = "reflected_on"
        case updatedAt = "updated_at"
        case devotional = "devotionals"
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
