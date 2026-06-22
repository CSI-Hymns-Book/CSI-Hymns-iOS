import Foundation

/// Persisted reading state for hymn / keerthane / carol detail screens.
public struct ReadingProgress: Sendable {
    public var fontSize: Double?
    public var language: String?
    public var scrollOffset: Double?
    public var showPdf: Bool?
}

public enum ReadingProgressService {
    private static func prefix(itemType: String, itemId: String) -> String {
        "reading_progress_v1_\(itemType)_\(itemId)"
    }
    
    public static func load(itemType: String, itemId: String) -> ReadingProgress {
        let key = prefix(itemType: itemType, itemId: itemId)
        let defaults = UserDefaults.standard
        return ReadingProgress(
            fontSize: defaults.object(forKey: "\(key)_fontSize") as? Double,
            language: defaults.string(forKey: "\(key)_language"),
            scrollOffset: defaults.object(forKey: "\(key)_scrollOffset") as? Double,
            showPdf: defaults.object(forKey: "\(key)_showPdf") as? Bool
        )
    }
    
    public static func save(
        itemType: String,
        itemId: String,
        fontSize: Double? = nil,
        language: String? = nil,
        scrollOffset: Double? = nil,
        showPdf: Bool? = nil
    ) {
        let key = prefix(itemType: itemType, itemId: itemId)
        let defaults = UserDefaults.standard
        if let fontSize { defaults.set(fontSize, forKey: "\(key)_fontSize") }
        if let language { defaults.set(language, forKey: "\(key)_language") }
        if let scrollOffset { defaults.set(scrollOffset, forKey: "\(key)_scrollOffset") }
        if let showPdf { defaults.set(showPdf, forKey: "\(key)_showPdf") }
    }
}
