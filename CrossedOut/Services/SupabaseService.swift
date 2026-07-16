import Foundation
import Supabase

// MARK: - Config

enum SupabaseConfig {
    static let url = URL(string: "https://wqumwxoiqsiwizlftojq.supabase.co")!
    static let key = "sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL"
}

// MARK: - Bible Translations

enum BibleTranslation: String, CaseIterable {
    case bsb = "BSB"
    case web = "WEB"
    case kjv = "KJV"
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

    /// True if there is a persisted, active Supabase session. The app
    /// requires a real account (email/password or Sign in with Apple) —
    /// there is no anonymous session fallback.
    var isAuthenticated: Bool {
        client.auth.currentSession != nil
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
    let donateURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, org, raised, goal
        case dateRange = "date_range"
        case donateURL = "donate_url"
    }

    func toModel() -> GiveProject {
        GiveProject(id: id, title: title, org: org, raised: Int(raised), goal: Int(goal), dateRange: dateRange, donateURL: donateURL)
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

// MARK: - Bible Verse DTO

struct BibleVerseDTO: Codable {
    let verse: Int
    let text: String
}

// MARK: - Fetch

extension SupabaseService {
    /// Fetches a single chapter's verses for a given translation/book/chapter,
    /// ordered by verse ascending, and maps them into a BibleChapter.
    func fetchChapter(translation: String, book: String, chapter: Int) async throws -> BibleChapter {
        let dtos: [BibleVerseDTO] = try await client
            .from("bible_verses")
            .select("verse,text")
            .eq("translation", value: translation)
            .eq("book", value: book)
            .eq("chapter", value: chapter)
            .order("verse", ascending: true)
            .execute()
            .value
        let verses = dtos.map { BibleVerse(number: $0.verse, text: $0.text) }
        return BibleChapter(book: book, chapter: chapter, translation: translation, heading: "", verses: verses)
    }

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

extension SupabaseService {
    /// Fetches the signed-in user's profile row, if one exists.
    func fetchProfile() async throws -> ProfileDTO? {
        guard let uid = currentUserID else { return nil }
        let rows: [ProfileDTO] = try await client
            .from("profiles")
            .select()
            .eq("id", value: uid)
            .limit(1)
            .execute()
            .value
        return rows.first
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

// MARK: - Community RPCs

extension SupabaseService {
    private struct PrayForParams: Encodable { let request_id: UUID }
    private struct EncouragePostParams: Encodable { let post_id: UUID }

    /// Calls the `pray_for` RPC and returns the new prayed_count, or nil on error.
    func prayFor(requestID: UUID) async -> Int? {
        do {
            let count: Int = try await client
                .rpc("pray_for", params: PrayForParams(request_id: requestID))
                .execute()
                .value
            return count
        } catch {
            print("SupabaseService: prayFor failed: \(error)")
            return nil
        }
    }

    /// Calls the `encourage_post` RPC and returns the new heart_count, or nil on error.
    func encouragePost(postID: UUID) async -> Int? {
        do {
            let count: Int = try await client
                .rpc("encourage_post", params: EncouragePostParams(post_id: postID))
                .execute()
                .value
            return count
        } catch {
            print("SupabaseService: encouragePost failed: \(error)")
            return nil
        }
    }
}

// MARK: - Bible Highlights

extension SupabaseService {
    private struct HighlightRowDTO: Codable { let verse: Int }

    private struct HighlightUpsert: Encodable {
        let user_id: UUID
        let book: String
        let chapter: Int
        let verse: Int
    }

    /// Verses highlighted by the current user for a given book/chapter.
    /// Returns an empty set if unauthenticated or on error.
    func fetchHighlights(book: String, chapter: Int) async throws -> Set<Int> {
        guard let uid = currentUserID else { return [] }
        let rows: [HighlightRowDTO] = try await client
            .from("user_highlights")
            .select("verse")
            .eq("user_id", value: uid)
            .eq("book", value: book)
            .eq("chapter", value: chapter)
            .execute()
            .value
        return Set(rows.map { $0.verse })
    }

    /// Best-effort insert/delete of a single verse highlight for the current user.
    func setHighlight(book: String, chapter: Int, verse: Int, on: Bool) async {
        guard let uid = currentUserID else { return }
        do {
            if on {
                let payload = HighlightUpsert(user_id: uid, book: book, chapter: chapter, verse: verse)
                try await client
                    .from("user_highlights")
                    .upsert(payload, onConflict: "user_id,book,chapter,verse", ignoreDuplicates: true)
                    .execute()
            } else {
                try await client
                    .from("user_highlights")
                    .delete()
                    .eq("user_id", value: uid)
                    .eq("book", value: book)
                    .eq("chapter", value: chapter)
                    .eq("verse", value: verse)
                    .execute()
            }
        } catch {
            print("SupabaseService: setHighlight failed: \(error)")
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

// MARK: - Deterministic Personalization Engine (curated verses)
//
// Wraps the `recommend_today_verse` / `record_verse_feedback` RPCs (backend
// migration 0009). This is purely additive: every entry point here is
// designed to fail silently (return nil / swallow errors) so Today's screen
// can fall back to its existing behavior when the backend tables/RPCs
// aren't deployed yet.

struct RecommendedVerse: Equatable {
    let curatedVerseId: String
    let passage: Passage
    let matchedFocus: String
    let reason: String
    let themeSummary: String
    let score: Int
}

private struct RecommendTodayVerseParams: Encodable {
    let p_focus_slugs: [String]
    let p_mood: String?
    let p_tone: String?
    let p_maturity: String?
}

private struct RecommendTodayVerseRow: Decodable {
    let curated_verse_id: UUID
    let book: String
    let chapter: Int
    let verse_start: Int
    let verse_end: Int
    let matched_focus: String
    let why_template: String
    let theme_summary: String
    let score: Int
}

extension SupabaseService {
    /// Calls the `recommend_today_verse` RPC, then fetches the verse text
    /// for the returned reference in the user's preferred translation via
    /// the existing `bible_verses` fetch path. Returns nil (never throws
    /// out of a bootstrap flow — callers should `try?` this) if the RPC
    /// isn't deployed yet, returns no match, or the verse text lookup fails.
    func recommendTodayVerse(
        focusSlugs: [String],
        mood: String?,
        tone: String?,
        maturity: String?
    ) async throws -> RecommendedVerse? {
        let params = RecommendTodayVerseParams(
            p_focus_slugs: focusSlugs, p_mood: mood, p_tone: tone, p_maturity: maturity
        )
        let rows: [RecommendTodayVerseRow] = try await client
            .rpc("recommend_today_verse", params: params)
            .execute()
            .value
        guard let row = rows.first else { return nil }

        let translation = (try? await fetchProfile())?.translation ?? BibleTranslation.bsb.rawValue
        let text = try await fetchVerseRangeText(
            translation: translation,
            book: row.book,
            chapter: row.chapter,
            verseStart: row.verse_start,
            verseEnd: row.verse_end
        )
        guard !text.isEmpty else { return nil }

        let ref = VerseRef(
            book: row.book,
            chapter: row.chapter,
            verseStart: row.verse_start,
            verseEnd: row.verse_end == 0 ? nil : row.verse_end
        )
        let passage = Passage(
            id: row.curated_verse_id,
            ref: ref,
            translation: translation,
            text: text,
            topics: [row.matched_focus]
        )
        let reason = row.why_template.replacingOccurrences(
            of: "{focus}", with: FocusAreaSlugMap.label(forSlug: row.matched_focus)
        )

        return RecommendedVerse(
            curatedVerseId: row.curated_verse_id.uuidString,
            passage: passage,
            matchedFocus: row.matched_focus,
            reason: reason,
            themeSummary: row.theme_summary,
            score: row.score
        )
    }

    /// Fetches verse text for a book/chapter/verse-range in a given
    /// translation, reusing the same `bible_verses` table access pattern as
    /// `fetchChapter`. `verseEnd == 0` means a single verse (verseEnd is
    /// treated as verseStart).
    private func fetchVerseRangeText(
        translation: String, book: String, chapter: Int, verseStart: Int, verseEnd: Int
    ) async throws -> String {
        let effectiveEnd = verseEnd == 0 ? verseStart : verseEnd
        let dtos: [BibleVerseDTO] = try await client
            .from("bible_verses")
            .select("verse,text")
            .eq("translation", value: translation)
            .eq("book", value: book)
            .eq("chapter", value: chapter)
            .gte("verse", value: verseStart)
            .lte("verse", value: effectiveEnd)
            .order("verse", ascending: true)
            .execute()
            .value
        return dtos.map { $0.text }.joined(separator: " ")
    }

    private struct RecordVerseFeedbackParams: Encodable {
        let p_curated_verse_id: UUID
        let p_signal: String
    }

    /// Best-effort feedback signal for a curated verse recommendation.
    /// Valid signals: 'spoke', 'not_today', 'deeper', 'less_like_this',
    /// 'more_like_this'. Never throws.
    func sendVerseFeedback(curatedVerseId: String, signal: String) async {
        guard let uuid = UUID(uuidString: curatedVerseId) else { return }
        do {
            try await client
                .rpc("record_verse_feedback", params: RecordVerseFeedbackParams(
                    p_curated_verse_id: uuid, p_signal: signal
                ))
                .execute()
        } catch {
            print("SupabaseService: sendVerseFeedback failed: \(error)")
        }
    }
}

// MARK: - Kyra AI Chat

enum KyraServiceError: Error {
    case notSignedIn
    case badResponse
    case missingText
}

private struct KyraRequestMessage: Encodable {
    let role: String
    let text: String
}

private struct KyraRequestBody: Encodable {
    let messages: [KyraRequestMessage]
    let firstName: String?
}

private struct KyraResponseBody: Decodable {
    let text: String?
}

extension SupabaseService {
    /// Calls the "kyra" Supabase Edge Function with the full chat history and
    /// returns Kyra's reply text. Uses URLSession directly (simplest — no
    /// need to fight the SDK's functions client for a plain JSON POST).
    func askKyra(messages: [ChatMessage], firstName: String?) async throws -> String {
        // The Kyra edge function requires the caller's real user JWT and
        // rejects the static publishable key — surface a clear error here
        // so the UI can show a "sign in to chat with Kyra" state instead of
        // a raw 401 from the network call.
        guard let session = client.auth.currentSession else {
            throw KyraServiceError.notSignedIn
        }

        let url = SupabaseConfig.url.appendingPathComponent("functions/v1/kyra")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = KyraRequestBody(
            messages: messages.map { KyraRequestMessage(role: $0.role.rawValue, text: $0.text) },
            firstName: firstName
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw KyraServiceError.badResponse
        }
        let decoded = try JSONDecoder().decode(KyraResponseBody.self, from: data)
        guard let text = decoded.text, !text.isEmpty else {
            throw KyraServiceError.missingText
        }
        return text
    }
}

// MARK: - Auth

extension SupabaseService {
    /// Email/password sign-up. Always performs a fresh
    /// `auth.signUp(email:password:)` — the app has no anonymous session to
    /// link, so every sign-up creates a brand-new real account.
    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    /// Signs in an existing user with email/password.
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    /// Best-effort sign-out; never throws.
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("SupabaseService: signOut failed: \(error)")
        }
    }

    /// The signed-in user's email, or nil if there is none (e.g. signed in
    /// with Apple only, or not signed in).
    var currentUserEmail: String? {
        let email = client.auth.currentSession?.user.email
        return (email?.isEmpty ?? true) ? nil : email
    }

    /// Signs in with a Sign in with Apple identity token. `nonce` must be the
    /// raw (unhashed) nonce that was SHA256-hashed into the original Apple
    /// authorization request.
    func signInWithApple(idToken: String, nonce: String) async throws {
        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }
}

// MARK: - Safety & Account

extension SupabaseService {
    private struct ContentReportInsert: Encodable {
        let reporter_id: UUID
        let content_kind: String
        let content_id: UUID?
        let reason: String
        let detail: String?
    }

    /// Best-effort content report insert; never throws.
    func reportContent(kind: String, contentID: UUID?, reason: String, detail: String?) async {
        guard let uid = currentUserID else { return }
        let payload = ContentReportInsert(
            reporter_id: uid, content_kind: kind, content_id: contentID,
            reason: reason, detail: detail
        )
        do {
            try await client.from("content_reports").insert(payload).execute()
        } catch {
            print("SupabaseService: reportContent failed: \(error)")
        }
    }

    private struct UserBlockUpsert: Encodable {
        let blocker_id: UUID
        let blocked_user_id: UUID?
        let blocked_author_name: String
    }

    /// Best-effort author block upsert; ignores duplicates, never throws.
    func blockAuthor(name: String, userID: UUID?) async {
        guard let uid = currentUserID else { return }
        let payload = UserBlockUpsert(blocker_id: uid, blocked_user_id: userID, blocked_author_name: name)
        do {
            try await client
                .from("user_blocks")
                .upsert(payload, onConflict: "blocker_id,blocked_author_name", ignoreDuplicates: true)
                .execute()
        } catch {
            print("SupabaseService: blockAuthor failed: \(error)")
        }
    }

    private struct BlockedAuthorRow: Decodable {
        let blocked_author_name: String
    }

    /// The set of author names the current user has blocked.
    func fetchBlockedAuthors() async throws -> Set<String> {
        guard let uid = currentUserID else { return [] }
        let rows: [BlockedAuthorRow] = try await client
            .from("user_blocks")
            .select("blocked_author_name")
            .eq("blocker_id", value: uid)
            .execute()
            .value
        return Set(rows.map(\.blocked_author_name))
    }

    /// Deletes the current user's account via the `delete_own_account` RPC
    /// (rows cascade server-side), then best-effort signs out locally.
    func deleteAccount() async -> Bool {
        do {
            try await client.rpc("delete_own_account").execute()
            try? await client.auth.signOut()
            return true
        } catch {
            print("SupabaseService: deleteAccount failed: \(error)")
            return false
        }
    }
}

// MARK: - Streak & Working Items

extension SupabaseService {
    /// Fetches the current user's streak row, or nil if unauthenticated /
    /// no row exists yet.
    func fetchStreak() async throws -> (current: Int, longest: Int, graceUsed: Int, graceTotal: Int)? {
        guard let uid = currentUserID else { return nil }
        let rows: [StreakDTO] = try await client
            .from("streaks")
            .select()
            .eq("user_id", value: uid)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return (current: row.current, longest: row.longest, graceUsed: row.graceUsed, graceTotal: row.graceTotal)
    }
}

private struct WorkingItemDTO: Codable {
    let id: UUID
    let text: String
    let crossed: Bool
    let position: Int

    func toModel() -> WorkingItem {
        WorkingItem(id: id, text: text, crossed: crossed)
    }
}

extension SupabaseService {
    /// Fetches the current user's working-through items, ordered by position.
    /// Returns an empty array if unauthenticated.
    func fetchWorkingItems() async throws -> [WorkingItem] {
        guard let uid = currentUserID else { return [] }
        let dtos: [WorkingItemDTO] = try await client
            .from("working_items")
            .select()
            .eq("user_id", value: uid)
            .order("position", ascending: true)
            .execute()
            .value
        return dtos.map { $0.toModel() }
    }

    private struct WorkingItemInsert: Encodable {
        let user_id: UUID
        let text: String
        let position: Int
    }

    /// Best-effort seed of the current user's working-through list with the
    /// given texts at positions 0..<n. Callers are responsible for ensuring
    /// this only runs once (e.g. guarding on an existing empty list).
    func seedWorkingItems(_ texts: [String]) async {
        guard let uid = currentUserID, !texts.isEmpty else { return }
        let payload = texts.enumerated().map { index, text in
            WorkingItemInsert(user_id: uid, text: text, position: index)
        }
        do {
            try await client.from("working_items").insert(payload).execute()
        } catch {
            print("SupabaseService: seedWorkingItems failed: \(error)")
        }
    }
}

// MARK: - Notes & Bookmarks

struct VerseNote: Identifiable, Hashable {
    let id: UUID
    let verse: Int
    let note: String
}

private struct VerseNoteDTO: Codable {
    let id: UUID
    let verse: Int
    let note: String

    func toModel() -> VerseNote {
        VerseNote(id: id, verse: verse, note: note)
    }
}

struct VerseBookmark: Identifiable, Hashable {
    let id: UUID
    let book: String
    let chapter: Int
    let verse: Int?
}

private struct VerseBookmarkDTO: Codable {
    let id: UUID
    let book: String
    let chapter: Int
    let verse: Int?

    func toModel() -> VerseBookmark {
        VerseBookmark(id: id, book: book, chapter: chapter, verse: verse)
    }
}

extension SupabaseService {
    /// Fetches the current user's notes for a given book/chapter, ordered by verse.
    func fetchNotes(book: String, chapter: Int) async throws -> [VerseNote] {
        guard let uid = currentUserID else { return [] }
        let dtos: [VerseNoteDTO] = try await client
            .from("user_notes")
            .select("id,verse,note")
            .eq("user_id", value: uid)
            .eq("book", value: book)
            .eq("chapter", value: chapter)
            .order("verse", ascending: true)
            .execute()
            .value
        return dtos.map { $0.toModel() }
    }

    private struct NoteInsert: Encodable {
        let user_id: UUID
        let book: String
        let chapter: Int
        let verse: Int
        let note: String
    }

    /// Best-effort insert of a new note for the current user.
    func saveNote(book: String, chapter: Int, verse: Int, note: String) async {
        guard let uid = currentUserID else { return }
        let payload = NoteInsert(user_id: uid, book: book, chapter: chapter, verse: verse, note: note)
        do {
            try await client.from("user_notes").insert(payload).execute()
        } catch {
            print("SupabaseService: saveNote failed: \(error)")
        }
    }

    /// Best-effort delete of a note by id, scoped to the current user.
    func deleteNote(id: UUID) async {
        guard let uid = currentUserID else { return }
        do {
            try await client
                .from("user_notes")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: uid)
                .execute()
        } catch {
            print("SupabaseService: deleteNote failed: \(error)")
        }
    }
}

extension SupabaseService {
    /// Fetches all bookmarks for the current user.
    func fetchBookmarks() async throws -> [VerseBookmark] {
        guard let uid = currentUserID else { return [] }
        let dtos: [VerseBookmarkDTO] = try await client
            .from("user_bookmarks")
            .select("id,book,chapter,verse")
            .eq("user_id", value: uid)
            .execute()
            .value
        return dtos.map { $0.toModel() }
    }

    private struct BookmarkInsert: Encodable {
        let user_id: UUID
        let book: String
        let chapter: Int
        let verse: Int?
    }

    /// Best-effort set/unset of a bookmark for book/chapter/(optional)verse.
    /// Deletes any existing matching row first (NULL-safe), then inserts a
    /// fresh row when `on` is true.
    func setBookmark(book: String, chapter: Int, verse: Int?, on: Bool) async {
        guard let uid = currentUserID else { return }
        do {
            try await deleteBookmarkRows(uid: uid, book: book, chapter: chapter, verse: verse)
            if on {
                let payload = BookmarkInsert(user_id: uid, book: book, chapter: chapter, verse: verse)
                try await client.from("user_bookmarks").insert(payload).execute()
            }
        } catch {
            print("SupabaseService: setBookmark failed: \(error)")
        }
    }

    private func deleteBookmarkRows(uid: UUID, book: String, chapter: Int, verse: Int?) async throws {
        if let verse {
            try await client
                .from("user_bookmarks")
                .delete()
                .eq("user_id", value: uid)
                .eq("book", value: book)
                .eq("chapter", value: chapter)
                .eq("verse", value: verse)
                .execute()
        } else {
            try await client
                .from("user_bookmarks")
                .delete()
                .eq("user_id", value: uid)
                .eq("book", value: book)
                .eq("chapter", value: chapter)
                .is("verse", value: nil)
                .execute()
        }
    }
}

// MARK: - Churches & Give

extension SupabaseService {
    private struct SavedChurchRowDTO: Codable { let church_id: UUID }

    /// IDs of churches the current user has saved. Empty if unauthenticated.
    func fetchSavedChurchIDs() async throws -> Set<UUID> {
        guard let uid = currentUserID else { return [] }
        let rows: [SavedChurchRowDTO] = try await client
            .from("saved_churches")
            .select("church_id")
            .eq("user_id", value: uid)
            .execute()
            .value
        return Set(rows.map { $0.church_id })
    }

    private struct SavedChurchInsert: Encodable {
        let user_id: UUID
        let church_id: UUID
    }

    /// Best-effort save/unsave of a church for the current user.
    func setChurchSaved(churchID: UUID, saved: Bool) async {
        guard let uid = currentUserID else { return }
        do {
            if saved {
                let payload = SavedChurchInsert(user_id: uid, church_id: churchID)
                try await client
                    .from("saved_churches")
                    .upsert(payload, onConflict: "user_id,church_id", ignoreDuplicates: true)
                    .execute()
            } else {
                try await client
                    .from("saved_churches")
                    .delete()
                    .eq("user_id", value: uid)
                    .eq("church_id", value: churchID)
                    .execute()
            }
        } catch {
            print("SupabaseService: setChurchSaved failed: \(error)")
        }
    }

    private struct GiveIntentInsert: Encodable {
        let user_id: UUID
        let project_id: UUID
        let amount: Double
    }

    /// Best-effort recording of a give intent (not an actual payment charge).
    func recordGiveIntent(projectID: UUID, amount: Double) async {
        guard let uid = currentUserID else { return }
        let payload = GiveIntentInsert(user_id: uid, project_id: projectID, amount: amount)
        do {
            try await client.from("give_intents").insert(payload).execute()
        } catch {
            print("SupabaseService: recordGiveIntent failed: \(error)")
        }
    }
}

// MARK: - Rhythm (daily completions)

extension SupabaseService {
    private struct CompletionUpsert: Encodable {
        let user_id: UUID
        let day: String
        let kind: String
    }

    /// Best-effort upsert of today's completion for the given kind
    /// ('scripture', 'prayer', 'reflection', 'community', 'encouragement',
    /// 'devotional'). Duplicate same-day/kind rows are ignored.
    func recordCompletion(kind: String) async {
        guard let uid = currentUserID else { return }
        let payload = CompletionUpsert(user_id: uid, day: Self.dayString(Date()), kind: kind)
        do {
            try await client
                .from("daily_completions")
                .upsert(payload, onConflict: "user_id,day,kind", ignoreDuplicates: true)
                .execute()
        } catch {
            print("SupabaseService: recordCompletion failed: \(error)")
        }
    }

    private struct CompletionRowDTO: Codable {
        let day: String
        let kind: String
    }

    /// Counts of completions per kind over the last 7 days (including today),
    /// aggregated client-side. Empty if unauthenticated.
    func fetchWeekCompletions() async throws -> [String: Int] {
        guard let uid = currentUserID else { return [:] }
        let sevenDaysAgo = Self.dayString(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        let rows: [CompletionRowDTO] = try await client
            .from("daily_completions")
            .select("day,kind")
            .eq("user_id", value: uid)
            .gte("day", value: sevenDaysAgo)
            .execute()
            .value
        var counts: [String: Int] = [:]
        for row in rows {
            counts[row.kind, default: 0] += 1
        }
        return counts
    }
}
