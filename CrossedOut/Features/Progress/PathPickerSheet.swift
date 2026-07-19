import SwiftUI

/// Catalog of multi-day Paths from `journeys` (deterministic content).
struct PathPickerSheet: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var paths: [JourneyPath] = []
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Loading paths…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if failed {
                    VStack(spacing: 12) {
                        Text("Couldn't load paths.")
                            .font(.coUI(14))
                            .foregroundColor(.coInkSecondary)
                        Button("Retry") { Task { await load() } }
                            .font(.coUI(14, weight: .medium))
                            .foregroundColor(.coCrossRed)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            Text("Pick a short walk through Scripture. Finish days to feed your streak — and earn the Path Walker badge.")
                                .font(.coUI(13))
                                .foregroundColor(.coInkSecondary)
                                .lineSpacing(4)
                                .padding(.bottom, 4)

                            ForEach(paths) { path in
                                Button {
                                    onSelect(path.slug)
                                    dismiss()
                                } label: {
                                    COCard {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(path.title)
                                                .font(.coUI(16, weight: .semibold))
                                                .foregroundColor(.coInk)
                                            if let sub = path.subtitle, !sub.isEmpty {
                                                Text(sub)
                                                    .font(.coUI(13))
                                                    .foregroundColor(.coInkSecondary)
                                                    .lineSpacing(3)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Text("\(path.totalDays) days")
                                                .font(.coUI(12, weight: .medium))
                                                .foregroundColor(.coOlive)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(22)
                    }
                }
            }
            .background(Color.coPaper.ignoresSafeArea())
            .navigationTitle("Choose a Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        failed = false
        do {
            paths = try await SupabaseService.shared.listJourneyPaths()
            loading = false
        } catch {
            failed = true
            loading = false
        }
    }
}
