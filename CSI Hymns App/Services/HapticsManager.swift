import UIKit
import SwiftUI

public final class HapticsManager {
    public static let shared = HapticsManager()
    
    private init() {}
    
    public func triggerLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func triggerMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func triggerHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func triggerSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    public func triggerSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    public func triggerWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    public func triggerError() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

// MARK: - SwiftUI Extensions for Haptics

public struct HapticFeedbackButtonStyle: ButtonStyle {
    let feedbackStyle: FeedbackStyle
    
    public enum FeedbackStyle {
        case light
        case medium
        case heavy
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    switch feedbackStyle {
                    case .light:
                        HapticsManager.shared.triggerLight()
                    case .medium:
                        HapticsManager.shared.triggerMedium()
                    case .heavy:
                        HapticsManager.shared.triggerHeavy()
                    }
                }
            }
    }
}

public extension ButtonStyle where Self == HapticFeedbackButtonStyle {
    static var hapticLight: HapticFeedbackButtonStyle {
        HapticFeedbackButtonStyle(feedbackStyle: .light)
    }
    static var hapticMedium: HapticFeedbackButtonStyle {
        HapticFeedbackButtonStyle(feedbackStyle: .medium)
    }
    static var hapticHeavy: HapticFeedbackButtonStyle {
        HapticFeedbackButtonStyle(feedbackStyle: .heavy)
    }
}

public struct HapticFeedbackSliderModifier<T: Equatable>: ViewModifier {
    let value: T
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: value) { _ in
                HapticsManager.shared.triggerSelection()
            }
    }
}

public extension View {
    func hapticFeedbackOnChange<T: Equatable>(of value: T) -> some View {
        modifier(HapticFeedbackSliderModifier(value: value))
    }
}

