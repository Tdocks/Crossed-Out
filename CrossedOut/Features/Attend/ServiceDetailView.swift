import SwiftUI
import UIKit

// MARK: - Service Detail

struct ServiceDetailView: View {
    let service: LiveService

    @State private var isSaved = false
    @State private var showPlanVisit = false
    @State private var primaryLabel: String = ""
    @State private var isPrimaryBusy = false
    @State private var watchSource: WatchSource?
    @Environment(\.openURL) private var openURL

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
        .onAppear {
            if primaryLabel.isEmpty {
                primaryLabel = service.isLive ? "Watch Live" : "Set a Reminder"
            }
        }
        .task { await loadSavedState() }
        .sheet(isPresented: $showPlanVisit) {
            PlanVisitSheet()
        }
        .fullScreenCover(item: $watchSource) { source in
            WatchView(source: source, churchName: service.church.name)
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
            Text(service.isLive ? viewerLabel : service.startsIn)
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
            HStack(spacing: 12) {
                saveChurchButton
                planVisitButton
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
            showPlanVisit = true
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
        } else {
            // Non-live: lightweight reminder confirmation (real APNs scheduling TBD).
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
        if ch.platform == "youtube", let cid = ch.youtubeChannelId, !cid.isEmpty {
            watchSource = .youtube(channelId: cid)
        } else if ch.platform == "hls", let s = ch.hlsURL, let u = URL(string: s) {
            watchSource = .hls(url: u)
        } else if let w = ch.watchURL, let u = URL(string: w) {
            openURL(u)
        }
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
}

// MARK: - Plan a Visit Sheet

private struct PlanVisitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didRequest = false

    private let readinessRows = [
        "Casual dress is welcome",
        "Free parking on site",
        "Children's check-in at the door",
        "Someone can meet you at the door",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coPaper.ignoresSafeArea()
                VStack(spacing: 24) {
                    if didRequest {
                        successState
                    } else {
                        formState
                    }
                }
                .padding(20)
            }
            .navigationTitle("Plan a Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private extension PlanVisitSheet {
    var formState: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("From online to in person")
                    .font(.coDisplay(20, weight: .semibold))
                    .foregroundColor(.coInk)
                Text("A few things to expect when you make the visit.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(readinessRows, id: \.self) { row in
                    HStack(spacing: 10) {
                        COIcon(.checkCircle, size: 18, color: .coOlive)
                        Text(row)
                            .font(.coUI(14))
                            .foregroundColor(.coInk)
                    }
                }
            }
            Spacer()
            COPrimaryButton(title: "Request a Welcome") {
                requestWelcome()
            }
        }
    }

    var successState: some View {
        VStack(spacing: 14) {
            Spacer()
            COIcon(.checkCircle, size: 40, color: .coOlive)
            Text("We'll ask the church to look out for you.")
                .font(.coUI(15))
                .foregroundColor(.coInkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func requestWelcome() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            didRequest = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServiceDetailView(service: MockData.liveNow)
    }
}
