import Foundation
import Supabase

// MARK: - Church membership (0039), circles (0040), prayer scopes (0041)
//
// Church membership: many-to-many join, RPC-only writes. Circles: private
// prayer groups joined by a shareable code, RPC-only writes. Prayer scopes:
// filter the prayer feed by Everyone / My Church / Mine / My Circle.

extension SupabaseService {

    // MARK: Church membership

    struct ChurchMembership { let churchID: UUID; let isPrimary: Bool }

    private struct ChurchMembershipRow: Decodable {
        let church_id: UUID
        let is_primary: Bool
    }

    func fetchChurchMemberships() async throws -> [ChurchMembership] {
        guard let uid = currentUserID else { return [] }
        let rows: [ChurchMembershipRow] = try await client
            .from("church_members")
            .select("church_id, is_primary")
            .eq("user_id", value: uid)
            .execute()
            .value
        return rows.map { ChurchMembership(churchID: $0.church_id, isPrimary: $0.is_primary) }
    }

    private struct JoinChurchParams: Encodable { let p_church_id: UUID; let p_primary: Bool }
    @discardableResult
    func joinChurch(churchID: UUID, primary: Bool = true) async -> Bool {
        do {
            try await client.rpc("join_church",
                params: JoinChurchParams(p_church_id: churchID, p_primary: primary)).execute()
            return true
        } catch {
            print("SupabaseService: joinChurch failed: \(error)")
            return false
        }
    }

    private struct LeaveChurchParams: Encodable { let p_church_id: UUID }
    @discardableResult
    func leaveChurch(churchID: UUID) async -> Bool {
        do {
            try await client.rpc("leave_church",
                params: LeaveChurchParams(p_church_id: churchID)).execute()
            return true
        } catch {
            print("SupabaseService: leaveChurch failed: \(error)")
            return false
        }
    }

    // MARK: Circles

    func fetchMyCircles() async throws -> [PrayerCircle] {
        // The circles RLS policy returns only circles the caller belongs to.
        let circles: [PrayerCircle] = try await client
            .from("circles")
            .select("id, name, join_code")
            .order("created_at", ascending: false)
            .execute()
            .value
        var result: [PrayerCircle] = []
        for c in circles {
            var withCount = c
            withCount.memberCount = (try? await circleMemberCount(id: c.id)) ?? 0
            result.append(withCount)
        }
        return result
    }

    private struct CreateCircleParams: Encodable { let p_name: String }
    func createCircle(name: String) async throws -> PrayerCircle {
        var c: PrayerCircle = try await client
            .rpc("create_circle", params: CreateCircleParams(p_name: name))
            .execute()
            .value
        c.memberCount = 1
        return c
    }

    private struct JoinCircleParams: Encodable { let p_code: String }
    func joinCircle(code: String) async throws -> PrayerCircle {
        var c: PrayerCircle = try await client
            .rpc("join_circle_by_code", params: JoinCircleParams(p_code: code))
            .execute()
            .value
        c.memberCount = (try? await circleMemberCount(id: c.id)) ?? 1
        return c
    }

    private struct LeaveCircleParams: Encodable { let p_circle_id: UUID }
    @discardableResult
    func leaveCircle(id: UUID) async -> Bool {
        do {
            try await client.rpc("leave_circle",
                params: LeaveCircleParams(p_circle_id: id)).execute()
            return true
        } catch {
            print("SupabaseService: leaveCircle failed: \(error)")
            return false
        }
    }

    private struct CircleCountParams: Encodable { let p_circle_id: UUID }
    func circleMemberCount(id: UUID) async throws -> Int {
        try await client
            .rpc("circle_member_count", params: CircleCountParams(p_circle_id: id))
            .execute()
            .value
    }

    // MARK: Prayer scopes

    func fetchPrayerRequests(scope: PrayerScope, churchID: UUID?) async throws -> [PrayerRequest] {
        switch scope {
        case .everyone:
            return try await fetchPrayerRequests()
        case .mine:
            guard let uid = currentUserID else { return [] }
            let dtos: [PrayerRequestDTO] = try await client
                .from("prayer_requests").select()
                .eq("user_id", value: uid)
                .order("created_at", ascending: false)
                .execute().value
            return dtos.map { $0.toModel() }
        case .myChurch:
            guard let churchID else { return [] }
            let dtos: [PrayerRequestDTO] = try await client
                .from("prayer_requests").select()
                .eq("church_id", value: churchID)
                .order("created_at", ascending: false)
                .execute().value
            return dtos.map { $0.toModel() }
        case .circle:
            let dtos: [PrayerRequestDTO] = try await client
                .rpc("circle_prayer_requests")
                .execute().value
            return dtos.map { $0.toModel() }
        }
    }
}
