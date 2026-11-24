import SwiftUI

/// Draws Santa's gifts: a box with a ribbon and a bow that squashes when it lands, pops its lid
/// when it opens, and sinks into the snow when nobody takes it.
enum FestiveGiftDrawing {
    private static let palettes: [(body: Color, ribbon: Color)] = [
        (Color(hex: "C8352B"), Color(hex: "F2D58A")),
        (Color(hex: "2F7D55"), Color(hex: "F4F7FF")),
        (Color(hex: "3C63B8"), Color(hex: "F2D58A")),
        (Color(hex: "8E3FB0"), Color(hex: "FFD9E8"))
    ]
    private static let gold = Color(hex: "E8C27A")

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * min(max(t, 0), 1) }

    /// Horizontal and vertical stretch, opacity, and how far the lid has lifted (0...1).
    private static func look(for gift: FestiveGift) -> (sx: Double, sy: Double, opacity: Double, lid: Double, dy: Double) {
        let age = gift.age
        switch gift.state {
        case .falling:
            return (1, 1, 1, 0, 0)
        case .landed:
            // A quick squash on landing: wide and low, then tall, then settled.
            if age < 0.2 { return (lerp(1.2, 0.92, age / 0.2), lerp(0.75, 1.1, age / 0.2), 1, 0, 0) }
            if age < 0.42 { return (lerp(0.92, 1, (age - 0.2) / 0.22), lerp(1.1, 1, (age - 0.2) / 0.22), 1, 0, 0) }
            return (1, 1, 1, 0, 0)
        case .opening:
            let box: (Double, Double)
            if age < 0.22 { box = (lerp(1, 0.82, age / 0.22), lerp(1, 1.18, age / 0.22)) }
            else if age < 0.45 { box = (lerp(0.82, 1.15, (age - 0.22) / 0.23), lerp(1.18, 0.9, (age - 0.22) / 0.23)) }
            else { box = (lerp(1.15, 1, (age - 0.45) / 0.2), lerp(0.9, 1, (age - 0.45) / 0.2)) }
            let fade = age < 0.7 ? 1 : lerp(1, 0, (age - 0.7) / 0.3)
            return (box.0, box.1, fade, min(age / 0.62, 1), 0)
        case .sinking:
            let t = age / GiftDrops.sinkSeconds
            return (1, 1, 1 - t, 0, 10 * t)
        }
    }

    static func draw(in ctx: inout GraphicsContext, gift: FestiveGift, alpha: Double) {
        let (body, ribbon) = palettes[gift.paletteIndex % palettes.count]
        let look = look(for: gift)

        // A pulsing ring tells you a landed gift can still be tapped.
        if gift.state == .landed {
            let t = (gift.age * 0.9).truncatingRemainder(dividingBy: 1)
            let r = 12 + 14 * t
            ctx.stroke(Path(ellipseIn: CGRect(x: gift.x - r, y: gift.y - r, width: 2 * r, height: 2 * r)),
                       with: .color(gold.opacity(0.9 * (1 - t) * alpha)), lineWidth: 2)
        }

        var c = ctx
        c.opacity = alpha * look.opacity
        c.translateBy(x: gift.x, y: gift.y + look.dy)
        c.rotate(by: .degrees(gift.rotation))
        c.scaleBy(x: 34.0 / 32.0 * look.sx, y: 34.0 / 32.0 * look.sy)
        c.translateBy(x: -16, y: -16)

        let edge = Color.black.opacity(0.25)
        let box = Path(roundedRect: CGRect(x: 5, y: 14, width: 22, height: 15), cornerRadius: 1.5)
        c.fill(box, with: .color(body))
        c.stroke(box, with: .color(edge), lineWidth: 0.6)
        c.fill(Path(CGRect(x: 14, y: 14, width: 4, height: 15)), with: .color(ribbon))

        // The lid and bow lift away, tilting, as the gift opens.
        var lid = c
        lid.opacity = alpha * look.opacity * (1 - look.lid * look.lid)
        lid.translateBy(x: 16, y: 11)
        lid.translateBy(x: 0, y: -34 * look.lid)
        lid.rotate(by: .degrees(-60 * look.lid))
        lid.translateBy(x: -16, y: -11)
        let top = Path(roundedRect: CGRect(x: 3, y: 8, width: 26, height: 6), cornerRadius: 1.5)
        lid.fill(top, with: .color(body))
        lid.stroke(top, with: .color(edge), lineWidth: 0.6)
        lid.fill(Path(CGRect(x: 14, y: 8, width: 4, height: 6)), with: .color(ribbon))
        for side in [-1.0, 1.0] {
            var loop = Path()
            loop.move(to: CGPoint(x: 16, y: 8))
            loop.addCurve(to: CGPoint(x: 16 + side * 6, y: 8), control1: CGPoint(x: 16 + side * 6, y: 0), control2: CGPoint(x: 16 + side * 12, y: 4))
            loop.closeSubpath()
            lid.fill(loop, with: .color(ribbon))
        }
    }

    /// An emoji effect (candy, bells, snowman, star), positioned from how old it is.
    static func drawEmoji(in ctx: inout GraphicsContext, particle p: FestiveEffects.Particle, alpha: Double) {
        let t = min(max(1 - p.life / p.maxLife, 0), 1)
        var x = p.x, y = p.y, scale = 1.0, rotation = p.rotation, opacity = alpha
        switch p.style {
        case .fall:
            opacity *= min(1, p.life * 3)
        case .swing:
            // `rotation` holds the direction (-1 or 1); the bell swings and settles.
            rotation = sin(t * 3 * 2 * .pi) * 0.45 * (1 - t) * p.rotation
            opacity *= t < 0.1 ? t / 0.1 : (t > 0.85 ? (1 - t) / 0.15 : 1)
        case .pop:
            scale = t < 0.3 ? lerp(0.3, 1.15, t / 0.3) : (t < 0.5 ? lerp(1.15, 0.95, (t - 0.3) / 0.2) : lerp(0.95, 1, (t - 0.5) / 0.2))
            y -= 34 * min(1, t / 0.35)
            rotation = t > 0.75 && t < 0.88 ? 0.14 : 0
            opacity *= t < 0.08 ? t / 0.08 : (t > 0.85 ? (1 - t) / 0.15 : 1)
        case .rise:
            // Up to near the top of the screen, then away to the right.
            if t < 0.7 {
                y += p.vy * (1 - pow(1 - t / 0.7, 2))
                scale = lerp(0.3, 1.4, t / 0.25)
            } else {
                let k = (t - 0.7) / 0.3
                y += p.vy; x += p.vx * k
                scale = lerp(1.2, 0.5, k)
                opacity *= 1 - k
            }
            rotation = t * 9
        }
        var c = ctx
        c.opacity = max(0, opacity)
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(rotation))
        c.scaleBy(x: scale, y: scale)
        c.draw(Text(p.text).font(.system(size: p.size)), at: .zero)
    }
}
