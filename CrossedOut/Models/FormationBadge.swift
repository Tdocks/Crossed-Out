import Foundation

/// A formation badge the user can earn. Catalog is client-defined;
/// persistence is `user_badges` (migration 0035).
struct FormationBadge: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: COIconName
    let tint: BadgeTint
    let earnedAt: Date?

    var isEarned: Bool { earnedAt != nil }

    enum BadgeTint: String, Hashable {
        case flame, gold, olive, ink
    }

    func withEarnedAt(_ date: Date?) -> FormationBadge {
        FormationBadge(
            id: id, title: title, subtitle: subtitle,
            icon: icon, tint: tint, earnedAt: date
        )
    }
}

enum FormationBadgeCatalog {
    static let all: [FormationBadge] = [
        // Streak fires
        FormationBadge(
            id: "first_flame", title: "First Flame",
            subtitle: "Showed up for day one.", icon: .flame, tint: .flame, earnedAt: nil
        ),
        FormationBadge(
            id: "streak_3", title: "Three Days",
            subtitle: "A small fire kept.", icon: .flame, tint: .flame, earnedAt: nil
        ),
        FormationBadge(
            id: "streak_7", title: "Week of Fire",
            subtitle: "Seven days in a row.", icon: .flame, tint: .flame, earnedAt: nil
        ),
        FormationBadge(
            id: "streak_14", title: "Fortnight Flame",
            subtitle: "Fourteen faithful days.", icon: .flame, tint: .gold, earnedAt: nil
        ),
        FormationBadge(
            id: "streak_30", title: "Month of Fire",
            subtitle: "Thirty days with God.", icon: .flame, tint: .gold, earnedAt: nil
        ),
        FormationBadge(
            id: "streak_100", title: "Hundredfold",
            subtitle: "A hundred-day streak.", icon: .flame, tint: .gold, earnedAt: nil
        ),

        // Action kinds
        FormationBadge(
            id: "scripture_seed", title: "Scripture Seed",
            subtitle: "Opened the Word today.", icon: .bible, tint: .ink, earnedAt: nil
        ),
        FormationBadge(
            id: "prayer_voice", title: "Prayer Voice",
            subtitle: "Brought something to God.", icon: .prayer, tint: .olive, earnedAt: nil
        ),
        FormationBadge(
            id: "reflecting_heart", title: "Reflecting Heart",
            subtitle: "Sat with a question.", icon: .journal, tint: .ink, earnedAt: nil
        ),
        FormationBadge(
            id: "community_presence", title: "Present",
            subtitle: "Showed up in community.", icon: .community, tint: .ink, earnedAt: nil
        ),
        FormationBadge(
            id: "encouraging_hand", title: "Encouraging Hand",
            subtitle: "Sent someone hope.", icon: .bridge, tint: .olive, earnedAt: nil
        ),
        FormationBadge(
            id: "daily_word", title: "Daily Word",
            subtitle: "Finished a devotional.", icon: .today, tint: .gold, earnedAt: nil
        ),
        FormationBadge(
            id: "practice_step", title: "Practice Step",
            subtitle: "Crossed off a real action.", icon: .checkCircle, tint: .olive, earnedAt: nil
        ),
        FormationBadge(
            id: "sabbath_rest", title: "Sabbath Rest",
            subtitle: "Rested without guilt.", icon: .leaf, tint: .olive, earnedAt: nil
        ),
        FormationBadge(
            id: "gathered", title: "Gathered",
            subtitle: "Joined the church body.", icon: .church, tint: .ink, earnedAt: nil
        ),

        // Path + grace
        FormationBadge(
            id: "path_walker", title: "Path Walker",
            subtitle: "Finished a guided path.", icon: .mapPin, tint: .gold, earnedAt: nil
        ),
        FormationBadge(
            id: "grace_held", title: "Grace Held",
            subtitle: "Let grace cover a miss.", icon: .leaf, tint: .olive, earnedAt: nil
        ),
        FormationBadge(
            id: "full_rhythm_week", title: "Full Rhythm",
            subtitle: "All six practices in a week.", icon: .calendar, tint: .gold, earnedAt: nil
        )
    ]

    static func merged(earnedIDs: [String: Date]) -> [FormationBadge] {
        all.map { $0.withEarnedAt(earnedIDs[$0.id]) }
    }
}
