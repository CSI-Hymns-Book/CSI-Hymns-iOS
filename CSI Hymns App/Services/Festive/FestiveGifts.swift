import Foundation

// Santa's gift drop: gifts fall from the sleigh, land on the cards (or fall off the screen), and
// open into one of five small surprises when tapped. Pure logic, no UI, so it can be checked in
// `scripts/festive-logic-check` and ported to Android line for line.

/// What a gift turns into when it opens. Odds are out of 100.
enum GiftSurprise: Int, CaseIterable, Sendable {
    case confetti, candy, bells, snowman, star

    var weight: Int {
        switch self {
        case .confetti: return 30
        case .candy: return 25
        case .bells: return 20
        case .snowman: return 15
        case .star: return 10
        }
    }

    var title: String {
        switch self {
        case .confetti: return "Confetti pop"
        case .candy: return "Candy-cane shower"
        case .bells: return "Jingle rings"
        case .snowman: return "Pop-up snowman"
        case .star: return "Golden star"
        }
    }

    /// `roll` is a random number in 0..<1; each surprise owns a slice as wide as its weight.
    static func pick(roll: Double) -> GiftSurprise {
        var point = Int(min(max(roll, 0), 0.999_999) * 100)
        for surprise in allCases {
            if point < surprise.weight { return surprise }
            point -= surprise.weight
        }
        return .confetti
    }
}

enum GiftHaptics {
    /// A soft double tap when a gift opens.
    static let open = HapticPattern(timings: [0, 18, 70, 18], amplitudes: [0, 150, 0, 230])
    /// A small thud when a gift lands on a card.
    static let land = HapticPattern(timings: [0, 16], amplitudes: [0, 110])
}

/// How many gifts open the "Gift collector" secret.
let giftCollectorGoal = 5

enum GiftState: Sendable { case falling, landed, opening, sinking }

struct FestiveGift: Sendable {
    let id: Int
    var x: Double
    var y: Double
    var vx: Double
    var vy = 0.0
    /// Sway while falling, in degrees.
    var rotation = 0.0
    var phase: Double
    var age = 0.0
    var state = GiftState.falling
    var surfaceKey: UUID?
    var paletteIndex: Int
}

enum GiftEvent: Equatable, Sendable {
    case landed(x: Double, y: Double)
}

struct GiftDrops: Sendable {
    /// Santa drops a gift each time his flight passes one of these fractions. The sleigh is on
    /// screen for roughly the first 0.63 of the flight, so all three drops fall inside it.
    static let dropPoints = [0.22, 0.38, 0.54]
    /// Never more than this many gifts on screen at once.
    static let maxGifts = 4
    static let halfSize = 14.0
    /// A landed gift waits this long before it sinks into the snow, so a miss is still tappable.
    static let landedGrace = 3.2
    static let sinkSeconds = 0.5
    static let openSeconds = 1.0
    static let tapRadius = 30.0
    static let paletteCount = 4

    private(set) var gifts: [FestiveGift] = []
    private var nextId = 0
    private var droppedPoints = Set<Int>()

    var isEmpty: Bool { gifts.isEmpty }

    /// Call when a new sleigh flight begins.
    mutating func startFlight() { droppedPoints = [] }

    /// Call every frame of the flight. Drops a gift at (x, y) when the flight crosses a drop point
    /// and `allowed` is true. A drop point that is skipped is not made up for later.
    mutating func flight(progress: Double, x: Double, y: Double, allowed: Bool, paletteSeed: Int = 0) {
        for (index, point) in Self.dropPoints.enumerated() where progress >= point && !droppedPoints.contains(index) {
            droppedPoints.insert(index)
            guard allowed, gifts.count < Self.maxGifts else { continue }
            gifts.append(FestiveGift(id: nextId, x: x, y: y, vx: 70, phase: Double(nextId) * 1.7,
                                     paletteIndex: (nextId + paletteSeed) % Self.paletteCount))
            nextId += 1
        }
    }

    /// Advances every gift. A falling gift lands on the highest surface it crosses; a landed gift
    /// rides its card as the list scrolls and falls again if the card goes away.
    mutating func step(dt: Double, surfaces: [FestiveSurface], height: Double) -> [GiftEvent] {
        var events: [GiftEvent] = []
        var kept: [FestiveGift] = []
        for var gift in gifts {
            gift.age += dt
            switch gift.state {
            case .falling:
                let previousBottom = gift.y + Self.halfSize
                gift.vy = min(gift.vy + 150 * dt, 120)
                gift.vx *= pow(0.35, dt)
                gift.phase += dt * 2.6
                gift.x += (gift.vx + sin(gift.phase) * 26) * dt
                gift.y += gift.vy * dt
                gift.rotation = sin(gift.phase) * 14
                if let surface = Self.landingSurface(x: gift.x, previousBottom: previousBottom, bottom: gift.y + Self.halfSize, in: surfaces) {
                    gift.state = .landed
                    gift.surfaceKey = surface.key
                    gift.y = surface.top - Self.halfSize
                    gift.vx = 0; gift.vy = 0; gift.age = 0
                    events.append(.landed(x: gift.x, y: surface.top))
                } else if gift.y > height + 40 {
                    continue
                }
            case .landed:
                if let key = gift.surfaceKey, let surface = surfaces.first(where: { $0.key == key }) {
                    gift.y = surface.top - Self.halfSize
                } else {
                    gift.state = .falling; gift.surfaceKey = nil; gift.vy = 0
                }
                gift.rotation *= pow(0.02, dt)
                if gift.age > Self.landedGrace { gift.state = .sinking; gift.age = 0 }
            case .sinking:
                if gift.age > Self.sinkSeconds { continue }
            case .opening:
                if gift.age > Self.openSeconds { continue }
            }
            kept.append(gift)
        }
        gifts = kept
        return events
    }

    /// The nearest falling or landed gift within `radius` of the tap starts opening and is returned.
    mutating func open(atX x: Double, y: Double, radius: Double = tapRadius) -> FestiveGift? {
        var best: (index: Int, distance: Double)?
        for (index, gift) in gifts.enumerated() where gift.state == .falling || gift.state == .landed {
            let distance = hypot(gift.x - x, gift.y - y)
            if distance <= radius, distance < (best?.distance ?? .infinity) { best = (index, distance) }
        }
        guard let hit = best else { return nil }
        gifts[hit.index].state = .opening
        gifts[hit.index].age = 0
        return gifts[hit.index]
    }

    mutating func clear() { gifts = [] }

    private static func landingSurface(x: Double, previousBottom: Double, bottom: Double, in surfaces: [FestiveSurface]) -> FestiveSurface? {
        surfaces
            .filter { x >= $0.left && x <= $0.right && previousBottom <= $0.top + 6 && bottom >= $0.top }
            .min { $0.top < $1.top }
    }
}
