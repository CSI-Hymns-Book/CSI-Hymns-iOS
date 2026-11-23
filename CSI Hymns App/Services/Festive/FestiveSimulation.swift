import SwiftUI

/// Something the per-frame simulation wants the UI layer to know about.
enum FestiveEvent: Sendable {
    case secret(FestiveSecret, message: String?)
    case haptic(HapticPattern)
    case toast(String)
}

/// One snow pile on a card: its screen frame, its depth and how far it has slid sideways.
final class FestiveCapModel: @unchecked Sendable {
    let key = UUID()
    let seed = Int.random(in: 0..<10_000)
    var frame = CGRect.zero
    var values: SnowCapValues
    var visible = true
    init(initialDepth: Double) { values = SnowCapValues(depth: initialDepth) }
}

/// Short-lived sparkles, confetti, gifts and rings (easter eggs and special days).
final class FestiveEffects: @unchecked Sendable {
    enum Kind { case spark, confetti, ring, gift }
    final class Particle {
        var kind = Kind.spark
        var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, life = 0.0, maxLife = 1.0, size = 3.0, rotation = 0.0, delay = 0.0
        var colorIndex = 0
    }
    static let colors: [Color] = [
        Color(hex: "FFD27A"), Color(hex: "FF6B5E"), Color(hex: "7BE0A0"), .white, Color(hex: "9CC8FF")
    ]
    private(set) var particles: [Particle] = []
    var unit = 1.0
    var isEmpty: Bool { particles.isEmpty }
    private let maxParticles = 600

    private func add(_ p: Particle) { if particles.count < maxParticles { particles.append(p) } }

    func sparkle(x: Double, y: Double, count: Int) {
        for _ in 0..<count {
            let p = Particle(); p.kind = .spark; p.x = x; p.y = y
            let angle = Double.random(in: 0...(2 * .pi)), speed = Double.random(in: 30...120) * unit
            p.vx = cos(angle) * speed; p.vy = sin(angle) * speed
            p.maxLife = .random(in: 0.5...1.1); p.life = p.maxLife; p.size = .random(in: 1.5...3.5) * unit
            p.colorIndex = [0, 3, 0, 4].randomElement()!
            add(p)
        }
    }

    func confetti(width: Double) {
        for _ in 0..<90 {
            let p = Particle(); p.kind = .confetti
            p.x = .random(in: 0...width); p.y = -10 * unit
            p.vx = .random(in: -30...30) * unit; p.vy = .random(in: 80...220) * unit
            p.maxLife = .random(in: 2.5...4); p.life = p.maxLife; p.size = .random(in: 5...9) * unit
            p.colorIndex = Int.random(in: 0..<Self.colors.count); p.rotation = .random(in: 0...6)
            add(p)
        }
    }

    func rings(x: Double, y: Double) {
        for i in 0..<3 {
            let p = Particle(); p.kind = .ring; p.x = x; p.y = y
            p.delay = Double(i) * 0.22; p.maxLife = 0.9; p.life = 0.9; p.size = 4 * unit; p.colorIndex = 0
            add(p)
        }
    }

    func gifts(x: Double, y: Double) {
        for _ in 0..<3 {
            let p = Particle(); p.kind = .gift; p.x = x; p.y = y
            p.vx = .random(in: -50...50) * unit; p.vy = .random(in: -90 ... -30) * unit
            p.maxLife = 2.4; p.life = 2.4; p.size = 22 * unit
            add(p)
        }
    }

    /// A firework: a ring of sparks (New Year).
    func burst(x: Double, y: Double) {
        for i in 0..<36 {
            let p = Particle(); p.kind = .spark; p.x = x; p.y = y
            let angle = Double(i) / 36 * 2 * .pi, speed = Double.random(in: 60...150) * unit
            p.vx = cos(angle) * speed; p.vy = sin(angle) * speed
            p.maxLife = 1.3; p.life = 1.3; p.size = 2.5 * unit; p.colorIndex = Int.random(in: 0..<Self.colors.count)
            add(p)
        }
    }

