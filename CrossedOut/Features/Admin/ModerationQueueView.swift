import SwiftUI

/// System-admin moderation queue (migration 0029): every open content
/// report, with the offending content inline, and three real actions —
/// Dismiss (report only), Hide, and Remove (both change the content's
/// visibility and close every open report against it). This is how the app
/// meets Apple's UGC requirement of acting on reports within ~24 hours.
struct ModerationQueueView: View {
    @State private var reports: [SupabaseService.ModerationReport] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var actingOn: UUID?
    @State private var errorMessage: String?
    @State private var confirmRemove: SupabaseService.ModerationReport?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Moderation")
                    .font(.coDisplay(28, weight: .semibold))
                    .foregroundColor(.coInk)
                    .padding(.top, 8)

                Text("Open reports, newest first. Hide or Remove takes the content out of every feed immediately and closes all open reports against it.")
                    .font(.coUI(13))
                    .foregroundColor(.coInkSecondary)
                    .lineSpacing(3)

                if isLoading {
                    COCard {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading reports…")
                                .font(.coUI(13))
                                .foregroundColor(.coInkTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if loadFailed {
                    COCard {
                        HStack {
                            Text("Couldn't load the queue.")
                                .font(.coUI(14))
                                .foregroundColor(.coInkSecondary)
                            Spacer()
                            Button { reload() } label: {
                                Text("Retry")
                                    .font(.coUI(13, weight: .medium))
                                    .foregroundColor(.coCrossRed)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if reports.isEmpty {
                    COCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Queue clear.")
                                .font(.coUI(15, weight: .semibold))
                                .foregroundColor(.coInk)
                            Text("No open reports. Well kept.")
                                .font(.coUI(13))
                                .foregroundColor(.coInkSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(reports) { report in
                        reportCard(report)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.coUI(12))
                        .foregroundColor(.coCrossRed)
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 22)
        }
        .background(Color.coPaper.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog(
            "Remove this content permanently? It disappears from every feed and all its open reports close.",
            isPresented: Binding(
                get: { confirmRemove != nil },
                set: { if !$0 { confirmRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Content", role: .destructive) {
                if let report = confirmRemove { act(on: report, action: "remove") }
                confirmRemove = nil
            }
            Button("Cancel", role: .cancel) { confirmRemove = nil }
        }
    }

    // MARK: Report card

    private func reportCard(_ report: SupabaseService.ModerationReport) -> some View {
        COCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(report.reason.uppercased())
                        .font(.coUI(11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(.coCrossRed)
                    if report.reportCount > 1 {
                        Text("×\(report.reportCount)")
                            .font(.coUI(11, weight: .semibold))
                            .foregroundColor(.coCrossRed)
                    }
                    Spacer()
                    Text(kindLabel(report.contentKind))
                        .font(.coUI(11))
                        .foregroundColor(.coInkTertiary)
                }

                if let author = report.authorName {
                    Text(author)
                        .font(.coUI(14, weight: .semibold))
                        .foregroundColor(.coInk)
                }

                if let text = report.contentText, !text.isEmpty {
                    Text(text)
                        .font(.coUI(14))
                        .foregroundColor(.coInkSecondary)
                        .lineSpacing(4)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Content unavailable (already deleted).")
                        .font(.coUIItalic(13))
                        .foregroundColor(.coInkTertiary)
                }

                if let detail = report.detail, !detail.isEmpty {
                    Text("Reporter's note: \(detail)")
                        .font(.coUI(12))
                        .foregroundColor(.coInkTertiary)
                }

                Text(SupabaseService.relativeTime(from: report.createdAt))
                    .font(.coUI(11))
                    .foregroundColor(.coInkTertiary)

                CODivider()

                HStack(spacing: 10) {
                    actionButton("Dismiss", tint: .coInkSecondary, filled: false, report: report) {
                        act(on: report, action: "dismiss")
                    }
                    actionButton("Hide", tint: .coGold, filled: false, report: report) {
                        act(on: report, action: "hide")
                    }
                    actionButton("Remove", tint: .coCrossRed, filled: true, report: report) {
                        confirmRemove = report
                    }
                    Spacer()
                    if actingOn == report.id {
                        ProgressView()
                    }
                }
            }
        }
    }

    private func actionButton(_ title: String, tint: Color, filled: Bool,
                              report: SupabaseService.ModerationReport,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.coUI(13, weight: .semibold))
                .foregroundColor(filled ? .white : tint)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(Capsule().fill(filled ? tint : Color.clear))
                .overlay(Capsule().strokeBorder(tint, lineWidth: filled ? 0 : 1))
        }
        .buttonStyle(.plain)
        .disabled(actingOn != nil)
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "prayer_request": return "Prayer request"
        case "community_post": return "Community post"
        default: return "Other"
        }
    }

    // MARK: Actions

    private func load() async {
        loadFailed = false
        do {
            reports = try await SupabaseService.shared.adminListOpenReports()
        } catch {
            loadFailed = true
        }
        isLoading = false
    }

    private func reload() {
        isLoading = true
        Task { await load() }
    }

    private func act(on report: SupabaseService.ModerationReport, action: String) {
        guard actingOn == nil else { return }
        actingOn = report.id
        errorMessage = nil
        Task {
            do {
                try await SupabaseService.shared.adminResolveReport(reportID: report.id, action: action)
                await load()
            } catch {
                errorMessage = "That action didn't go through. Try again."
            }
            actingOn = nil
        }
    }
}

#Preview {
    NavigationStack { ModerationQueueView() }
}
