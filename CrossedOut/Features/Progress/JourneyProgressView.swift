import SwiftUI
import UIKit

struct JourneyProgressView: View {
    @State private var workingThrough: [WorkingItem] = MockData.streak.workingThrough

    private let streak = MockData.streak
    private let weekRhythm: [CGFloat] = [0.35, 0.55, 0.9, 0.5, 1.0, 0.7, 0.3]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Your Journey")
                    .font(.coDisplay(28, weight: .semibold))
                    .foregroundColor(.coInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                streakHero

                StreakWeekRow(states: streak.weekStates)

                graceDaysCard

                workingThroughSection

                thisWeekCard

                Text("Your progress is still here. Today is another opportunity.")
                    .font(.coUIItalic(12))
                    .foregroundColor(.coInkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 90)
        }
        .background(Color.coPaper.ignoresSafeArea())
    }

    private var streakHero: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                COIcon(.flame, size: 20, color: .coCrossRed)
                Text("\(streak.current)")
                    .font(.coDisplay(40, weight: .semibold))
                    .foregroundColor(.coInk)
            }
            Text("Day Streak")
                .font(.coUI(13))
                .foregroundColor(.coInkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var graceDaysCard: some View {
        COCard {
            HStack(spacing: 14) {
                COIcon(.leaf, size: 22, color: .coOlive)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grace Days")
                        .font(.coUI(15, weight: .semibold))
                        .foregroundColor(.coInk)
                    Text("\(streak.graceUsed) of \(streak.graceTotal) this month")
                        .font(.coUI(13))
                        .foregroundColor(.coInkSecondary)
                }
                Spacer()
                COIcon(.chevronRight, size: 14, color: .coInkTertiary)
            }
        }
    }

    private var workingThroughSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            COSectionHeader(title: "What you're working through")

            VStack(spacing: 0) {
                ForEach(Array(workingThrough.enumerated()), id: \.element.id) { index, item in
                    workingRow(index: index, item: item)
                    if index < workingThrough.count - 1 { CODivider() }
                }
            }
            .padding(.horizontal, 4)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )
            .coShadow(cornerRadius: 14)
        }
    }

    private func workingRow(index: Int, item: WorkingItem) -> some View {
        HStack(spacing: 12) {
            CrossOutText(item.text, crossed: item.crossed)
            Spacer()
            if !item.crossed {
                COIcon(.checkCircle, size: 18, color: .coInkTertiary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { crossOut(index) }
    }

    private func crossOut(_ index: Int) {
        guard workingThrough.indices.contains(index), !workingThrough[index].crossed else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.easeOut(duration: 0.35)) {
            workingThrough[index].crossed = true
        }
    }

    private var thisWeekCard: some View {
        COCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("This Week")
                        .font(.coUI(11, weight: .medium))
                        .foregroundColor(.coInkTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text("\(streak.weekWithGodDays)/\(streak.weekWithGodTotal) Days with God")
                        .font(.coUI(14, weight: .semibold))
                        .foregroundColor(.coInk)
                }
                Spacer()
                RhythmBars(values: weekRhythm)
            }
        }
    }
}

#Preview {
    JourneyProgressView()
}
