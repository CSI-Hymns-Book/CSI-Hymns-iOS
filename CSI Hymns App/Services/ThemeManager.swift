import SwiftUI
import Observation

/// The active theme modes supported throughout the application.
public enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case light = "Light Mode"
    case dark = "Dark Mode"
    case amoled = "AMOLED Black"
    
    public var id: String { self.rawValue }
}

/// Custom global accent colors chosen by the user.
public enum AppAccentColor: String, CaseIterable, Identifiable, Codable {
    case blue = "Blue"
    case indigo = "Indigo"
    case skyBlue = "Sky Blue"
    case mint = "Mint"
    case emerald = "Emerald"
    case teal = "Teal"
    case green = "Green"
    case amber = "Amber"
    case orange = "Orange"
    case coral = "Coral"
    case red = "Red"
    case rose = "Rose"
    case pink = "Pink"
    case lavender = "Lavender"
    case purple = "Purple"
    case deepPurple = "Deep Purple"
    case slate = "Slate"
    case electricIndigo = "Electric Indigo"
    
    public var id: String { self.rawValue }
    
    public var color: Color {
        primary
    }
    
    public var primary: Color {
        switch self {
        case .blue: return Color(hex: "007AFF")
        case .indigo: return Color(hex: "5856D6")
        case .skyBlue: return Color(hex: "3498DB")
        case .mint: return Color(hex: "00C7BE")
        case .emerald: return Color(hex: "2ECC71")
        case .teal: return Color(hex: "30B0C7")
        case .green: return Color(hex: "34C759")
        case .amber: return Color(hex: "F1C40F")
        case .orange: return Color(hex: "FF9500")
        case .coral: return Color(hex: "E67E22")
        case .red: return Color(hex: "FF3B30")
        case .rose: return Color(hex: "E91E63")
        case .pink: return Color(hex: "FF2D55")
        case .lavender: return Color(hex: "9B59B6")
        case .purple: return Color(hex: "AF52DE")
        case .deepPurple: return Color(hex: "6C5CE7")
        case .slate: return Color(hex: "607D8B")
        case .electricIndigo: return Color(hex: "6366F1")
        }
    }
    
    public var pressed: Color {
        primary.opacity(0.7)
    }
    
    public var backgroundTint: Color {
        primary.opacity(0.12)
    }
    
    public var textPairing: Color {
        switch self {
        case .amber: return Color(hex: "1F2937") // Dark slate for clear contrast on Gold
        default: return Color.white
        }
    }
}

/// A staff-level global theme engine propagating semantic design tokens reactively.
@Observable
public final class ThemeManager {
    public static let shared = ThemeManager()
    
    public var activeTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(activeTheme.rawValue, forKey: "csi_active_theme")
            updateSystemAppearance()
        }
    }
    
    public var selectedAccent: AppAccentColor {
        didSet {
            UserDefaults.standard.set(selectedAccent.rawValue, forKey: "csi_selected_accent")
        }
    }
    
    public var accentColor: Color {
        isChristmas ? ChristmasColors.christmasRed : selectedAccent.color
    }
    
    /// Whether festive Christmas styling should currently be applied app-wide.
    private var isChristmas: Bool {
        ChristmasModeService.shared.isChristmasTime
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "csi_active_theme") ?? AppTheme.dark.rawValue
        self.activeTheme = AppTheme(rawValue: saved) ?? .dark
        
        let savedAccent = UserDefaults.standard.string(forKey: "csi_selected_accent") ?? AppAccentColor.blue.rawValue
        self.selectedAccent = AppAccentColor(rawValue: savedAccent) ?? .blue
        
        updateSystemAppearance()
    }
    
    /// Maps our custom themes to standard SwiftUI ColorSchemes.
    public var colorScheme: ColorScheme {
        switch activeTheme {
        case .light:
            return .light
        case .dark, .amoled:
            return .dark
        }
    }
    
    // MARK: - Semantic Color Tokens
    
    public var backgroundColor: Color {
        switch activeTheme {
        case .light:
            return isChristmas ? ChristmasColors.lightBackground : Color(hex: "F4F6F9")
        case .dark:
            return isChristmas ? ChristmasColors.darkBackground : Color(hex: "0D1B2A")
        case .amoled:
            return Color.black
        }
    }
    
    public var secondaryBackgroundColor: Color {
        switch activeTheme {
        case .light:
            return isChristmas ? ChristmasColors.lightSurface : Color(hex: "FFFFFF")
        case .dark:
            return isChristmas ? ChristmasColors.darkSurface : Color(hex: "1B263B")
        case .amoled:
            return Color(hex: "121212")
        }
    }
    
    public var cardBackground: Color {
        switch activeTheme {
        case .light:
            return isChristmas ? ChristmasColors.snowWhite : Color(hex: "FFFFFF")
        case .dark:
            return isChristmas ? ChristmasColors.darkSurfaceContainer : Color.white.opacity(0.05)
        case .amoled:
            return Color(hex: "181818")
        }
    }
    
    public var cardStroke: Color {
        switch activeTheme {
        case .light:
            return Color.black.opacity(0.06)
        case .dark:
            return Color.white.opacity(0.12)
        case .amoled:
            return Color.white.opacity(0.15)
        }
    }
    
    public var textPrimary: Color {
        switch activeTheme {
        case .light:
            return Color(hex: "1F2937")
        case .dark, .amoled:
            return Color.white
        }
    }
    
    public var textSecondary: Color {
        switch activeTheme {
        case .light:
            return Color(hex: "4B5563")
        case .dark, .amoled:
            return Color.white.opacity(0.6)
        }
    }
    
    public var shadowColor: Color {
        switch activeTheme {
        case .light:
            return Color.black.opacity(0.05)
        case .dark, .amoled:
            return Color.black.opacity(0.3)
        }
    }
    
    public var surfaceColor: Color {
        secondaryBackgroundColor
    }
    
    public var strokeColor: Color {
        cardStroke
    }
    
    /// Global gradient background setup
    public var backgroundGradient: LinearGradient {
        switch activeTheme {
        case .light:
            return LinearGradient(
                colors: isChristmas
                    ? [ChristmasColors.lightBackground, ChristmasColors.lightSurface]
                    : [Color(hex: "F8F9FA"), Color(hex: "E9ECEF")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .dark:
            return LinearGradient(
                colors: isChristmas
                    ? [ChristmasColors.darkBackground, ChristmasColors.darkSurface]
                    : [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .amoled:
            return LinearGradient(
                colors: [Color.black, Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Appearance Bridging
    
    public func updateSystemAppearance() {
        let style: UIUserInterfaceStyle
        switch activeTheme {
        case .light:
            style = .light
        case .dark, .amoled:
            style = .dark
        }
        
        // Liquid Glass: use system default translucent nav/tab chrome (do not force opaque colors).
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        switch activeTheme {
        case .light:
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor(red: 31/255, green: 41/255, blue: 55/255, alpha: 1)]
            navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 31/255, green: 41/255, blue: 55/255, alpha: 1)]
        case .dark, .amoled:
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        }
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}
