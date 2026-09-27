import SwiftUI

/// Silhouette paths normalized to the unit square (0...1 x 0...1).
enum SilhouetteShapes {
    static func path(for silhouette: BlobatarTraits.Silhouette, squash: Double = 0) -> Path {
        switch silhouette {
        case .blob: return blob(squash: squash)
        case .droplet: return droplet()
        case .bean: return bean()
        case .egg: return egg()
        case .pill: return pill()
        case .squish: return squish()
        case .cloud: return cloud()
        case .star: return star()
        case .hex: return hex()
        case .heart: return heart()
        }
    }

    // MARK: Building blocks

    private static func unitBlobPath(seeds: [Double], squash: Double) -> Path {
        // 4 control points on "rounded" positions, then smooth cubic joins.
        // seeds in 0...1 shift each anchor radially -> organic wobble.
        let cx = 0.5, cy = 0.5
        var anchors: [(x: Double, y: Double)] = []
        let base: [(angle: Double, r0: Double)] = [
            (-.pi / 2, 0.40 + seeds[0] * 0.10),
            (0, 0.36 + seeds[1] * 0.10),
            (.pi / 2, 0.40 + seeds[2] * 0.10),
            (.pi, 0.36 + seeds[3] * 0.10),
        ]
        for b in base {
            let r = b.r0
            anchors.append((cx + cos(b.angle) * r, cy + sin(b.angle) * r * (1.0 - squash * 0.25)))
        }
        let smooth: Double = 0.55
        var p = Path()
        p.move(to: CGPoint(x: anchors[0].x, y: anchors[0].y))
        for i in 0..<4 {
            let a = anchors[i]
            let n = anchors[(i + 1) % 4]
            let dx = n.x - a.x, dy = n.y - a.y
            let c1x = a.x + dx * smooth, c1y = a.y + dy * smooth
            let c2x = n.x - dx * smooth, c2y = n.y - dy * smooth
            p.curve(to: CGPoint(x: n.x, y: n.y),
                    control1: CGPoint(x: c1x, y: c1y),
                    control2: CGPoint(x: c2x, y: c2y))
        }
        p.closeSubpath()
        return p
    }

    // MARK: Silhouettes

    static func blob(squash: Double) -> Path {
        unitBlobPath(seeds: [0.4, 0.5, 0.4, 0.5], squash: squash)
    }

    static func droplet() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.5, y: 0.08))
        p.addCurve(
            to: CGPoint(x: 0.92, y: 0.72),
            control1: CGPoint(x: 0.85, y: 0.18),
            control2: CGPoint(x: 0.92, y: 0.48)
        )
        p.addArc(
            center: CGPoint(x: 0.5, y: 0.72),
            radius: 0.42,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        p.addCurve(
            to: CGPoint(x: 0.5, y: 0.08),
            control1: CGPoint(x: 0.08, y: 0.48),
            control2: CGPoint(x: 0.15, y: 0.18)
        )
        p.closeSubpath()
        return p
    }

    static func bean() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.08, y: 0.5))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.06), control1: CGPoint(x: 0.10, y: 0.22), control2: CGPoint(x: 0.28, y: 0.06))
        p.addCurve(to: CGPoint(x: 0.94, y: 0.52), control1: CGPoint(x: 0.76, y: 0.08), control2: CGPoint(x: 0.95, y: 0.30))
        p.addCurve(to: CGPoint(x: 0.52, y: 0.94), control1: CGPoint(x: 0.93, y: 0.76), control2: CGPoint(x: 0.74, y: 0.94))
        p.addCurve(to: CGPoint(x: 0.08, y: 0.5), control1: CGPoint(x: 0.26, y: 0.94), control2: CGPoint(x: 0.07, y: 0.78))
        p.closeSubpath()
        return p
    }

    static func egg() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.5, y: 0.05))
        p.addCurve(to: CGPoint(x: 0.95, y: 0.65), control1: CGPoint(x: 0.83, y: 0.12), control2: CGPoint(x: 0.95, y: 0.42))
        p.addArc(center: CGPoint(x: 0.5, y: 0.65), radius: 0.45, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: 0.5, y: 0.05), control1: CGPoint(x: 0.05, y: 0.42), control2: CGPoint(x: 0.17, y: 0.12))
        p.closeSubpath()
        return p
    }

    static func pill() -> Path {
        let r: CGFloat = 0.28
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 0.06, y: 0.24, width: 0.88, height: 0.52), cornerSize: CGSize(width: r, height: r), style: .continuous)
        return p
    }

    static func squish() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.04, y: 0.62))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.08), control1: CGPoint(x: 0.04, y: 0.28), control2: CGPoint(x: 0.26, y: 0.08))
        p.addCurve(to: CGPoint(x: 0.96, y: 0.62), control1: CGPoint(x: 0.74, y: 0.08), control2: CGPoint(x: 0.96, y: 0.28))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.96), control1: CGPoint(x: 0.96, y: 0.88), control2: CGPoint(x: 0.74, y: 0.96))
        p.addCurve(to: CGPoint(x: 0.04, y: 0.62), control1: CGPoint(x: 0.26, y: 0.96), control2: CGPoint(x: 0.04, y: 0.88))
        p.closeSubpath()
        return p
    }

    static func cloud() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.10, y: 0.72))
        p.addArc(center: CGPoint(x: 0.26, y: 0.72), radius: 0.16, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        p.addArc(center: CGPoint(x: 0.44, y: 0.58), radius: 0.18, startAngle: .degrees(200), endAngle: .degrees(-40), clockwise: true)
        p.addArc(center: CGPoint(x: 0.68, y: 0.52), radius: 0.20, startAngle: .degrees(210), endAngle: .degrees(-30), clockwise: true)
        p.addArc(center: CGPoint(x: 0.80, y: 0.70), radius: 0.16, startAngle: .degrees(240), endAngle: .degrees(0), clockwise: true)
        p.addLine(to: CGPoint(x: 0.96, y: 0.84))
        p.addLine(to: CGPoint(x: 0.10, y: 0.84))
        p.closeSubpath()
        return p
    }

    static func star() -> Path {
        var p = Path()
        let cx = 0.5, cy = 0.5
        let spikes = 5
        for i in 0..<(spikes * 2) {
            let angle = Double(i) / Double(spikes * 2) * 2 * .pi - .pi / 2
            let r = i % 2 == 0 ? 0.46 : 0.20
            let x = cx + cos(angle) * r
            let y = cy + sin(angle) * r
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }

    static func hex() -> Path {
        var p = Path()
        let cx = 0.5, cy = 0.5
        for i in 0..<6 {
            let angle = Double(i) / 6 * 2 * .pi - .pi / 2
            let x = cx + cos(angle) * 0.44
            let y = cy + sin(angle) * 0.44
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }

    static func heart() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.5, y: 0.96))
        p.addCurve(to: CGPoint(x: 0.06, y: 0.42), control1: CGPoint(x: 0.10, y: 0.78), control2: CGPoint(x: 0.06, y: 0.58))
        p.addArc(center: CGPoint(x: 0.26, y: 0.30), radius: 0.21, startAngle: .degrees(180), endAngle: .degrees(300), clockwise: true)
        p.addArc(center: CGPoint(x: 0.74, y: 0.30), radius: 0.21, startAngle: .degrees(240), endAngle: .degrees(0), clockwise: true)
        p.addCurve(to: CGPoint(x: 0.5, y: 0.96), control1: CGPoint(x: 0.94, y: 0.58), control2: CGPoint(x: 0.90, y: 0.78))
        p.closeSubpath()
        return p
    }
}