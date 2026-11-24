import SwiftUI

/// The icon on a carol's card: a little Christmas tree whose lights twinkle one after another and
/// whose star softly glows. Still when Reduce Motion is on or Christmas effects are off.
struct FestiveCarolBadge: View {
    var size: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ambience = FestiveAmbience.shared

    private static let lights: [(x: Double, y: Double)] = [(13, 14.5), (19.5, 17), (10, 22), (16, 21.5), (22, 24), (12.5, 26.5), (19, 27)]
    private static let bulbs = [Color(hex: "FFD27A"), Color(hex: "FF6B5E"), Color(hex: "9CC8FF"), Color(hex: "F4F7FF")]

    var body: some View {
        let animate = !reduceMotion && ambience.level != .off
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !animate)) { timeline in
            Canvas { ctx, canvas in
                Self.draw(&ctx, size: canvas, t: animate ? timeline.date.timeIntervalSinceReferenceDate : 0.8)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let u = size.width / 32
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * u, y: y * u) }

        // Trunk.
        ctx.fill(Path(roundedRect: CGRect(x: 13.5 * u, y: 27 * u, width: 5 * u, height: 4 * u), cornerRadius: 1 * u), with: .color(Color(hex: "7A4B2A")))

        // Three tiers, widest first so the upper ones overlap it.
        for (apexY, baseY, half, color) in [(15.0, 28.0, 12.0, "2A7048"), (10.5, 21.5, 9.5, "2F7D55"), (6.0, 15.0, 7.0, "3A8F63")] {
            var tier = Path()
            tier.move(to: p(16, apexY)); tier.addLine(to: p(16 + half, baseY)); tier.addLine(to: p(16 - half, baseY)); tier.closeSubpath()
            ctx.fill(tier, with: .color(Color(hex: color)))
        }

        // Lights, each on its own beat.
        for (i, light) in lights.enumerated() {
            let glow = 0.5 + 0.5 * sin(t * 2.6 + Double(i) * 1.7)
            let color = bulbs[i % bulbs.count]
            let c = p(light.x, light.y)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3 * u, y: c.y - 3 * u, width: 6 * u, height: 6 * u)), with: .color(color.opacity(0.22 * glow)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 1.5 * u, y: c.y - 1.5 * u, width: 3 * u, height: 3 * u)), with: .color(color.opacity(0.45 + 0.55 * glow)))
        }

        // Star, pulsing gently.
        let pulse = 1 + 0.12 * sin(t * 2.4)
        let center = p(16, 5.2)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - 5 * u, y: center.y - 5 * u, width: 10 * u, height: 10 * u)),
                 with: .color(Color(hex: "FFD27A").opacity(0.25 + 0.2 * (0.5 + 0.5 * sin(t * 2.4)))))
        var star = Path()
        for i in 0..<10 {
            let angle = -Double.pi / 2 + Double(i) * .pi / 5
            let radius = (i % 2 == 0 ? 3.6 : 1.5) * u * pulse
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(Color(hex: "FFE08A")))
    }
}
