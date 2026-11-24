import Foundation

// Pure Foundation logic for the Christmas ("festive") mode: no UIKit/SwiftUI so it can be
// verified quickly with `scripts/festive-logic-check`.

// MARK: - Effects level

/// How much Christmas motion the user wants. Stored in UserDefaults as `rawValue`.
public enum FestiveEffectsLevel: String, CaseIterable, Sendable {
    case off = "OFF"
    case gentle = "GENTLE"

    public static let storageKey = "christmas_effects"
    public static let `default`: FestiveEffectsLevel = .gentle

    /// Share of snow particles drawn (0...1).
    public var snowDensity: Double { self == .off ? 0 : 0.3 }
    /// How many drifting emoji easter eggs fall with the snow.
    public var emojiCount: Int { self == .off ? 0 : 2 }
    public var label: String { self == .off ? "Off" : "Gentle" }
    public var detail: String {
        self == .off
            ? "No snow or moving effects"
            : "Light snowfall, snow piles on cards, tilt, shake and Santa"
    }

    /// Unknown or missing values fall back to Gentle; the retired "FULL" reads as Gentle.
    public static func fromKey(_ key: String?) -> FestiveEffectsLevel {
        guard let key, let level = FestiveEffectsLevel(rawValue: key) else { return .default }
        return level
    }
}

// MARK: - Christmas mode resolution

/// Decides whether Christmas mode is on. What the user chose on this phone always wins; otherwise
/// the server's setting, then the last server setting we saw (offline), then the calendar season.
public enum ChristmasModeResolver {
    public static func resolve(manual: Bool?, remote: Bool?, cachedRemote: Bool?, season: Bool) -> Bool {
        manual ?? remote ?? cachedRemote ?? season
    }
}

// MARK: - Secrets

public enum FestiveSecret: String, CaseIterable, Sendable {
    case star, bell, snowman, pop, lights, shake, tilt, santa, gifts

    public var hint: String {
        switch self {
        case .star: return "Tap the star 7 times"
        case .bell: return "Ring the hanging bell"
        case .snowman: return "Tap the snow at the bottom-left 3 times"
        case .pop: return "Tap a drifting emoji"
        case .lights: return "Press and hold “Merry Christmas”"
        case .shake: return "Shake the phone"
        case .tilt: return "Tilt the phone"
        case .santa: return "Tap Santa’s sleigh as it flies past"
        case .gifts: return "Open five of the gifts Santa drops"
        }
    }

    public static func fromStored(_ names: [String]) -> Set<FestiveSecret> {
        Set(names.compactMap { FestiveSecret(rawValue: $0) })
    }
}

public enum StarTapResult: Equatable, Sendable { case tap, hint, shootingStar }

/// Counts quick taps on the Star of Bethlehem: a hint at 4, the shooting star at 7.
public struct StarTapCounter: Sendable {
    public var windowSeconds = 2.5
    public var hintAt = 4
    public var triggerAt = 7
    private var count = 0
    private var lastTap: Double?

    public init() {}

    public mutating func tap(now: Double) -> StarTapResult {
        if let last = lastTap, now - last > windowSeconds { count = 0 }
        if lastTap == nil { count = 0 }
        lastTap = now
        count += 1
        if count >= triggerAt { count = 0; return .shootingStar }
        if count == hintAt { return .hint }
        return .tap
    }
}

// MARK: - Calendar

public enum FestiveMoment: Equatable, Sendable { case none, christmasEve, christmasDay, newYear, epiphany }

