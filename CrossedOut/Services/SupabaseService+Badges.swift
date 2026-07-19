import Foundation
import Supabase

extension SupabaseService {
    private struct BadgeRow: Decodable {
        let badge_id: String
        let earned_at: String
    }

    /// Fetches earned badge ids → dates for the current user.
    func fetchEarnedBadges() async throws -> [String: Date] {
        guard let uid = currentUserID else { return [:] }
        let rows: [BadgeRow] = try await client
            .from("user_badges")
            .select("badge_id,earned_at")
            .eq("user_id", value: uid)
            .execute()
            .value

        var map: [String: Date] = [:]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        for row in rows {
            let date = formatter.date(from: row.earned_at)
                ?? fallback.date(from: row.earned_at)
                ?? Date()
            map[row.badge_id] = date
        }
        return map
    }

    /// Runs award evaluation; returns newly earned badge ids.
    @discardableResult
    func awardEarnedBadges() async -> [String] {
        guard currentUserID != nil else { return [] }
        do {
            let response = try await client.rpc("award_earned_badges").execute()
            if let ids = try? JSONDecoder().decode([String].self, from: response.data) {
                return ids
            }
            // Some PostgREST builds wrap JSON as a string literal.
            if let wrapped = try? JSONDecoder().decode(String.self, from: response.data),
               let inner = wrapped.data(using: .utf8),
               let ids = try? JSONDecoder().decode([String].self, from: inner) {
                return ids
            }
            return []
        } catch {
            return await awardBadgesClientSide()
        }
    }

    /// Client-side award path when the RPC is unavailable.
    private func awardBadgesClientSide() async -> [String] {
        guard let uid = currentUserID else { return [] }
        do {
            let earned = try await fetchEarnedBadges()
            let streakRows: [StreakDTO] = try await client
                .from("streaks").select().eq("user_id", value: uid).execute().value
            let streak = streakRows.first
            let longest = max(streak?.longest ?? 0, streak?.current ?? 0)
            let graceUsed = streak?.graceUsed ?? 0

            struct KindRow: Decodable { let kind: String }
            let allKinds: [KindRow] = try await client
                .from("daily_completions")
                .select("kind")
                .eq("user_id", value: uid)
                .execute()
                .value
            let kindSet = Set(allKinds.map(\.kind))

            let sevenDaysAgo = Self.dayString(
                Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            )
            let weekRows: [KindRow] = try await client
                .from("daily_completions")
                .select("kind")
                .eq("user_id", value: uid)
                .gte("day", value: sevenDaysAgo)
                .execute()
                .value
            let weekKinds = Set(weekRows.map(\.kind))

            struct EnrollDone: Decodable {
                let id: UUID
                let completed_at: String?
            }
            let enrollments: [EnrollDone] = try await client
                .from("user_journey_enrollments")
                .select("id,completed_at")
                .eq("user_id", value: uid)
                .execute()
                .value
            let pathDone = enrollments.contains { $0.completed_at != nil }

            var candidates: [String] = []
            if longest >= 1 { candidates.append("first_flame") }
            if longest >= 3 { candidates.append("streak_3") }
            if longest >= 7 { candidates.append("streak_7") }
            if longest >= 14 { candidates.append("streak_14") }
            if longest >= 30 { candidates.append("streak_30") }
            if longest >= 100 { candidates.append("streak_100") }
            if kindSet.contains("scripture") { candidates.append("scripture_seed") }
            if kindSet.contains("prayer") { candidates.append("prayer_voice") }
            if kindSet.contains("reflection") { candidates.append("reflecting_heart") }
            if kindSet.contains("community") { candidates.append("community_presence") }
            if kindSet.contains("encouragement") { candidates.append("encouraging_hand") }
            if kindSet.contains("devotional") { candidates.append("daily_word") }
            if kindSet.contains("action") { candidates.append("practice_step") }
            if kindSet.contains("rest") { candidates.append("sabbath_rest") }
            if kindSet.contains("church") { candidates.append("gathered") }
            if pathDone { candidates.append("path_walker") }
            if graceUsed > 0 { candidates.append("grace_held") }
            let core = Set(["scripture", "prayer", "reflection", "community", "encouragement", "devotional"])
            if core.isSubset(of: weekKinds) { candidates.append("full_rhythm_week") }

            let fresh = candidates.filter { earned[$0] == nil }
            guard !fresh.isEmpty else { return [] }

            struct Insert: Encodable {
                let user_id: UUID
                let badge_id: String
            }
            for id in fresh {
                try await client
                    .from("user_badges")
                    .upsert(Insert(user_id: uid, badge_id: id), onConflict: "user_id,badge_id")
                    .execute()
            }
            return fresh
        } catch {
            print("SupabaseService: awardBadgesClientSide failed: \(error)")
            return []
        }
    }
}
