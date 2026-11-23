import SwiftUI
import UIKit

extension View {
    /// Hides the tab bar while this pushed screen is showing. SwiftUI on its own only brings the
    /// bar back after the pop animation has finished, so it snaps in a beat late (the "glitch"
    /// on the way back from a song). Here the bar starts sliding back the moment the pop begins.
    func hidesTabBarWhenPushed() -> some View {
        modifier(TabBarHiddenWhileShown())
    }
}

private struct TabBarHiddenWhileShown: ViewModifier {
    @State private var hidden = true

    func body(content: Content) -> some View {
        content
            .toolbar(hidden ? .hidden : .visible, for: .tabBar)
            .background(
                AppearanceProbe(
                    willAppear: { hidden = true },
                    willDisappear: { withAnimation(.easeOut(duration: 0.3)) { hidden = false } }
                )
                .frame(width: 0, height: 0)
            )
    }
}

/// Reports UIKit's will-appear / will-disappear, which fire at the start of a push or pop
/// (SwiftUI's onAppear / onDisappear only fire once the transition is over).
private struct AppearanceProbe: UIViewControllerRepresentable {
    let willAppear: () -> Void
    let willDisappear: () -> Void

    func makeUIViewController(context: Context) -> Probe { Probe() }

    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.willAppear = willAppear
        probe.willDisappear = willDisappear
    }

    final class Probe: UIViewController {
        var willAppear: () -> Void = {}
        var willDisappear: () -> Void = {}

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            willAppear()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            willDisappear()
        }
    }
}
