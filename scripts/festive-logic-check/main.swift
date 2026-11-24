import Foundation

// Quick logic checks for the festive/Christmas port.
// Run: scripts/festive-logic-check/run.sh
var failures = 0
func check(_ ok: Bool, _ name: String, line: Int = #line) {
    if ok { print("PASS \(name)") } else { failures += 1; print("FAIL \(name) (line \(line))") }
}
func near(_ a: Double, _ b: Double, _ eps: Double = 0.01) -> Bool { abs(a - b) < eps }

// Effects level
check(FestiveEffectsLevel.fromKey(nil) == .gentle, "missing level -> gentle")
check(FestiveEffectsLevel.fromKey("FULL") == .gentle, "retired FULL -> gentle")
check(FestiveEffectsLevel.fromKey("OFF") == .off, "OFF stays off")
check(FestiveEffectsLevel.gentle.snowDensity == 0.3 && FestiveEffectsLevel.gentle.emojiCount == 2, "gentle density/emoji")

// Star taps
var counter = StarTapCounter()
check(counter.tap(now: 0) == .tap, "first tap")
_ = counter.tap(now: 0.2); _ = counter.tap(now: 0.4)
check(counter.tap(now: 0.6) == .hint, "hint at 4")
_ = counter.tap(now: 0.8); _ = counter.tap(now: 1.0)
check(counter.tap(now: 1.2) == .shootingStar, "shooting star at 7")
var slow = StarTapCounter()
_ = slow.tap(now: 0); _ = slow.tap(now: 1); _ = slow.tap(now: 2)
check(slow.tap(now: 10) == .tap, "gap resets the count")

// Calendar
let cal = Calendar(identifier: .gregorian)
func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
check(FestiveCalendar.moment(for: date(2026, 12, 24)) == .christmasEve, "eve")
check(FestiveCalendar.moment(for: date(2027, 1, 6)) == .epiphany, "epiphany")
check(FestiveCalendar.countdownLabel(date(2026, 11, 23)) == "32 days to Christmas", "countdown 32")
check(FestiveCalendar.countdownLabel(date(2026, 12, 24)) == "1 day to Christmas", "countdown 1")
check(FestiveCalendar.adventLabel(date(2026, 11, 23)) == "Advent begins Sun 29 Nov", "advent start label")
check(FestiveCalendar.adventLabel(date(2026, 12, 10)) == "Advent season", "advent season")
check(FestiveCalendar.adventLabel(date(2026, 12, 28)) == "Christmastide", "christmastide")
check(FestiveCalendar.chipLabel(date(2026, 12, 27)) == "Christmastide", "chip christmastide")

// Shepherds
check(ShepherdWalk.walkers(at: 0).isEmpty, "none before first start")
check(ShepherdWalk.walkers(at: 3).map(\.index) == [0], "first sets off alone")
check(ShepherdWalk.walkers(at: 3 + 14 + 1).map(\.index) == [0, 1], "second follows after gap")
check(stride(from: 0.0, to: 1000, by: 0.5).allSatisfy { ShepherdWalk.walkers(at: $0).count <= 2 }, "never more than two")
check(!ShepherdWalk.walkers(at: 3 + 26.1).map(\.index).contains(0), "first leaves")
check((0..<6).map { ShepherdWalk.Walker(index: $0, progress: 0.5).variant } == [0, 1, 2, 0, 1, 2], "variants rotate")

