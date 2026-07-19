import SwiftUI
import EventKit
import EventKitUI

// MARK: - Add to Calendar

/// Wraps EventKit's own `EKEventEditViewController` — the system's native
/// "Add Event" sheet, prefilled with a church visit. This is the real
/// EventKit integration (not a home-grown form): the controller manages its
/// own calendar-access prompt (write-only, iOS 17+), and the user reviews
/// and taps "Add" themselves before anything is saved.
struct AddToCalendarSheet: UIViewControllerRepresentable {
    let event: EKEvent
    let eventStore: EKEventStore
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.event = event
        controller.eventStore = eventStore
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true) { [onDone] in onDone() }
        }
    }
}

// MARK: - Event builder

enum ChurchVisitEvent {
    /// Builds a one-hour "visit" event for a church, defaulting to the
    /// upcoming Sunday. Deterministic — no AI, no network. `timeString`
    /// (e.g. "9:00 AM") comes from the specific service being viewed; a
    /// free-text `service_times` value on the church is too unstructured
    /// to parse reliably, so it's included in the notes instead when
    /// present, never guessed into a start time.
    static func makeEvent(store: EKEventStore, churchName: String, address: String?,
                          timeString: String?, notes: String?) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = "Visit \(churchName)"
        event.location = address
        event.calendar = store.defaultCalendarForNewEvents

        let start = nextServiceDate(timeString: timeString)
        event.startDate = start
        event.endDate = start.addingTimeInterval(60 * 60)

        var noteLines: [String] = []
        if let notes, !notes.isEmpty { noteLines.append(notes) }
        noteLines.append("Planned from Crossed Out.")
        event.notes = noteLines.joined(separator: "\n")

        return event
    }

    /// The next Sunday at the given time-of-day (parsed from a "h:mm a"
    /// string like "9:00 AM"; defaults to 10:00 AM when absent/unparsable).
    /// If today is already Sunday and the time hasn't passed yet, uses
    /// today instead of jumping a week ahead.
    static func nextServiceDate(timeString: String?, from now: Date = Date(),
                                calendar: Calendar = .current) -> Date {
        var hour = 10
        var minute = 0
        if let timeString {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let parsed = formatter.date(from: timeString.trimmingCharacters(in: .whitespaces)) {
                let comps = calendar.dateComponents([.hour, .minute], from: parsed)
                hour = comps.hour ?? 10
                minute = comps.minute ?? 0
            }
        }

        let todayWeekday = calendar.component(.weekday, from: now) // 1 = Sunday
        var daysAhead = (8 - todayWeekday) % 7 // 0 if today is Sunday
        var candidate = calendar.date(
            bySettingHour: hour, minute: minute, second: 0,
            of: calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now
        ) ?? now

        if daysAhead == 0 && candidate <= now {
            // Today's service time already passed — use next Sunday instead.
            daysAhead = 7
            candidate = calendar.date(
                bySettingHour: hour, minute: minute, second: 0,
                of: calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now
            ) ?? now
        }
        return candidate
    }
}
