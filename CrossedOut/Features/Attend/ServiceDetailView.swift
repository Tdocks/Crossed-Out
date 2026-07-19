import SwiftUI
import UIKit
import EventKit

// MARK: - Service Detail

struct ServiceDetailView: View {
    let service: LiveService

    @State private var isSaved = false
    @State private var isPlanVisitPresented = false
    @State private var primaryLabel: String = ""
    @State private var isPrimaryBusy = false
    @State private var watchSource: WatchSource?
    @State private var showNotLiveAlert = false
    @State private var notLiveChannelURL: URL?
    /// The current user's recorded watches of this church (migration 0032).
    /// 2+ unlocks the "Plan a Visit" affordance — a repeat online viewer,
    /// not a first-time browser, is who this bridge is for.
    @State private var watchCount = 0
    @Environment(\.openURL) private var openURL

    private var qualifiesForVisitPlanning: Bool { watchCount >= 2 }

    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    identityBlock
                    aboutSection
                    actionsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBar()
        .onAppear {
            if primaryLabel.isEmpty {
                primaryLabel = service.isLive ? "Watch Live" : "Set a Reminder"
            }
        }
        .task {
            await loadSavedState()
            await loadWatchCount()
        }
        .sheet(isPresented: $isPlanVisitPresented) {
            PlanVisitSheet(church: service.church, defaultTimeString: service.time)
        }
        .fullScreenCover(item: $watchSource) { source in
            WatchView(source: source, churchName: service.church.name)
        }
        .alert("Not live right now", isPresented: $showNotLiveAlert) {
            if let url = notLiveChannelURL {
                Button("Open on YouTube") { openURL(url) }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(service.church.name) isn't streaming at the moment. Check their YouTube channel for the schedule.")
        }
    }
}

// MARK: - Header Banner

private extension ServiceDetailView {
    var header: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let t = service.church.thumbnailURL, let u = URL(string: t) {
                    AsyncImage(url: u) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color(hex: "3B372F"))
                    }
                } else {
                    Rectangle()
                        .fill(Color(hex: "3B372F"))
                        .overlay(COIcon(.church, size: 46, color: Color.white.opacity(0.14)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            if service.isLive {
                liveBadge
                    .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, 8)
    }

    var liveBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.white).frame(width: 5, height: 5)
            Text("LIVE")
                .font(.coUI(10, weight: .semibold))
                .foregroundColor(.white)
                .tracking(0.4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.coCrossRed))
    }
}

// MARK: - Identity Block

private extension ServiceDetailView {
    var identityBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(service.church.name)
                .font(.coDisplay(26, weight: .semibold))
                .foregroundColor(.coInk)
            Text(service.church.city)
                .font(.coUI(14))
                .foregroundColor(.coInkSecondary)
            metaRow
        }
    }

    var metaRow: some View {
        HStack(spacing: 6) {
            Text(service.church.style)
            Text("·")
            Text("\(String(format: "%.1f", service.church.rating)) ★")
            Text("·")
            Text(service.isLive ? viewerLabel : service.scheduleLabel)
        }
        .font(.coUI(12))
        .foregroundColor(.coInkTertiary)
    }

    var viewerLabel: String {
        guard let viewers = service.church.viewers else { return "Live now" }
        if viewers >= 1000 {
            return String(format: "%.1fK watching", Double(viewers) / 1000.0)
        }
        return "\(viewers) watching"
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this service")
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(.coInkSecondary)
            Text("Join this gathering live from wherever you are. Take notes, save Scripture, and if it feels like home, plan an in-person visit.")
                .font(.coUI(14))
                .foregroundColor(.coInk)
                .lineSpacing(5)
        }
    }
}

// MARK: - Actions

private extension ServiceDetailView {
    var actionsSection: some View {
        VStack(spacing: 12) {
            COPrimaryButton(title: primaryLabel) {
                handlePrimaryAction()
            }
            if qualifiesForVisitPlanning {
                HStack(spacing: 12) {
                    saveChurchButton
                    planVisitButton
                }
            } else {
                saveChurchButton
            }
        }
    }

