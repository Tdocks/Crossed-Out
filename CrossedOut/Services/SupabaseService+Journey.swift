import Foundation
import Supabase

// MARK: - Journey / Path models (migration 0034)

struct JourneyPath: Identifiable, Hashable {
    let id: UUID
    let slug: String
    let title: String
    let subtitle: String?
    let totalDays: Int
}

struct JourneyDayContent: Identifiable, Hashable {
    var id: Int { day }
    let day: Int
    let title: String
    let ref: String
    let text: String
    let body: String
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int?
}

struct JourneyEnrollment: Identifiable, Hashable {
    let id: UUID
    let journeyId: UUID
    let slug: String
    let title: String
    let subtitle: String?
    let currentDay: Int
    let totalDays: Int
    let completedAt: String?
    let companionName: String?
    let bridgeToken: String?
    let completedDays: Set<Int>

    var isComplete: Bool { completedAt != nil }
    var progressLabel: String {
        if isComplete { return "Completed" }
        return "Day \(min(currentDay, totalDays)) of \(totalDays)"
    }
}

struct GraceStatus: Hashable {
    let graceUsed: Int
    let graceTotal: Int
    let current: Int
    let applied: Bool
    let graceHeldDay: String?

    var remaining: Int { max(0, graceTotal - graceUsed) }
    var heldYesterday: Bool {
        guard let graceHeldDay else { return false }
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return graceHeldDay == SupabaseService.dayString(yesterday)
    }
}

struct WeekTrailMark: Hashable {
    let day: String
    let kind: String // completed | grace | rest
}

// MARK: - DTOs

private struct JourneyRow: Decodable {
    let id: UUID
    let slug: String
    let title: String
    let subtitle: String?
}

private struct JourneyDayCountRow: Decodable {
    let journey_id: UUID
}

private struct EnrollmentRow: Decodable {
    let id: UUID
    let journey_id: UUID
    let current_day: Int
    let completed_at: String?
    let companion_name: String?
    let bridge_token: String?
    let journeys: JourneyEmbed?

    struct JourneyEmbed: Decodable {
        let slug: String
        let title: String
        let subtitle: String?
    }
}

private struct DayCompletionRow: Decodable {
    let day: Int
}

private struct GraceRPCResult: Decodable {
    let ok: Bool?
    let applied: Bool?
    let grace_used: Int?
    let grace_total: Int?
    let current: Int?
    let grace_held_day: String?
    let reason: String?
}

struct EnrollRPCResult: Decodable {
    let enrollment_id: UUID
    let journey_id: UUID
    let slug: String
    let current_day: Int
    let total_days: Int
}

struct CompleteDayRPCResult: Decodable {
    let enrollment_id: UUID
    let current_day: Int
    let completed: Bool
    let total_days: Int
}

private struct GetJourneyJSON: Decodable {
    let found: Bool
    let title: String?
    let subtitle: String?
    let days: [GetJourneyDay]?
}

private struct GetJourneyDay: Decodable {
    let day: Int
    let title: String
    let ref: String
    let text: String?
    let body: String
}

private struct WeekTrailMarkDTO: Decodable {
    let day: String
    let kind: String
}

// MARK: - Service

extension SupabaseService {

    func applyGraceIfNeeded() async -> GraceStatus? {
        guard currentUserID != nil else { return nil }
        do {
            let result: GraceRPCResult = try await decodeJSONRPC("apply_grace_if_needed")
            return GraceStatus(
                graceUsed: result.grace_used ?? 0,
                graceTotal: result.grace_total ?? 3,
                current: result.current ?? 0,
                applied: result.applied ?? false,
                graceHeldDay: result.grace_held_day
            )
        } catch {
            print("SupabaseService: applyGraceIfNeeded failed: \(error)")
            return nil
        }
    }

    func useGraceDay() async throws -> GraceStatus {
        let result: GraceRPCResult = try await decodeJSONRPC("use_grace_day")
        if result.ok == false {
            throw KyraServiceError.badResponse
        }
        return GraceStatus(
            graceUsed: result.grace_used ?? 0,
            graceTotal: result.grace_total ?? 3,
            current: result.current ?? 0,
            applied: result.applied ?? false,
            graceHeldDay: result.grace_held_day
        )
    }

    /// Decodes `returns json` RPCs (PostgREST body is the JSON value).
    private func decodeJSONRPC<T: Decodable>(_ fn: String) async throws -> T {
        let response = try await client.rpc(fn).execute()
        return try JSONDecoder().decode(T.self, from: response.data)
    }

    private func decodeJSONRPC<T: Decodable, P: Encodable>(
        _ fn: String, params: P
    ) async throws -> T {
        let response = try await client.rpc(fn, params: params).execute()
        return try JSONDecoder().decode(T.self, from: response.data)
    }

