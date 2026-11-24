import SwiftUI

/// Something the per-frame simulation wants the UI layer to know about.
enum FestiveEvent: Sendable {
    case secret(FestiveSecret, message: String?)
    case haptic(HapticPattern)
    case toast(String)
    case giftOpened(GiftSurprise)
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
    enum Kind { case spark, confetti, ring, gift, emoji }
    /// How an emoji particle moves: it falls, swings like a bell, pops up like a jack-in-the-box,
    /// or rises and flies off.
    enum EmojiStyle { case fall, swing, pop, rise }
    final class Particle {
        var kind = Kind.spark
        var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, life = 0.0, maxLife = 1.0, size = 3.0, rotation = 0.0, delay = 0.0
        var colorIndex = 0
        var gravity = 0.0, spin = 0.0
        var text = ""
        var style = EmojiStyle.fall
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


    // MARK: Gift surprises

    /// Confetti thrown from a point, arcing up and falling back down.
    func confettiBurst(x: Double, y: Double, count: Int = 44) {
        for i in 0..<count {
            let p = Particle(); p.kind = .confetti; p.x = x; p.y = y
            p.vx = .random(in: -130...130) * unit; p.vy = .random(in: -260 ... -90) * unit; p.gravity = 380 * unit
            p.maxLife = .random(in: 1.0...1.7); p.life = p.maxLife; p.size = .random(in: 6...10) * unit
            p.colorIndex = i % Self.colors.count; p.rotation = .random(in: 0...6)
            add(p)
        }
    }

    /// A puff of snow where a gift lands.
    func snowPuff(x: Double, y: Double) {
        for _ in 0..<9 {
            let p = Particle(); p.kind = .spark; p.x = x; p.y = y
            let angle = -Double.pi * (0.1 + 0.8 * Double.random(in: 0...1)), speed = Double.random(in: 30...80) * unit
            p.vx = cos(angle) * speed * 1.4; p.vy = sin(angle) * speed
            p.maxLife = .random(in: 0.5...0.8); p.life = p.maxLife; p.size = .random(in: 2...4) * unit; p.colorIndex = 3
            add(p)
        }
    }

    private func emoji(_ text: String, x: Double, y: Double, style: EmojiStyle, size: Double, life: Double, delay: Double = 0) -> Particle {
        let p = Particle(); p.kind = .emoji; p.text = text; p.style = style
        p.x = x; p.y = y; p.size = size * unit; p.maxLife = life; p.life = life; p.delay = delay
        add(p)
        return p
    }

    func candyShower(width: Double, fallTo: Double) {
        for i in 0..<9 {
            let p = emoji("🍭", x: (Double(i) + 0.5) / 9 * width + .random(in: -10...10), y: -20 * unit, style: .fall, size: 24,
                          life: .random(in: 1.1...1.7), delay: Double(i) * 0.07)
            p.vy = max(fallTo, 200) / p.maxLife * 0.9; p.spin = .random(in: -4...4)
        }
    }

    func bells(x: Double, y: Double) {
        for side in [-1.0, 1.0] {
            // `rotation` carries the swing direction for the drawing.
            let bell = emoji("🔔", x: x + side * 18 * unit, y: y - 8 * unit, style: .swing, size: 30, life: 1.5)
            bell.rotation = side
        }
        rings(x: x, y: y)
    }

    func snowman(x: Double, y: Double) {
        _ = emoji("⛄", x: x, y: y, style: .pop, size: 40, life: 2.2)
        sparkle(x: x, y: y - 30 * unit, count: 6)
    }

    func goldStar(x: Double, y: Double, width: Double) {
        let p = emoji("⭐", x: x, y: y, style: .rise, size: 40, life: 1.7)
        p.vx = width * 0.6; p.vy = -(y - 70 * unit)
        sparkle(x: x, y: y - 30 * unit, count: 10)
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
            case .confetti: p.rotation += dt * 6; p.vy += p.gravity * dt
            case .ring: break
            case .emoji: if p.style == .fall { p.rotation += p.spin * dt }
            }
            // Bells, snowmen and stars are positioned from their age when drawn.
            if !(p.kind == .emoji && p.style != .fall) { p.x += p.vx * dt; p.y += p.vy * dt }
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
    private(set) var gifts = GiftDrops()
    private var giftFlightStart: Double?
    private var pendingSurprises: [(at: Double, kind: GiftSurprise, x: Double, y: Double)] = []
    private var screenSize = CGSize.zero
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
        screenSize = size
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
        stepGifts(dt: dt, surfaces: surfaces, height: size.height)

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

    // MARK: Gifts

    /// Gifts drop only on the home screen and lists, never behind lyrics.
    private var giftsAllowed: Bool { eggsEnabled && effectiveLevel != .off && dimRequests == 0 }

    private func stepGifts(dt: Double, surfaces: [FestiveSurface], height: Double) {
        for event in gifts.step(dt: dt, surfaces: surfaces, height: height) {
            if case .landed(let x, let y) = event {
                effects.snowPuff(x: x, y: y)
                if snowHapticsAllowed { onEvent?(.haptic(GiftHaptics.land)) }
            }
        }
        while let next = pendingSurprises.first, next.at <= time {
            pendingSurprises.removeFirst()
            playSurprise(next.kind, x: next.x, y: next.y)
        }
    }

    private func playSurprise(_ kind: GiftSurprise, x: Double, y: Double) {
        switch kind {
        case .confetti: effects.confettiBurst(x: x, y: y)
        case .candy: effects.candyShower(width: screenSize.width, fallTo: screenSize.height)
        case .bells: effects.bells(x: x, y: y)
        case .snowman: effects.snowman(x: min(max(x, 34 * unit), screenSize.width - 34 * unit), y: y)
        case .star: effects.goldStar(x: x, y: y, width: screenSize.width)
        }
    }

    private func openGift(_ gift: FestiveGift) {
        let kind = GiftSurprise.pick(roll: .random(in: 0..<1))
        effects.sparkle(x: gift.x, y: gift.y, count: 10)
        pendingSurprises.append((time + 0.38, kind, gift.x, gift.y))
        if snowHapticsAllowed { onEvent?(.haptic(GiftHaptics.open)) }
        onEvent?(.giftOpened(kind))
    }

    // MARK: Santa and special days

    func santaPose(width: Double) -> SantaPose? {
        guard let start = santaStart else { return nil }
        return SantaFlight.pose(elapsed: time - start, width: width, unit: unit)
    }

    func callSanta() { if santaStart == nil { santaStart = time } }

    /// Starts a gift run when a new flight begins, then lets the flight drop its gifts.
    private func dropGifts(pose: SantaPose) {
        if giftFlightStart != santaStart { giftFlightStart = santaStart; gifts.startFlight() }
        gifts.flight(progress: pose.progress, x: pose.x + 10 * unit, y: pose.y + 8 * unit, allowed: giftsAllowed,
                     paletteSeed: Int.random(in: 0..<GiftDrops.paletteCount))
    }

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
        dropGifts(pose: pose)
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
        if let gift = gifts.open(atX: x, y: y, radius: GiftDrops.tapRadius * unit) {
            openGift(gift)
            return true
        }
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
