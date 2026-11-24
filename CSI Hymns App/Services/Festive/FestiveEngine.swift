import Foundation

/// A card (or other element) top edge that snow can land on, in screen points.
struct FestiveSurface {
    let key: UUID
    let left: Double
    let right: Double
    let top: Double
}

/// Snow particle simulation: three depth layers falling with gusts and tilt drift, flakes that land
/// on registered surfaces, settled flakes, falling chunks and drifting emoji. Deliberately mutable
/// reference types: it is stepped every frame and must not allocate.
final class FestiveSnowEngine: @unchecked Sendable {
    struct Layer {
        let count: Int
        let minRadius, maxRadius, minSpeed, maxSpeed, minAlpha, maxAlpha, windFactor: Double
        let isFlake: Bool
    }

    static let layers: [Layer] = [
        Layer(count: 70, minRadius: 0.6, maxRadius: 1.1, minSpeed: 12, maxSpeed: 20, minAlpha: 0.22, maxAlpha: 0.40, windFactor: 0.35, isFlake: false),
        Layer(count: 46, minRadius: 1.1, maxRadius: 1.9, minSpeed: 22, maxSpeed: 34, minAlpha: 0.35, maxAlpha: 0.55, windFactor: 0.65, isFlake: false),
        Layer(count: 24, minRadius: 3.6, maxRadius: 6.2, minSpeed: 38, maxSpeed: 56, minAlpha: 0.40, maxAlpha: 0.70, windFactor: 1, isFlake: true)
    ]
    static let emojis = ["🎄", "⭐", "🎁", "🔔", "❄️", "🦌", "⛄", "🕯️"]

    final class Particle {
        var x = 0.0, y = 0.0, radius = 0.0, speed = 0.0, alpha = 0.0, phase = 0.0, rotation = 0.0
        var layer = 0
        var rank = 0.0
    }
    final class Settled { var x = 0.0, y = 0.0, radius = 0.0, alpha = 0.0, life = 0.0, age = 0.0, rotation = 0.0; var isFlake = false; var key = UUID() }
    final class Chunk { var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, radius = 0.0, life = 0.0 }
    final class Drifter {
        var emoji = "", x = 0.0, y = 0.0, speed = 0.0, phase = 0.0, hiddenSeconds = 0.0
        var isHidden: Bool { hiddenSeconds > 0 }
    }

    private(set) var particles: [Particle] = []
    private(set) var settled: [Settled] = []
    private(set) var chunks: [Chunk] = []
    private(set) var drifters: [Drifter] = []
    private(set) var width = 0.0, height = 0.0, unit = 1.0, time = 0.0
    var onAbsorb: ((UUID) -> Void)?

    static let maxSettled = 90, maxChunks = 260
    /// Same threshold as the snow caps: past this the phone counts as tilted.
    static let slideTiltDegrees = 12.0
    /// How visible a settled flake is: it fades in over a quarter second after landing (so it does
    /// not pop into view) and fades out over its last two seconds.
    static func settledFade(age: Double, life: Double) -> Double {
        min(1, max(0, age) / 0.25) * min(1, max(0, life) / 2)
    }

    private let landChance = 0.55, gravity = 520.0, settledSlide = 4.0

    func resize(width: Double, height: Double, unit: Double) {
        guard width > 0, height > 0, abs(width - self.width) > 0.5 || abs(height - self.height) > 0.5 else { return }
        self.width = width; self.height = height; self.unit = unit
        if particles.isEmpty { build() }
        for p in particles { p.x = min(p.x, width); p.y = min(p.y, height) }
    }

    private func build() {
        for (index, layer) in Self.layers.enumerated() {
            for i in 0..<layer.count {
                let p = Particle()
                p.layer = index
                p.rank = Double(i) / Double(layer.count)
                p.radius = .random(in: layer.minRadius...layer.maxRadius)
                p.speed = .random(in: layer.minSpeed...layer.maxSpeed)
                p.alpha = .random(in: layer.minAlpha...layer.maxAlpha)
                p.phase = .random(in: 0...(2 * .pi))
                p.rotation = .random(in: 0...(2 * .pi))
                p.x = .random(in: 0...width); p.y = .random(in: 0...height)
                particles.append(p)
            }
        }
        for slot in 0..<Self.emojis.count {
            let d = Drifter()
            d.emoji = Self.emojis[slot]
            d.x = .random(in: 0.05...0.95); d.y = .random(in: 0...1)
            d.speed = .random(in: 14...24); d.phase = .random(in: 0...(2 * .pi))
            drifters.append(d)
        }
    }

    func isVisible(_ p: Particle, density: Double) -> Bool { p.rank < density }