    var saveChurchButton: some View {
        Button {
            toggleSaved()
        } label: {
            HStack(spacing: 8) {
                COIcon(.heart, size: 16, color: isSaved ? .coCrossRed : .coInkSecondary)
                Text("Save Church")
                    .font(.coUI(14, weight: .medium))
                    .foregroundColor(isSaved ? .coCrossRed : .coInkSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSaved ? Color.coCrossRed.opacity(0.4) : Color.coDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var planVisitButton: some View {
        Button {
            isPlanVisitPresented = true
        } label: {
            HStack(spacing: 8) {
                COIcon(.bridge, size: 16, color: .coInkSecondary)
                Text("Plan a Visit")
                    .font(.coUI(14, weight: .medium))
                    .foregroundColor(.coInkSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Behaviors

private extension ServiceDetailView {
    func handlePrimaryAction() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if service.isLive {
            startWatching()
        } else if let vid = service.upcomingVideoId, !vid.isEmpty,
                  let url = URL(string: "https://www.youtube.com/watch?v=\(vid)") {
            // Upcoming broadcast: open its page so the viewer can tap "Notify me".
            openURL(url)
        } else {
            // No scheduled video — lightweight reminder confirmation (APNs TBD).
            guard !isPrimaryBusy else { return }
            isPrimaryBusy = true
            withAnimation(.easeOut(duration: 0.2)) { primaryLabel = "Reminder set." }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.2)) { primaryLabel = "Set a Reminder" }
                isPrimaryBusy = false
            }
        }
    }

    /// In-app player for YouTube (iframe live embed) or direct HLS; otherwise
    /// link out to the church's watch page (Facebook, or a YouTube /live URL).
    func startWatching() {
        let ch = service.church
        if ch.platform == "youtube" {
            if ch.isLive, let vid = ch.liveVideoId, !vid.isEmpty {
                recordWatch()
                watchSource = .youtube(videoId: vid)     // embed the exact live broadcast
            } else {
                // No current live video (refresh pipeline says not live) — don't
                // show a dead embed; offer the channel's /live page instead.
                notLiveChannelURL = fallbackURL(for: ch)
                showNotLiveAlert = true
            }
        } else if ch.platform == "hls", let s = ch.hlsURL, let u = URL(string: s) {
            recordWatch()
            watchSource = .hls(url: u)
        } else if let w = ch.watchURL, let u = URL(string: w) {
            recordWatch()
            openURL(u)
        } else {
            // Last resort for a church with no configured stream: search YouTube.
            // Not a confirmed watch of THIS church's stream — don't record it.
            let q = ch.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ch.name
            if let u = URL(string: "https://www.youtube.com/results?search_query=\(q)+live") {
                openURL(u)
            }
        }
    }

    /// Records a real watch of this church (migration 0032: church_attendance)
    /// and optimistically bumps the local count so "Plan a Visit" can appear
    /// within the same session once the threshold is crossed.
    func recordWatch() {
        let churchID = service.church.id
        Task {
            await SupabaseService.shared.recordChurchWatch(churchID: churchID)
            await MainActor.run {
                watchCount += 1
            }
        }
    }

    func fallbackURL(for ch: Church) -> URL? {
        if let cid = ch.youtubeChannelId, !cid.isEmpty {
            return URL(string: "https://www.youtube.com/channel/\(cid)/live")
        }
        if let w = ch.watchURL { return URL(string: w) }
        return nil
    }

    func toggleSaved() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let churchID = service.church.id
        let newValue = !isSaved
        withAnimation(.easeOut(duration: 0.2)) {
            isSaved = newValue
        }
        Task {
            await SupabaseService.shared.setChurchSaved(churchID: churchID, saved: newValue)
        }
    }

    func loadSavedState() async {
        guard let ids = try? await SupabaseService.shared.fetchSavedChurchIDs() else { return }
        if ids.contains(service.church.id) {
            await MainActor.run {
                isSaved = true
            }
        }
    }

    /// Loads the current user's recorded watch count for this church, so
    /// the "Plan a Visit" affordance is gated correctly on first appear
    /// (not just after a watch recorded this session).
    func loadWatchCount() async {
        let count = await SupabaseService.shared.fetchChurchAttendanceCount(churchID: service.church.id)
        await MainActor.run {
            watchCount = max(watchCount, count)
        }
    }
}

// MARK: - Plan a Visit Sheet
//
// The online -> in-person bridge (migration 0032). Shows only the
// practical info the church has actually filled in — never an empty
// placeholder — plus two deterministic actions: add a visit to the
// user's calendar (EventKit), and let the church know they're coming
// (mailto when a contact email exists; always a private saved intent).

private struct PlanVisitSheet: View {
    let church: Church
    /// The specific service's structured time ("9:00 AM"), used (never
    /// guessed) as the calendar event's start time when present.
    var defaultTimeString: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isIntentSent = false
    @State private var isCalendarSheetPresented = false
    @State private var pendingEvent: EKEvent?
    private let eventStore = EKEventStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coPaper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if let serviceTimes = church.serviceTimes, !serviceTimes.isEmpty {
                            infoRow(icon: .calendar, title: "Service times", text: serviceTimes)
                        }
                        if let address = church.address, !address.isEmpty {
                            addressSection(address)
                        }
                        whatToExpectSection
                        actionsSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Plan a Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $isCalendarSheetPresented) {
                if let pendingEvent {
                    AddToCalendarSheet(event: pendingEvent, eventStore: eventStore) {
                        isCalendarSheetPresented = false
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }
}

private extension PlanVisitSheet {
    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From online to in person")
                .font(.coDisplay(20, weight: .semibold))
                .foregroundColor(.coInk)
            Text("You've watched \(church.name) a few times now — here's what to know if you'd like to visit.")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
        }
    }

    func infoRow(icon: COIconName, title: String, text: String) -> some View {
        COCard {
            HStack(alignment: .top, spacing: 12) {
                COIcon(icon, size: 18, color: .coInkSecondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.coUI(10, weight: .semibold))
                        .foregroundColor(.coInkTertiary)
                        .tracking(0.8)
                    Text(text)
                        .font(.coUI(14))
                        .foregroundColor(.coInk)
                }
            }
        }
    }

    func addressSection(_ address: String) -> some View {
        COCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    COIcon(.mapPin, size: 18, color: .coInkSecondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ADDRESS")
                            .font(.coUI(10, weight: .semibold))
                            .foregroundColor(.coInkTertiary)
                            .tracking(0.8)
                        Text(address)
                            .font(.coUI(14))
                            .foregroundColor(.coInk)
                    }
                }
                COSecondaryButton(title: "Directions", tint: .coCrossRed) {
                    openDirections(to: address)
                }
            }
        }
    }

    var whatToExpectRows: [(icon: COIconName, text: String)] {
        var rows: [(COIconName, String)] = [
            (.checkCircle, "Come as you are — there's no dress code.")
        ]
        if let parking = church.parkingInfo, !parking.isEmpty {
            rows.append((.mapPin, parking))
        }
        if let kids = church.kidsInfo, !kids.isEmpty {
            rows.append((.community, kids))
        }
        if let accessibility = church.accessibilityInfo, !accessibility.isEmpty {
            rows.append((.checkCircle, accessibility))
        }
        if let newcomer = church.newcomerInfo, !newcomer.isEmpty {
            rows.append((.heart, newcomer))
        }
        return rows
    }

    var whatToExpectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to expect")
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(.coInkSecondary)
            COCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(whatToExpectRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 10) {
                            COIcon(row.icon, size: 16, color: .coOlive)
                            Text(row.text)
                                .font(.coUI(14))
                                .foregroundColor(.coInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    var actionsSection: some View {
        VStack(spacing: 12) {
            COPrimaryButton(title: "Add to Calendar") {
                addToCalendar()
            }
            letThemKnowButton
        }
        .padding(.top, 4)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    var letThemKnowButton: some View {
        if isIntentSent {
            HStack(spacing: 8) {
                COIcon(.checkCircle, size: 16, color: .coOlive)
                Text("We'll let them know you're coming.")
                    .font(.coUI(14, weight: .medium))
                    .foregroundColor(.coOlive)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
        } else {
            Button {
                letThemKnow()
            } label: {
                HStack(spacing: 8) {
                    COIcon(.heart, size: 16, color: .coInkSecondary)
                    Text(hasContactEmail ? "Let \(church.name) know you're coming" : "Let them know you're coming")
                        .font(.coUI(14, weight: .medium))
                        .foregroundColor(.coInkSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .padding(.vertical, 8)
                .background(Color.coCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.coDivider, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    var hasContactEmail: Bool {
        guard let email = church.contactEmail else { return false }
        return !email.isEmpty
    }

    func openDirections(to address: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        guard let url = URL(string: "https://maps.apple.com/?q=\(encoded)") else { return }
        openURL(url)
    }

    func addToCalendar() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        pendingEvent = ChurchVisitEvent.makeEvent(
            store: eventStore,
            churchName: church.name,
            address: church.address,
            timeString: defaultTimeString,
            notes: church.serviceTimes
        )
        isCalendarSheetPresented = true
    }

    func letThemKnow() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        let churchID = church.id
        Task {
            await SupabaseService.shared.recordVisitIntent(churchID: churchID)
        }
        if hasContactEmail, let email = church.contactEmail {
            let subject = "We'd love to visit \(church.name)!"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let body = "Hi! We've been watching online and are planning to visit in person soon. Looking forward to it!"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "mailto:\(email)?subject=\(subject)&body=\(body)") {
                openURL(url)
            }
        }
        withAnimation(.easeOut(duration: 0.2)) {
            isIntentSent = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServiceDetailView(service: MockData.liveNow)
    }
}