    func fetchWeekTrailMarks() async throws -> [WeekTrailMark] {
        guard let uid = currentUserID else { return [] }
        let start = Self.dayString(
            Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        )

        struct CompletionDay: Decodable { let day: String; let kind: String }
        struct GraceDay: Decodable { let day: String }

        let completions: [CompletionDay] = try await client
            .from("daily_completions")
            .select("day,kind")
            .eq("user_id", value: uid)
            .gte("day", value: start)
            .execute()
            .value

        let graceRows: [GraceDay] = (try? await client
            .from("streak_grace_log")
            .select("day")
            .eq("user_id", value: uid)
            .gte("day", value: start)
            .execute()
            .value) ?? []

        var marks: [WeekTrailMark] = []
        var completedDays = Set<String>()
        var restDays = Set<String>()
        for c in completions {
            if c.kind == "rest" { restDays.insert(c.day) }
            else { completedDays.insert(c.day) }
        }
        for d in completedDays { marks.append(WeekTrailMark(day: d, kind: "completed")) }
        for d in restDays where !completedDays.contains(d) {
            marks.append(WeekTrailMark(day: d, kind: "rest"))
        }
        for g in graceRows {
            marks.append(WeekTrailMark(day: g.day, kind: "grace"))
        }
        return marks
    }