public enum FestiveCalendar {
    /// A Gregorian calendar in `timeZone`. It is built on every call and defaults to the auto-updating
    /// current zone: a calendar stored once keeps the zone it was created in, so it would show the
    /// wrong day after travelling, a zone change or daylight saving.
    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    public static func moment(for date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> FestiveMoment {
        let c = calendar(timeZone).dateComponents([.month, .day], from: date)
        switch (c.month ?? 0, c.day ?? 0) {
        case (12, 24): return .christmasEve
        case (12, 25): return .christmasDay
        case (1, 1): return .newYear
        case (1, 6): return .epiphany
        default: return .none
        }
    }

    /// Dec 25 through Jan 5.
    public static func isChristmastide(_ date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> Bool {
        let c = calendar(timeZone).dateComponents([.month, .day], from: date)
        guard let m = c.month, let d = c.day else { return false }
        return (m == 12 && d >= 25) || (m == 1 && d <= 5)
    }

    /// Whole calendar days from the local date of `date` to the next 25 December (0 on the day itself;
    /// from the 26th it counts to next year's). Calendar days, not 24-hour spans, so a daylight-saving
    /// change never shifts the number.
    public static func daysToChristmas(from date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> Int {
        let cal = calendar(timeZone)
        let today = cal.startOfDay(for: date)
        let year = cal.component(.year, from: date)
        var target = cal.date(from: DateComponents(year: year, month: 12, day: 25))!
        if today > target { target = cal.date(from: DateComponents(year: year + 1, month: 12, day: 25))! }
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    public static func countdownLabel(_ date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let n = daysToChristmas(from: date, in: timeZone)
        return n == 1 ? "1 day to Christmas" : "\(n) days to Christmas"
    }

    /// The Sunday that starts Advent: three weeks before the last Sunday on or before 24 December.
    public static func adventStart(year: Int, in timeZone: TimeZone = .autoupdatingCurrent) -> Date {
        let cal = calendar(timeZone)
        let eve = cal.date(from: DateComponents(year: year, month: 12, day: 24))!
        let weekday = cal.component(.weekday, from: eve) // Sunday = 1
        let lastSunday = cal.date(byAdding: .day, value: -(weekday - 1), to: eve)!
        return cal.date(byAdding: .day, value: -21, to: lastSunday)!
    }

    public static func adventLabel(_ date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> String {
        if isChristmastide(date, in: timeZone) { return "Christmastide" }
        let cal = calendar(timeZone)
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        guard month >= 10 else { return "" }
        let start = adventStart(year: year, in: timeZone)
        let day = cal.startOfDay(for: date)
        if day < start {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = timeZone
            f.dateFormat = "EEE d MMM"
            return "Advent begins \(f.string(from: start))"
        }
        return "Advent season"
    }

    public static func chipLabel(_ date: Date, in timeZone: TimeZone = .autoupdatingCurrent) -> String {
        switch moment(for: date, in: timeZone) {
        case .christmasEve: return "Christmas Eve"
        case .christmasDay: return "Christmas Day"
        case .newYear: return "Happy New Year"
        case .epiphany: return "Epiphany"
        case .none: return isChristmastide(date, in: timeZone) ? "Christmastide" : countdownLabel(date, in: timeZone)
        }
    }
}

// MARK: - Shepherds

/// A new shepherd sets off every `gapSeconds`, each taking `walkSeconds` to cross, so at most two show.
public enum ShepherdWalk {
    public static let firstStartSeconds = 3.0
    public static let gapSeconds = 14.0
    public static let walkSeconds = 26.0
    public static let variants = 3

    public struct Walker: Equatable, Sendable {
        public let index: Int
        public let progress: Double
        public var variant: Int { index % ShepherdWalk.variants }
    }

    public static func walkers(at seconds: Double) -> [Walker] {
        guard seconds >= firstStartSeconds else { return [] }
        let newest = Int((seconds - firstStartSeconds) / gapSeconds)
        let oldest = max(0, newest - Int((walkSeconds / gapSeconds).rounded(.up)))
        return (oldest...newest).compactMap { index in
            let progress = (seconds - (firstStartSeconds + Double(index) * gapSeconds)) / walkSeconds
            return (0...1).contains(progress) ? Walker(index: index, progress: progress) : nil
        }
    }
}

// MARK: - Santa

public struct SantaPose: Equatable, Sendable { public let x: Double; public let y: Double; public let progress: Double }

public enum SantaFlight {
    public static let durationSeconds = 11.0

    /// `unit` is points per design unit (screen density factor).
    public static func pose(elapsed: Double, width: Double, unit: Double) -> SantaPose? {
        let p = elapsed / durationSeconds
        guard p >= 0, p <= 1 else { return nil }
        let x = -150 * unit + p * (width + 470 * unit)
        let y = (100 - 44 * p + 9 * sin(elapsed * 3.1)) * unit
        return SantaPose(x: x, y: y, progress: p)
    }

    public static func isHit(_ pose: SantaPose, x: Double, y: Double, unit: Double) -> Bool {
        x >= pose.x - 25 * unit && x <= pose.x + 135 * unit && abs(y - pose.y) <= 26 * unit
    }
}
