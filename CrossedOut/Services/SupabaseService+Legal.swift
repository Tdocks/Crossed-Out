import Foundation

// MARK: - Legal acceptance (migration 0023)

/// Records and checks which Terms version the signed-in user has accepted.
/// `legal_acceptances` is append-only under RLS (own rows, insert + select
/// only), so recording is idempotent and can never be edited client-side.
extension SupabaseService {

    private struct LegalAcceptanceInsert: Encodable {
        let user_id: UUID
        let doc: String
        let version: String
    }

    private struct LegalAcceptanceRow: Decodable {
        let version: String
    }

    /// Idempotently records acceptance of the given Terms version for the
    /// current user, and caches it locally so the gate never re-prompts on
    /// this device. Safe to call repeatedly; returns false only when there
    /// is no session or the network write failed (the local cache still
    /// records intent, and bootstrap re-syncs it later).
    @discardableResult
    func recordLegalAcceptance(version: String) async -> Bool {
        UserDefaults.standard.set(version, forKey: "co.legalAcceptedVersion")
        guard let uid = currentUserID else { return false }
        let payload = LegalAcceptanceInsert(user_id: uid, doc: "terms", version: version)
        do {
            try await client
                .from("legal_acceptances")
                .upsert(payload, onConflict: "user_id,doc,version", ignoreDuplicates: true)
                .execute()
            return true
        } catch {
            print("SupabaseService: recordLegalAcceptance failed: \(error)")
            return false
        }
    }

    /// True if the current user has a server-side acceptance record for the
    /// given Terms version. Throws on network failure so callers can
    /// distinguish "definitely not accepted" from "couldn't check".
    func hasAcceptedLegal(version: String) async throws -> Bool {
        guard let uid = currentUserID else { return false }
        let rows: [LegalAcceptanceRow] = try await client
            .from("legal_acceptances")
            .select("version")
            .eq("user_id", value: uid)
            .eq("doc", value: "terms")
            .eq("version", value: version)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }
}
