import SwiftUI
import Foundation

// MARK: - Attend

struct AttendView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAllServices = false

    /// Currently-live services (from the real feed; the hero + any extras).
    private var liveServices: [LiveService] {
        appState.services.filter { $0.isLive }
    }

    /// Unscheduled, not-yet-live services ("18m", "45m").
    private var startingSoonServices: [LiveService] {
        appState.services.filter { !$0.isLive && $0.time == nil }
    }

    /// Time-scheduled services (e.g. "9:00 AM").
    private var tomorrowServicesList: [LiveService] {
        appState.services.filter { !$0.isLive && $0.time != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coPaper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("Attend")
                            .font(.coDisplay(30, weight: .semibold))
                            .foregroundColor(.coInk)
                            .padding(.top, 8)

                        if appState.attendLoading {
                            loadingState
                        } else if appState.attendLoadFailed {
                            errorState
                        } else if appState.services.isEmpty {
                            COEmptyState(
                                icon: .attend,
                                title: "No services scheduled right now",
                                message: "Check back Sunday morning — or explore churches near you."
                            )
                        } else {
                            if !liveServices.isEmpty {
                                liveNowSection
                            }
                            if !startingSoonServices.isEmpty {
                                startingSoonSection
                            }
                            if !tomorrowServicesList.isEmpty {
                                tomorrowSection
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAllServices) {
                AllServicesSheet(services: appState.services)
            }
        }
    }

    // MARK: Loading / Error

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.coCrossRed)
            Text("Loading services…")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var errorState: some View {
        COEmptyState(
            icon: .attend,
            title: "Couldn't load services",
            message: "Check your connection and try again.",
            actionTitle: "Try Again",
            action: { Task { await appState.retryAttend() } }
        )
    }

    // MARK: Live Now

    private var liveNowSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "Live Now", actionTitle: "See all") {
                showAllServices = true
            }
            if let hero = liveServices.first {
                liveHeroCard(hero)
            }
            ForEach(Array(liveServices.dropFirst())) { service in
                ServiceRow(service: service, rightLabel: "Live")
            }
        }
    }

    private func liveHeroCard(_ service: LiveService) -> some View {
        NavigationLink {
            ServiceDetailView(service: service)
        } label: {
            COCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        COPlaceholderBlock(icon: .church, cornerRadius: 0, iconSize: 46)
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)
                        liveBadge
                            .padding(12)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(service.church.name)
                            .font(.coUI(16, weight: .semibold))
                            .foregroundColor(.coInk)
                        HStack {
                            Text(service.church.city)
                                .font(.coUI(12))
                                .foregroundColor(.coInkTertiary)
                            Spacer()
                            Text(viewerLabel(service.church.viewers))
                                .font(.coUI(11))
                                .foregroundColor(.coInkTertiary)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var liveBadge: some View {
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

    private func viewerLabel(_ viewers: Int?) -> String {
        guard let viewers else { return "" }
        if viewers >= 1000 {
            let thousands = Double(viewers) / 1000.0
            return String(format: "%.1fK watching", thousands)
        }
        return "\(viewers) watching"
    }

    // MARK: Starting Soon

    private var startingSoonSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            COSectionHeader(title: "Starting Soon")
                .padding(.bottom, 10)
            VStack(spacing: 0) {
                ForEach(Array(startingSoonServices.enumerated()), id: \.element.id) { index, service in
                    ServiceRow(service: service, rightLabel: service.startsIn)
                    if index < startingSoonServices.count - 1 {
                        CODivider()
                    }
                }
            }
        }
    }

    // MARK: Tomorrow Morning

    private var tomorrowSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            COSectionHeader(title: "Tomorrow Morning")
                .padding(.bottom, 10)
            VStack(spacing: 0) {
                ForEach(Array(tomorrowServicesList.enumerated()), id: \.element.id) { index, service in
                    ServiceRow(service: service, rightLabel: service.time ?? service.startsIn)
                    if index < tomorrowServicesList.count - 1 {
                        CODivider()
                    }
                }
            }
        }
    }
}

// MARK: - Service Row

fileprivate struct ServiceRow: View {
    let service: LiveService
    let rightLabel: String

    var body: some View {
        NavigationLink {
            ServiceDetailView(service: service)
        } label: {
            HStack(spacing: 12) {
                COPlaceholderBlock(icon: .church, cornerRadius: 10, iconSize: 18)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.church.name)
                        .font(.coUI(15, weight: .medium))
                        .foregroundColor(.coInk)
                    Text(service.church.city)
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                }
                Spacer()
                Text(rightLabel)
                    .font(.coUI(12))
                    .foregroundColor(.coInkSecondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder Block

fileprivate struct COPlaceholderBlock: View {
    var icon: COIconName
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.coPaperSecondary)
            .overlay(
                COIcon(icon, size: iconSize, color: .coInkSecondary)
                    .opacity(0.25)
            )
    }
}

// MARK: - All Services Sheet

private struct AllServicesSheet: View {
    let services: [LiveService]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coPaper.ignoresSafeArea()
                if services.isEmpty {
                    COEmptyState(
                        icon: .attend,
                        title: "No services right now",
                        message: "Check back Sunday morning — or explore churches near you."
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(services.enumerated()), id: \.element.id) { index, service in
                                ServiceRow(service: service, rightLabel: service.time ?? service.startsIn)
                                if index < services.count - 1 {
                                    CODivider()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("All Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AttendView()
        .environmentObject(AppState())
}
