import SwiftUI

/// A pine garland strung across the top of the home scene in gentle swags, with twinkling bulbs,
/// red bows at the pins, and the gold bell hanging from one pin, so the bell hangs from something
/// instead of floating in the sky.
struct FestiveGarland: View {
    /// Where the bell hangs, as a fraction of the width.
    var bellFraction: CGFloat = 0.86
    /// Extra string above the bell, so it can hang from the very top edge past the status bar.
    var bellDrop: CGFloat = 0
    let animate: Bool
    let onRing: (CGPoint) -> Void

    static let height: CGFloat = 34
    private static let pinY: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pins = Self.pins(width: width, bellFraction: bellFraction)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in GarlandDrawing.drawGarland(&ctx, pins: pins) }
                    .frame(height: Self.height)
                    .allowsHitTesting(false)
                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !animate)) { timeline in
                    Canvas { ctx, _ in
                        let t = animate ? timeline.date.timeIntervalSinceReferenceDate : 0
                        GarlandDrawing.drawBulbs(&ctx, pins: pins, t: t)
                    }
                }
                .frame(height: Self.height)
                .allowsHitTesting(false)
                FestiveHangingBell(extraString: bellDrop, onRing: onRing)
                    .position(x: width * bellFraction, y: Self.pinY + (92 + bellDrop) / 2)
                ForEach(Array(pins.enumerated()), id: \.offset) { _, pin in
                    GarlandBow().position(pin)
                }
            }
        }
        .frame(height: Self.pinY + 92 + bellDrop)
        .accessibilityElement(children: .contain)
    }

    /// Pin points: both edges, the bell, and one more halfway to the bell.
    static func pins(width: CGFloat, bellFraction: CGFloat) -> [CGPoint] {
        [0, bellFraction / 2, bellFraction, 1].map { CGPoint(x: width * $0, y: pinY) }
    }
}

/// A little red bow with two holly berries, drawn where the garland is pinned.
private struct GarlandBow: View {
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let red = Color(hex: "D6493D"), dark = Color(hex: "9E2A22")
            for side in [-1.0, 1.0] {
                var loop = Path()
                loop.move(to: c)
                loop.addQuadCurve(to: CGPoint(x: c.x + side * 8, y: c.y - 4), control: CGPoint(x: c.x + side * 5, y: c.y - 8))
                loop.addQuadCurve(to: c, control: CGPoint(x: c.x + side * 9, y: c.y + 3))
                ctx.fill(loop, with: .color(red))
                var tail = Path()
                tail.move(to: c); tail.addLine(to: CGPoint(x: c.x + side * 4.5, y: c.y + 8))
                ctx.stroke(tail, with: .color(dark), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2.4, y: c.y - 2.4, width: 4.8, height: 4.8)), with: .color(dark))
        }
        .frame(width: 22, height: 20)
        .allowsHitTesting(false)
    }
}

enum GarlandDrawing {
    private static let needleDark = Color(hex: "1F5B3A"), needleLight = Color(hex: "3F8F5E"), rope = Color(hex: "173F2A")
    private static let bulbColors = [Color(hex: "FFD27A"), Color(hex: "FF6B5E"), Color(hex: "9CC8FF"), Color(hex: "7BE0A0")]

    /// Point on the swag between two pins at `t` (0...1), sagging by `sag`.
    private static func point(_ a: CGPoint, _ b: CGPoint, sag: CGFloat, _ t: CGFloat) -> CGPoint {
        let control = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + sag * 2)
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
                       y: u * u * a.y + 2 * u * t * control.y + t * t * b.y)
    }

    private static func sag(_ a: CGPoint, _ b: CGPoint) -> CGFloat { min(9, abs(b.x - a.x) * 0.05) }

    static func drawGarland(_ ctx: inout GraphicsContext, pins: [CGPoint]) {
        for (a, b) in zip(pins, pins.dropFirst()) {
            let sag = sag(a, b)
            var line = Path()
            line.move(to: a)
            line.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + sag * 2))
            ctx.stroke(line, with: .color(rope), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            // Pine needles: short strokes fanning out from the rope, alternating shades.
            let steps = max(4, Int(abs(b.x - a.x) / 4))
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let p = point(a, b, sag: sag, t)
                let flip: CGFloat = i % 2 == 0 ? 1 : -1
                let lean = CGFloat((i * 37) % 7) / 7 - 0.5
                var needle = Path()
                needle.move(to: CGPoint(x: p.x - 3.2 + lean, y: p.y - 3.4 * flip))
                needle.addLine(to: CGPoint(x: p.x + 3.2 + lean, y: p.y + 3.4 * flip))
                ctx.stroke(needle, with: .color(i % 3 == 0 ? needleLight : needleDark), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
    }

    static func drawBulbs(_ ctx: inout GraphicsContext, pins: [CGPoint], t: Double) {
        var index = 0
        for (a, b) in zip(pins, pins.dropFirst()) {
            let sag = sag(a, b)
            let count = max(1, Int(abs(b.x - a.x) / 34))
            for i in 0..<count {
                let along = (CGFloat(i) + 0.5) / CGFloat(count)
                let p = point(a, b, sag: sag, along)
                let bulb = CGPoint(x: p.x, y: p.y + 5)
                let glow = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 2.2 + Double(index) * 1.3))
                let color = bulbColors[index % bulbColors.count]
                ctx.fill(Path(ellipseIn: CGRect(x: bulb.x - 7, y: bulb.y - 7, width: 14, height: 14)), with: .color(color.opacity(0.28 * glow)))
                ctx.fill(Path(CGRect(x: bulb.x - 1.2, y: bulb.y - 3.6, width: 2.4, height: 1.8)), with: .color(Color(hex: "8A7448")))
                ctx.fill(Path(ellipseIn: CGRect(x: bulb.x - 2.4, y: bulb.y - 2.2, width: 4.8, height: 5.6)), with: .color(color.opacity(0.6 + 0.4 * glow)))
                index += 1
            }
        }
    }
}
