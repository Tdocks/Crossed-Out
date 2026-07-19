import SwiftUI
import UIKit

/// Day-by-day Path reader. Verse text comes from live `bible_verses` (BSB).
struct PathDetailView: View {
    let enrollment: JourneyEnrollment
    var initialDay: Int? = nil
    var onChanged: () async -> Void = {}

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var days: [JourneyDayContent] = []
    @State private var title = ""
    @State private var subtitle: String?
    @State private var dayIndex = 0
    @State private var completedLocal: Set<Int> = []
    @State private var loading = true
    @State private var completing = false
    @State private var loadFailed = false

    private var current: JourneyDayContent? {
        days.indices.contains(dayIndex) ? days[dayIndex] : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadFailed || days.isEmpty {
                    VStack(spacing: 12) {
                        Text("Couldn't open this path.")
                            .font(.coUI(14))
                            .foregroundColor(.coInkSecondary)
                        Button("Close") { dismiss() }
                            .foregroundColor(.coCrossRed)
                    }
                } else if let day = current {
                    dayReader(day)
                }
            }
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func dayReader(_ day: JourneyDayContent) -> some View {
        let isDone = completedLocal.contains(day.day)
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Day \(day.day) of \(days.count)")
                        .font(.coUI(12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.coInkTertiary)

                    Text(day.title)
                        .font(.coDisplay(24, weight: .semibold))
                        .foregroundColor(.coInk)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(day.ref)
                            .font(.coUI(12, weight: .semibold))
                            .foregroundColor(.coCrossRed)
                        Text(day.text)
                            .font(.coScripture(18))
                            .foregroundColor(.coInk)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 14)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.coGold).frame(width: 2)
                    }

                    Text(day.body)
                        .font(.coUI(15))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    if isDone {
                        Text("Marked for today. See you on the next day.")
                            .font(.coUIItalic(13))
                            .foregroundColor(.coOlive)
                    }
                }
                .padding(22)
                .padding(.bottom, 24)
            }

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation { dayIndex = max(0, dayIndex - 1) }
                    } label: {
                        Text("Previous")
                            .font(.coUI(14, weight: .medium))
                            .foregroundColor(dayIndex == 0 ? .coInkTertiary : .coInkSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .disabled(dayIndex == 0)
                    .buttonStyle(.plain)

                    if !isDone {
                        COPrimaryButton(title: completing ? "Saving…" : "Mark Day \(day.day) complete") {
                            Task { await complete(day.day) }
                        }
                        .disabled(completing)
                    } else if dayIndex < days.count - 1 {
                        COPrimaryButton(title: "Next day") {
                            withAnimation { dayIndex += 1 }
                        }
                    } else {
                        COPrimaryButton(title: "Done", tint: .coOlive) { dismiss() }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.coPaper)
        }
    }

    private func load() async {
        loading = true
        loadFailed = false
        do {
            let fetched = try await SupabaseService.shared.fetchJourneyDays(slug: enrollment.slug)
            title = fetched.title
            subtitle = fetched.subtitle
            days = fetched.days
            completedLocal = enrollment.completedDays
            let startDay = initialDay ?? enrollment.currentDay
            if let idx = days.firstIndex(where: { $0.day == startDay }) {
                dayIndex = idx
            } else {
                dayIndex = 0
            }
            loading = false
        } catch {
            loadFailed = true
            loading = false
        }
    }

    private func complete(_ day: Int) async {
        guard !completing else { return }
        completing = true
        do {
            let result = try await SupabaseService.shared.completeJourneyDay(
                enrollmentId: enrollment.id, day: day
            )
            completedLocal.insert(day)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await onChanged()
            if result.completed {
                appState.justCompletedPathTitle = title
                await SupabaseService.shared.touchStreak()
                await appState.recordActivity(kind: "devotional")
                await appState.refreshBadges(award: true)
            } else {
                await SupabaseService.shared.touchStreak()
                await appState.recordActivity(kind: "devotional")
            }
            if dayIndex < days.count - 1 {
                withAnimation { dayIndex += 1 }
            }
        } catch {
            // leave UI; user can retry
        }
        completing = false
    }
}
