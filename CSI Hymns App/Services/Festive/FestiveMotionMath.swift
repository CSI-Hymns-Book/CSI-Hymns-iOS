import Foundation

// Tilt, shake, haptic patterns and snow-cap geometry (pure, no UIKit).

// MARK: - Tilt and shake

public enum FestiveMotionMath {
    /// Re-expresses a reading in the screen's own directions. Sensors report along the phone's
    /// natural (portrait) sides, so a rotated screen swaps the axes; without this a phone held
    /// upright in landscape would read as tilted by 90 degrees. `quarterTurns` follows Android's
    /// `Surface.ROTATION_*` (0 portrait, 1 top-left, 2 upside down, 3 top-right).
    public static func toScreenFrame(x: Double, y: Double, quarterTurns: Int) -> (x: Double, y: Double) {
        switch ((quarterTurns % 4) + 4) % 4 {
        case 1: return (-y, x)
        case 2: return (-x, -y)
        case 3: return (y, -x)
        default: return (x, y)
        }
    }

    /// Side-to-side tilt in degrees from a gravity reading in the "up-pointing" convention
    /// (upright portrait = (0, g, 0)). Positive means the right edge is lower.
    public static func rollDegrees(x: Double, y: Double, z: Double) -> Double {
        -atan2(x, (y * y + z * z).squareRoot()) * 180 / .pi
    }

    /// CoreMotion's gravity points toward the ground; flip it to the up-pointing convention in g.
    public static func upConvention(gravityX: Double, gravityY: Double, gravityZ: Double) -> (x: Double, y: Double, z: Double) {
        (-gravityX, -gravityY, -gravityZ)
    }
}

/// Detects a deliberate shake from raw acceleration in g (gravity included).
public struct FestiveShakeDetector: Sendable {
    public var thresholdG = 2.4
    public var cooldownMillis = 1_500.0
    private var lastShake: Double?

    public init() {}

    public mutating func onAcceleration(x: Double, y: Double, z: Double, atMillis: Double) -> Bool {
        let g = (x * x + y * y + z * z).squareRoot()
        guard g >= thresholdG else { return false }
        if let last = lastShake, atMillis - last < cooldownMillis { return false }
        lastShake = atMillis
        return true
    }
}

// MARK: - Haptics

/// A vibration as (pause, pulse) steps: `timings` are milliseconds, `amplitudes` 0...255 (0 = pause).
public struct HapticPattern: Equatable, Sendable {
    public let timings: [Int]
    public let amplitudes: [Int]
    public var totalMillis: Int { timings.reduce(0, +) }
}

public enum SnowHaptics {
    private static let maxShakeDepth = 4.0

    public static func slide(depth: Double) -> HapticPattern {
        let amplitude = 45 + Int((min(max(depth, 0), 1) * 75).rounded())
        return HapticPattern(timings: [0, 14], amplitudes: [0, amplitude])
    }

    public static func shake(totalDepth: Double) -> HapticPattern {
        let weight = min(max(totalDepth / maxShakeDepth, 0), 1)
        let thump = 110 + Int((weight * 145).rounded())
        let pulses = 3 + Int((weight * 6).rounded())
        var timings = [0, 32]
        var amplitudes = [0, thump]
        var strength = Double(thump)
        for i in 0..<pulses {
            strength *= 0.72
            timings.append(38 + i * 9); amplitudes.append(0)
            timings.append(16); amplitudes.append(min(max(Int(strength.rounded()), 1), 255))
        }
        return HapticPattern(timings: timings, amplitudes: amplitudes)
    }
}

/// Slide ticks: at least `minGapMillis` apart and at most `maxTicksPerWindow` per `windowMillis`,
/// so the motor never buzzes on and on.
public struct SlideHapticThrottle: Sendable {
    public var minGapMillis: Double
    public var maxTicksPerWindow = 5
    public var windowMillis = 4_000.0
    private var recent: [Double] = []

    public init(minGapMillis: Double = 140) { self.minGapMillis = minGapMillis }

    public mutating func tryFire(nowMillis: Double) -> Bool {
        recent.removeAll { nowMillis - $0 >= windowMillis }
        if let last = recent.last, nowMillis - last < minGapMillis { return false }
        if recent.count >= maxTicksPerWindow { return false }
        recent.append(nowMillis)
        return true
    }
}

// MARK: - Snow cap geometry

