import Foundation
import UserNotifications

/// Local notifications only (no APNs yet). Settings owns enable/time via
/// @AppStorage; this service applies the schedule.
enum ReminderService {

    private static let dailyID = "co.daily"
    private static let streakID = "co.streak"

    /// Gentle, rotating lines — picked by day-of-year so the message varies
    /// without needing any server or persistence.
    private static let bodyLines = [
        "Your verse for today is ready.",
        "A quiet moment with God is waiting.",
        "What are you carrying today?",
        "Take a breath. Today's Word is here for you.",
        "A few minutes with Scripture, whenever you're ready."
    ]

    private static let streakBodies = [
        "Your streak fire is waiting — one quiet check-in keeps it lit.",
        "Grace covers missed days. Showing up today still counts.",
        "A short moment with God is enough to keep the flame."
    ]

    /// Requests notification authorization (if needed), removes any pending
    /// daily request, and schedules a repeating daily calendar trigger at
    /// the given time. Returns whether the app is authorized to notify.
    @discardableResult
    static func schedule(hour: Int, minute: Int) async -> Bool {
        let granted = await requestAuth()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Crossed Out"
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        content.body = bodyLines[dayOfYear % bodyLines.count]
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger)
        await withCheckedContinuation { continuation in
            center.add(request) { _ in continuation.resume() }
        }
        return true
    }

    /// Optional evening streak nudge (local). Does not require server state.
    @discardableResult
    static func scheduleStreakNudge(hour: Int, minute: Int) async -> Bool {
        let granted = await requestAuth()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakID])
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Keep the flame"
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        content.body = streakBodies[dayOfYear % streakBodies.count]
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: streakID, content: content, trigger: trigger)
        await withCheckedContinuation { continuation in
            center.add(request) { _ in continuation.resume() }
        }
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyID])
    }

    static func cancelStreakNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [streakID])
    }

    private static func requestAuth() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
}