// Motion math
check(near(FestiveMotionMath.rollDegrees(x: 0, y: 9.81, z: 0), 0), "upright is level")
check(near(FestiveMotionMath.rollDegrees(x: -9.81, y: 0, z: 0), 90), "right edge down is +90")
let l = FestiveMotionMath.toScreenFrame(x: 9.81, y: 0, quarterTurns: 1)
check(near(FestiveMotionMath.rollDegrees(x: l.x, y: l.y, z: 0), 0), "landscape left is level")
let r = FestiveMotionMath.toScreenFrame(x: -9.81, y: 0, quarterTurns: 3)
check(near(FestiveMotionMath.rollDegrees(x: r.x, y: r.y, z: 0), 0), "landscape right is level")
let t = FestiveMotionMath.toScreenFrame(x: 5, y: 5, quarterTurns: 1)
check(FestiveMotionMath.rollDegrees(x: t.x, y: t.y, z: 0) > 0, "landscape tilt right edge down is positive")
let up = FestiveMotionMath.toScreenFrame(x: 0, y: -9.81, quarterTurns: 2)
check(near(FestiveMotionMath.rollDegrees(x: up.x, y: up.y, z: 0), 0), "upside down level")
let g = FestiveMotionMath.upConvention(gravityX: 0, gravityY: -1, gravityZ: 0)
check(g.y == 1, "CoreMotion gravity flips to up convention")
var shake = FestiveShakeDetector()
check(!shake.onAcceleration(x: 0, y: 1, z: 0, atMillis: 0), "resting is not a shake")
check(shake.onAcceleration(x: 3, y: 1, z: 0.5, atMillis: 1000), "jolt is a shake")
check(!shake.onAcceleration(x: 3, y: 1, z: 0.5, atMillis: 1400), "cooldown")
check(shake.onAcceleration(x: 3, y: 1, z: 0.5, atMillis: 2600), "after cooldown")

// Haptics
let light = SnowHaptics.shake(totalDepth: 0.3), heavy = SnowHaptics.shake(totalDepth: 3)
check(heavy.totalMillis > light.totalMillis && heavy.amplitudes.max()! > light.amplitudes.max()!, "more snow, bigger shake")
check(light.timings.count == light.amplitudes.count, "pattern lengths match")
let fade = heavy.amplitudes.filter { $0 > 0 }
check(fade.first! > fade.last!, "shake fades")
check(SnowHaptics.slide(depth: 1).amplitudes.max()! > SnowHaptics.slide(depth: 0.1).amplitudes.max()!, "deeper slide is firmer")
var throttle = SlideHapticThrottle(minGapMillis: 140)
check(throttle.tryFire(nowMillis: 1000) && !throttle.tryFire(nowMillis: 1100) && throttle.tryFire(nowMillis: 1150), "min gap")
var budget = SlideHapticThrottle(minGapMillis: 100); budget.maxTicksPerWindow = 3; budget.windowMillis = 2000
check((0..<12).filter { _ in false }.isEmpty && (0..<12).reduce(0, { $0 + (budget.tryFire(nowMillis: 1000 + Double($1) * 150) ? 1 : 0) }) == 3, "burst budget")
check(budget.tryFire(nowMillis: 9000), "budget resets")

// Snow caps
for (w, c) in [(100.0, 18.0), (170, 24), (360, 22), (60, 28)] {
    var xs: [Double] = []
    for cmd in buildSnowCapOutline(cardWidth: w, seed: 5, corner: c) {
        switch cmd { case .move(let x, _), .line(let x, _): xs.append(x); case .quad(let cx, _, let x, _): xs += [cx, x] }
    }
    check(xs.min()! >= SnowCapMetrics.overhang - 1e-9 && xs.max()! <= w + SnowCapMetrics.overhang + 1e-9, "cap inside card width \(w)")
}
check(buildSnowCapOutline(cardWidth: 200, seed: 3) == buildSnowCapOutline(cardWidth: 200, seed: 3), "same seed same cap")
if case .move(let big, _) = buildSnowCapOutline(cardWidth: 200, seed: 1, corner: 28).first!,
   case .move(let small, _) = buildSnowCapOutline(cardWidth: 200, seed: 1, corner: 10).first! { check(big > small, "larger corner pulls ends in") }
let grow = advanceSnowCap(SnowCapValues(depth: 0.5), dt: 1, tiltDegrees: 0, isSnowing: true, roll: 1)
check(grow.values.depth > 0.5 && grow.spillDirection == 0, "snow builds up")
let melt = advanceSnowCap(SnowCapValues(depth: 1), dt: 0.1, tiltDegrees: 25, isSnowing: true, roll: 0)
check(melt.values.depth < 1 && melt.spillDirection == 1 && melt.values.slide > 0, "tilt right melts and spills right")