public enum SnowCapMetrics {
    public static let overhang = 1.0
    public static let height = 20.0
    public static let baseline = 11.0
    public static let moundAboveCard = 3.0
    public static let defaultCorner = 22.0
    public static let slideTiltDegrees = 12.0
    static let maxSlide = 18.0
}

public enum CapCommand: Equatable, Sendable {
    case move(Double, Double)
    case line(Double, Double)
    case quad(cx: Double, cy: Double, x: Double, y: Double)
}

/// Deterministic pseudo-random numbers so a card's cap keeps its shape between frames.
struct SeededRandom {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0x1000000)
    }
}

/// Outline of a snow cap for a card `cardWidth` wide whose corners have radius `corner`. The snow
/// stays inside the card's width: it rises from the rounded corners, forms a lumpy mound along
/// the top and hangs a few icicles, so none of it sticks out into the air beside the card.
public func buildSnowCapOutline(cardWidth: Double, seed: Int, corner: Double = SnowCapMetrics.defaultCorner) -> [CapCommand] {
    var random = SeededRandom(seed: seed)
    let o = SnowCapMetrics.overhang
    let base = SnowCapMetrics.baseline
    let w = cardWidth + 2 * o
    let r = min(max(corner, 0), cardWidth / 2)
    let tipY = min(19.5, base + 0.374 * r)
    let leftTip = o + 0.22 * r
    let rightTip = w - o - 0.22 * r
    let leftShoulder = o + 0.55 * r + 4
    let rightShoulder = w - o - 0.55 * r - 4

    var commands: [CapCommand] = [.move(leftTip, tipY), .quad(cx: o + 0.1 * r, cy: 7, x: leftShoulder, y: 5)]
    var x = leftShoulder
    while x < rightShoulder - 6 {
        let next = min(rightShoulder, x + random.next() * 10 + 12)
        commands.append(.quad(cx: (x + next) / 2, cy: random.next() * 3.5, x: next, y: 4 + random.next() * 2))
        x = next
    }
    commands.append(.quad(cx: w - o - 0.1 * r, cy: 7, x: rightTip, y: tipY))
    commands.append(.quad(cx: rightTip - 2, cy: base, x: rightShoulder, y: base))

    let span = max(rightShoulder - leftShoulder - 16, 0)
    let dripCount = max(2, Int((cardWidth / 70).rounded()))
    let drips = (0..<dripCount).map { _ in leftShoulder + 8 + random.next() * span }.sorted(by: >)
    for dx in drips {
        commands.append(.line(dx + 3.5, base))
        commands.append(.line(dx, base + 4 + random.next() * 4))
        commands.append(.line(dx - 3.5, base))
    }
    commands.append(.line(leftShoulder, base))
    commands.append(.quad(cx: leftTip + 2, cy: base, x: leftTip, y: tipY))
    return commands
}

public struct SnowCapValues: Equatable, Sendable {
    public var depth: Double
    public var slide: Double = 0
    public init(depth: Double, slide: Double = 0) { self.depth = depth; self.slide = slide }
}

public struct SnowCapStep: Equatable, Sendable {
    public var values: SnowCapValues
    public var spillDirection: Int = 0
}

/// Advances a cap by `dt` seconds. Tilting past the slide angle melts it toward the low side and
/// spills clumps; otherwise it slowly builds back up while it is snowing. `roll` is a 0...1 random.
public func advanceSnowCap(_ values: SnowCapValues, dt: Double, tiltDegrees: Double, isSnowing: Bool, roll: Double) -> SnowCapStep {
    let tiltOn = abs(tiltDegrees) > SnowCapMetrics.slideTiltDegrees
    let direction = tiltDegrees > 0 ? 1 : (tiltDegrees < 0 ? -1 : 0)
    var depth = values.depth
    var spill = 0
    if tiltOn && depth > 0.02 {
        let loss = min(depth, dt * 0.9)
        depth -= loss
        if roll < loss * 40 { spill = direction }
    } else if isSnowing {
        depth = min(1, depth + dt * 0.03)
    }
    let target = tiltOn ? Double(direction) * (1 - depth) * SnowCapMetrics.maxSlide : 0
    let eased = values.slide + (target - values.slide) * min(1, dt * 6)
    let slide = abs(target - eased) < 0.05 ? target : eased
    return SnowCapStep(values: SnowCapValues(depth: min(max(depth, 0), 1), slide: slide), spillDirection: spill)
}
