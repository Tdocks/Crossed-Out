import Foundation
import Supabase

// MARK: - Config

enum SupabaseConfig {
    static let url = URL(string: "https://wqumwxoiqsiwizlftojq.supabase.co")!
    static let key = "sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL"
}

// MARK: - Service

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    lazy var client: SupabaseClient = {
        SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.key)
    }()

    private init() {}

    var currentUserID: UUID? {
        client.auth.currentSession?.user.id
    }

    /// Signs in anonymously if there is no existing session.
    /// Never throws/crashes — anonymous sign-ins may be disabled in the
    /// dashboard, in which case this just returns false and the app
    /// keeps running with mock data.
    func signInAnonymouslyIfNeeded() async -> Bool {
        if client.auth.currentSession != nil {
            return true
        }
        do {
            try await client.auth.signInAnonymously()
            return true
        } catch {
            print("SupabaseService: anonymous sign-in failed: \(error)")
            return false
        }
    }
}

// MARK: - Date helpers

extension SupabaseService {
    nonisolated static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    nonisolated static func parseISODate(_ string: String?) -> Date {
        guard let string else { return Date() }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: string) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: string) { return d }
        return Date()
    }

    nonisolated static func relativeTime(from isoString: String?) -> String {
        let date = parseISODate(isoString)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - DTOs

struct PassageDTO: Codable {
    let id: UUID
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int?
    let translation: String
    let text: String
    let topics: [String]?
    let tone: String?
    let maturity: String?

    enum CodingKeys: String, CodingKey {
        case id, book, chapter
        case verseStart = "verse_start"
        case verseEnd = "verse_end"
        case translation, text, topics, tone, maturity
    }

    func toModel() -> Passage {
        Passage(
            id: id,
            ref: VerseRef(book: book, chapter: chapter, verseStart: verseStart, verseEnd: verseEnd),
            translation: translation,
            text: text,
            topics: topics ?? []
        )
    }
}

struct PrayerRequestDTO: Codable {
    let id: UUID
    let userId: UUID?
    let authorName: String
    let body: String
    let prayedCount: Int
    let isAnswered: Bool
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case authorName = "author_name"
        case body
        case prayedCount = "prayed_count"
        case isAnswered = "is_answered"
        case createdAt = "created_at"
    }

    func toModel() -> PrayerRequest {
        PrayerRequest(
            id: id,
            authorName: authorName,
            timeAgo: SupabaseService.relativeTime(from: createdAt),
            text: body,
            prayedCount: prayedCount,
            isAnswered: isAnswered
        )
    }
}

struct CommunityPostDTO: Codable {
    let id: UUID
    let userId: UUID?
    let authorName: String
    let kind: String
    let body: String
    let verseRef: String?
    let verseText: String?
    let heartCount: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case authorName = "author_name"
        case kind, body
        case verseRef = "verse_ref"
        case verseText = "verse_text"
        case heartCount = "heart_count"
        case createdAt = "created_at"
    }

    var postKind: PostKind {
        switch kind {
        case "verse_share": return .verseShare
        case "testimony": return .testimony
        default: return .prayer
        }
    }

    func toModel() -> CommunityPost {
        CommunityPost(
            id: id,
            authorName: authorName,
            timeAgo: SupabaseService.relativeTime(from: createdAt),
            kind: postKind,
            text: body,
            verseRef: verseRef,
            verseText: verseText,
            heartCount: heartCount
        )
    }
}

struct ChurchDTO: Codable {
    let id: UUID
    let name: String
    let city: String
    let rating: Double
    let style: String
    let distanceMiles: Double
    let isLive: Bool?
    let viewers: Int?
    let accent: String

    enum CodingKeys: String, CodingKey {
        case id, name, city, rating, style
        case distanceMiles = "distance_miles"
        case isLive = "is_live"
        case viewers, accent
    }

    func toModel() -> Church {
        Church(
            id: id,
            name: name,
            city: city,
            rating: rating,
            style: style,
            distanceMiles: distanceMiles,
            isLive: isLive ?? false,
            viewers: viewers,
            accent: accent
        )
    }
}

struct LiveServiceDTO: Codable {
    let id: UUID
    let churchId: UUID
    let title: String
    let startsIn: String?
    let serviceTime: String?
    let isLive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case churchId = "church_id"
        case title
        case startsIn = "starts_in"
        case serviceTime = "service_time"
        case isLive = "is_live"
    }

    func toModel(church: Church) -> LiveService {
        LiveService(
            id: id,
            church: church,
            title: title,
            startsIn: startsIn ?? "",
            isLive: isLive,
            time: serviceTime
        )
    }
}

