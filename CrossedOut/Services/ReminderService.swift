import Foundation
import UserNotifications

/// Schedules (and cancels) the single daily "check in" local notification.
/// Stateless by design — SettingsView owns the enabled/hour/minute state via
/// @AppStorage and calls into this enum to apply it.
enum ReminderService {

    private static let requestID = "co.daily"

    /// Gentle, rotating lines — picked by day-of-year so the message varies
    /// without needing any server or persistence.
    private static let bodyLines = [
        "Your verse for today is ready.",
        "A quiet moment with God is waiting.",
        "What are you carrying today?",
        "Take a breath. Today's Word is here for you.",
        "A few minutes with Scripture, whenever you're ready."
    ]

    /// Requests notification authorization (if needed), removes any pending
    /// daily request, and schedules a repeating daily calendar trigger at
    /// the given time. Returns whether the app is authorized to notify —
    /// callers should reflect that back into their enabled toggle.
    @discardableResult
    static func schedule(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()

        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            granted = false
        }

        center.removePendingNotificationRequests(withIdentifiers: [requestID])

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

        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        await withCheckedContinuation { continuation in
            center.add(request) { _ in continuation.resume() }
        }

        return true
    }

    /// Removes the pending daily request, if any.
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestID])
    }
}