// Interop
let ykc = "com.reyzie.oneykc"
check(CarolInterop.resolveCaller(scheme: "csihymns", host: "carols", from: ykc)?.label == "YKC One", "ykc accepted")
check(CarolInterop.resolveCaller(scheme: "csihymns", host: "carols", from: ykc)?.returnURL.absoluteString == "ykcone://", "ykc return url")
check(CarolInterop.resolveCaller(scheme: "csihymns", host: "carols", from: "com.evil.app") == nil, "unlisted refused")
check(CarolInterop.resolveCaller(scheme: "csihymns", host: "carols", from: nil) == nil, "missing from refused")
check(CarolInterop.resolveCaller(scheme: "csihymns", host: "carols", from: "com.reyzie.hymns") == nil, "self refused")
check(CarolInterop.resolveCaller(scheme: "https", host: "carols", from: ykc) == nil, "wrong scheme refused")
check(CarolInterop.resolveCaller(scheme: "csihymns", host: "donation_result", from: ykc) == nil, "wrong host refused")
check(CarolInterop.resolveCaller(url: URL(string: "csihymns://carols?from=com.reyzie.oneykc")!)?.bundleId == ykc, "url parse")
check(CarolInterop.isCarolsLink(URL(string: "csihymns://carols")!), "carols link recognised")
if let c = CarolInterop.resolveCaller(scheme: "csihymns", host: "carols", from: ykc) { check(CarolInterop.canReturn(to: c), "can return to ykc") }

// Carol helpers
check(CarolRecents.push(["a", "b"], "c") == ["c", "a", "b"], "recents front")
check(CarolRecents.push(["a", "b", "c"], "b") == ["b", "a", "c"], "recents dedupe")
check(CarolRecents.push(["1", "2", "3"], "4", max: 3) == ["4", "1", "2"], "recents limit")
check(near(CarolTextScale.bigger(1), 1.1) && near(CarolTextScale.smaller(0.8), 0.8) && near(CarolTextScale.bigger(1.8), 1.8), "text scale steps")
check(churchInitials("St. Paul's Church") == "SP" && churchInitials("Bethel") == "B" && churchInitials("   ") == "✦", "initials")
check(churchColorSlot("Bethel", slotCount: 5) == churchColorSlot("Bethel", slotCount: 5), "stable colour")
check(splitStanzas("1. A\nB\n\n  \n2. C\r\n\r\nD ") == ["1. A\nB", "2. C", "D"], "stanzas")


// Snow engine: settled snow slides off when the phone tilts, and nothing lands while tilted.
let engine = FestiveSnowEngine()
engine.resize(width: 400, height: 800, unit: 1)
let card = FestiveSurface(key: UUID(), left: 20, right: 380, top: 300)
for _ in 0..<(30 * 20) { engine.step(dt: 1.0 / 30, density: 1, tilt: 0, flurry: false, surfaces: [card]) }
check(!engine.settled.isEmpty, "snow settles on a level card")
var sawChunks = false
for _ in 0..<(30 * 4) {
    engine.step(dt: 1.0 / 30, density: 1, tilt: 30, flurry: false, surfaces: [card])
    if !engine.chunks.isEmpty { sawChunks = true }
}
check(engine.settled.isEmpty, "tilting slides all settled snow off")
check(sawChunks, "snow tumbles off the low edge as chunks")
let moved = FestiveSurface(key: card.key, left: 20, right: 380, top: 120)
for _ in 0..<(30 * 20) { engine.step(dt: 1.0 / 30, density: 1, tilt: 0, flurry: false, surfaces: [card]) }
engine.step(dt: 1.0 / 30, density: 1, tilt: 0, flurry: false, surfaces: [moved])
check(engine.settled.allSatisfy { $0.y == 120 }, "settled snow follows its card when it scrolls")

