import Foundation
import Supabase

// MARK: - Roles, church admin, and verification (migration 0021)
//
// All of these call SECURITY DEFINER RPCs. The client never writes role /
// account_status / church_id or the churches table directly — the database
// grants forbid it — so this layer is the only supported path for church
// signup, church editing, and system-admin verification actions.

/// One church account awaiting system-admin verification.
struct PendingChurch: Identifiable, Hashable {
    var id: UUID { userId }
    let userId: UUID
    let contactEmail: String?
    let churchId: UUID?
    let churchName: String?
    let city: String?
    let youtubeHandle: String?
}

private struct PendingChurchDTO: Decodable {
    let userId: UUID
    let contactEmail: String?
    let churchId: UUID?
    let churchName: String?
    let city: String?
    let youtubeHandle: String?
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contactEmail = "contact_email"
        case churchId = "church_id"
        case churchName = "church_name"
        case city
        case youtubeHandle = "youtube_handle"
        case submittedAt = "submitted_at"
    }

    func toModel() -> PendingChurch {
        PendingChurch(userId: userId, contactEmail: contactEmail, churchId: churchId,
                      churchName: churchName, city: city, youtubeHandle: youtubeHandle)
    }
}

extension SupabaseService {

    // MARK: In-app church self-signup (-> pending_verification)

    private struct ChurchApplicationParams: Encodable {
        let p_contact_name: String
        let p_church_name: String
        let p_city: String
        let p_denomination: String?
        let p_style: String?
        let p_youtube_handle: String?
        let p_website_url: String?
        let p_contact_email: String?
    }

    /// Submits an in-app church application. On success the caller's account
    /// becomes a `church_admin` in `pending_verification` and an unpublished
    /// church row is created. Returns the new church id. Throws on failure so
    /// the UI can surface an error.
    @discardableResult
    func submitChurchApplication(
        contactName: String, churchName: String, city: String,
        denomination: String?, style: String?, youtubeHandle: String?,
        websiteURL: String?, contactEmail: String?
    ) async throws -> UUID {
        let params = ChurchApplicationParams(
            p_contact_name: contactName, p_church_name: churchName, p_city: city,
            p_denomination: denomination, p_style: style, p_youtube_handle: youtubeHandle,
            p_website_url: websiteURL, p_contact_email: contactEmail
        )
        return try await client.rpc("submit_church_application", params: params).execute().value
    }

    // MARK: Church admin edits own church

    private struct UpdateMyChurchParams: Encodable {
        let p_name: String?
        let p_city: String?
        let p_denomination: String?
        let p_style: String?
        let p_youtube_handle: String?
        let p_website_url: String?
        let p_contact_email: String?
        // Visit-planning fields (migration 0032).
        let p_address: String?
        let p_service_times: String?
        let p_parking_info: String?
        let p_kids_info: String?
        let p_accessibility_info: String?
        let p_newcomer_info: String?
        // system_admin only — a plain church_admin passing this is
        // silently ignored server-side and falls back to their own church.
        let p_church_id: UUID?
    }

    func updateMyChurch(
        name: String?, city: String?, denomination: String?, style: String?,
        youtubeHandle: String?, websiteURL: String?, contactEmail: String?,
        address: String? = nil, serviceTimes: String? = nil, parkingInfo: String? = nil,
        kidsInfo: String? = nil, accessibilityInfo: String? = nil, newcomerInfo: String? = nil,
        churchID: UUID? = nil
    ) async throws {
        let params = UpdateMyChurchParams(
            p_name: name, p_city: city, p_denomination: denomination, p_style: style,
            p_youtube_handle: youtubeHandle, p_website_url: websiteURL, p_contact_email: contactEmail,
            p_address: address, p_service_times: serviceTimes, p_parking_info: parkingInfo,
            p_kids_info: kidsInfo, p_accessibility_info: accessibilityInfo, p_newcomer_info: newcomerInfo,
            p_church_id: churchID
        )
        try await client.rpc("update_my_church", params: params).execute()
    }

    /// The church the signed-in church_admin manages (may be unpublished; RLS
    /// exposes it to its own admin via `my_church_id()`).
    func fetchMyChurch(churchID: UUID) async throws -> Church? {
        let rows: [ChurchDTO] = try await client
            .from("churches").select().eq("id", value: churchID).limit(1).execute().value
        return rows.first?.toModel()
    }

    // MARK: System-admin actions

    func adminListPendingChurches() async throws -> [PendingChurch] {
        let dtos: [PendingChurchDTO] = try await client
            .rpc("admin_list_pending_churches").execute().value
        return dtos.map { $0.toModel() }
    }

    private struct UserIDParam: Encodable { let p_user_id: UUID }

    func adminVerifyChurchAccount(userID: UUID) async throws {
        try await client.rpc("admin_verify_church_account",
                             params: UserIDParam(p_user_id: userID)).execute()
    }

