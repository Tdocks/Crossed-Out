import SwiftUI
import UIKit

/// Cross the Bridge home: a warm explanation of what a Bridge is, the
/// entry into the real composer, and "Your Bridges" — every package the
/// user has sent, its status (sent / opened / responded / declined), and
/// the recipient's responses. Fully live (migration 0031); the old mock
/// stub (MockData.bridgeShare + VersePickerStub) is gone.
struct BridgeShareView: View {
    var isModal: Bool = false

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var bridges: [SentBridge] = []
    @State private var loading = true
    @State private var loadFailed = false
    @State private var showComposer = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.coPaper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    bridgeVisual
                    COPrimaryButton(title: "Build a Bridge") {
                        showComposer = true
                    }
                    yourBridgesSection
                }
                .padding(.horizontal, 22)
                .padding(.top, isModal ? 52 : 16)
                .padding(.bottom, 100)
            }
            .refreshable { await reload() }

            if isModal {
                dismissButton
            }
        }
        .navigationDestination(isPresented: $showComposer) {
            BridgeComposerView { await reload() }
                .environmentObject(appState)
        }
        .task { await reload() }
    }

    private func reload() async {
        do {
            bridges = try await SupabaseService.shared.listMyBridges()
            loadFailed = false
        } catch {
            loadFailed = true
        }
        loading = false
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Cross the Bridge")
                .font(.coDisplay(26, weight: .semibold))
                .foregroundColor(.coInk)
            Text("A personal package of hope for someone you love — a note, a verse, and a no-pressure way to respond. They just open a link.")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var bridgeVisual: some View {
        HStack {
            Spacer()
            BridgeMotif(width: 150)
            Spacer()
        }
    }

    // MARK: Your Bridges

    private var yourBridgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR BRIDGES")
                .font(.coUI(11, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(.coInkTertiary)

            if loading {
                COCard {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Checking your bridges…")
                            .font(.coUI(13))
                            .foregroundColor(.coInkTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if loadFailed {
                COCard {
                    HStack {
                        Text("Couldn't load your bridges.")
                            .font(.coUI(13))
                            .foregroundColor(.coInkSecondary)
                        Spacer()
                        Button {
                            loading = true
                            Task { await reload() }
                        } label: {
                            Text("Retry")
                                .font(.coUI(13, weight: .medium))
                                .foregroundColor(.coCrossRed)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if bridges.isEmpty {
                COCard {
                    Text("No bridges yet. When someone comes to mind — a friend grieving, questioning, or just far off — build them one.")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(bridges) { bridge in
                        bridgeCard(bridge)
                    }
                }
            }
        }
    }

    private func bridgeCard(_ bridge: SentBridge) -> some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("For \(bridge.toName)")
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                    Spacer()
                    statusChip(bridge)
                }
                HStack(spacing: 8) {
                    Text(bridge.verseRef)
                        .font(.coUI(12, weight: .medium))
                        .foregroundColor(.coCrossRed)
                    Text(SupabaseService.relativeTime(from: bridge.createdAt))
                        .font(.coUI(11))
                        .foregroundColor(.coInkTertiary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = BridgeConfig.link(token: bridge.token)
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        Text("Copy link")
                            .font(.coUI(12, weight: .medium))
                            .foregroundColor(.coOlive)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }

                let visibleResponses = bridge.responses.filter { $0.kind != "journey_day" }
                if !visibleResponses.isEmpty {
                    CODivider()
                    ForEach(visibleResponses) { response in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(response.kindLabel)
                                    .font(.coUI(12, weight: .semibold))
                                    .foregroundColor(response.kind == "decline" ? .coInkTertiary : .coOlive)
                                Spacer()
                                Text(SupabaseService.relativeTime(from: response.createdAt))
                                    .font(.coUI(11))
                                    .foregroundColor(.coInkTertiary)
                            }
                            if let text = response.message, !text.isEmpty {
                                Text(text)
                                    .font(.coUIItalic(13))
                                    .foregroundColor(.coInkSecondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    let journeyDays = bridge.responses.filter { $0.kind == "journey_day" }.count
                    if journeyDays > 0 {
                        Text("Seven Days of Hope: \(min(journeyDays, 7)) of 7 days walked")
                            .font(.coUI(12))
                            .foregroundColor(.coGold)
                    }
                }
            }
        }
    }

    private func statusChip(_ bridge: SentBridge) -> some View {
        let color: Color = {
            switch bridge.status {
            case "responded": return .coOlive
            case "opened": return .coGold
            case "declined": return .coInkTertiary
            default: return .coInkSecondary
            }
        }()
        return Text(bridge.statusLabel)
            .font(.coUI(11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Text("✕")
                .font(.coUI(15, weight: .medium))
                .foregroundColor(.coInkSecondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.coCard))
                .overlay(Circle().strokeBorder(Color.coDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack { BridgeShareView() }
        .environmentObject(AppState())
}
