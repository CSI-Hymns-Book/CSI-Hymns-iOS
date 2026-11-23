import SwiftUI
import CoreHaptics
import CoreMotion
import Observation
import UIKit

struct FestiveToast: Equatable, Identifiable { let id: Int; let text: String }

/// Shared Christmas state the UI reads: effects level, easter-egg progress, toasts and tilt/shake
/// input. The per-frame work lives in `FestiveSimulation`; this class is the main-actor bridge.
@MainActor
@Observable
final class FestiveAmbience {
    static let shared = FestiveAmbience()

    private static let secretsKey = "christmas_secrets_found"
    private static let eggsKey = "christmas_easter_eggs"

    var level: FestiveEffectsLevel {
        didSet {
            UserDefaults.standard.set(level.rawValue, forKey: FestiveEffectsLevel.storageKey)
            sim.level = level
            if level == .off { FestiveMotionService.shared.stop() } else { FestiveMotionService.shared.start() }
        }
    }
    var easterEggsEnabled: Bool {
        didSet { UserDefaults.standard.set(easterEggsEnabled, forKey: Self.eggsKey); sim.eggsEnabled = easterEggsEnabled }
    }
    private(set) var foundSecrets: Set<FestiveSecret>
    private(set) var toast: FestiveToast?
    private(set) var shakeGeneration = 0

    @ObservationIgnored let sim = FestiveSimulation()
    @ObservationIgnored private var nextToastId = 0
    @ObservationIgnored private var releaseDim: [Int: Bool] = [:]
    @ObservationIgnored private var nextDimToken = 0

    let moment = FestiveCalendar.moment(for: Date())

    var effectiveLevel: FestiveEffectsLevel { sim.effectiveLevel }
    var eggsActive: Bool { easterEggsEnabled && effectiveLevel != .off }

    private init() {
        let defaults = UserDefaults.standard
        level = FestiveEffectsLevel.fromKey(defaults.string(forKey: FestiveEffectsLevel.storageKey))
        easterEggsEnabled = defaults.object(forKey: Self.eggsKey) as? Bool ?? true
        foundSecrets = FestiveSecret.fromStored(defaults.stringArray(forKey: Self.secretsKey) ?? [])
        sim.level = level
        sim.eggsEnabled = easterEggsEnabled
        sim.moment = moment
        sim.reduceMotion = UIAccessibility.isReduceMotionEnabled
        if moment == .christmasEve { sim.setEarlySanta() }
        sim.onEvent = { event in Task { @MainActor in FestiveAmbience.shared.handle(event) } }
        NotificationCenter.default.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in FestiveAmbience.shared.sim.reduceMotion = UIAccessibility.isReduceMotionEnabled }
        }
    }

    // MARK: Events from the simulation

    fileprivate func handle(_ event: FestiveEvent) {
        switch event {
        case .secret(let secret, let message): discover(secret, message: message)
        case .haptic(let pattern): FestiveHaptics.shared.play(pattern)
        case .toast(let text): showToast(text)
        }
    }

    // MARK: Secrets and toasts

    /// Marks a secret found (first time only), shows "Secret found · n of 8". Returns true if new.
    @discardableResult
    func discover(_ secret: FestiveSecret, message: String? = nil) -> Bool {
        guard easterEggsEnabled, !foundSecrets.contains(secret) else { return false }
        foundSecrets.insert(secret)
        UserDefaults.standard.set(foundSecrets.map(\.rawValue).sorted(), forKey: Self.secretsKey)
        let count = "\(foundSecrets.count) of \(FestiveSecret.allCases.count)"
        showToast(message.map { "\($0) · \(count)" } ?? "✨ Secret found · \(count)")
        return true
    }

    func resetSecrets() {
        foundSecrets = []
        UserDefaults.standard.removeObject(forKey: Self.secretsKey)
        sim.resetTiltAnnouncement()
        showToast("Secrets reset · find them all again")
    }

    func showToast(_ text: String) {
        nextToastId += 1
        toast = FestiveToast(id: nextToastId, text: text)
    }

    func dismissToast(id: Int) { if toast?.id == id { toast = nil } }

    // MARK: Input

    func setDeviceTilt(_ degrees: Double) { sim.rawTilt = min(max(degrees, -40), 40) }

    func shake() {
        sim.shake()
        shakeGeneration = sim.shakeGeneration
    }

    /// Dims the snow until the returned closure is called (reading screens keep lyrics clear).
    func requestDim() -> () -> Void {
        sim.dimRequests += 1
        var released = false
        return { [weak self] in
            guard !released else { return }
            released = true
            self?.sim.dimRequests -= 1
        }
    }

    func handleTap(x: Double, y: Double, width: Double) -> Bool { sim.handleTap(x: x, y: y, width: width) }
    func celebrateChristmasDay(width: Double) { if effectiveLevel != .off { sim.effects.confetti(width: width) } }
}