    func step(dt: Double) {
        var i = 0
        while i < particles.count {
            let p = particles[i]
            if p.delay > 0 { p.delay -= dt; i += 1; continue }
            p.life -= dt
            switch p.kind {
            case .spark: p.vy += 90 * unit * dt
            case .gift: p.vy += 260 * unit * dt
            case .confetti: p.rotation += dt * 6
            case .ring: break
            }
            p.x += p.vx * dt; p.y += p.vy * dt
            if p.life <= 0 { particles.remove(at: i) } else { i += 1 }
        }
    }
}

/// All per-frame Christmas state: snow, caps, Santa, effects, tilt. A plain (non-isolated) class
/// because the Canvas renderer calls it from outside the main actor; the UI layer talks to it
/// through `FestiveAmbience`.
final class FestiveSimulation: @unchecked Sendable {
    let engine = FestiveSnowEngine()
    let effects = FestiveEffects()
    var level = FestiveEffectsLevel.default
    var reduceMotion = false
    var eggsEnabled = true
    var moment = FestiveMoment.none
    var onEvent: (@Sendable (FestiveEvent) -> Void)?

    private(set) var tilt = 0.0
    private(set) var snowAlpha = 1.0
    private(set) var shakeGeneration = 0
    var rawTilt = 0.0
    var dimRequests = 0
    var darkSkyBehind = false

    private(set) var caps: [UUID: FestiveCapModel] = [:]
    private var lastFrame: Date?
    private var flurryUntil = -1.0
    private var santaStart: Double?
    private var nextSantaAt = 18.0
    private var nextFireworkAt = 0.0
    private var slideThrottle = SlideHapticThrottle(minGapMillis: 140)
    private var tiltAnnounced = false
    private var unit = 1.0

    var effectiveLevel: FestiveEffectsLevel { reduceMotion ? .off : level }
    /// Snow buzzes only on the home and list screens. Reading screens (lyrics, carols) dim the
    /// snow, and there the phone stays still so it never interrupts someone singing.
    var snowHapticsAllowed: Bool { dimRequests == 0 }
    var isSnowing: Bool { effectiveLevel != .off || time < flurryUntil }
    var time: Double { engine.time }
    var isActive: Bool { effectiveLevel != .off || !effects.isEmpty }

    init() {
        engine.onAbsorb = { [weak self] key in
            guard let cap = self?.caps[key] else { return }
            cap.values.depth = min(1, cap.values.depth + 0.012)
        }
    }

    // MARK: Caps

    func register(_ cap: FestiveCapModel) { caps[cap.key] = cap }
    func unregister(_ cap: FestiveCapModel) { caps[cap.key] = nil }

    private func surface(for cap: FestiveCapModel) -> FestiveSurface? {
        guard cap.visible, !cap.frame.isEmpty else { return nil }
        let lift = SnowCapMetrics.moundAboveCard * unit * cap.values.depth
        return FestiveSurface(key: cap.key, left: cap.frame.minX, right: cap.frame.maxX, top: cap.frame.minY - lift)
    }

    // MARK: Frame

    func advance(now: Date, size: CGSize, unit: Double) {
        let dt = min(max(lastFrame.map { now.timeIntervalSince($0) } ?? 0, 0), 0.05)
        lastFrame = now
        self.unit = unit
        effects.unit = unit
        engine.resize(width: size.width, height: size.height, unit: unit)

        tilt += (rawTilt - tilt) * min(1, dt * 5)
        let alphaTarget = dimRequests > 0 ? 0.5 : 1.0
        snowAlpha += (alphaTarget - snowAlpha) * min(1, dt * 4)

        // Every visible card is a surface, even one whose pile just slid off, so flakes resting on
        // it keep sliding with the tilt instead of vanishing.
        let surfaces = caps.values.compactMap { surface(for: $0) }
        engine.step(dt: dt, density: effectiveLevel.snowDensity, tilt: tilt, flurry: time < flurryUntil, surfaces: surfaces)
        if effectiveLevel != .off { stepCaps(dt: dt) }
        effects.step(dt: dt)

        if abs(rawTilt) > SnowCapMetrics.slideTiltDegrees, !tiltAnnounced, eggsEnabled {
            tiltAnnounced = true
            onEvent?(.secret(.tilt, message: nil))
        }
        if effectiveLevel != .off { advanceSanta(size: size); launchFireworks(width: size.width) }
    }

