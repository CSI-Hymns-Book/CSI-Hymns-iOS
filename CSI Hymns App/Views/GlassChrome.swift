import SwiftUI

extension View {
    /// System Liquid Glass navigation bar (iOS 26+).
    func csiGlassNavigationBar(theme: ThemeManager) -> some View {
        self
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
    }
    
    /// Liquid Glass card surface for lists, search bars, and panels.
    func csiGlassCard(cornerRadius: CGFloat = 16) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