    /// Builds Mon→Sun `StreakDayState` for the current week (locale calendar).
    func buildWeekStates(from marks: [WeekTrailMark]) -> [StreakDayState] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Week starting Monday to match StreakWeekRow labels M T W T F S S
        let weekday = cal.component(.weekday, from: today) // 1=Sun ... 7=Sat
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return Array(repeating: .future, count: 7)
        }

        let markMap: [String: String] = Dictionary(
            marks.map { ($0.day, $0.kind) },
            uniquingKeysWith: { existing, new in
                // Prefer completed > grace > rest
                let rank = ["completed": 3, "grace": 2, "rest": 1]
                return (rank[new] ?? 0) > (rank[existing] ?? 0) ? new : existing
            }
        )

        var states: [StreakDayState] = []
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: monday) else {
                states.append(.future)
                continue
            }
            let key = Self.dayString(day)
            if cal.isDate(day, inSameDayAs: today) {
                if let kind = markMap[key] {
                    states.append(kind == "grace" ? .grace : kind == "rest" ? .rest : .done)
                } else {
                    states.append(.today)
                }
            } else if day > today {
                states.append(.future)
            } else if let kind = markMap[key] {
                switch kind {
                case "grace": states.append(.grace)
                case "rest": states.append(.rest)
                default: states.append(.done)
                }
            } else {
                states.append(.missed)
            }
        }
        return states
    }

    func listJourneyPaths() async throws -> [JourneyPath] {
        let rows: [JourneyRow] = try await client
            .from("journeys")
            .select("id,slug,title,subtitle")
            .order("title", ascending: true)
            .execute()
            .value

        // Count days per journey
        struct DayRow: Decodable { let journey_id: UUID }
        let days: [DayRow] = try await client
            .from("journey_days")
            .select("journey_id")
            .execute()
            .value
        var counts: [UUID: Int] = [:]
        for d in days { counts[d.journey_id, default: 0] += 1 }

        return rows.map {
            JourneyPath(
                id: $0.id, slug: $0.slug, title: $0.title,
                subtitle: $0.subtitle, totalDays: counts[$0.id] ?? 0
            )
        }
    }

    func fetchJourneyDays(slug: String) async throws -> (title: String, subtitle: String?, days: [JourneyDayContent]) {
        struct DayRow: Decodable {
            let day: Int
            let title: String
            let book: String
            let chapter: Int
            let verse_start: Int
            let verse_end: Int?
            let body: String
        }

        let journeyRows: [JourneyRow] = try await client
            .from("journeys")
            .select("id,slug,title,subtitle")
            .eq("slug", value: slug)
            .limit(1)
            .execute()
            .value
        guard let journey = journeyRows.first else {
            throw KyraServiceError.missingText
        }
        let rows: [DayRow] = try await client
            .from("journey_days")
            .select("day,title,book,chapter,verse_start,verse_end,body")
            .eq("journey_id", value: journey.id)
            .order("day", ascending: true)
            .execute()
            .value

        var content: [JourneyDayContent] = []
        for row in rows {
            let end = row.verse_end ?? row.verse_start
            let text: String
            if let fetched = try? await fetchBibleVerse(
                book: row.book, chapter: row.chapter, verse: row.verse_start, translation: "BSB"
            ), end == row.verse_start {
                text = fetched.text
            } else if let chapter = try? await fetchChapter(
                translation: "BSB", book: row.book, chapter: row.chapter
            ) {
                text = chapter.verses
                    .filter { $0.number >= row.verse_start && $0.number <= end }
                    .map(\.text)
                    .joined(separator: " ")
            } else {
                text = ""
            }
            let ref: String
            if let ve = row.verse_end, ve > row.verse_start {
                ref = "\(row.book) \(row.chapter):\(row.verse_start)-\(ve)"
            } else {
                ref = "\(row.book) \(row.chapter):\(row.verse_start)"
            }
            content.append(JourneyDayContent(
                day: row.day, title: row.title, ref: ref, text: text, body: row.body,
                book: row.book, chapter: row.chapter,
                verseStart: row.verse_start, verseEnd: row.verse_end
            ))
        }
        return (journey.title, journey.subtitle, content)
    }

    func fetchActiveEnrollment() async throws -> JourneyEnrollment? {
        guard let uid = currentUserID else { return nil }
        let rows: [EnrollmentRow] = try await client
            .from("user_journey_enrollments")
            .select("id,journey_id,current_day,completed_at,companion_name,bridge_token,journeys(slug,title,subtitle)")
            .eq("user_id", value: uid)
            .is("completed_at", value: nil)
            .order("started_at", ascending: false)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first, let j = row.journeys else { return nil }
        return try await hydrateEnrollment(row, slug: j.slug, title: j.title, subtitle: j.subtitle)
    }

    func fetchEnrollment(id: UUID) async throws -> JourneyEnrollment? {
        guard let uid = currentUserID else { return nil }
        let rows: [EnrollmentRow] = try await client
            .from("user_journey_enrollments")
            .select("id,journey_id,current_day,completed_at,companion_name,bridge_token,journeys(slug,title,subtitle)")
            .eq("user_id", value: uid)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first, let j = row.journeys else { return nil }
        return try await hydrateEnrollment(row, slug: j.slug, title: j.title, subtitle: j.subtitle)
    }

    private func hydrateEnrollment(
        _ row: EnrollmentRow, slug: String, title: String, subtitle: String?
    ) async throws -> JourneyEnrollment {
        let comps: [DayCompletionRow] = try await client
            .from("user_journey_day_completions")
            .select("day")
            .eq("enrollment_id", value: row.id)
            .execute()
            .value
        let dayCount: Int = try await {
            struct C: Decodable { let day: Int }
            let rows: [C] = try await client
                .from("journey_days")
                .select("day")
                .eq("journey_id", value: row.journey_id)
                .execute()
                .value
            return rows.count
        }()
        return JourneyEnrollment(
            id: row.id,
            journeyId: row.journey_id,
            slug: slug,
            title: title,
            subtitle: subtitle,
            currentDay: row.current_day,
            totalDays: dayCount,
            completedAt: row.completed_at,
            companionName: row.companion_name,
            bridgeToken: row.bridge_token,
            completedDays: Set(comps.map(\.day))
        )
    }

    @discardableResult
    func enrollJourney(slug: String, companionName: String? = nil) async throws -> EnrollRPCResult {
        struct Params: Encodable {
            let p_slug: String
            let p_companion_name: String?
        }
        return try await decodeJSONRPC(
            "enroll_journey",
            params: Params(p_slug: slug, p_companion_name: companionName)
        )
    }

    @discardableResult
    func completeJourneyDay(enrollmentId: UUID, day: Int) async throws -> CompleteDayRPCResult {
        struct Params: Encodable {
            let p_enrollment_id: UUID
            let p_day: Int
        }
        return try await decodeJSONRPC(
            "complete_journey_day",
            params: Params(p_enrollment_id: enrollmentId, p_day: day)
        )
    }

    func linkJourneyCompanion(enrollmentId: UUID, companionName: String, bridgeToken: String?) async {
        struct Params: Encodable {
            let p_enrollment_id: UUID
            let p_companion_name: String
            let p_bridge_token: String?
        }
        do {
            try await client
                .rpc("link_journey_companion", params: Params(
                    p_enrollment_id: enrollmentId,
                    p_companion_name: companionName,
                    p_bridge_token: bridgeToken
                ))
                .execute()
        } catch {
            print("SupabaseService: linkJourneyCompanion failed: \(error)")
        }
    }

    func addWorkingItem(text: String, focusSlug: String?) async -> WorkingItem? {
        guard let uid = currentUserID else { return nil }
        struct Insert: Encodable {
            let user_id: UUID
            let text: String
            let position: Int
            let focus_slug: String?
        }
        struct Row: Decodable {
            let id: UUID
            let text: String
            let crossed: Bool
            let focus_slug: String?
        }
        do {
            let existing = try await fetchWorkingItems()
            let row: Row = try await client
                .from("working_items")
                .insert(Insert(
                    user_id: uid, text: text,
                    position: existing.count, focus_slug: focusSlug
                ))
                .select("id,text,crossed,focus_slug")
                .single()
                .execute()
                .value
            return WorkingItem(id: row.id, text: row.text, crossed: row.crossed, focusSlug: row.focus_slug)
        } catch {
            print("SupabaseService: addWorkingItem failed: \(error)")
            return nil
        }
    }
}
