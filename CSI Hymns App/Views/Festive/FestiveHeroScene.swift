import SwiftUI

/// Mutable bits of the hero the canvas reads each frame (taps set them). Plain class: the Canvas
/// renderer runs outside the main actor.
final class FestiveHeroModel: @unchecked Sendable {
    var starTappedAt = -100.0
    var shootingStarAt: Double?
    var snowmanPieceStartedAt: [Double] = []
    var snowmanStage: Int { snowmanPieceStartedAt.count }
    var isSnowmanDone: Bool { snowmanStage >= 3 }
    let moment: FestiveMoment
    let start = Date()
    /// Seconds on the scene clock (the same one the renderer uses).
    var clock: Double { Date().timeIntervalSince(start) }
    init(moment: FestiveMoment) { self.moment = moment }
}

/// The home screen's Bethlehem scene, drawn on a 390x352 design canvas that stretches to fit.
/// It is ALWAYS a dark night sky, in light mode too, so the title and chips stay readable.
struct FestiveHeroScene: View {
    let model: FestiveHeroModel
    let animate: Bool
    var onStarTap: (CGPoint) -> Void = { _ in }
    var onSnowTap: () -> Void = {}

    @State private var size = CGSize.zero
    @State private var origin = CGPoint.zero
    private static let designSize = CGSize(width: 390, height: 352)
    static let starCenter = CGPoint(x: 300, y: 172)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animate)) { timeline in
            Canvas { ctx, size in
                let t = animate ? timeline.date.timeIntervalSince(model.start) : 0
                FestiveHeroRenderer.draw(&ctx, size: size, t: t, model: model, palette: .night)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { tap in
                // Convert the tap to design space inside a GeometryReader-free way.
                handle(tap.location)
            }
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { size = $0.size; origin = $0.origin }
        .accessibilityHidden(true)
    }

    private func handle(_ location: CGPoint) {
        guard size.width > 0 else { return }
        let design = FestiveHeroRenderer.designPoint(location, size: size)
        if hypot(design.x - Self.starCenter.x, design.y - Self.starCenter.y) <= 34 {
            onStarTap(CGPoint(x: origin.x + location.x, y: origin.y + location.y))
        } else if design.x < 120, design.y > Self.designSize.height - 62 {
            onSnowTap()
        }
    }
}

enum FestiveHeroRenderer {
    private struct Star { let x, y, r, phase, speed: Double }
    private enum Kind { case house, tower, dome, stable }
    private struct Building { let x, w, h: Double; let kind: Kind; let lit: [Bool] }

    private static let stars: [Star] = {
        var rng = SeededRandom(seed: 7)
        // The sky reaches above the 352-unit scene on tall layouts, so stars start well above it.
        return (0..<120).map { _ in Star(x: rng.next() * 390, y: -280 + rng.next() * 520, r: 0.5 + rng.next() * 1.2, phase: rng.next() * 6.28, speed: 0.6 + rng.next() * 1.6) }
    }()
    private static let buildings: [Building] = {
        var rng = SeededRandom(seed: 11)
        func lit() -> [Bool] { (0..<6).map { _ in rng.next() > 0.3 } }
        return [
            Building(x: 112, w: 26, h: 22, kind: .house, lit: lit()), Building(x: 141, w: 18, h: 36, kind: .tower, lit: lit()),
            Building(x: 162, w: 34, h: 18, kind: .house, lit: lit()), Building(x: 199, w: 24, h: 32, kind: .dome, lit: lit()),
            Building(x: 226, w: 30, h: 20, kind: .house, lit: lit()), Building(x: 273, w: 52, h: 30, kind: .stable, lit: []),
            Building(x: 330, w: 24, h: 26, kind: .house, lit: lit()), Building(x: 357, w: 30, h: 18, kind: .house, lit: lit())
        ]
    }()

