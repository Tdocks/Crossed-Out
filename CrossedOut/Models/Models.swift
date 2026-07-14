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
