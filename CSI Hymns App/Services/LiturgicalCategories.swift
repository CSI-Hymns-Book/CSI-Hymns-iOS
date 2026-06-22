import Foundation

/// Seasonal liturgical hymn/keerthane collections (Flutter sidebar categories).
public struct LiturgicalCategory: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let hymnRange: ClosedRange<Int>?
    public let keerthaneRange: ClosedRange<Int>?
    
    public var hymnNumbers: [Int] {
        hymnRange.map { Array($0) } ?? []
    }
    
    public var keerthaneNumbers: [Int] {
        keerthaneRange.map { Array($0) } ?? []
    }
}

public enum LiturgicalCategories {
    public static let all: [LiturgicalCategory] = [
        LiturgicalCategory(id: "christmas", title: "Christmas", icon: "sparkles", hymnRange: 76...84, keerthaneRange: 43...57),
        LiturgicalCategory(id: "lent", title: "Lent and Good Friday", icon: "cross.fill", hymnRange: 91...107, keerthaneRange: 64...73),
        LiturgicalCategory(id: "easter", title: "Easter", icon: "sun.max.fill", hymnRange: 108...113, keerthaneRange: 74...80),
        LiturgicalCategory(id: "ascension", title: "Jesus' Ascension and His Kingdom", icon: "arrow.up.circle.fill", hymnRange: 119...130, keerthaneRange: 81...82),
        LiturgicalCategory(id: "coming_again", title: "Jesus' Coming Again", icon: "cloud.fill", hymnRange: 114...118, keerthaneRange: 83...85)
    ]
}
