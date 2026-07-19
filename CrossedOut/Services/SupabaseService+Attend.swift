import Foundation

// MARK: - Attend: watch tracking & visit planning (migration 0032)
//
// church_attendance records each time a user actually starts watching a
// church's live service — hooked into ServiceDetailView's startWatching(),
// never a page view or a tap on "Watch Live" that turns out not-live. Own
// rows RLS: never readable by anyone but the watcher, including the church
// itself. Repeat attendance (2+ watches of the same church) unlocks the
// "Plan a Visit" affordance client-side.
//
// church_visit_intents records a lightweight, deterministic "I'm planning
// to visit" signal from the Plan-a-Visit sheet's "Let them know you're
// coming" action. No marketing capture — just a user-owned row, optionally
// paired with a mailto: to the church's contact_email when one exists.

private struct ChurchAttendanceInsert: Encodable {
    let user_id: UUID
    let church_id: UUID
}

private struct ChurchAttendanceRow: Decodable {
    let id: UUID
}

extension SupabaseService {
    /// Best-effort record of a real watch. Never throws — a logging
    /// failure here should never interrupt someone actually watching a
    /// service.
    func recordChurchWatch(churchID: UUID) async {
        guard let uid = currentUserID else { return }
        let payload = ChurchAttendanceInsert(user_id: uid, church_id: churchID)
        do {
            try await client.from("church_attendance").insert(payload).execute()
        } catch {
            print("SupabaseService: recordChurchWatch failed: \(error)")
        }
    }

    /// Count of the current user's recorded watches of a given church.
    /// Returns 0 if unauthenticated or on error — callers treat that as
    /// "not yet a repeat visitor" rather than surfacing an error, so a
    /// transient failure never wrongly reveals (or hides) Plan a Visit.
    func fetchChurchAttendanceCount(churchID: UUID) async -> Int {
        guard let uid = currentUserID else { return 0 }
        do {
            let rows: [ChurchAttendanceRow] = try await client
                .from("church_attendance")
                .select("id")
                .eq("user_id", value: uid)
                .eq("church_id", value: churchID)
                .execute()
                .value
            return rows.count
        } catch {
            print("SupabaseService: fetchChurchAttendanceCount failed: \(error)")
            return 0
        }
    }
}

private struct ChurchVisitIntentInsert: Encodable {
    let user_id: UUID
    let church_id: UUID
}

extension SupabaseService {
    /// Best-effort record of a "planning to visit" signal from the
    /// Plan-a-Visit sheet. Never throws.
    func recordVisitIntent(churchID: UUID) async {
        guard let uid = currentUserID else { return }
        let payload = ChurchVisitIntentInsert(user_id: uid, church_id: churchID)
        do {
            try await client.from("church_visit_intents").insert(payload).execute()
        } catch {
            print("SupabaseService: recordVisitIntent failed: \(error)")
        }
    }
}
