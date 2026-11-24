import SwiftUI

/// App-wide Christmas layer: snowfall, snow that lands on cards, drifting emoji, easter-egg
/// effects and Santa's sleigh. Draw-only: it never intercepts touches (taps are caught by the
/// root view's `festiveTapCatcher`).
struct FestiveSnowfallOverlay: View {
    private let ambience = FestiveAmbience.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let sim = ambience.sim
        let palette = FestivePalette.forScheme(scheme)
        TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: ambience.level == .off)) { timeline in
            Canvas { ctx, size in
                FestiveSnowfallRenderer.render(sim: sim, ctx: &ctx, size: size, now: timeline.date, palette: palette)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum FestiveSnowfallRenderer {
    /// A six-armed snowflake with side branches, radius 1, centred on the origin.
    private static let flake: Path = {
        var p = Path()
        for i in 0..<6 {
            let a = Double(i) / 6 * 2 * .pi
            let tip = CGPoint(x: cos(a), y: sin(a))
            p.move(to: .zero); p.addLine(to: tip)
            let mid = CGPoint(x: tip.x * 0.55, y: tip.y * 0.55)
            for side in [-0.6, 0.6] {
                p.move(to: mid)
                p.addLine(to: CGPoint(x: mid.x + cos(a + side) * 0.35, y: mid.y + sin(a + side) * 0.35))
            }
        }
        return p
    }()

    static func render(sim: FestiveSimulation, ctx: inout GraphicsContext, size: CGSize, now: Date, palette: FestivePalette) {
        sim.advance(now: now, size: size, unit: 1)
        let engine = sim.engine
        let level = sim.effectiveLevel
        let dim = sim.snowAlpha
        let night = palette.isNight || sim.darkSkyBehind
        let snowColor = night ? Color.white : palette.snow

        if level != .off {
            let density = level.snowDensity
            for p in engine.particles where engine.isVisible(p, density: density) {
                let layer = FestiveSnowEngine.layers[p.layer]
                let a = p.alpha * dim
                if layer.isFlake {
                    var c = ctx
                    c.translateBy(x: p.x, y: p.y); c.rotate(by: .radians(p.rotation)); c.scaleBy(x: p.radius, y: p.radius)
                    c.stroke(flake, with: .color(snowColor.opacity(a)), style: StrokeStyle(lineWidth: 0.16, lineCap: .round))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - p.radius, y: p.y - p.radius, width: p.radius * 2, height: p.radius * 2)),
                             with: .color(snowColor.opacity(a)))
                }
            }
            for s in engine.settled {
                let a = s.alpha * 0.9 * dim * min(1, s.life / 2)
                ctx.fill(Path(ellipseIn: CGRect(x: s.x - s.radius, y: s.y - s.radius, width: s.radius * 2, height: s.radius * 2)),
                         with: .color(snowColor.opacity(a)))
            }
            for c in engine.chunks {
                let a = min(1, c.life / 0.8) * 0.95 * dim
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - c.radius, y: c.y - c.radius, width: c.radius * 2, height: c.radius * 2)),
                         with: .color(palette.capSnow.opacity(a)))
            }
            let emojiOpacity = palette.emojiOpacity * dim
            for d in engine.drifters.prefix(level.emojiCount) where !d.isHidden {
                var c = ctx
                c.opacity = emojiOpacity
                c.draw(Text(d.emoji).font(.system(size: 14)), at: CGPoint(x: d.x * size.width, y: d.y * size.height))
            }
        }

        for p in sim.effects.particles where p.delay <= 0 {
            let fade = max(0, min(1, p.life / p.maxLife))
            let color = FestiveEffects.colors[p.colorIndex % FestiveEffects.colors.count]
            switch p.kind {
            case .spark:
                let r = p.size * (0.5 + 0.5 * fade)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(fade)))
            case .confetti:
                var c = ctx
                c.translateBy(x: p.x, y: p.y); c.rotate(by: .radians(p.rotation))
                let h = p.size * 0.5 * abs(cos(p.rotation * 1.3))
                c.fill(Path(CGRect(x: -p.size / 2, y: -h / 2, width: p.size, height: h)), with: .color(color.opacity(min(1, fade * 2))))
            case .ring:
                let radius = p.size + (p.maxLife - p.life) * 60
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(color.opacity(fade * 0.8)), lineWidth: 1.6)
            case .gift:
                var c = ctx
                c.opacity = min(1, fade * 3)
                c.draw(Text("🎁").font(.system(size: p.size)), at: CGPoint(x: p.x, y: p.y))
            case .emoji:
                FestiveGiftDrawing.drawEmoji(in: &ctx, particle: p, alpha: 1)
            }
        }

        if level != .off {
            for gift in sim.gifts.gifts { FestiveGiftDrawing.draw(in: &ctx, gift: gift, alpha: max(0.5, dim)) }
        }

        if level != .off, let pose = sim.santaPose(width: size.width) {
            FestiveSantaDrawing.draw(in: &ctx, pose: pose, time: sim.time, night: night, alpha: max(0.4, dim), unit: 1)
        }
    }
}

// MARK: - Root-level tap catcher

extension View {
    /// Lets Santa and the drifting emoji be tapped without stealing taps from the buttons below.
    func festiveTapCatcher() -> some View {
        modifier(FestiveTapCatcher())
    }
}

private struct FestiveTapCatcher: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            content.simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
                    let ambience = FestiveAmbience.shared
                    _ = ambience.handleTap(x: tap.location.x, y: tap.location.y, width: geo.size.width)
                }
            )
        }
    }
}