    func adminRejectChurchAccount(userID: UUID) async throws {
        try await client.rpc("admin_reject_church_account",
                             params: UserIDParam(p_user_id: userID)).execute()
    }

    private struct CreateInviteParams: Encodable {
        let p_church_name: String?
        let p_contact_email: String?
        let p_expires_days: Int
    }

    /// Mints an invite token (system-admin only). Returns the raw token — the
    /// caller wraps it into a portal URL.
    func createChurchInvite(churchName: String?, contactEmail: String?, expiresDays: Int = 30) async throws -> String {
        let params = CreateInviteParams(p_church_name: churchName, p_contact_email: contactEmail, p_expires_days: expiresDays)
        return try await client.rpc("create_church_invite", params: params).execute().value
    }

    // MARK: Moderation queue (migration 0029)

    /// One open content report with the offending content joined in.
    struct ModerationReport: Identifiable, Hashable {
        let id: UUID
        let createdAt: String?
        let contentKind: String
        let contentID: UUID?
        let reason: String
        let detail: String?
        let reportCount: Int
        let authorName: String?
        let contentText: String?
        let contentStatus: String?
    }

    private struct ModerationReportDTO: Decodable {
        let reportId: UUID
        let createdAt: String?
        let contentKind: String
        let contentId: UUID?
        let reason: String
        let detail: String?
        let reportCount: Int
        let authorName: String?
        let contentText: String?
        let contentStatus: String?

        enum CodingKeys: String, CodingKey {
            case reportId = "report_id"
            case createdAt = "created_at"
            case contentKind = "content_kind"
            case contentId = "content_id"
            case reason, detail
            case reportCount = "report_count"
            case authorName = "author_name"
            case contentText = "content_text"
            case contentStatus = "content_status"
        }
    }

    /// Open reports, newest first (system_admin only — the RPC returns
    /// nothing for anyone else). Throws so the queue can show an error state.
    func adminListOpenReports() async throws -> [ModerationReport] {
        let dtos: [ModerationReportDTO] = try await client
            .rpc("admin_list_open_reports").execute().value
        return dtos.map {
            ModerationReport(
                id: $0.reportId, createdAt: $0.createdAt, contentKind: $0.contentKind,
                contentID: $0.contentId, reason: $0.reason, detail: $0.detail,
                reportCount: $0.reportCount, authorName: $0.authorName,
                contentText: $0.contentText, contentStatus: $0.contentStatus
            )
        }
    }

    private struct ResolveReportParams: Encodable {
        let p_report_id: UUID
        let p_action: String
    }

    /// Resolve a report: "dismiss" closes it; "hide" / "remove" change the
    /// content's visibility and close every open report on that content.
    func adminResolveReport(reportID: UUID, action: String) async throws {
        try await client.rpc("admin_resolve_report",
                             params: ResolveReportParams(p_report_id: reportID, p_action: action))
            .execute()
    }

    // MARK: Add a church (system-admin) via the add_church edge function
    //
    // Resolves the YouTube channel, upserts the church, and wires up a
    // live_services row so it appears in Attend. Authenticated with the
    // signed-in system_admin's JWT (the function verifies the role), so no
    // pipeline secret ever ships in the app. Mirrors askKyra's transport.

    enum AddChurchError: LocalizedError {
        case notSignedIn
        case message(String)
        case failed
        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "You need to be signed in."
            case .message(let m): return m
            case .failed: return "Couldn't add that church. Check the channel and try again."
            }
        }
    }

    struct AddChurchResult { let name: String; let liveNow: Bool }

    private struct AddChurchResponse: Decodable {
        struct Row: Decodable { let name: String }
        let church: Row
        let liveNow: Bool
        enum CodingKeys: String, CodingKey { case church; case liveNow = "live_now" }
    }
    private struct AddChurchErrorBody: Decodable { let error: String }

    func addChurch(input: String, name: String?, city: String?,
                   denomination: String?, style: String?) async throws -> AddChurchResult {
        guard let session = client.auth.currentSession else { throw AddChurchError.notSignedIn }
        let url = SupabaseConfig.url.appendingPathComponent("functions/v1/add_church")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = ["input": input]
        if let name, !name.isEmpty { body["name"] = name }
        if let city, !city.isEmpty { body["city"] = city }
        if let denomination, !denomination.isEmpty { body["denomination"] = denomination }
        if let style, !style.isEmpty { body["style"] = style }
        request.httpBody = try? JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AddChurchError.failed }
        guard (200...299).contains(http.statusCode) else {
            if let errBody = try? JSONDecoder().decode(AddChurchErrorBody.self, from: data) {
                throw AddChurchError.message(errBody.error)
            }
            throw AddChurchError.failed
        }
        let decoded = try JSONDecoder().decode(AddChurchResponse.self, from: data)
        return AddChurchResult(name: decoded.church.name, liveNow: decoded.liveNow)
    }
}