// Gift drop: surprises, flight drops, landing, riding a card, falling off, tapping.
var odds = [GiftSurprise: Int]()
for percent in 0..<100 { odds[GiftSurprise.pick(roll: Double(percent) / 100 + 0.001), default: 0] += 1 }
check(GiftSurprise.allCases.allSatisfy { odds[$0] == $0.weight }, "surprise odds match their weights")
check(GiftSurprise.allCases.map(\.weight).reduce(0, +) == 100, "surprise weights total 100")
check(GiftSurprise.pick(roll: 0) == .confetti && GiftSurprise.pick(roll: 0.9999) == .star, "roll edges pick first and last")

var drops = GiftDrops()
drops.startFlight()
drops.flight(progress: 0.1, x: 50, y: 50, allowed: true)
check(drops.isEmpty, "no gift before the first drop point")
drops.flight(progress: 0.23, x: 50, y: 50, allowed: true)
drops.flight(progress: 0.24, x: 60, y: 50, allowed: true)
check(drops.gifts.count == 1, "one gift per drop point")
drops.flight(progress: 0.5, x: 120, y: 50, allowed: true)
drops.flight(progress: 0.9, x: 220, y: 50, allowed: true)
check(drops.gifts.count == 3, "three gifts over a full flight")
drops.startFlight()
drops.flight(progress: 0.9, x: 220, y: 50, allowed: true)
check(drops.gifts.count == GiftDrops.maxGifts, "never more than the cap on screen")

var quiet = GiftDrops()
quiet.startFlight()
quiet.flight(progress: 1, x: 10, y: 10, allowed: false)
check(quiet.isEmpty, "no gifts when not allowed (reading screens)")

let shelf = FestiveSurface(key: UUID(), left: 0, right: 400, top: 300)
var landing = GiftDrops()
landing.startFlight()
landing.flight(progress: 0.23, x: 200, y: 80, allowed: true)
var landedEvents: [GiftEvent] = []
for _ in 0..<(30 * 8) { landedEvents += landing.step(dt: 1.0 / 30, surfaces: [shelf], height: 800) }
check(landedEvents.count == 1, "a gift lands once on the card it crosses")
for _ in 0..<(30 * 6) { _ = landing.step(dt: 1.0 / 30, surfaces: [shelf], height: 800) }
check(landing.isEmpty, "a gift that is never opened sinks away")

var riding = GiftDrops()
riding.startFlight()
riding.flight(progress: 0.23, x: 200, y: 80, allowed: true)
for _ in 0..<(30 * 4) { _ = riding.step(dt: 1.0 / 30, surfaces: [shelf], height: 800) }
let scrolled = FestiveSurface(key: shelf.key, left: 0, right: 400, top: 180)
_ = riding.step(dt: 1.0 / 30, surfaces: [scrolled], height: 800)
check(riding.gifts.first.map { near($0.y, 180 - GiftDrops.halfSize) } ?? false, "a landed gift rides its card when it scrolls")

var falling = GiftDrops()
falling.startFlight()
falling.flight(progress: 0.23, x: 200, y: 80, allowed: true)
for _ in 0..<(30 * 12) { _ = falling.step(dt: 1.0 / 30, surfaces: [], height: 800) }
check(falling.isEmpty, "with no card below, a gift falls off the screen")

var tapping = GiftDrops()
tapping.startFlight()
tapping.flight(progress: 0.23, x: 200, y: 200, allowed: true)
check(tapping.open(atX: 400, y: 600) == nil, "a tap far from any gift opens nothing")
let opened = tapping.open(atX: 215, y: 190)
check(opened != nil && tapping.gifts.first?.state == .opening, "a tap near a gift opens it")
check(tapping.open(atX: 215, y: 190) == nil, "an opening gift cannot be opened twice")
for _ in 0..<45 { _ = tapping.step(dt: 1.0 / 30, surfaces: [], height: 800) }
check(tapping.isEmpty, "an opened gift disappears after its animation")

