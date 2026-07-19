import Foundation

// MARK: - Explore (migration 0037)
//
// explore_items is a shared, read-only discovery surface populated server-side
// by the explore_* edge functions (YouTube sermons, devotional RSS, later:
// events / music / movies). The app never writes here — it reads active items
// and deep-links the user OUT to the source app. No third-party media is
// hosted or reproduced; we surface titles, thumbnails, capped excerpts, and
// official links only.

enum ExploreVertical: String, CaseIterable, Identifiable {
    case music, sermons, devotionals, movies, events

    var id: String { rawValue }

    /// Short label used on filter chips.
    var chipTitle: String {
        switch self {
        case .music: return "Music"
        case .sermons: return "Sermons"
        case .devotionals: return "Devotionals"
        case .movies: return "Movies"
        case .events: return "Events"
        }
    }

    /// Warm editorial heading used above each section.
    var sectionTitle: String {
        switch self {
        case .music: return "Worship & Music"
        case .sermons: return "Sermons & Teaching"
        case .devotionals: return "Daily Devotionals"
        case .movies: return "Movies & Shows"
        case .events: return "Events Near You"
        }
    }

    var icon: COIconName {
        switch self {
        case .music: return .music
        case .sermons: return .play
        case .devotionals: return .journal
        case .movies: return .play
        case .events: return .calendar
        }
    }

    /// Display order top-to-bottom in the feed.
    var order: Int {
        switch self {
        case .devotionals: return 0
        case .sermons: return 1
        case .music: return 2
        case .movies: return 3
        case .events: return 4
        }
    }

    /// Verticals we've committed to but haven't wired to a live source yet.
    /// They render a quiet "coming soon" section instead of pulling data.
    var isComingSoon: Bool {
        switch self {
        case .movies: return true
        default: return false
        }
    }

    /// One-line promise shown in the coming-soon section.
    var comingSoonMessage: String {
        switch self {
        case .movies:
            return "Hand-picked Christian films and shows, with where to watch them — on the way."
        default:
            return "Coming soon."
        }
    }
}

// MARK: - Model

struct ExploreItem: Identifiable, Hashable {
    let id: UUID
    let vertical: ExploreVertical
    let source: String
    let title: String
    let subtitle: String?
    let excerpt: String?
    let thumbnailURL: String?
    let openURL: String
    let appURL: String?
    let attribution: String?

    /// The link we hand off to. Universal https link first (routes into the
    /// native app if installed, otherwise the web) — the safest handoff.
    var handoffURL: URL? { URL(string: openURL) }
}

// MARK: - DTO

private struct ExploreItemDTO: Decodable {
    let id: UUID
    let vertical: String
    let source: String
    let title: String
    let subtitle: String?
    let excerpt: String?
    let thumbnailUrl: String?
    let openUrl: String
    let appUrl: String?
    let attribution: String?

    enum CodingKeys: String, CodingKey {
        case id, vertical, source, title, subtitle, excerpt
        case thumbnailUrl = "thumbnail_url"
        case openUrl = "open_url"
        case appUrl = "app_url"
        case attribution
    }

    func toModel() -> ExploreItem? {
        guard let v = ExploreVertical(rawValue: vertical) else { return nil }
        return ExploreItem(
            id: id, vertical: v, source: source, title: title,
            subtitle: subtitle, excerpt: excerpt, thumbnailURL: thumbnailUrl,
            openURL: openUrl, appURL: appUrl, attribution: attribution
        )
    }
}

// MARK: - Fetch

extension SupabaseService {
    /// Fetches active Explore items, already ordered by curation rank then
    /// recency. Callers group by `vertical` for display. Rows with an
    /// unrecognized vertical are dropped rather than throwing.
    func fetchExploreItems() async throws -> [ExploreItem] {
        let dtos: [ExploreItemDTO] = try await client
            .from("explore_items")
            .select("id,vertical,source,title,subtitle,excerpt,thumbnail_url,open_url,app_url,attribution,published_at,rank")
            .eq("is_active", value: true)
            .order("rank", ascending: false)
            .order("published_at", ascending: false)
            .execute()
            .value
        return dtos.compactMap { $0.toModel() }
    }
}
