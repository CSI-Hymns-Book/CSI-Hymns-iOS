import SwiftUI

/// Festive Christmas color palette and semantic tokens.
///
/// Ported from the Flutter app's `christmas_theme.dart`. When Christmas mode is active,
/// `ThemeManager` swaps its semantic colors for the Christmas variants below so the
/// festive look applies app-wide rather than only on the Christmas portal screens.
public enum ChristmasColors {
    // Primary Christmas colors
    public static let christmasRed = Color(hex: "B22222")    // Deep red
    public static let christmasGreen = Color(hex: "228B22")  // Forest green
    public static let christmasGold = Color(hex: "FFD700")   // Gold
    public static let snowWhite = Color(hex: "F8F8FF")       // Ghost white
    public static let hollyGreen = Color(hex: "006400")      // Dark green
    public static let candyCaneRed = Color(hex: "DC143C")    // Crimson
    public static let starGold = Color(hex: "DAA520")        // Goldenrod

    // Light theme surfaces
    public static let lightSurface = Color(hex: "FFFAFA")    // Snow
    public static let lightBackground = Color(hex: "FFF8F0") // Warm white

    // Dark theme surfaces
    public static let darkSurface = Color(hex: "1A1A2E")     // Deep navy
    public static let darkSurfaceContainer = Color(hex: "16213E")
    public static let darkBackground = Color(hex: "0F0F1A")  // Very dark blue
}
