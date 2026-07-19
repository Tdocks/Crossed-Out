import Foundation
import Supabase

// MARK: - Micros (migration 0030)
// Create goes through the create_micro RPC (active-account gate, case-
// insensitive unique name with a friendly error, atomic owner membership).
// Everything else is direct table access under the 0030 RLS: membership is
// own-row member-only, announcements are owner-only, deletes are
// author-or-owner. Deterministic — no AI anywhere in this feature.

enum MicroError: Error {
    case nameTaken
    case notSignedIn
    case failed
}

extension SupabaseService {

    private struct CreateMicroParams: Encodable {
        let p_name: String
        let p_description: String
        let p_city: String?
    }

    /// Creates a micro (RPC). Throws `.nameTaken` for a friendly duplicate-
    /// name error; `.failed` otherwise. Returns the new micro's id.
    @discardableResult
    func createMicro(name: String, description: String, city: String?) async throws -> UUID {
        guard isAuthenticated else { throw MicroError.notSignedIn }
        do {
            let id: UUID = try await client
                .rpc("create_micro", params: CreateMicroParams(
                    p_name: name, p_description: description, p_city: city
                ))
                .execute()
                .value
            return id
        } catch {
            if "\(error)".localizedCaseInsensitiveContains("name_taken") {
                throw MicroError.nameTaken
            }
            print("SupabaseService: createMicro failed: \(error)")
            throw MicroError.failed
        }
    }

    private struct MembershipRow: Decodable {
        let role: String
        let micros: Micro
    }

    /// The user's joined/created micros with their membership role.
    /// Throws so the segment can show an error state.
    func fetchMyMicros() async throws -> [(micro: Micro, role: String)] {
        guard let uid = currentUserID else { return [] }
        let rows: [MembershipRow] = try await client
            .from("micro_members")
            .select("role, micros(id, name, description, city, owner_user_id, created_at)")
            .eq("user_id", value: uid)
            .order("joined_at", ascending: false)
            .execute()
            .value
        return rows.map { ($0.micros, $0.role) }
    }

    /// Name search for discovery (case-insensitive substring).
    func searchMicros(query: String) async throws -> [Micro] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let rows: [Micro] = try await client
            .from("micros")
            .select("id, name, description, city, owner_user_id, created_at")
            .ilike("name", pattern: "%\(trimmed)%")
            .limit(25)
            .execute()
            .value
        return rows
    }

    private struct JoinMicroInsert: Encodable {
        let micro_id: UUID
        let user_id: UUID
        let role: String
    }

    /// Joins a micro as a member (RLS forbids self-escalating to owner).
    func joinMicro(id: UUID) async -> Bool {
        guard let uid = currentUserID else { return false }
        do {
            try await client
                .from("micro_members")
                .upsert(JoinMicroInsert(micro_id: id, user_id: uid, role: "member"),
                        onConflict: "micro_id,user_id", ignoreDuplicates: true)
                .execute()
            return true
        } catch {
            print("SupabaseService: joinMicro failed: \(error)")
            return false
        }
    }

    /// Leaves a micro (members only — the owner's row is RLS-protected).
    func leaveMicro(id: UUID) async -> Bool {
        guard let uid = currentUserID else { return false }
        do {
            try await client
                .from("micro_members")
                .delete()
                .eq("micro_id", value: id)
                .eq("user_id", value: uid)
                .execute()
            return true
        } catch {
            print("SupabaseService: leaveMicro failed: \(error)")
            return false
        }
    }

    /// Deletes a micro (owner only via RLS; members/posts cascade).
    func deleteMicro(id: UUID) async -> Bool {
        do {
            try await client.from("micros").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("SupabaseService: deleteMicro failed: \(error)")
            return false
        }
    }

    private struct MicroFeedParams: Encodable { let p_micro_id: UUID }

    /// The micro's feed, pinned state computed server-side (micro_feed RPC).
    func fetchMicroFeed(microID: UUID) async throws -> [MicroPost] {
        let rows: [MicroPost] = try await client
            .rpc("micro_feed", params: MicroFeedParams(p_micro_id: microID))
            .execute()
            .value
        return rows
    }

    private struct MicroPostInsert: Encodable {
        let micro_id: UUID
        let author_user_id: UUID
        let author_name: String
        let body: String
        let is_announcement: Bool
        let expires_at: String?
    }

    /// Posts an update (any member) or an announcement (owner only — RLS
    /// enforces both). `expiresAt` applies to announcements: nil = permanent.
    func postMicroMessage(microID: UUID, authorName: String, body: String,
                          isAnnouncement: Bool, expiresAt: Date?) async -> Bool {
        guard let uid = currentUserID else { return false }
        let iso: String? = expiresAt.map {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: $0)
        }
        let payload = MicroPostInsert(
            micro_id: microID, author_user_id: uid, author_name: authorName,
            body: String(body.prefix(2000)),
            is_announcement: isAnnouncement, expires_at: iso
        )
        do {
            try await client.from("micro_posts").insert(payload).execute()
            return true
        } catch {
            print("SupabaseService: postMicroMessage failed: \(error)")
            return false
        }
    }

    /// Deletes a post (author or micro owner, via RLS).
    func deleteMicroPost(id: UUID) async -> Bool {
        do {
            try await client.from("micro_posts").delete().eq("id", value: id).execute()
            return true
        } catch {
            print("SupabaseService: deleteMicroPost failed: \(error)")
            return false
        }
    }
}