// MARK: - Haptics

@MainActor
final class FestiveHaptics {
    static let shared = FestiveHaptics()
    private var engine: CHHapticEngine?
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    /// Plays a (pause, pulse) pattern: steps with amplitude 0 are silence.
    func play(_ pattern: HapticPattern) {
        guard AppHaptics.isEnabled else { return }
        guard supported else { fallback(pattern); return }
        do {
            if engine == nil {
                let e = try CHHapticEngine()
                e.isAutoShutdownEnabled = true
                e.resetHandler = { [weak self] in Task { @MainActor in self?.engine = nil } }
                engine = e
            }
            try engine?.start()
            var events: [CHHapticEvent] = []
            var t = 0.0
            for (ms, amp) in zip(pattern.timings, pattern.amplitudes) {
                let seconds = Double(ms) / 1000
                if amp > 0 {
                    let params = [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Self.intensity(amp)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ]
                    events.append(CHHapticEvent(
                        eventType: ms <= 20 ? .hapticTransient : .hapticContinuous,
                        parameters: params, relativeTime: t, duration: ms <= 20 ? 0 : seconds
                    ))
                }
                t += seconds
            }
            guard !events.isEmpty else { return }
            let player = try engine?.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback(pattern)
        }
    }

    /// Android amplitudes (1...255) drive a motor that is felt at low values; the Taptic Engine
    /// is not, so quiet pulses get a floor that is still clearly felt.
    private static func intensity(_ amplitude: Int) -> Float {
        0.4 + 0.6 * Float(min(max(amplitude, 0), 255)) / 255
    }

    private func fallback(_ pattern: HapticPattern) {
        let strongest = pattern.amplitudes.max() ?? 0
        guard strongest > 0 else { return }
        UIImpactFeedbackGenerator(style: strongest > 160 ? .heavy : (strongest > 90 ? .medium : .light)).impactOccurred()
    }
}

// MARK: - Motion

/// Feeds tilt and shakes into the ambience. Tilt is measured against the *screen*, so a phone held
/// upright in landscape is level; only listens while the app is active and effects are on.
@MainActor
final class FestiveMotionService {
    static let shared = FestiveMotionService()
    private let manager = CMMotionManager()
    private var shake = FestiveShakeDetector()
    private var running = false

    func start() {
        let ambience = FestiveAmbience.shared
        guard !running, ambience.effectiveLevel != .off, manager.isDeviceMotionAvailable else { return }
        running = true
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            Task { @MainActor in self.handle(motion) }
        }
    }

    func stop() {
        guard running else { return }
        running = false
        manager.stopDeviceMotionUpdates()
        FestiveAmbience.shared.setDeviceTilt(0)
    }

    private func handle(_ motion: CMDeviceMotion) {
        let g = FestiveMotionMath.upConvention(gravityX: motion.gravity.x, gravityY: motion.gravity.y, gravityZ: motion.gravity.z)
        let screen = FestiveMotionMath.toScreenFrame(x: g.x, y: g.y, quarterTurns: Self.quarterTurns())
        FestiveAmbience.shared.setDeviceTilt(FestiveMotionMath.rollDegrees(x: screen.x, y: screen.y, z: g.z))
        let a = motion.userAcceleration
        if shake.onAcceleration(x: motion.gravity.x + a.x, y: motion.gravity.y + a.y, z: motion.gravity.z + a.z, atMillis: motion.timestamp * 1000) {
            FestiveAmbience.shared.shake()
        }
    }

    /// Android-style quarter turns of the screen: 0 portrait, 1 top-left, 2 upside down, 3 top-right.
    private static func quarterTurns() -> Int {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        switch scene?.interfaceOrientation ?? .portrait {
        case .landscapeRight: return 1
        case .portraitUpsideDown: return 2
        case .landscapeLeft: return 3
        default: return 0
        }
    }
}
