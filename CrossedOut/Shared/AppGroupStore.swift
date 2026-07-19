import Foundation

/// Shared App Group bridge for the main app ↔ WidgetKit extension.
enum AppGroupStore {
    static let suiteName = "group.com.tdocks.crossedout"
    private static let snapshotKey = "co.widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    struct VerseSnapshot: Codable, Hashable {
        var ref: String
        var text: String
        var streakCurrent: Int
        var updatedAt: Date
    }

    static func writeSnapshot(_ snapshot: VerseSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func readSnapshot() -> VerseSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(VerseSnapshot.self, from: data)
    }
}