// Countdown across time zones: the same instant is a different local date in different places.
func zone(_ id: String) -> TimeZone { TimeZone(identifier: id)! }
func instant(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
let eveUTC = instant("2026-12-24T20:00:00Z")
check(FestiveCalendar.moment(for: eveUTC, in: zone("America/New_York")) == .christmasEve, "tz: New York is still Christmas Eve")
check(FestiveCalendar.moment(for: eveUTC, in: zone("America/Los_Angeles")) == .christmasEve, "tz: Los Angeles is still Christmas Eve")
check(FestiveCalendar.moment(for: eveUTC, in: zone("Asia/Kolkata")) == .christmasDay, "tz: India has reached Christmas Day")
check(FestiveCalendar.moment(for: eveUTC, in: zone("Pacific/Kiritimati")) == .christmasDay, "tz: UTC+14 has reached Christmas Day")
let novUTC = instant("2026-11-24T10:00:00Z")
check(FestiveCalendar.daysToChristmas(from: novUTC, in: zone("America/New_York")) == 31, "tz: 31 days in New York")
check(FestiveCalendar.daysToChristmas(from: novUTC, in: zone("Asia/Kolkata")) == 31, "tz: 31 days in India")
check(FestiveCalendar.daysToChristmas(from: novUTC, in: zone("Pacific/Kiritimati")) == 30, "tz: 30 days once UTC+14 passes midnight")
check(FestiveCalendar.daysToChristmas(from: novUTC, in: zone("Pacific/Pago_Pago")) == 32, "tz: 32 days while UTC-11 is still yesterday")
check(FestiveCalendar.daysToChristmas(from: instant("2026-10-31T16:00:00Z"), in: zone("America/New_York")) == 55, "dst: the clocks going back do not change the count")
check(FestiveCalendar.daysToChristmas(from: instant("2026-03-01T12:00:00Z"), in: zone("Europe/London")) == 299, "dst: count from spring is whole days")
check(FestiveCalendar.daysToChristmas(from: instant("2026-12-25T12:00:00Z"), in: zone("Asia/Kolkata")) == 0, "countdown is 0 on Christmas Day")
check(FestiveCalendar.daysToChristmas(from: instant("2026-12-26T12:00:00Z"), in: zone("Asia/Kolkata")) == 364, "from the 26th it counts to next Christmas")
check(FestiveCalendar.countdownLabel(instant("2026-12-24T12:00:00Z"), in: zone("UTC")) == "1 day to Christmas", "label says 1 day")
check(FestiveCalendar.adventLabel(novUTC, in: zone("Asia/Kolkata")) == "Advent begins Sun 29 Nov", "advent label in India")
check(FestiveCalendar.adventLabel(novUTC, in: zone("Pacific/Kiritimati")) == "Advent begins Sun 29 Nov", "advent label at UTC+14")

// Review parity: settled snow fades in, presenter taps and paging, Christmas Day greeting only on the 25th.
check(near(FestiveSnowEngine.settledFade(age: 0, life: 5), 0), "a flake that just landed is invisible, not full opacity")
check(near(FestiveSnowEngine.settledFade(age: 0.125, life: 5), 0.5), "a flake is half visible midway through the fade-in")
check(near(FestiveSnowEngine.settledFade(age: 1, life: 5), 1), "a settled flake is fully visible after the fade-in")
check(near(FestiveSnowEngine.settledFade(age: 3, life: 1), 0.5), "a flake fades out over its last two seconds")
check(near(FestiveSnowEngine.settledFade(age: 3, life: -1), 0), "an expired flake is invisible")
let fadeEngine = FestiveSnowEngine()
fadeEngine.resize(width: 400, height: 800, unit: 1)
let fadeCard = FestiveSurface(key: UUID(), left: 20, right: 380, top: 300)
var sawFreshFlake = false
for _ in 0..<(30 * 20) {
    fadeEngine.step(dt: 1.0 / 30, density: 1, tilt: 0, flurry: false, surfaces: [fadeCard])
    if fadeEngine.settled.contains(where: { $0.age > 0 && $0.age < 0.1 && FestiveSnowEngine.settledFade(age: $0.age, life: $0.life) < 0.5 }) { sawFreshFlake = true }
}
check(sawFreshFlake, "flakes that land in the engine start faint and age upward")

check(PresenterTap.at(x: 50, width: 400) == .previous && PresenterTap.at(x: 250, width: 400) == .next, "presenter: left half goes back, right half goes forward")
check(PresenterTap.at(x: 200, width: 400) == .next, "presenter: the exact middle goes forward")
check(PresenterPaging.moved(0, by: -1, count: 5) == 0 && PresenterPaging.moved(4, by: 1, count: 5) == 4, "presenter: stops at the first and last verse")
check(PresenterPaging.clamped(7, count: 3) == 2 && PresenterPaging.clamped(2, count: 0) == 0, "presenter: a page past the end is pulled back when verses change")

var greetingDays = 0
var greetingWrong = 0
var cursor = instant("2026-01-01T12:00:00Z")
let utc = TimeZone(identifier: "UTC")!
var utcCal = Calendar(identifier: .gregorian); utcCal.timeZone = utc
while cursor < instant("2028-12-31T12:00:00Z") {
    let c = utcCal.dateComponents([.month, .day], from: cursor)
    let label = FestiveCalendar.chipLabel(cursor, in: utc)
    if label == "Christmas Day" { greetingDays += 1; if !(c.month == 12 && c.day == 25) { greetingWrong += 1 } }
    if c.month == 12 && c.day == 25 && label != "Christmas Day" { greetingWrong += 1 }
    if FestiveCalendar.daysToChristmas(from: cursor, in: utc) < 0 { greetingWrong += 1 }
    cursor = utcCal.date(byAdding: .day, value: 1, to: cursor)!
}
check(greetingDays == 3 && greetingWrong == 0, "Christmas Day shows only on 25 December across 2026-2028")

// Carol search: English finds Kannada by sound, Kannada finds English, numbers ignore verse numbers.
func carol(_ title: String, _ number: String?, _ lyrics: String, scale: String = "C Major") -> CarolSong {
    CarolSong(churchId: UUID(), title: title, songNumber: number, lyrics: lyrics, scale: scale, createdByUserId: UUID())
}
let joyCarol = carol("ಯೇಸು ಹುಟ್ಟಿದನು", "12",
                     CarolBilingual.join(kannada: "ಯೇಸು ಕ್ರಿಸ್ತನು ಜನಿಸಿದನು\nಹಾಡಿರಿ ಸಂತೋಷದಿಂದ", english: "Jesus Christ was born\nSing with joy"), scale: "G Major")
let starCarol = carol("ಬೆತ್ಲೆಹೇಮಿನ ನಕ್ಷತ್ರ", "7", "ಬೆತ್ಲೆಹೇಮ್ ನಕ್ಷತ್ರ ಮಿನುಗಿತು")
let englishOnlyCarol = carol("Silent night", "3", "Jesus Christ is born")
let verseCarol = carol("Hark", "9", "1. Hark the herald\n2. Sing")
let carolLibrary = [joyCarol, starCarol, englishOnlyCarol, verseCarol]
func found(_ query: String) -> [UUID] { CarolSearch.filter(carolLibrary, query: query).map(\.id) }

check(found("") == carolLibrary.map(\.id) && found("   ") == carolLibrary.map(\.id), "search: an empty query returns every song")
check(KannadaRoman.transliterate("ಕರ್ತನು") == "kartanu", "search: Kannada is spelled out in roman letters")
check(CarolSearch.plain("೧೨") == "12", "search: Kannada digits become 0-9")
check(CarolSearch.phoneticKey("Yesu") == CarolSearch.phoneticKey("ಯೇಸು"), "search: Yesu sounds like ಯೇಸು")
check(CarolSearch.phoneticKey("Jesus") == CarolSearch.phoneticKey("Yesus"), "search: Jesus sounds like Yesus")
check(found("yesu").contains(joyCarol.id), "search: typing yesu finds the Kannada title ಯೇಸು")
check(found("jesus").contains(joyCarol.id) && found("jesus").contains(englishOnlyCarol.id), "search: jesus finds the Kannada song and the English one")
check(found("bethlehem") == [starCarol.id], "search: bethlehem finds ಬೆತ್ಲೆಹೇಮಿನ")
check(found("nakshatra") == [starCarol.id], "search: nakshatra finds the Kannada lyrics")
check(found("sing with joy") == [joyCarol.id], "search: English translation text is searched")
check(found("G Major").contains(joyCarol.id) && !found("G Major").contains(starCarol.id), "search: the scale is searched")
check(found("12") == [joyCarol.id] && found("7") == [starCarol.id], "search: a song number finds its song")
check(found("1") == [joyCarol.id], "search: a number never matches the verse numbers inside lyrics")
check(found("ಯೇಸು").contains(joyCarol.id) && found("ಯೇಸು").contains(englishOnlyCarol.id), "search: typing Kannada finds Kannada and English-text songs")
check(found("yesu 12") == [joyCarol.id] && found("yesu 7").isEmpty, "search: every word has to match")
check(found("zebra").isEmpty, "search: an unrelated word finds nothing")
check(CarolSearch.matches(text: "Wesley Church, Mysore", query: "mysore") && !CarolSearch.matches(text: "Wesley Church", query: "mysore"), "search: church names use the same matching")
check(CarolBilingual.split(CarolBilingual.join(kannada: "ಕ", english: "A")) == (kannada: "ಕ", english: "A"), "lyrics: joining then splitting gives the parts back")
check(CarolBilingual.join(kannada: " ಕ ", english: "  ") == "ಕ", "lyrics: no English means no divider")

// Carol permissions: only the church's owner or an admin may delete; the song's uploader may edit.
let owner = UUID(), uploader = UUID(), stranger = UUID()
check(CarolPermissions.canDelete(userId: owner, churchOwnerId: owner, isAdmin: false), "perm: the church owner can delete")
check(!CarolPermissions.canDelete(userId: uploader, churchOwnerId: owner, isAdmin: false), "perm: a song's uploader who does not own the church cannot delete")
check(!CarolPermissions.canDelete(userId: stranger, churchOwnerId: owner, isAdmin: false), "perm: a stranger cannot delete")
check(!CarolPermissions.canDelete(userId: nil, churchOwnerId: owner, isAdmin: false), "perm: signed out cannot delete")
check(!CarolPermissions.canDelete(userId: owner, churchOwnerId: nil, isAdmin: false), "perm: an unknown church owner cannot be matched")
check(CarolPermissions.canDelete(userId: stranger, churchOwnerId: owner, isAdmin: true), "perm: an admin can delete anything")
check(CarolPermissions.canEditSong(userId: uploader, churchOwnerId: owner, songOwnerId: uploader, isAdmin: false), "perm: the song's uploader can edit it")
check(CarolPermissions.canEditSong(userId: owner, churchOwnerId: owner, songOwnerId: uploader, isAdmin: false), "perm: the church owner can edit a song")
check(!CarolPermissions.canEditSong(userId: stranger, churchOwnerId: owner, songOwnerId: uploader, isAdmin: false), "perm: a stranger cannot edit")
check(CarolPermissions.canEditSong(userId: stranger, churchOwnerId: owner, songOwnerId: uploader, isAdmin: true), "perm: an admin can edit")

// Christmas mode: the user's own choice beats the server, then server, cache and season.
check(ChristmasModeResolver.resolve(manual: true, remote: false, cachedRemote: false, season: false) == true, "mode: manual ON beats a server that says off")
check(ChristmasModeResolver.resolve(manual: false, remote: true, cachedRemote: true, season: true) == false, "mode: manual OFF beats a server that says on")
check(ChristmasModeResolver.resolve(manual: nil, remote: true, cachedRemote: false, season: false) == true, "mode: with no manual choice the server decides")
check(ChristmasModeResolver.resolve(manual: nil, remote: nil, cachedRemote: true, season: false) == true, "mode: offline uses the last server value")
check(ChristmasModeResolver.resolve(manual: nil, remote: nil, cachedRemote: nil, season: true) == true, "mode: with nothing else the season decides")
check(ChristmasModeResolver.resolve(manual: true, remote: nil, cachedRemote: nil, season: false) == true, "mode: manual ON survives an offline relaunch")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
