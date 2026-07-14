import SwiftUI
import Foundation

// MARK: - Attend

struct AttendView: View {
    var body: some View {
        ZStack {
            Color.coPaper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Attend")
                        .font(.coDisplay(30, weight: .semibold))
                        .foregroundColor(.coInk)
                        .padding(.top, 8)

                    liveNowSection
                    startingSoonSection
                    tomorrowSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 90)
            }
        }
    }

    // MARK: Live Now

    private var liveNowSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "Live Now", actionTitle: "See all") {}
            liveHeroCard
        }
    }

    private var liveHeroCard: some View {
        let service = MockData.liveNow
        return COCard(padding: 0) {
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
                ForEach(Array(MockData.startingSoon.enumerated()), id: \.element.id) { index, service in
                    ServiceRow(service: service, rightLabel: service.startsIn)
                    if index < MockData.startingSoon.count - 1 {
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
                ForEach(Array(MockData.tomorrowServices.enumerated()), id: \.element.id) { index, service in
                    ServiceRow(service: service, rightLabel: service.time ?? service.startsIn)
                    if index < MockData.tomorrowServices.count - 1 {
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

// MARK: - Preview

#Preview {
    AttendView()
}
