import SwiftUI

// MARK: - Icon Catalog

enum COIconName: String, CaseIterable {
    case crossOut, bridge, prayer, church, bible, community, journal, give
    case music, today, attend, more, heart, share, highlight, note, study
    case flame, leaf, play, search, bell, calendar, mapPin, checkCircle, chevronRight
}

// MARK: - Public API

/// A custom monoline icon. Hand-drawn feel, no fills, round caps, ~1.6 stroke.
struct COIcon: View {
    let name: COIconName
    var size: CGFloat = 22
    var color: Color = .coInkSecondary

    init(_ name: COIconName, size: CGFloat = 22, color: Color = .coInkSecondary) {
        self.name = name
        self.size = size
        self.color = color
    }

    var body: some View {
        COIconShape(name: name)
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

// MARK: - Shape

/// Draws each icon into a normalized 24x24 space scaled to the target rect.
struct COIconShape: Shape {
    let name: COIconName

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        let ox = rect.minX + (rect.width - 24 * s) / 2
        let oy = rect.minY + (rect.height - 24 * s) / 2
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * s, y: oy + y * s)
        }
        var path = Path()
        draw(name, into: &path, P: P, s: s)
        return path
    }
}

// MARK: - Drawing

extension COIconShape {
    fileprivate func draw(_ name: COIconName, into path: inout Path,
                          P: (CGFloat, CGFloat) -> CGPoint, s: CGFloat) {
        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            path.move(to: P(a.0, a.1)); path.addLine(to: P(b.0, b.1))
        }
        func poly(_ pts: [(CGFloat, CGFloat)], closed: Bool = false) {
            guard let f = pts.first else { return }
            path.move(to: P(f.0, f.1))
            for p in pts.dropFirst() { path.addLine(to: P(p.0, p.1)) }
            if closed { path.closeSubpath() }
        }
        func quad(_ a: (CGFloat, CGFloat), _ c: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            path.move(to: P(a.0, a.1))
            path.addQuadCurve(to: P(b.0, b.1), control: P(c.0, c.1))
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            let c = P(cx, cy)
            path.addEllipse(in: CGRect(x: c.x - r * s, y: c.y - r * s,
                                       width: r * 2 * s, height: r * 2 * s))
        }
        func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat,
                 _ start: CGFloat, _ end: CGFloat) {
            let c = P(cx, cy)
            path.addArc(center: c, radius: r * s,
                        startAngle: .degrees(start), endAngle: .degrees(end),
                        clockwise: false)
        }

        switch name {
        case .crossOut:
            // Hand-drawn X over a short horizontal line.
            line((7, 6), (17, 15))
            line((17, 6), (7, 15))
            line((6, 19), (18, 19))

        case .bridge:
            // Suspension arch with two towers and a deck.
            quad((3, 15), (12, 4), (21, 15))
            line((3, 17), (21, 17))
            line((7, 8.6), (7, 17))
            line((17, 8.6), (17, 17))

        case .prayer:
            // Simplified praying hands meeting at a peak.
            quad((12, 3), (8, 9), (7, 20))
            quad((12, 3), (16, 9), (17, 20))
            line((7, 20), (17, 20))
            line((12, 5), (12, 18))

        case .church:
            // Chapel body, gable roof, rooftop cross.
            poly([(6, 12), (12, 7), (18, 12)])
            poly([(7.5, 12), (7.5, 20), (16.5, 20), (16.5, 12)])
            line((12, 7), (12, 2.5))
            line((10.2, 4), (13.8, 4))
            line((10.5, 20), (10.5, 16)); line((13.5, 20), (13.5, 16))
            line((10.5, 16), (13.5, 16))

        case .bible:
            // Open book, two curved pages around a spine.
            line((12, 6), (12, 19))
            quad((12, 6), (7, 5), (4, 7))
            line((4, 7), (4, 18))
            quad((4, 18), (7, 17), (12, 19))
            quad((12, 6), (17, 5), (20, 7))
            line((20, 7), (20, 18))
            quad((20, 18), (17, 17), (12, 19))

        case .community:
            // Three abstract heads with shoulder arcs.
            circle(12, 7, 2.4)
            arc(12, 20, 4.2, 200, 340)
            circle(5.5, 9, 1.9)
            arc(5.5, 20, 3.4, 205, 335)
            circle(18.5, 9, 1.9)
            arc(18.5, 20, 3.4, 205, 335)

        case .journal:
            // Page with ruled lines and a diagonal pen.
            poly([(6, 4), (15, 4), (15, 20), (6, 20)], closed: true)
            line((8, 9), (13, 9))
            line((8, 12), (13, 12))
            line((16.5, 6), (20, 9.5))
            line((16.5, 6), (14.5, 8)); line((14.5, 8), (18, 11.5)); line((18, 11.5), (20, 9.5))

        case .give:
            // Small heart resting in an open hand.
            quad((12, 6.5), (9.5, 3.5), (8, 6)); quad((8, 6), (8, 8.5), (12, 11))
            quad((12, 11), (16, 8.5), (16, 6)); quad((16, 6), (14.5, 3.5), (12, 6.5))
            quad((4, 15), (12, 21), (20, 15))

        case .music:
            // Quarter note.
            line((10, 5), (10, 17))
            quad((10, 5), (15, 5), (16, 8))
            circle(7.7, 17, 2.3)

        case .today:
            // Rising sun over a horizon with rays.
            arc(12, 15, 4.2, 180, 360)
            line((3, 15), (21, 15))
            line((12, 6.5), (12, 4)); line((6, 9), (4.3, 7.3)); line((18, 9), (19.7, 7.3))

        case .attend:
            // Arched chapel door.
            quad((7, 10), (12, 4), (17, 10))
            line((7, 10), (7, 20)); line((17, 10), (17, 20))
            line((7, 20), (17, 20))
            circle(14, 14, 0.7)

        case .more:
            // Three staggered horizontal lines.
            line((5, 8), (17, 8))
            line((7, 12), (19, 12))
            line((5, 16), (15, 16))

        case .heart:
            quad((12, 8), (9, 4.5), (6.5, 6.5)); quad((6.5, 6.5), (4, 9), (7, 13))
            line((7, 13), (12, 18)); line((12, 18), (17, 13))
            quad((17, 13), (20, 9), (17.5, 6.5)); quad((17.5, 6.5), (15, 4.5), (12, 8))

        case .share:
            // Arrow rising out of an open box.
            poly([(9, 12), (5, 12), (5, 20), (19, 20), (19, 12), (15, 12)])
            line((12, 4), (12, 14))
            poly([(8.5, 7.5), (12, 4), (15.5, 7.5)])

        case .highlight:
            // Marker tip drawing a line.
            poly([(14, 5), (19, 10), (11, 18), (7, 18), (6, 14)], closed: false)
            line((6, 14), (14, 5))
            line((5, 21), (12, 21))

        case .note:
            // Pencil.
            poly([(5, 19), (5.5, 15.5), (16, 5), (19, 8), (8.5, 18.5), (5, 19)], closed: true)
            line((14, 7), (17, 10))

        case .study:
            // Magnifier over a book.
            poly([(4, 7), (10, 7), (10, 17), (4, 17)], closed: true)
            line((4, 7), (4, 17))
            circle(15, 12, 3.4)
            line((17.6, 14.6), (20, 17))

        case .flame:
            // Streak flame.
            quad((12, 3), (7, 9), (8, 14))
            quad((8, 14), (8.5, 19), (12, 20)); quad((12, 20), (16, 19), (16, 14))
            quad((16, 14), (16, 10), (13, 8)); quad((13, 8), (13.5, 12), (11, 12))
            quad((11, 12), (10, 9), (12, 3))

        case .leaf:
            // Grace-day leaf with a vein.
            quad((5, 19), (5, 6), (19, 5)); quad((19, 5), (18, 18), (5, 19))
            line((5, 19), (16, 8))

        case .play:
            // Triangle in a circle.
            circle(12, 12, 9)
            poly([(10, 8), (16, 12), (10, 16)], closed: true)

        case .search:
            circle(11, 11, 6)
            line((15.4, 15.4), (20, 20))

        case .bell:
            quad((6, 17), (6, 9), (12, 8)); quad((12, 8), (18, 9), (18, 17))
            line((5, 17), (19, 17))
            line((12, 5.5), (12, 8))
            arc(12, 18.5, 1.8, 0, 180)

        case .calendar:
            poly([(4, 7), (20, 7), (20, 20), (4, 20)], closed: true)
            line((4, 11), (20, 11))
            line((8, 5), (8, 9)); line((16, 5), (16, 9))

        case .mapPin:
            quad((12, 21), (5, 12), (7, 8)); quad((7, 8), (12, 2), (17, 8))
            quad((17, 8), (19, 12), (12, 21))
            circle(12, 9, 2.3)

        case .checkCircle:
            circle(12, 12, 9)
            poly([(8, 12.2), (11, 15), (16, 9)])

        case .chevronRight:
            poly([(9, 5), (16, 12), (9, 19)])
        }
    }
}
