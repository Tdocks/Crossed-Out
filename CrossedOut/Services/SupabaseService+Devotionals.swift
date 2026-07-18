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
