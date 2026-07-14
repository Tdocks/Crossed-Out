import SwiftUI

// MARK: - Streak Day State

enum StreakDayState: String, Codable, Hashable {
    case done, grace, missed, today, future
}

// MARK: - Buttons

struct COPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.coUI(16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.coCrossRed)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct COSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.coUI(15, weight: .medium))
                .foregroundColor(.coInkSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card

struct COCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.coCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.coDivider, lineWidth: 1)
            )
            .coShadow(cornerRadius: 14)
    }
}

// MARK: - Chip

struct COChip: View {
    let text: String
    var selected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.coUI(14, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? .coCrossRed : .coInkSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(selected ? Color.coCrossRed.opacity(0.08) : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.coCrossRed : Color.coDivider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header & Divider

struct COSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.coDisplay(20, weight: .semibold))
                .foregroundColor(.coInk)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.coUI(13, weight: .semibold))
                        .foregroundColor(.coCrossRed)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CODivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.coDivider)
            .frame(height: 1)
    }
}

// MARK: - Avatar

struct COAvatar: View {
    let initials: String
    var size: CGFloat = 40

    var body: some View {
        Text(initials)
            .font(.coUI(size * 0.38, weight: .medium))
            .foregroundColor(.coInkSecondary)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.coPaperSecondary))
            .overlay(Circle().strokeBorder(Color.coDivider, lineWidth: 1))
    }
}

// MARK: - Progress Bar

struct COProgressBar: View {
    let value: Double
    var tint: Color = .coCrossRed

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.coDivider)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .animation(.easeOut(duration: 0.5), value: value)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Rhythm Bars

struct RhythmBars: View {
    let values: [CGFloat]

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, v in
                Capsule()
                    .fill(index == values.count - 1 ? Color.coCrossRed : Color.coGold)
                    .frame(width: 3, height: max(4, v * 32))
                    .opacity(0.85)
            }
        }
        .frame(height: 34, alignment: .bottom)
    }
}

// MARK: - Streak Week Row

struct StreakWeekRow: View {
    let states: [StreakDayState]
    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 8) {
                    Text(labels[i])
                        .font(.coUI(11, weight: .medium))
                        .foregroundColor(.coInkTertiary)
                    dayCircle(states.indices.contains(i) ? states[i] : .future)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCircle(_ state: StreakDayState) -> some View {
        ZStack {
            switch state {
            case .done:
                Circle().fill(Color.coCrossRed)
                COCheckShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 11, height: 11)
            case .grace:
                Circle().fill(Color.coOlive.opacity(0.12))
                Circle().strokeBorder(Color.coOlive, lineWidth: 1.4)
                COIcon(.leaf, size: 12, color: .coOlive)
            case .today:
                Circle().strokeBorder(Color.coCrossRed, lineWidth: 1.6)
            case .missed:
                Circle().strokeBorder(Color.coDivider, lineWidth: 1.4)
                    .overlay(Circle().fill(Color.coDivider.opacity(0.35)))
            case .future:
                Circle().strokeBorder(Color.coDivider, lineWidth: 1.4)
            }
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Small Check Shape

struct COCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.maxY - rect.height * 0.18))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.2))
        return p
    }
}

// MARK: - CrossOutText

/// Renders text with an organic hand-drawn red strike that trims in when crossed.
struct CrossOutText: View {
    let text: String
    let crossed: Bool

    init(_ text: String, crossed: Bool) {
        self.text = text
        self.crossed = crossed
    }

    var body: some View {
        Text(text)
            .font(.coUI(15))
            .foregroundColor(crossed ? .coInkTertiary : .coInk)
            .animation(.easeOut(duration: 0.35), value: crossed)
            .overlay(
                GeometryReader { geo in
                    StrikeLine()
                        .trim(from: 0, to: crossed ? 1 : 0)
                        .stroke(Color.coCrossRed,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .rotationEffect(.degrees(-1.5))
                        .animation(.easeOut(duration: 0.35), value: crossed)
                }
            )
    }
}

/// A very slightly curved strike line across the text bounds.
struct StrikeLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX + 1, y: y + 1.5))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - 1, y: y - 1),
            control: CGPoint(x: rect.midX, y: y - 3)
        )
        return p
    }
}

// MARK: - Brand Wordmark

/// Stacked CROSSED / OUT wordmark with a tapered red brush strike through OUT
/// and a small red cross mark to the left.
struct COBrandWordmark: View {
    var size: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.02) {
            Text("CROSSED")
                .font(.coDisplay(size, weight: .bold))
                .tracking(size * 0.14)
                .foregroundColor(.coInk)
            HStack(spacing: size * 0.22) {
                COCrossMark()
                    .stroke(Color.coCrossRed,
                            style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                    .frame(width: size * 0.42, height: size * 0.42)
                Text("OUT")
                    .font(.coDisplay(size, weight: .bold))
                    .tracking(size * 0.14)
                    .foregroundColor(.coInk)
                    .overlay(brushStrike)
            }
        }
        .fixedSize()
    }

    private var brushStrike: some View {
        GeometryReader { geo in
            ZStack {
                Capsule()
                    .fill(Color.coCrossRed.opacity(0.9))
                    .frame(width: geo.size.width * 1.18, height: size * 0.13)
                Capsule()
                    .fill(Color.coCrossRed.opacity(0.6))
                    .frame(width: geo.size.width * 1.05, height: size * 0.08)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .rotationEffect(.degrees(-4))
        }
    }
}

/// A small hand-drawn cross (plus with slightly offset arms).
struct COCrossMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.08))
        return p
    }
}

// MARK: - Bridge Motif

/// A thin monoline arc connecting two small circles. Used in Bridge Share.
struct BridgeMotif: View {
    var width: CGFloat = 140

    var body: some View {
        Canvas { context, size in
            let r: CGFloat = 4
            let leftC = CGPoint(x: r + 1, y: size.height - r - 1)
            let rightC = CGPoint(x: size.width - r - 1, y: size.height - r - 1)

            var arc = Path()
            arc.move(to: CGPoint(x: leftC.x, y: leftC.y))
            arc.addQuadCurve(
                to: CGPoint(x: rightC.x, y: rightC.y),
                control: CGPoint(x: size.width / 2, y: 2)
            )
            context.stroke(arc, with: .color(.coInkTertiary),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

            for c in [leftC, rightC] {
                let dot = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                context.fill(dot, with: .color(.coCard))
                context.stroke(dot, with: .color(.coInkSecondary), lineWidth: 1.4)
            }
        }
        .frame(width: width, height: width * 0.42)
    }
}
