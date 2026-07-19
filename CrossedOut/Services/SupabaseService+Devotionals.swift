import Foundation

// MARK: - Devotionals (G19)
// Built-in catalog reads, independent-study create/list, and the
// "was this helpful?" feedback signal shared across both surfaces.

extension SupabaseService {

    /// Today's built-in devotional (deterministic per day). nil on none/error.
    func fetchTodayDevotional() async -> Devotional? {
        do {
            let rows: [Devotional] = try await client
                .rpc("today_devotional")
                .execute()
                .value
            return rows.first
        } catch {
            print("SupabaseService: fetchTodayDevotional failed: \(error)")
            return nil
        }
    }

    private struct UserDevotionalInsert: Encodable {
        let user_id: UUID
        let title: String?
        let verse_ref: String
        let book: String?
        let chapter: Int?
        let verse: Int?
        let verse_end: Int?
        let notes: String
    }

    /// Create an independent-study devotional; returns the saved row (or nil).
    func createUserDevotional(title: String?, verseRef: String,
                              book: String? = nil, chapter: Int? = nil,
                              verse: Int? = nil, verseEnd: Int? = nil,
                              notes: String) async -> UserDevotional? {
        guard let uid = currentUserID else { return nil }
        let payload = UserDevotionalInsert(
            user_id: uid, title: title, verse_ref: verseRef,
            book: book, chapter: chapter, verse: verse, verse_end: verseEnd,
            notes: notes)
        do {
            let row: UserDevotional = try await client
                .from("user_devotionals")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            return row
        } catch {
            print("SupabaseService: createUserDevotional failed: \(error)")
            return nil
        }
    }

    /// The current user's independent-study devotionals, newest first.
    func listMyDevotionals() async -> [UserDevotional] {
        guard let uid = currentUserID else { return [] }
        do {
            let rows: [UserDevotional] = try await client
                .from("user_devotionals")
                .select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("SupabaseService: listMyDevotionals failed: \(error)")
            return []
        }
    }

    private struct SubmitDevotionalFeedbackParams: Encodable {
        let p_source: String
        let p_devotional_id: UUID?
        let p_user_devotional_id: UUID?
        let p_helpful: Bool
        let p_reason: String?
    }

    /// Upsert "was this helpful?" feedback for a built-in or independent devotional.
    /// Best-effort; never throws.
    func submitDevotionalFeedback(source: DevotionalSource,
                                  devotionalID: UUID? = nil,
                                  userDevotionalID: UUID? = nil,
                                  helpful: Bool,
                                  reason: String? = nil) async {
        do {
            try await client
                .rpc("submit_devotional_feedback", params: SubmitDevotionalFeedbackParams(
                    p_source: source.rawValue,
                    p_devotional_id: devotionalID,
                    p_user_devotional_id: userDevotionalID,
                    p_helpful: helpful,
                    p_reason: reason))
                .execute()
        } catch {
            print("SupabaseService: submitDevotionalFeedback failed: \(error)")
        }
    }
}

// MARK: - Private reflections (migration 0028)
// PRIVACY: reflections are own-rows RLS data. They are read and written ONLY
// through these table calls — never included in any edge-function payload,
// so no AI (Kyra, devotional_suggest, semantic_search) ever receives them.
// The schema's `shared_with_kyra` column is a seam for a possible FUTURE
// explicit opt-in; the app neither sets nor reads it today.

extension SupabaseService {

    private struct ReflectionUpsert: Encodable {
        let user_id: UUID
        let devotional_id: UUID
        let body: String
    }

    /// The current user's reflection for one devotional, if any.
    /// Throws on network failure so callers can distinguish "none yet"
    /// from "couldn't load".
    func fetchMyReflection(devotionalID: UUID) async throws -> DevotionalReflection? {
        guard let uid = currentUserID else { return nil }
        let rows: [DevotionalReflection] = try await client
            .from("devotional_reflections")
            .select("id, devotional_id, body, reflected_on, updated_at")
            .eq("user_id", value: uid)
            .eq("devotional_id", value: devotionalID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Create-or-update the user's reflection for a devotional
    /// (one per user per devotional; upsert on that unique pair).
    func saveReflection(devotionalID: UUID, body: String) async -> Bool {
        guard let uid = currentUserID else { return false }
        let payload = ReflectionUpsert(
            user_id: uid,
            devotional_id: devotionalID,
            body: String(body.prefix(8000))
        )
        do {
            try await client
                .from("devotional_reflections")
                .upsert(payload, onConflict: "user_id,devotional_id")
                .execute()
            return true
        } catch {
            print("SupabaseService: saveReflection failed: \(error)")
            return false
        }
    }

    /// Archive: the user's reflections with their devotionals joined,
    /// newest-edited first. Throws so the hub can show an error state.
    func listMyReflections(limit: Int = 100) async throws -> [DevotionalReflection] {
        guard let uid = currentUserID else { return [] }
        let rows: [DevotionalReflection] = try await client
            .from("devotional_reflections")
            .select("id, devotional_id, body, reflected_on, updated_at, devotionals(id, title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)")
            .eq("user_id", value: uid)
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows
    }
}

// MARK: - Tier 2 (deterministic re-roll) + Tier 3 (gated AI suggestion)

extension SupabaseService {

    private struct NextDevotionalParams: Encodable { let p_exclude: [UUID] }

    /// Tier 2: another built-in devotional, deterministically, excluding the
    /// ones already seen this session. nil when nothing new / on error.
    func nextDevotional(excluding excludeIDs: [UUID]) async -> Devotional? {
        do {
            let rows: [Devotional] = try await client
                .rpc("next_devotional", params: NextDevotionalParams(p_exclude: excludeIDs))
                .execute()
                .value
            return rows.first
        } catch {
            print("SupabaseService: nextDevotional failed: \(error)")
            return nil
        }
    }

    /// Tier 2: prepare a daily-verse re-roll (penalize + clear today's pick).
    /// After this, call recommendTodayVerse again to get the next-best verse.
    /// Best-effort; deterministic; no AI.
    func prepareVerseReroll() async {
        do {
            try await client.rpc("reroll_prepare_today_verse").execute()
        } catch {
            print("SupabaseService: prepareVerseReroll failed: \(error)")
        }
    }

    /// Tier 3: explicit, capped AI suggestion. Retrieves a real verse and a
    /// framed reflection via the devotional_suggest edge function. Mirrors
    /// askKyra's transport (direct URLSession POST with the user JWT).
    func requestAiDevotionalSuggestion(context: String) async -> Result<AiDevotionalSuggestion, DevotionalAIError> {
        guard let session = client.auth.currentSession else { return .failure(.notSignedIn) }
        let url = SupabaseConfig.url.appendingPathComponent("functions/v1/devotional_suggest")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["context": context])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.failed) }
            if http.statusCode == 429 { return .failure(.dailyLimit) }
            guard (200...299).contains(http.statusCode) else { return .failure(.failed) }
            let decoded = try JSONDecoder().decode(AiDevotionalSuggestion.self, from: data)
            return .success(decoded)
        } catch {
            print("SupabaseService: requestAiDevotionalSuggestion failed: \(error)")
            return .failure(.failed)
        }
    }
}