    func step(dt: Double, density: Double, tilt: Double, flurry: Bool, surfaces: [FestiveSurface]) {
        guard width > 0 else { return }
        time += dt
        // While the phone is tilted nothing new settles: snow should be sliding off, not piling up.
        let tiltOn = abs(tilt) > Self.slideTiltDegrees
        let gust = sin(time * 0.35) * 8 + sin(time * 0.9) * 4 + (flurry ? 80 : 0)
        let fall = flurry ? 2.3 : 1.0
        for p in particles where isVisible(p, density: density) {
            let layer = Self.layers[p.layer]
            let previousY = p.y
            p.y += p.speed * fall * unit * dt
            p.x += ((gust + tilt * 1.6) * layer.windFactor + sin(p.phase + time * 0.8) * 6 * layer.windFactor) * unit * dt
            p.rotation += dt * 0.6
            if p.layer > 0, !tiltOn, !surfaces.isEmpty {
                for s in surfaces where p.x > s.left + 8 * unit && p.x < s.right - 8 * unit && previousY < s.top && p.y >= s.top {
                    if Double.random(in: 0...1) < landChance { land(p, on: s); break }
                }
            }
            if p.y > height + 10 { p.y = -10; p.x = .random(in: 0...width) }
            if p.x > width + 10 { p.x = -10 } else if p.x < -10 { p.x = width + 10 }
        }
        stepSettled(dt: dt, tilt: tilt, surfaces: surfaces)
        stepChunks(dt: dt, tilt: tilt)
        for d in drifters {
            if d.hiddenSeconds > 0 { d.hiddenSeconds = max(0, d.hiddenSeconds - dt) }
            d.y += d.speed * unit * dt / height
            d.x += sin(time * 0.5 + d.phase) * 0.01 * dt
            if d.y > 1.05 { d.y = -0.05; d.x = .random(in: 0.05...0.95) }
        }
    }

    private func land(_ p: Particle, on surface: FestiveSurface) {
        if settled.count < Self.maxSettled {
            let s = Settled()
            s.x = p.x; s.y = surface.top; s.key = surface.key
            s.isFlake = Self.layers[p.layer].isFlake
            s.radius = s.isFlake ? p.radius * 0.7 : max(1.3 * unit, p.radius)
            s.alpha = p.alpha; s.life = .random(in: 2.5...6); s.rotation = p.rotation
            settled.append(s)
        } else {
            onAbsorb?(surface.key)
        }
        p.y = -10; p.x = .random(in: 0...width)
    }

    /// Settled flakes ride along with their card (it may scroll), slide downhill when the phone
    /// is tilted and tumble off the edge as chunks, or melt into the card's snow cap.
    private func stepSettled(dt: Double, tilt: Double, surfaces: [FestiveSurface]) {
        let tiltOn = abs(tilt) > Self.slideTiltDegrees
        var byKey: [UUID: FestiveSurface] = [:]
        for s in surfaces { byKey[s.key] = s }
        var i = 0
        while i < settled.count {
            let s = settled[i]
            guard let surface = byKey[s.key] else { settled.remove(at: i); continue }
            s.y = surface.top
            if tiltOn {
                s.x += tilt * settledSlide * unit * dt
                let margin = 6 * unit
                if s.x < surface.left - margin || s.x > surface.right + margin {
                    spawnChunk(x: s.x, y: s.y, vx: tilt * 3 * unit, vy: -10 * unit, radius: s.radius)
                    settled.remove(at: i)
                    continue
                }
            }
            s.life -= dt
            s.age += dt
            if s.life <= 0 {
                onAbsorb?(s.key)
                settled.remove(at: i)
            } else {
                i += 1
            }
        }
    }

    private func stepChunks(dt: Double, tilt: Double) {
        var i = 0
        while i < chunks.count {
            let c = chunks[i]
            c.life -= dt; c.vy += gravity * unit * dt; c.vx += tilt * 3 * unit * dt
            c.x += c.vx * dt; c.y += c.vy * dt
            if c.life <= 0 || c.y > height + 20 { chunks.remove(at: i) } else { i += 1 }
        }
    }

    /// A few clumps tumble off the edge a tilted card slid snow toward.
    func spill(from surface: FestiveSurface, direction: Double) {
        let x = direction > 0 ? surface.right - 6 * unit : surface.left + 6 * unit
        spawnChunk(x: x, y: surface.top, vx: direction * 30 * unit, vy: -10 * unit, radius: .random(in: 1.4...3.2) * unit)
    }

    /// A shake knocks the whole pile off: pieces burst up and fall.
    func knockOff(_ surface: FestiveSurface, depth: Double) {
        let pieces = Int((16 * max(depth, 0.2)).rounded())
        for _ in 0..<pieces {
            spawnChunk(
                x: .random(in: surface.left...max(surface.left + 1, surface.right)), y: surface.top,
                vx: .random(in: -60...60) * unit, vy: .random(in: -120 ... -40) * unit,
                radius: .random(in: 1.4...3.2) * unit
            )
        }
        settled.removeAll { $0.key == surface.key }
    }

    private func spawnChunk(x: Double, y: Double, vx: Double, vy: Double, radius: Double) {
        guard chunks.count < Self.maxChunks else { return }
        let c = Chunk(); c.x = x; c.y = y; c.vx = vx; c.vy = vy; c.radius = radius; c.life = 2.2
        chunks.append(c)
    }

    /// Pops the first of the `visibleCount` emoji within `radius` of the tap (hidden for 2.2s).
    func popEmoji(atX x: Double, y: Double, radius: Double, visibleCount: Int) -> (x: Double, y: Double)? {
        for d in drifters.prefix(visibleCount) where !d.isHidden {
            let dx = d.x * width - x, dy = d.y * height - y
            if dx * dx + dy * dy <= radius * radius {
                d.hiddenSeconds = 2.2
                return (d.x * width, d.y * height)
            }
        }
        return nil
    }
}