    private static func farHill(_ x: Double) -> Double { 290 + 9 * sin(x / 70 + 1) + 5 * sin(x / 23) }
    private static func nearHill(_ x: Double) -> Double { 312 + 7 * sin(x / 90 + 2) + 3 * sin(x / 31) }

    private static let warmWindow = Color(hex: "FFC96B"), stableGlow = Color(hex: "FFBE64"), starCore = Color(hex: "FFF6DC")

    /// Maps design units to points with ONE scale, so nothing stretches. The scene fills the
    /// width and sits on the bottom edge; on taller layouts the sky simply continues upward.
    private struct Scene {
        let s: Double, ox: Double, oy: Double
        var unit: Double { s }
        init(_ size: CGSize) {
            s = max(0.01, min(size.width / 390, size.height / 250))
            ox = (size.width - 390 * s) / 2
            oy = size.height - 352 * s
        }
        /// Design x range that covers the whole width (wider than 0...390 when the scene is pillarboxed).
        var xRange: ClosedRange<Double> { (-ox / s - 6)...((390 + ox / s) + 6) }
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: ox + x * s, y: oy + y * s, width: w * s, height: h * s) }
        func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path { Path(ellipseIn: r(x, y, w, h)) }
        func circle(_ cx: Double, _ cy: Double, _ rad: Double) -> Path { oval(cx - rad, cy - rad, rad * 2, rad * 2) }
    }

    /// A point on the canvas in design units (for taps).
    static func designPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        let s = Scene(size)
        return CGPoint(x: (point.x - s.ox) / s.s, y: (point.y - s.oy) / s.s)
    }

    /// Where design-unit y lands on the canvas, so overlays can stay clear of the skyline.
    static func canvasY(designY: Double, size: CGSize) -> Double {
        let s = Scene(size)
        return s.oy + designY * s.s
    }

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double, model: FestiveHeroModel, palette: FestivePalette) {
        let s = Scene(size)
        let h = max(size.height, 1)
        func loc(_ designY: Double) -> Double { min(1, max(0, s.p(0, designY).y / h)) }
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(stops: [
                .init(color: palette.skyTop, location: 0), .init(color: palette.skyMid, location: max(0.0001, loc(150))),
                .init(color: palette.skyLow, location: loc(253)), .init(color: palette.horizon, location: loc(320)),
                .init(color: palette.ground, location: 1)
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let starColor = Color(hex: "FFFAEB")
        for star in stars {
            let pos = s.p(star.x, star.y)
            guard pos.y > -4 else { continue }
            let tw = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * star.speed + star.phase))
            ctx.fill(s.circle(star.x, star.y, star.r), with: .color(starColor.opacity(tw)))
        }
        drawStarOfBethlehem(&ctx, s, t: t, flare: max(0, min(1, 1 - (t - model.starTappedAt) * 1.6)))
        if let at = model.shootingStarAt { drawShootingStar(&ctx, s, progress: (t - at) / 1.3) }

        fillHill(&ctx, s, size: size, height: farHill, color: Color(hex: "1C1A3D"))
        let city = Color(hex: "0A0C20")
        drawCaravan(&ctx, s, t: t, color: city, stop: model.moment == .epiphany)
        for walker in ShepherdWalk.walkers(at: t) { drawShepherd(&ctx, s, walker: walker, t: t, color: city) }
        fillHill(&ctx, s, size: size, height: nearHill, color: Color(hex: "11132C"))
        for b in buildings { drawBuilding(&ctx, s, b, color: city, t: t, candles: model.moment == .christmasEve) }
        drawSnowMound(&ctx, s, size: size, t: t, color: palette.capSnow)
        drawSnowman(&ctx, s, t: t, model: model)
    }

    private static func fillHill(_ ctx: inout GraphicsContext, _ s: Scene, size: CGSize, height: (Double) -> Double, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        var x = s.xRange.lowerBound
        while x <= s.xRange.upperBound { path.addLine(to: s.p(x, height(x))); x += 6 }
        path.addLine(to: CGPoint(x: size.width, y: size.height)); path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    // MARK: Star, shooting star

    /// Eight tapering rays (the one pointing down to the stable is the longest), a soft breathing
    /// glow and a bright eight-point core. Matches the Android star.
    private static let rayLengths: [Double] = [40, 15, 32, 15, 104, 15, 32, 15]

    private static func drawStarOfBethlehem(_ ctx: inout GraphicsContext, _ s: Scene, t: Double, flare: Double) {
        let c = s.p(300, 172)
        let glowR = (46 * (1 + 0.06 * sin(t * 1.4)) + flare * 34) * s.unit
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - glowR, y: c.y - glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [Color(hex: "E9C27B").opacity(0.5 + 0.35 * flare), .clear]), center: c, startRadius: 0, endRadius: glowR))
        for (i, base) in rayLengths.enumerated() {
            let angle = -Double.pi / 2 + Double(i) * .pi / 4 + sin(t * 0.4) * 0.03
            let length = base * s.unit * (1 + 0.08 * sin(t * 2.3 + Double(i))) * (1 + flare * 0.25)
            let tip = CGPoint(x: c.x + cos(angle) * length, y: c.y + sin(angle) * length)
            let half = 1.8 * s.unit
            let perp = CGPoint(x: -sin(angle) * half, y: cos(angle) * half)
            var ray = Path()
            ray.move(to: CGPoint(x: c.x + perp.x, y: c.y + perp.y))
            ray.addLine(to: CGPoint(x: c.x - perp.x, y: c.y - perp.y))
            ray.addLine(to: tip); ray.closeSubpath()
            ctx.fill(ray, with: .linearGradient(Gradient(colors: [starCore.opacity(0.95), starCore.opacity(0)]), startPoint: c, endPoint: tip))
        }
        var core = Path()
        for i in 0..<8 {
            let angle = -Double.pi / 2 + Double(i) * .pi / 4
            let r = (i % 2 == 1 ? 2.6 : 9 + flare * 3) * s.unit
            let pt = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
            if i == 0 { core.move(to: pt) } else { core.addLine(to: pt) }
        }
        core.closeSubpath()
        let haloR = 7 * s.unit
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - haloR, y: c.y - haloR, width: haloR * 2, height: haloR * 2)), with: .color(starCore.opacity(0.35)))
        ctx.fill(core, with: .color(starCore))
    }

    private static func drawShootingStar(_ ctx: inout GraphicsContext, _ s: Scene, progress: Double) {
        guard (0...1).contains(progress) else { return }
        let head = s.p(40 + progress * 300, 30 + progress * 120), tail = s.p(40 + max(0, progress - 0.2) * 300, 30 + max(0, progress - 0.2) * 120)
        var line = Path(); line.move(to: tail); line.addLine(to: head)
        ctx.stroke(line, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(1 - progress * 0.6)]), startPoint: tail, endPoint: head),
                   style: StrokeStyle(lineWidth: 2.2 * s.unit, lineCap: .round))
    }

    // MARK: Caravan and shepherds

    private static func drawCaravan(_ ctx: inout GraphicsContext, _ s: Scene, t: Double, color: Color, stop: Bool) {
        if stop {
            let walked = -40 + max(t - 2, 0) * 15
            let lead = min(walked, 250)
            for i in 0..<3 { drawCamel(&ctx, s, x: lead - Double(i) * 30, t: t, color: color, walking: walked < 250) }
            return
        }
        let cycle = t.truncatingRemainder(dividingBy: 60) - 6
        guard t >= 6, cycle >= 0 else { return }
        let lead = -40 + cycle * 15
        guard lead - 60 <= 420 else { return }
        for i in 0..<3 { drawCamel(&ctx, s, x: lead - Double(i) * 30, t: t, color: color, walking: true) }
    }

    private static func drawCamel(_ ctx: inout GraphicsContext, _ s: Scene, x: Double, t: Double, color: Color, walking: Bool) {
        let base = farHill(x) + 1
        for (i, off) in [-7.0, -4.0, 5.0, 8.0].enumerated() {
            let swing = walking ? sin(t * 6 + Double(i) * .pi) * 2.4 : 0
            var leg = Path(); leg.move(to: s.p(x + off, base - 10)); leg.addLine(to: s.p(x + off + swing, base))
            ctx.stroke(leg, with: .color(color), style: StrokeStyle(lineWidth: 1.8 * s.unit, lineCap: .round))
        }
        ctx.fill(s.oval(x - 10, base - 18, 20, 10), with: .color(color))
        ctx.fill(s.oval(x - 6, base - 21, 10, 8), with: .color(color))
        var neck = Path(); neck.move(to: s.p(x + 8, base - 14)); neck.addLine(to: s.p(x + 13, base - 22))
        ctx.stroke(neck, with: .color(color), style: StrokeStyle(lineWidth: 3 * s.unit, lineCap: .round))
        ctx.fill(s.oval(x + 11.4, base - 24, 7.2, 4), with: .color(color))
        var rider = Path()
        rider.move(to: s.p(x - 5, base - 18)); rider.addLine(to: s.p(x + 2, base - 18)); rider.addLine(to: s.p(x - 1.5, base - 29)); rider.closeSubpath()
        ctx.fill(rider, with: .color(color))
        ctx.fill(s.circle(x - 1.5, base - 31, 2.3), with: .color(color))
        ctx.fill(Path(s.r(x - 3.5, base - 35.5, 4, 1.8)), with: .color(Color(hex: "E9C27B")))
    }

    private static let sheepWool = Color(hex: "E6E0D2")
    private static let shepherdCloths = [Color(hex: "C9553F"), Color(hex: "5E8F6B"), Color(hex: "D9A441")]

    /// One shepherd walking leftward along the far hill with a swinging lantern; a sheep follows
    /// (or a lamb rides on the shoulders).
    private static func drawShepherd(_ ctx: inout GraphicsContext, _ s: Scene, walker: ShepherdWalk.Walker, t: Double, color: Color) {
        let margin = 26.0
        let x = 390 + margin - walker.progress * (390 + 2 * margin)
        let base = farHill(x) + 1
        let step = sin(t * 7) * 2.2
        for (dx, sign) in [(-1.5, 1.0), (1.5, -1.0)] {
            var leg = Path(); leg.move(to: s.p(x + dx, base - 6)); leg.addLine(to: s.p(x + dx + step * sign, base))
            ctx.stroke(leg, with: .color(color), style: StrokeStyle(lineWidth: 1.6 * s.unit, lineCap: .round))
        }
        var robe = Path()
        robe.move(to: s.p(x - 3.4, base - 4)); robe.addLine(to: s.p(x - 1.6, base - 15)); robe.addLine(to: s.p(x + 1.6, base - 15)); robe.addLine(to: s.p(x + 3.4, base - 4)); robe.closeSubpath()
        ctx.fill(robe, with: .color(color))
        ctx.fill(s.circle(x, base - 17, 2.1), with: .color(color))
        ctx.fill(Path(s.r(x - 2.4, base - 19.4, 4.8, 1.5)), with: .color(shepherdCloths[walker.variant]))
        var staff = Path(); staff.move(to: s.p(x - 5.2, base)); staff.addLine(to: s.p(x - 5.2, base - 20)); staff.addLine(to: s.p(x - 3.6, base - 21.2))
        ctx.stroke(staff, with: .color(color), style: StrokeStyle(lineWidth: 1 * s.unit, lineCap: .round))
        let sway = sin(t * 3.5 + Double(walker.index)) * 1.2
        let lamp = s.p(x + 5.2 + sway, base - 9)
        var cord = Path(); cord.move(to: s.p(x + 2, base - 12)); cord.addLine(to: lamp)
        ctx.stroke(cord, with: .color(color), lineWidth: 0.8 * s.unit)
        let flicker = 0.8 + 0.2 * sin(t * 9 + Double(walker.index) * 2)
        ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - 6 * s.unit, y: lamp.y - 6 * s.unit, width: 12 * s.unit, height: 12 * s.unit)), with: .color(warmWindow.opacity(0.3 * flicker)))
        ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - 1.3 * s.unit, y: lamp.y - 1.3 * s.unit, width: 2.6 * s.unit, height: 2.6 * s.unit)), with: .color(warmWindow.opacity(flicker)))
        if walker.variant == 1 {
            ctx.fill(s.oval(x - 3.6, base - 17, 6.4, 3.2), with: .color(sheepWool))
        } else {
            let sx = x + 15, sb = farHill(sx) + 1, hop = sin(t * 7 + 1.5) * 1.2
            for (dx, sign) in [(-2.0, 1.0), (2.0, -1.0)] {
                var leg = Path(); leg.move(to: s.p(sx + dx, sb - 3)); leg.addLine(to: s.p(sx + dx + hop * sign, sb))
                ctx.stroke(leg, with: .color(color), style: StrokeStyle(lineWidth: 1.1 * s.unit, lineCap: .round))
            }
            ctx.fill(s.oval(sx - 4.6, sb - 8.6, 9.2, 6), with: .color(sheepWool))
            ctx.fill(s.circle(sx - 5.6, sb - 6.6, 1.6), with: .color(color))
        }
    }

    // MARK: Buildings and nativity

    private static func drawBuilding(_ ctx: inout GraphicsContext, _ s: Scene, _ b: Building, color: Color, t: Double, candles: Bool) {
        let base = nearHill(b.x + b.w / 2) + 3, top = base - b.h
        func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Color = color) { ctx.fill(Path(s.r(x, y, w, h)), with: .color(c)) }
        switch b.kind {
        case .stable: drawStable(&ctx, s, b, base: base, top: top, color: color, t: t); return
        case .dome:
            rect(b.x, top + 9, b.w, b.h + 12)
            ctx.fill(s.oval(b.x, top - 2, b.w, b.w), with: .color(color))
        case .tower:
            rect(b.x, top, b.w, b.h + 20); rect(b.x + b.w / 2 - 4, top - 8, 8, 8)
            rect(b.x + b.w / 2 - 0.8, top - 17, 1.6, 9); rect(b.x + b.w / 2 - 3, top - 14, 6, 1.6)
        case .house:
            rect(b.x, top, b.w, b.h + 20); rect(b.x + 2, top - 3, 6, 3)
        }
        let rows = b.h > 24 ? 2 : 1
        var index = 0
        for row in 0..<rows {
            var wx = b.x + 4
            while wx + 4 <= b.x + b.w - 3 {
                let lit = b.lit[index % max(b.lit.count, 1)] || candles
                index += 1
                if lit {
                    let wy = top + (b.kind == .dome ? 14 : 6) + Double(row) * 11
                    let flicker = candles ? 0.85 + 0.15 * sin(t * 9 + wx) : 0.8
                    if candles { ctx.fill(s.oval(wx - 4.5, wy - 4, 9, 9), with: .color(warmWindow.opacity(0.22))) }
                    rect(wx, wy, 3, 4, warmWindow.opacity(flicker))
                }
                wx += 8
            }
        }
    }

    private static let maryRobe = Color(hex: "3E5BA9"), maryVeil = Color(hex: "2B4180"), josephRobe = Color(hex: "A8702F")
    private static let skin = Color(hex: "F1C79E"), wood = Color(hex: "6B4423"), hay = Color(hex: "E8C46A"), swaddle = Color(hex: "FFF3DA")

    private static func drawStable(_ ctx: inout GraphicsContext, _ s: Scene, _ b: Building, base: Double, top: Double, color: Color, t: Double) {
        let cx = b.x + b.w / 2
        let gc = s.p(cx, base - 6), gr = 34 * s.unit
        ctx.fill(Path(ellipseIn: CGRect(x: gc.x - gr, y: gc.y - gr, width: gr * 2, height: gr * 2)),
                 with: .radialGradient(Gradient(colors: [stableGlow.opacity(0.55 + 0.08 * sin(t * 2)), .clear]), center: gc, startRadius: 0, endRadius: gr))
        var roof = Path()
        roof.move(to: s.p(b.x - 5, top + 7)); roof.addLine(to: s.p(cx, top - 6)); roof.addLine(to: s.p(b.x + b.w + 5, top + 7))
        roof.addLine(to: s.p(b.x + b.w + 5, top + 10)); roof.addLine(to: s.p(b.x - 5, top + 10)); roof.closeSubpath()
        ctx.fill(roof, with: .color(color))
        ctx.fill(Path(s.r(b.x, top + 9, 4, b.h + 12)), with: .color(color))
        ctx.fill(Path(s.r(b.x + b.w - 4, top + 9, 4, b.h + 12)), with: .color(color))
        ctx.fill(Path(s.r(b.x + 4, top + 10, b.w - 8, b.h - 8)), with: .color(warmWindow.opacity(0.55)))
        drawNativity(&ctx, s, cx: cx, base: base, t: t)
        ctx.fill(Path(s.r(b.x - 2, base - 2, b.w + 4, 24)), with: .color(color))
    }

    /// Mary kneeling in blue, Joseph standing with his staff, and the baby Jesus asleep in the
    /// manger with a softly pulsing halo.
    private static func drawNativity(_ ctx: inout GraphicsContext, _ s: Scene, cx: Double, base: Double, t: Double) {
        let mx = cx - 13.5
        var robe = Path()
        robe.move(to: s.p(mx - 5.5, base - 1))
        robe.addQuadCurve(to: s.p(mx + 0.5, base - 11), control: s.p(mx - 4, base - 9))
        robe.addQuadCurve(to: s.p(mx + 5.5, base - 1), control: s.p(mx + 4.5, base - 9)); robe.closeSubpath()
        ctx.fill(robe, with: .color(maryRobe))
        ctx.fill(s.circle(mx + 1, base - 13, 3), with: .color(maryVeil))
        ctx.fill(s.circle(mx + 2, base - 12.6, 1.5), with: .color(skin))

        let jx = cx + 14.5
        var tunic = Path()
        tunic.move(to: s.p(jx - 4.5, base - 1)); tunic.addLine(to: s.p(jx - 2.6, base - 14)); tunic.addLine(to: s.p(jx + 2.6, base - 14)); tunic.addLine(to: s.p(jx + 4.5, base - 1)); tunic.closeSubpath()
        ctx.fill(tunic, with: .color(josephRobe))
        ctx.fill(s.circle(jx - 0.4, base - 16.4, 2.3), with: .color(skin))
        var staff = Path(); staff.move(to: s.p(jx + 6, base - 1)); staff.addLine(to: s.p(jx + 6, base - 19)); staff.addLine(to: s.p(jx + 4.3, base - 20.2))
        ctx.stroke(staff, with: .color(wood), style: StrokeStyle(lineWidth: 1.1 * s.unit, lineCap: .round))

        let halo = 0.5 + 0.12 * sin(t * 2.2), bc = s.p(cx, base - 8.8), hr = 10 * s.unit
        ctx.fill(Path(ellipseIn: CGRect(x: bc.x - hr, y: bc.y - hr, width: hr * 2, height: hr * 2)),
                 with: .radialGradient(Gradient(colors: [swaddle.opacity(halo), .clear]), center: bc, startRadius: 0, endRadius: hr))
        var trough = Path()
        trough.move(to: s.p(cx - 7.5, base - 7)); trough.addLine(to: s.p(cx + 7.5, base - 7)); trough.addLine(to: s.p(cx + 5, base - 0.8)); trough.addLine(to: s.p(cx - 5, base - 0.8)); trough.closeSubpath()
        ctx.fill(trough, with: .color(wood))
        ctx.fill(s.oval(cx - 6.5, base - 9, 13, 3.6), with: .color(hay))
        ctx.fill(s.oval(cx - 3, base - 10.2, 7, 3.4), with: .color(swaddle))
        ctx.fill(s.circle(cx - 3.4, base - 9.4, 1.6), with: .color(skin))
    }

    // MARK: Snow and snowman

    private static func drawSnowMound(_ ctx: inout GraphicsContext, _ s: Scene, size: CGSize, t: Double, color: Color) {
        // A soft, uneven drift: rolling bumps, a bluish shadow line under the crest, and a
        // highlight along the top so it reads as snow rather than a flat white band.
        let grow = min(1, 0.6 + t * 0.02)
        func crest(_ x: Double) -> Double { 342 - (5 + 3.2 * sin(x / 38 + 1) + 2.2 * sin(x / 13 + 0.4) + 1.5 * sin(x / 71)) * grow }
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        var x = s.xRange.lowerBound
        while x <= s.xRange.upperBound { path.addLine(to: s.p(x, crest(x))); x += 4 }
        path.addLine(to: CGPoint(x: size.width, y: size.height)); path.closeSubpath()
        let top = s.p(0, 330).y
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [color, color.opacity(0.94), Color(hex: "C9D5EA")]),
            startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
        var shine = Path()
        x = s.xRange.lowerBound
        shine.move(to: s.p(x, crest(x) + 0.8))
        while x <= s.xRange.upperBound { shine.addLine(to: s.p(x, crest(x) + 0.8)); x += 4 }
        ctx.stroke(shine, with: .color(.white.opacity(0.75)), lineWidth: 1 * s.unit)
    }

    private static func drawSnowman(_ ctx: inout GraphicsContext, _ s: Scene, t: Double, model: FestiveHeroModel) {
        let shade = Color(hex: "AAB6D0")
        func grow(_ i: Int) -> Double {
            guard i < model.snowmanPieceStartedAt.count else { return 0 }
            return min(1, (t - model.snowmanPieceStartedAt[i]) / 0.45)
        }
        func ball(_ cy: Double, _ r: Double, _ g: Double) {
            guard g > 0 else { return }
            ctx.fill(s.circle(58, cy, r * g), with: .color(Color(hex: "F4F7FD")))
            ctx.stroke(s.circle(58, cy, r * g), with: .color(shade), lineWidth: 0.8)
        }
        ball(323, 11, grow(0)); ball(305, 8, grow(1))
        let head = grow(2)
        guard head > 0 else { return }
        ball(291, 6, head)
        if head >= 1 {
            ctx.fill(s.circle(56, 290, 0.8), with: .color(.black)); ctx.fill(s.circle(60, 290, 0.8), with: .color(.black))
            var nose = Path(); nose.move(to: s.p(58, 292)); nose.addLine(to: s.p(64, 293.5)); nose.addLine(to: s.p(58, 294)); nose.closeSubpath()
            ctx.fill(nose, with: .color(Color(hex: "F28C28")))
            ctx.fill(Path(s.r(52, 283, 12, 2)), with: .color(Color(hex: "1B1B1B"))); ctx.fill(Path(s.r(54, 277, 8, 6)), with: .color(Color(hex: "1B1B1B")))
            ctx.fill(Path(s.r(53, 297, 10, 2.4)), with: .color(Color(hex: "D6493D")))
            let wave = sin(t * 3) * 6
            var arm = Path(); arm.move(to: s.p(50, 304)); arm.addLine(to: s.p(40, 298 - wave))
            ctx.stroke(arm, with: .color(Color(hex: "6B4423")), style: StrokeStyle(lineWidth: 1.4 * s.unit, lineCap: .round))
            var arm2 = Path(); arm2.move(to: s.p(66, 304)); arm2.addLine(to: s.p(76, 300))
            ctx.stroke(arm2, with: .color(Color(hex: "6B4423")), style: StrokeStyle(lineWidth: 1.4 * s.unit, lineCap: .round))
        }
    }
}
