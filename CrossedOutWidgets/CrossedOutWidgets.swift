import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(
            date: Date(),
            ref: "Psalm 46:1",
            text: "God is our refuge and strength, an ever-present help in times of trouble.",
            streak: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(entryFromStore() ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let entry = entryFromStore() ?? placeholder(in: context)
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date().addingTimeInterval(14400)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func entryFromStore() -> VerseEntry? {
        guard let snap = AppGroupStore.readSnapshot() else { return nil }
        return VerseEntry(
            date: snap.updatedAt,
            ref: snap.ref,
            text: snap.text,
            streak: snap.streakCurrent
        )
    }
}

struct VerseEntry: TimelineEntry {
    let date: Date
    let ref: String
    let text: String
    let streak: Int
}

struct CrossedOutWidgetsEntryView: View {
    var entry: VerseEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CROSSED OUT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.45, green: 0.42, blue: 0.38))
                Spacer()
                if entry.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(entry.streak)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.72, green: 0.22, blue: 0.18))
                }
            }
            Text(entry.ref)
                .font(.system(size: family == .systemSmall ? 13 : 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.12))
            Text(entry.text)
                .font(.system(size: family == .systemSmall ? 12 : 14, design: .serif))
                .foregroundStyle(Color(red: 0.28, green: 0.26, blue: 0.24))
                .lineLimit(family == .systemSmall ? 4 : 6)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(red: 0.96, green: 0.94, blue: 0.90)
        }
    }
}

struct CrossedOutWidgets: Widget {
    let kind: String = "CrossedOutVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CrossedOutWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("Today's verse and your streak fire.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CrossedOutWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CrossedOutWidgets()
    }
}
