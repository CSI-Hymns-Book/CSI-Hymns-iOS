import SwiftUI

/// Colour tokens for the candlelit Christmas look. Night is used with the dark theme and Dawn with
/// the light theme; the hero scene on the home screen is ALWAYS night (a dark sky in both).
struct FestivePalette {
    let isNight: Bool
    let skyTop, skyMid, skyLow, horizon, ground, groundDeep: Color
    let ink, inkMuted, gold, holly: Color
    let glass, glassHigh, edge, featureStart, featureEnd: Color
    let pine, pineBackground, ice, iceBackground, ember, emberBackground: Color
    let snow, capSnow, capShadow, hollyLeaf: Color
    let emojiOpacity: Double

    var screenGradient: [Color] { [skyTop, skyMid, ground, groundDeep] }

    static let night = FestivePalette(
        isNight: true,
        skyTop: Color(hex: "050919"), skyMid: Color(hex: "10183A"), skyLow: Color(hex: "261C45"),
        horizon: Color(hex: "4B2A4C"), ground: Color(hex: "0E1124"), groundDeep: Color(hex: "080A16"),
        ink: Color(hex: "F5EFE4"), inkMuted: Color(hex: "F5EFE4").opacity(0.7),
        gold: Color(hex: "E9C27B"), holly: Color(hex: "D6493D"),
        glass: Color.white.opacity(0.06), glassHigh: Color.white.opacity(0.11),
        edge: Color(hex: "E9C27B").opacity(0.28),
        featureStart: Color(hex: "D6493D").opacity(0.30), featureEnd: Color(hex: "5C1834").opacity(0.32),
        pine: Color(hex: "8FD3AA"), pineBackground: Color(hex: "6EBE8C").opacity(0.14),
        ice: Color(hex: "9CC8FF"), iceBackground: Color(hex: "82B4FF").opacity(0.14),
        ember: Color(hex: "F3B26B"), emberBackground: Color(hex: "F3A05A").opacity(0.15),
        snow: .white, capSnow: Color(hex: "EEF3FC"), capShadow: Color.black.opacity(0.35),
        hollyLeaf: Color(hex: "4FAE74"), emojiOpacity: 0.28
    )

    static let dawn = FestivePalette(
        isNight: false,
        skyTop: Color(hex: "87A2CF"), skyMid: Color(hex: "BCCDE8"), skyLow: Color(hex: "E7D7D8"),
        horizon: Color(hex: "F4CDAA"), ground: Color(hex: "F1F4F9"), groundDeep: Color(hex: "E1E8F2"),
        ink: Color(hex: "17203A"), inkMuted: Color(hex: "17203A").opacity(0.7),
        gold: Color(hex: "9C6A17"), holly: Color(hex: "B5362C"),
        glass: Color.white.opacity(0.62), glassHigh: Color.white.opacity(0.85),
        edge: Color(hex: "9C6A17").opacity(0.3),
        featureStart: Color(hex: "D6493D").opacity(0.16), featureEnd: Color.white.opacity(0.7),
        pine: Color(hex: "2D7A4F"), pineBackground: Color(hex: "2D7A4F").opacity(0.12),
        ice: Color(hex: "2B62A8"), iceBackground: Color(hex: "2B62A8").opacity(0.11),
        ember: Color(hex: "B4601A"), emberBackground: Color(hex: "B4601A").opacity(0.12),
        snow: Color(hex: "6E88B6"), capSnow: .white, capShadow: Color(hex: "3C5582").opacity(0.3),
        hollyLeaf: Color(hex: "2F8A55"), emojiOpacity: 0.38
    )

    static func forScheme(_ scheme: ColorScheme) -> FestivePalette { scheme == .dark ? .night : .dawn }
}

extension Font {
    /// Display face for Christmas headings (the system serif).
    static func festiveSerif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

private struct FestivePaletteKey: EnvironmentKey { static let defaultValue = FestivePalette.night }

extension EnvironmentValues {
    var festivePalette: FestivePalette {
        get { self[FestivePaletteKey.self] }
        set { self[FestivePaletteKey.self] = newValue }
    }
}

/// Reads the colour scheme and publishes the matching palette to everything below.
struct FestivePaletteProvider<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: () -> Content
    var body: some View { content().environment(\.festivePalette, .forScheme(scheme)) }
}