struct GiveProjectDTO: Codable {
    let id: UUID
    let title: String
    let org: String
    let raised: Double
    let goal: Double
    let dateRange: String?

    enum CodingKeys: String, CodingKey {
        case id, title, org, raised, goal
        case dateRange = "date_range"
    }

    func toModel() -> GiveProject {
        GiveProject(id: id, title: title, org: org, raised: Int(raised), goal: Int(goal), dateRange: dateRange)
    }
}

struct ProfileDTO: Codable {
    let id: UUID
    let firstName: String?
    let need: String?
    let translation: String?
    let dayNumber: Int?
    let focusAreas: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case need, translation
        case dayNumber = "day_number"
        case focusAreas = "focus_areas"
    }
}

struct StreakDTO: Codable {
    let userId: UUID
    let current: Int
    let longest: Int
    let graceUsed: Int
    let graceTotal: Int
    let lastActive: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case current, longest
        case graceUsed = "grace_used"
        case graceTotal = "grace_total"
        case lastActive = "last_active"
    }
}

struct CheckInDTO: Codable {
    let id: UUID?
    let userId: UUID
    let day: String
    let mood: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case day, mood, note
    }
}

// MARK: - Fetch

extension SupabaseService {
    func fetchPassages(topics: [String]? = nil) async throws -> [Passage] {
        let dtos: [PassageDTO] = try await client
            .from("passages")
            .select()
            .execute()
            .value
        let models = dtos.map { $0.toModel() }
        guard let topics, !topics.isEmpty else { return models }
        let wanted = Set(topics.map { $0.lowercased() })
        let filtered = models.filter { !Set($0.topics.map { $0.lowercased() }).isDisjoint(with: wanted) }
        return filtered.isEmpty ? models : filtered
    }

    func fetchPrayerRequests() async throws -> [PrayerRequest] {
        let dtos: [PrayerRequestDTO] = try await client
            .from("prayer_requests")
            .select()
            .execute()
            .value
        return dtos.map { $0.toModel() }
    }

    func fetchCommunityPosts() async throws -> [CommunityPost] {
        let dtos: [CommunityPostDTO] = try await client
            .from("community_posts")
            .select()
            .execute()
            .value
        return dtos.map { $0.toModel() }
    }
}

extension SupabaseService {
    func fetchChurches() async throws -> [Church] {
        let dtos: [ChurchDTO] = try await client
            .from("churches")
            .select()
            .execute()
            .value
        return dtos.map { $0.toModel() }
    }

    func fetchLiveServices() async throws -> [LiveService] {
        let churchDTOs: [ChurchDTO] = try await client
            .from("churches")
            .select()
            .execute()
            .value
        let serviceDTOs: [LiveServiceDTO] = try await client
            .from("live_services")
            .select()
            .execute()
            .value
        let churchesById = Dictionary(uniqueKeysWithValues: churchDTOs.map { ($0.id, $0.toModel()) })
        return serviceDTOs.compactMap { dto in
            guard let church = churchesById[dto.churchId] else { return nil }
            return dto.toModel(church: church)
        }
    }

    func fetchGiveProjects() async throws -> [GiveProject] {
        let dtos: [GiveProjectDTO] = try await client
            .from("give_projects")
            .select()
            .execute()
            .value
        return dtos.map { $0.toModel() }
    }
}

// MARK: - Writes (best-effort, no-throw)

extension SupabaseService {
    private struct ProfileUpsert: Encodable {
        let id: UUID
        let first_name: String
        let need: String
        let translation: String
        let day_number: Int
        let focus_areas: [String]
    }

    func upsertProfile(firstName: String, need: String, translation: String, dayNumber: Int, focusAreas: [String]) async {
        guard let uid = currentUserID else { return }
        let payload = ProfileUpsert(
            id: uid, first_name: firstName, need: need,
            translation: translation, day_number: dayNumber, focus_areas: focusAreas
        )
        do {
            try await client.from("profiles").upsert(payload, onConflict: "id").execute()
        } catch {
            print("SupabaseService: upsertProfile failed: \(error)")
        }
    }
}

extension SupabaseService {
    private struct CheckInUpsert: Encodable {
        let user_id: UUID
        let day: String
        let mood: String
        let note: String?
    }

    func saveCheckIn(mood: String, note: String?) async {
        guard let uid = currentUserID else { return }
        let payload = CheckInUpsert(user_id: uid, day: Self.dayString(Date()), mood: mood, note: note)
        do {
            try await client.from("check_ins").upsert(payload, onConflict: "user_id,day").execute()
        } catch {
            print("SupabaseService: saveCheckIn failed: \(error)")
        }
    }
}

