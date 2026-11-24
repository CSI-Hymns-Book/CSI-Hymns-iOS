import SwiftUI

/// Leaving a book for the home screen. Every "Home" button and the edge swipe use this, so the
/// return always runs the same animation as the way in (no two springs fighting each other).
@MainActor
enum BookNavigation {
    static func goHome() {
        guard AppNavigationService.shared.activeSection != nil else { return }
        AppHaptics.tap()
        let animation = ChristmasModeService.shared.isChristmasTime
            ? FestiveMotion.screen
            : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(animation) { AppNavigationService.shared.activeSection = nil }
    }
}

/// Taps the user can feel. Honours the "Tactile Haptics" switch in Settings, and keeps one
/// prepared generator so the first tap after launch is not swallowed while the engine wakes up.
@MainActor
enum AppHaptics {
    static let settingKey = "enable_haptic_feedback"
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true }

    /// A crisp tap for opening a card, a song or going back.
    static func tap() {
        guard isEnabled else { return }
        impact.impactOccurred(intensity: 0.8)
        impact.prepare()
    }

    /// A lighter tick for small steps, such as the previous and next song arrows.
    static func light() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.7)
        lightImpact.prepare()
    }
}