    private func stepCaps(dt: Double) {
        for cap in caps.values where cap.visible {
            let step = advanceSnowCap(cap.values, dt: dt, tiltDegrees: tilt, isSnowing: isSnowing, roll: .random(in: 0...1))
            cap.values = step.values
            guard step.spillDirection != 0, let s = surface(for: cap) else { continue }
            engine.spill(from: s, direction: Double(step.spillDirection))
            if snowHapticsAllowed, slideThrottle.tryFire(nowMillis: time * 1000) {
                onEvent?(.haptic(SnowHaptics.slide(depth: cap.values.depth)))
            }
        }
    }

    /// A shake knocks every visible pile off and starts a short flurry.
    func shake() {
        guard effectiveLevel != .off else { return }
        shakeGeneration += 1
        var total = 0.0
        for cap in caps.values where cap.visible {
            total += cap.values.depth
            if let s = surface(for: cap) { engine.knockOff(s, depth: cap.values.depth) }
            cap.values.depth = 0
        }
        flurryUntil = time + 5
        if snowHapticsAllowed { onEvent?(.haptic(SnowHaptics.shake(totalDepth: total))) }
        if eggsEnabled { onEvent?(.secret(.shake, message: nil)) }
    }

    func resetTiltAnnouncement() { tiltAnnounced = false }

    // MARK: Santa and special days

    func santaPose(width: Double) -> SantaPose? {
        guard let start = santaStart else { return nil }
        return SantaFlight.pose(elapsed: time - start, width: width, unit: unit)
    }

    func callSanta() { if santaStart == nil { santaStart = time } }

    private func advanceSanta(size: CGSize) {
        guard let start = santaStart else {
            if time >= nextSantaAt { santaStart = time }
            return
        }
        guard let pose = SantaFlight.pose(elapsed: time - start, width: size.width, unit: unit) else {
            santaStart = nil
            nextSantaAt = time + .random(in: 60...90)
            return
        }
        if Double.random(in: 0...1) < 0.5 { effects.sparkle(x: pose.x - 18 * unit, y: pose.y + 4 * unit, count: 1) }
    }

    private func launchFireworks(width: Double) {
        guard moment == .newYear, time >= nextFireworkAt, width > 0 else { return }
        effects.burst(x: .random(in: width * 0.2...width * 0.8), y: .random(in: 120...330) * unit)
        nextFireworkAt = time + .random(in: 0.8...1.6)
    }

    func setEarlySanta() { nextSantaAt = 4 }

    // MARK: Taps

    /// A tap anywhere: catches Santa, or pops a drifting emoji. Returns true when it did.
    func handleTap(x: Double, y: Double, width: Double) -> Bool {
        guard eggsEnabled, effectiveLevel != .off else { return false }
        if let pose = santaPose(width: width), SantaFlight.isHit(pose, x: x, y: y, unit: unit) {
            effects.gifts(x: pose.x, y: pose.y)
            onEvent?(.secret(.santa, message: "🎅 Ho ho ho! You caught Santa"))
            return true
        }
        if let popped = engine.popEmoji(atX: x, y: y, radius: 24 * unit, visibleCount: effectiveLevel.emojiCount) {
            effects.sparkle(x: popped.x, y: popped.y, count: 18)
            onEvent?(.secret(.pop, message: nil))
            return true
        }
        return false
    }
}
