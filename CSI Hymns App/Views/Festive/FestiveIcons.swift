import SwiftUI

/// Draws into a square design box scaled to the frame, with a looping phase (0...1) when animated.
private struct IconCanvas: View {
    let size: CGFloat
    let viewBox: CGFloat
    let period: Double
    let animate: Bool
    let draw: (inout GraphicsContext, Double) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animate)) { timeline in
            Canvas { ctx, canvasSize in
                let phase = animate ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period : 0.5
                ctx.scaleBy(x: canvasSize.width / viewBox, y: canvasSize.height / viewBox)
                draw(&ctx, phase)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

/// A hymn book with a holly sprig. The book sways, a page turns every few seconds, a music note
/// floats up out of it and the holly berries twinkle.
struct FestiveHymnBookIcon: View {
    let tint: Color, leaf: Color, size: CGFloat, animate: Bool
    private static let berry = Color(hex: "D6493D"), noteGold = Color(hex: "E9C27B")

    var body: some View {
        IconCanvas(size: size, viewBox: 36, period: 3.6, animate: animate) { ctx, phase in
            let sway = animate ? 3 * sin(phase * 2 * .pi) : 0
            var book = ctx
            book.translateBy(x: 18, y: 30); book.rotate(by: .degrees(sway)); book.translateBy(x: -18, y: -30)
            var left = Path()
            left.move(to: p(3, 10)); left.addQuadCurve(to: p(18, 10.8), control: p(10.5, 7.2))
            left.addLine(to: p(18, 29.8)); left.addQuadCurve(to: p(3, 29), control: p(10.5, 26.4)); left.closeSubpath()
            var right = Path()
            right.move(to: p(18, 10.8)); right.addQuadCurve(to: p(33, 10), control: p(25.5, 7.2))
            right.addLine(to: p(33, 29)); right.addQuadCurve(to: p(18, 29.8), control: p(25.5, 26.4)); right.closeSubpath()
            let stroke = StrokeStyle(lineWidth: 2, lineJoin: .round)
            book.stroke(left, with: .color(tint), style: stroke); book.stroke(right, with: .color(tint), style: stroke)
            var lines = Path()
            for y in [16.0, 20, 24] { lines.move(to: p(7.5, y)); lines.addLine(to: p(y == 24 ? 12 : 14, y)) }
            for y in [16.0, 20] { lines.move(to: p(22, y)); lines.addLine(to: p(28.5, y)) }
            book.stroke(lines, with: .color(tint.opacity(0.55)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            if animate, phase < 0.32 {
                // The right page lifts, passes edge-on, and lands on the left.
                var page = book
                page.translateBy(x: 18, y: 0); page.scaleBy(x: cos(phase / 0.32 * .pi), y: 1); page.translateBy(x: -18, y: 0)
                page.fill(right, with: .color(tint.opacity(0.22))); page.stroke(right, with: .color(tint), lineWidth: 1.4)
            }
            if animate, phase > 0.45 {
                let rise = (phase - 0.45) / 0.55
                let a = sin(rise * .pi), x = 11 + 3 * sin(rise * 2 * .pi), y = 12 - 10 * rise
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.7, y: y - 1.7, width: 3.4, height: 3.4)), with: .color(Self.noteGold.opacity(a)))
                var stem = Path(); stem.move(to: p(x + 1.5, y)); stem.addLine(to: p(x + 1.5, y - 5))
                ctx.stroke(stem, with: .color(Self.noteGold.opacity(a)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
            var leaf1 = ctx; leaf1.translateBy(x: 26, y: 6); leaf1.rotate(by: .degrees(-25))
            leaf1.fill(Path(ellipseIn: CGRect(x: -5, y: -2.4, width: 10, height: 4.8)), with: .color(leaf))
            var leaf2 = ctx; leaf2.translateBy(x: 31.5, y: 7.5); leaf2.rotate(by: .degrees(35))
            leaf2.fill(Path(ellipseIn: CGRect(x: -4.5, y: -2.2, width: 9, height: 4.4)), with: .color(leaf))
            for (i, (x, y, r)) in [(28.6, 9.0, 2.0), (31.4, 10.8, 1.8), (26.4, 11.2, 1.6)].enumerated() {
                let tw = 0.75 + 0.25 * sin((phase * 2 + Double(i) * 0.2) * 2 * .pi)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Self.berry.opacity(tw)))
            }
        }
    }
}

/// A paper star lantern (as hung outside homes in Karnataka at Christmas) swaying on its string.
struct FestiveStarLanternIcon: View {
    let tint: Color, size: CGFloat, animate: Bool
    private static let gold = Color(hex: "F2C14E"), red = Color(hex: "D6493D")

    var body: some View {
        IconCanvas(size: size, viewBox: 40, period: 3.4, animate: animate) { ctx, phase in
            var c = ctx
            c.translateBy(x: 20, y: 0); c.rotate(by: .degrees(animate ? 7 * sin(phase * 2 * .pi) : 0)); c.translateBy(x: -20, y: 0)
            var string = Path(); string.move(to: p(20, 0)); string.addLine(to: p(20, 9))
            c.stroke(string, with: .color(tint), lineWidth: 1.4)
            c.fill(Path(ellipseIn: CGRect(x: 10, y: 11, width: 20, height: 20)), with: .color(Self.gold.opacity(0.35)))
            var star = Path()
            for i in 0..<10 {
                let angle = -Double.pi / 2 + Double(i) * .pi / 5, radius = i % 2 == 0 ? 12.0 : 5.2
                let pt = p(20 + cos(angle) * radius, 21 + sin(angle) * radius + 0.5)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            c.fill(star, with: .color(Self.gold)); c.stroke(star, with: .color(tint), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            c.fill(Path(ellipseIn: CGRect(x: 17.6, y: 18.6, width: 4.8, height: 4.8)), with: .color(.white))
            var tassels = Path()
            for (x0, x1) in [(13.0, 12.0), (27, 28), (20, 20)] { tassels.move(to: p(x0, 30.7)); tassels.addLine(to: p(x1, 38)) }
            c.stroke(tassels, with: .color(Self.red), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}

/// A Christmas tree with bulbs that blink.
struct FestiveTreeIcon: View {
    let leaf: Color, size: CGFloat, animate: Bool
    var body: some View {
        IconCanvas(size: size, viewBox: 32, period: 1.8, animate: animate) { ctx, phase in
            var tree = Path()
            tree.move(to: p(16, 4)); tree.addLine(to: p(22.5, 13)); tree.addLine(to: p(19.5, 13)); tree.addLine(to: p(25.5, 21))
            tree.addLine(to: p(21.5, 21)); tree.addLine(to: p(27.5, 28)); tree.addLine(to: p(4.5, 28)); tree.addLine(to: p(10.5, 21))
            tree.addLine(to: p(6.5, 21)); tree.addLine(to: p(12.5, 13)); tree.addLine(to: p(9.5, 13)); tree.closeSubpath()
            ctx.fill(tree, with: .color(leaf))
            ctx.fill(Path(CGRect(x: 14, y: 28, width: 4, height: 3)), with: .color(Color(hex: "7A5230")))
            var star = Path()
            for i in 0..<10 {
                let a = -Double.pi / 2 + Double(i) * .pi / 5, r = i % 2 == 0 ? 3.2 : 1.4
                let pt = p(16 + cos(a) * r, 3.2 + sin(a) * r)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(Color(hex: "F2C14E")))
            let colors = [Color(hex: "FF6B5E"), Color(hex: "F2C14E"), Color(hex: "9CC8FF"), Color(hex: "FF6B5E"), Color(hex: "F2C14E")]
            for (i, b) in [p(14, 11), p(18.5, 17), p(12, 19.5), p(20.5, 24.5), p(10.5, 25.5)].enumerated() {
                let blink = animate ? 0.45 + 0.55 * (0.5 + 0.5 * sin((phase + Double(i) * 0.21) * 2 * .pi)) : 1
                ctx.fill(Path(ellipseIn: CGRect(x: b.x - 1.4, y: b.y - 1.4, width: 2.8, height: 2.8)), with: .color(colors[i].opacity(blink)))
            }
        }
    }
}

/// Piano keys with a red bow.
struct FestivePianoBowIcon: View {
    let tint: Color, size: CGFloat
    var body: some View {
        IconCanvas(size: size, viewBox: 24, period: 1, animate: false) { ctx, _ in
            let body = Path(roundedRect: CGRect(x: 2.5, y: 7, width: 19, height: 13), cornerRadius: 2)
            ctx.stroke(body, with: .color(tint), lineWidth: 1.6)
            var keys = Path()
            for x in [6.5, 10.5, 14.5, 18.5] { keys.move(to: p(x - 0.5, 7)); keys.addLine(to: p(x - 0.5, 20)) }
            ctx.stroke(keys, with: .color(tint.opacity(0.7)), lineWidth: 1.1)
            for x in [5.0, 9.0, 16.0] { ctx.fill(Path(CGRect(x: x, y: 7, width: 2.4, height: 7.5)), with: .color(tint)) }
            var bow = Path()
            bow.move(to: p(12, 7)); bow.addCurve(to: p(9, 6.6), control1: p(9, 2.5), control2: p(6.5, 4))
            bow.move(to: p(12, 7)); bow.addCurve(to: p(15, 6.6), control1: p(15, 2.5), control2: p(17.5, 4))
            ctx.stroke(bow, with: .color(Color(hex: "D6493D")), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }
}

/// A stave with notes that bob in turn.
struct FestiveBobbingStave: View {
    let tint: Color
    let animate: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animate)) { timeline in
            Canvas { ctx, size in
                let phase = animate ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.6) / 2.6 : 0.5
                ctx.scaleBy(x: size.width / 104, y: size.height / 58)
                for y in [14.0, 22, 30, 38, 46] {
                    var line = Path(); line.move(to: p(0, y)); line.addLine(to: p(104, y))
                    ctx.stroke(line, with: .color(tint.opacity(0.65)), lineWidth: 1.3)
                }
                for (i, (x, y, delay)) in [(24.0, 38.0, 0.0), (52, 30, 0.13), (80, 22, 0.27)].enumerated() {
                    let bob = -3 * (0.5 - 0.5 * cos((phase - delay) * 2 * .pi))
                    var n = ctx; n.translateBy(x: 0, y: bob)
                    var head = n; head.translateBy(x: x, y: y); head.rotate(by: .degrees(-20))
                    head.fill(Path(ellipseIn: CGRect(x: -5, y: -3.6, width: 10, height: 7.2)), with: .color(tint))
                    n.fill(Path(CGRect(x: x + 4, y: y - 26, width: 1.6, height: 26)), with: .color(tint))
                    if i == 2 {
                        var flag = Path(); flag.move(to: p(85.6, 0)); flag.addQuadCurve(to: p(89.6, 14), control: p(93.6, 6)); flag.addQuadCurve(to: p(85.6, 5), control: p(90.6, 7))
                        n.fill(flag, with: .color(tint))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Hanging bell

/// A gold bell on a string at the top right. Tapping swings it, rings gold rings, jingles the phone
/// and counts toward the "bell" secret.
struct FestiveHangingBell: View {
    /// Extra string length above the bell (points), for hanging it from the top edge.
    var extraString: CGFloat = 0
    let onRing: (CGPoint) -> Void
    @State private var ringCount = 0

    /// A longer string swings the same arc with a smaller angle, like a real pendulum.
    private var swingScale: Double { 52 / (52 + Double(extraString)) }

    var body: some View {
        let extra = extraString
        GeometryReader { geo in
            Canvas { ctx, size in
                let gold = Color(hex: "C9A15C")
                var top = Path(); top.move(to: CGPoint(x: size.width / 2, y: 0)); top.addLine(to: CGPoint(x: size.width / 2, y: extra + 1))
                ctx.stroke(top, with: .color(gold), lineWidth: 1.4)
                ctx.translateBy(x: 0, y: extra)
                ctx.scaleBy(x: size.width / 40, y: (size.height - extra) / 92)
                var string = Path(); string.move(to: p(20, 0)); string.addLine(to: p(20, 52))
                ctx.stroke(string, with: .color(gold), lineWidth: 1.4)
                var bow = Path(); bow.move(to: p(13, 50)); bow.addQuadCurve(to: p(27, 50), control: p(20, 43)); bow.addLine(to: p(24, 53)); bow.addQuadCurve(to: p(16, 53), control: p(20, 50)); bow.closeSubpath()
                ctx.fill(bow, with: .color(Color(hex: "D6493D")))
                var bell = Path()
                bell.move(to: p(20, 54)); bell.addCurve(to: p(9, 68), control1: p(12, 54), control2: p(9, 61))
                bell.addCurve(to: p(4, 79), control1: p(9, 74), control2: p(7, 77)); bell.addLine(to: p(36, 79))
                bell.addCurve(to: p(31, 68), control1: p(33, 77), control2: p(31, 74)); bell.addCurve(to: p(20, 54), control1: p(31, 61), control2: p(28, 54)); bell.closeSubpath()
                ctx.fill(bell, with: .linearGradient(Gradient(colors: [Color(hex: "F2CF86"), Color(hex: "E2B66A"), Color(hex: "B98A3E")]), startPoint: p(6, 60), endPoint: p(36, 79)))
                ctx.stroke(bell, with: .color(Color(hex: "A97C34")), lineWidth: 1)
                var shine = Path(); shine.move(to: p(12, 66)); shine.addLine(to: p(17, 57.5))
                ctx.stroke(shine, with: .color(Color(hex: "FFF3D6").opacity(0.75)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: 16.6, y: 78.6, width: 6.8, height: 6.8)), with: .color(Color(hex: "A97C34")))
            }
            .keyframeAnimator(initialValue: 0.0, trigger: ringCount) { view, angle in
                view.rotationEffect(.degrees(angle * swingScale), anchor: .top)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(24, duration: 0.2); CubicKeyframe(-19, duration: 0.24); CubicKeyframe(13, duration: 0.24)
                    CubicKeyframe(-8, duration: 0.24); CubicKeyframe(4, duration: 0.24); CubicKeyframe(0, duration: 0.5)
                }
            }
            .contentShape(Rectangle().offset(y: extra).size(width: 40, height: 92))
            .onTapGesture {
                ringCount += 1
                let frame = geo.frame(in: .global)
                onRing(CGPoint(x: frame.midX, y: frame.maxY - 92 * 0.12))
            }
        }
        .frame(width: 40, height: 92 + extraString)
        .accessibilityLabel("Ring the bell")
        .accessibilityAddTraits(.isButton)
    }
}
