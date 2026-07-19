import Foundation
import Supabase

// MARK: - Cross the Bridge (migration 0031)

/// Where portal/bridge.html is hosted. The share link is
/// `<baseURL>?bridge=<token>`. Same hosting as the church portal
/// (see PortalConfig / RBAC_AND_PORTAL_RUNBOOK.md).
enum BridgeConfig {
    static let baseURL = "https://crossedout-church-portal.pages.dev/bridge.html"

    static func link(token: String) -> String {
        "\(baseURL)?bridge=\(token)"
    }
}

/// A bridge the user has sent, with any recipient responses joined in.
struct SentBridge: Identifiable, Decodable, Hashable {
    let id: UUID
    let toName: String
    let token: String
    let status: String
    let verseRef: String
    let message: String
    let createdAt: String?
    let responses: [BridgeResponse]

    enum CodingKeys: String, CodingKey {
        case id, token, status, message
        case toName = "to_name"
        case verseRef = "verse_ref"
        case createdAt = "created_at"
        case responses = "bridge_responses"
    }

    var statusLabel: String {
        switch status {
        case "opened": return "Opened"
        case "responded": return "Responded"
        case "declined": return "Declined"
        default: return "Sent"
        }
    }
}

/// One recipient interaction (reply, prayer request, decline, journey
/// progress). Inserted only via the anon respond_bridge RPC; readable only
/// by the bridge's sender.
struct BridgeResponse: Identifiable, Decodable, Hashable {
    let id: UUID
    let kind: String
    let message: String?
    let day: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, message, day
        case createdAt = "created_at"
    }

    var kindLabel: String {
        switch kind {
        case "reply": return "Replied"
        case "prayer_request": return "Asked for prayer"
        case "decline": return "Not right now"
        case "journey_started": return "Started Seven Days of Hope"
        case "journey_day": return "Journey day \(day.map(String.init) ?? "")"
        default: return kind
        }
    }
}

extension SupabaseService {

    private struct BridgeInsert: Encodable {
        let user_id: UUID
        let sender_name: String
        let to_name: String
        let why_text: String
        let message: String
        let verse_ref: String
        let verse_text: String
        let verse_book: String?
        let verse_chapter: Int?
        let verse_start: Int?
        let verse_end: Int?
        let meaning: String
        let invitation: String?
        let response_option: String
    }

    private struct BridgeTokenRow: Decodable {
        let token: String
    }

    /// Creates the full bridge package and returns its share token.
    /// Throws on failure so the composer can show an honest error.
    func createBridge(
        senderName: String, toName: String, whyText: String, message: String,
        verseRef: String, verseText: String,
        verseBook: String?, verseChapter: Int?, verseStart: Int?, verseEnd: Int?,
        meaning: String, invitation: String?, responseOption: String
    ) async throws -> String {
        guard let uid = currentUserID else { throw KyraServiceError.notSignedIn }
        let payload = BridgeInsert(
            user_id: uid,
            sender_name: senderName,
            to_name: toName,
            why_text: whyText,
            message: message,
            verse_ref: verseRef,
            verse_text: verseText,
            verse_book: verseBook,
            verse_chapter: verseChapter,
            verse_start: verseStart,
            verse_end: verseEnd,
            meaning: meaning,
            invitation: invitation?.isEmpty == true ? nil : invitation,
            response_option: responseOption
        )
        let row: BridgeTokenRow = try await client
            .from("bridge_shares")
            .insert(payload)
            .select("token")
            .single()
            .execute()
            .value
        return row.token
    }

    /// The user's sent bridges (newest first) with responses joined.
    /// Throws so "Your Bridges" can show an error state.
    func listMyBridges() async throws -> [SentBridge] {
        guard let uid = currentUserID else { return [] }
        let rows: [SentBridge] = try await client
            .from("bridge_shares")
            .select("id, to_name, token, status, verse_ref, message, created_at, bridge_responses(id, kind, message, day, created_at)")
            .eq("user_id", value: uid)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return rows
    }
}
