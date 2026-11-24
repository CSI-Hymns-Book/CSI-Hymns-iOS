import SwiftUI

/// Santa's sleigh with four reindeer. White reindeer and sleigh with a gold rim and a warm glow so
/// they stand out against the night sky; Santa wears a red coat and hat. In daylight the outline is
/// navy instead so white still shows on a pale background.
enum FestiveSantaDrawing {
    private static let red = Color(hex: "D6493D")
    private static let cream = Color(hex: "FFF8EA")
    private static let gold = Color(hex: "FFDE9A")
    private static let dayRim = Color(hex: "33405F")
    private static let nose = Color(hex: "FF3B30")

    static func draw(in ctx: inout GraphicsContext, pose: SantaPose, time: Double, night: Bool, alpha: Double, unit u: Double) {
        let fill = (night ? cream : Color.white).opacity(alpha)
        let rim = (night ? gold : dayRim).opacity(alpha)
        let x = pose.x, y = pose.y

        // Warm glow behind the team, squashed to fit its shape.
        let glowCenter = CGPoint(x: x + 66 * u, y: y - 3 * u)
        let glowColor = night ? Color(hex: "FFCB6B") : Color.white
        let strength = (night ? 0.30 : 0.55) * alpha
        var glowCtx = ctx
        glowCtx.translateBy(x: glowCenter.x, y: glowCenter.y)
        glowCtx.scaleBy(x: 1, y: 0.42)
        let r = 100 * u
        glowCtx.fill(
            Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
            with: .radialGradient(Gradient(colors: [glowColor.opacity(strength), glowColor.opacity(strength * 0.35), .clear]),
                                  center: .zero, startRadius: 0, endRadius: r)
        )

        var reins = Path()
        reins.move(to: CGPoint(x: x + 16 * u, y: y - 9 * u))
        reins.addLine(to: CGPoint(x: x + 112 * u, y: y + (-4 + sin(time * 8 + 3) * 1.2) * u))
        ctx.stroke(reins, with: .color(rim), lineWidth: 1.1 * u)

        for i in 0..<4 {
            let bob = sin(time * 8 + Double(i)) * 1.4
            drawReindeer(&ctx, x: x + (40 + Double(i) * 24) * u, y: y + (-2 + bob) * u, time: time, index: i, lead: i == 3, fill: fill, rim: rim, alpha: alpha, u: u)
        }
        drawSleigh(&ctx, x: x, y: y, time: time, fill: fill, rim: rim, alpha: alpha, u: u)
    }

    private static func drawReindeer(_ ctx: inout GraphicsContext, x rx: Double, y ry: Double, time t: Double, index: Int, lead: Bool,
                                     fill: Color, rim: Color, alpha: Double, u: Double) {
        func p(_ dx: Double, _ dy: Double) -> CGPoint { CGPoint(x: rx + dx * u, y: ry + dy * u) }
        let gallop = sin(t * 12 + Double(index) * 1.3) * 3 * u
        for (dx, sign) in [(4.0, 1.0), (-5.0, -1.0)] {
            var leg = Path()
            leg.move(to: p(dx, 2))
            leg.addLine(to: CGPoint(x: rx + (dx + sign) * u + gallop * sign, y: ry + 8 * u))
            ctx.stroke(leg, with: .color(fill), style: StrokeStyle(lineWidth: 1.3 * u, lineCap: .round))
        }
        let body = Path(ellipseIn: CGRect(x: rx - 8 * u, y: ry - 3.3 * u, width: 16 * u, height: 6.6 * u))
        ctx.fill(body, with: .color(fill))
        ctx.stroke(body, with: .color(rim), lineWidth: 1.2 * u)
        var neck = Path(); neck.move(to: p(6, -1)); neck.addLine(to: p(9, -6))
        ctx.stroke(neck, with: .color(fill), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: rx + 7.7 * u, y: ry - 8.3 * u, width: 5.6 * u, height: 3.6 * u)), with: .color(fill))
        for (from, to) in [((9.0, -8.0), (7.0, -13.0)), ((8.0, -11.0), (5.5, -11.5)), ((10.5, -8.0), (12.0, -13.0))] {
            var antler = Path(); antler.move(to: p(from.0, from.1)); antler.addLine(to: p(to.0, to.1))
            ctx.stroke(antler, with: .color(rim), style: StrokeStyle(lineWidth: 1 * u, lineCap: .round))
        }
        if lead {
            let c = p(13.4, -6.6)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 6 * u, y: c.y - 6 * u, width: 12 * u, height: 12 * u)), with: .color(nose.opacity(0.45 * alpha)))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 1.5 * u, y: c.y - 1.5 * u, width: 3 * u, height: 3 * u)), with: .color(nose.opacity(alpha)))
        }
    }

    private static func drawSleigh(_ ctx: inout GraphicsContext, x: Double, y: Double, time t: Double,
                                   fill: Color, rim: Color, alpha: Double, u: Double) {
        func p(_ dx: Double, _ dy: Double) -> CGPoint { CGPoint(x: x + dx * u, y: y + dy * u) }
        func circle(_ dx: Double, _ dy: Double, _ r: Double) -> Path {
            Path(ellipseIn: CGRect(x: x + (dx - r) * u, y: y + (dy - r) * u, width: 2 * r * u, height: 2 * r * u))
        }
        let coat = red.opacity(alpha)
        ctx.fill(circle(-11, -10, 5.5), with: .color(coat))
        ctx.stroke(circle(-11, -10, 5.5), with: .color(rim), lineWidth: 1.4 * u)
        ctx.fill(circle(-3, -10, 5), with: .color(coat))
        ctx.fill(circle(-2, -17, 3), with: .color(fill))
        var hat = Path(); hat.move(to: p(-5, -18.5)); hat.addLine(to: p(1, -18.5)); hat.addLine(to: p(-6, -25)); hat.closeSubpath()
        ctx.fill(hat, with: .color(coat))
        ctx.fill(circle(-6.2, -25, 1.3), with: .color(Color.white.opacity(alpha)))
        let wave = -1.9 + sin(t * 7) * 0.35
        var arm = Path(); arm.move(to: p(-1, -12))
        arm.addLine(to: CGPoint(x: x + (-1 + cos(wave) * 7) * u, y: y + (-12 + sin(wave) * 7) * u))
        ctx.stroke(arm, with: .color(coat), style: StrokeStyle(lineWidth: 1.8 * u, lineCap: .round))

        var body = Path()
        body.move(to: p(-15, -7)); body.addLine(to: p(10, -7))
        body.addQuadCurve(to: p(16, -13), control: p(16, -7)); body.addLine(to: p(19, -13))
        body.addQuadCurve(to: p(8, 2), control: p(19, 2)); body.addLine(to: p(-15, 2)); body.closeSubpath()
        ctx.fill(body, with: .color(fill))
        ctx.stroke(body, with: .color(rim), lineWidth: 1.4 * u)
        var runner = Path()
        runner.move(to: p(-17, 6)); runner.addLine(to: p(15, 6)); runner.addQuadCurve(to: p(20, 1), control: p(21, 6))
        ctx.stroke(runner, with: .color(rim), style: StrokeStyle(lineWidth: 1.9 * u, lineCap: .round))
        for dx in [-9.0, 6.0] {
            var strut = Path(); strut.move(to: p(dx, 2)); strut.addLine(to: p(dx, 6))
            ctx.stroke(strut, with: .color(rim), lineWidth: 0.9 * u)
        }
    }
}