extension SupabaseService {
    private struct StreakUpsert: Encodable {
        let user_id: UUID
        let current: Int
        let longest: Int
        let grace_used: Int
        let grace_total: Int
        let last_active: String
    }

    /// Fetches the current streak row, computes the new streak client-side,
    /// and upserts it back. If last_active == yesterday -> increment.
    /// If last_active == today -> no-op (already touched today).
    /// Otherwise -> reset to 1. longest is always max(longest, current).
    func touchStreak() async {
        guard let uid = currentUserID else { return }
        let today = Self.dayString(Date())
        let yesterday = Self.dayString(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())

        do {
            let rows: [StreakDTO] = try await client
                .from("streaks")
                .select()
                .eq("user_id", value: uid)
                .execute()
                .value

            var current = 1
            var longest = 1
            var graceUsed = 0
            var graceTotal = 3

            if let row = rows.first {
                graceUsed = row.graceUsed
                graceTotal = row.graceTotal
                longest = row.longest
                if row.lastActive == today {
                    current = row.current
                } else if row.lastActive == yesterday {
                    current = row.current + 1
                } else {
                    current = 1
                }
                longest = max(longest, current)
            }

            let payload = StreakUpsert(
                user_id: uid, current: current, longest: longest,
                grace_used: graceUsed, grace_total: graceTotal, last_active: today
            )
            try await client.from("streaks").upsert(payload, onConflict: "user_id").execute()
        } catch {
            print("SupabaseService: touchStreak failed: \(error)")
        }
    }
}

extension SupabaseService {
    private struct PrayerRequestInsert: Encodable {
        let user_id: UUID?
        let author_name: String
        let body: String
    }

    func insertPrayerRequest(authorName: String, body: String) async {
        guard let uid = currentUserID else { return }
        let payload = PrayerRequestInsert(user_id: uid, author_name: authorName, body: body)
        do {
            try await client.from("prayer_requests").insert(payload).execute()
        } catch {
            print("SupabaseService: insertPrayerRequest failed: \(error)")
        }
    }

    private struct BridgeShareInsert: Encodable {
        let user_id: UUID
        let to_name: String
        let why_text: String
        let verse_ref: String
        let verse_text: String
    }

    func insertBridgeShare(toName: String, whyText: String, verseRef: String, verseText: String) async {
        guard let uid = currentUserID else { return }
        let payload = BridgeShareInsert(
            user_id: uid, to_name: toName, why_text: whyText,
            verse_ref: verseRef, verse_text: verseText
        )
        do {
            try await client.from("bridge_shares").insert(payload).execute()
        } catch {
            print("SupabaseService: insertBridgeShare failed: \(error)")
        }
    }
}

extension SupabaseService {
    func setWorkingItemCrossed(id: UUID, crossed: Bool) async {
        guard currentUserID != nil else { return }
        do {
            try await client
                .from("working_items")
                .update(["crossed": crossed])
                .eq("id", value: id)
                .execute()
        } catch {
            print("SupabaseService: setWorkingItemCrossed failed: \(error)")
        }
    }
}

// MARK: - Recommendation (deterministic, no AI)

extension SupabaseService {
    private static let moodThemes: [String: [String]] = [
        "anxious": ["anxiety", "peace"],
        "discouraged": ["hope", "encouragement"],
        "grateful": ["trust"],
        "overwhelmed": ["rest", "peace"],
        "hopeful": ["hope", "future"],
        "peaceful": ["rest"]
    ]

    func recommendPassage(focus: [String], mood: String?) async -> Passage? {
        guard let dtos = try? await fetchPassageDTOs() else { return nil }
        guard !dtos.isEmpty else { return nil }

        let focusSet = Set(focus.map { $0.lowercased() })
        let themeSet = Set(mood.flatMap { Self.moodThemes[$0.lowercased()] } ?? [])

        func score(_ dto: PassageDTO) -> Int {
            let topics = Set((dto.topics ?? []).map { $0.lowercased() })
            var s = 0
            if !topics.isDisjoint(with: focusSet) { s += 30 }
            if !topics.isDisjoint(with: themeSet) { s += 25 }
            return s
        }

        let best = dtos
            .map { (dto: $0, score: score($0)) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.dto.id.uuidString < rhs.dto.id.uuidString
            }
            .first

        return best?.dto.toModel()
    }

    private func fetchPassageDTOs() async throws -> [PassageDTO] {
        try await client
            .from("passages")
            .select()
            .execute()
            .value
    }
}
