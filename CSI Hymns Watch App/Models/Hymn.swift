import Foundation

/// Represents a bilingual hymn or keerthane song entity.
public struct Hymn: Codable, Identifiable, Hashable {
    public var id: String { "\(type)_\(number)" }
    
    public let number: Int
    public let title: String
    public let signature: String
    public let lyricsKannada: String
    public let lyricsEnglish: String
    public var type: String // "hymn" or "keerthane"
    public let category: String?
    public let kannadaCategory: String?
    
    // Pre-parsed fields for instantaneous, zero-latency rendering on Apple Watch
    public let stanzasKannada: [String]
    public let stanzasEnglish: [String]
    public let firstLineKannada: String
    
    enum CodingKeys: String, CodingKey {
        case number
        case title
        case signature
        case lyricsKannada = "lyrics_kannada"
        case lyricsEnglish = "lyrics_english"
        case type
        case category
        case kannadaCategory
        
        // Alternative keys for remote JSON mapping
        case lyricsAlternative = "lyrics"
        case kannadaLyricsAlternative = "kannadaLyrics"
    }
    
    public init(number: Int, title: String, signature: String, lyricsKannada: String, lyricsEnglish: String, type: String = "hymn", category: String? = nil, kannadaCategory: String? = nil) {
        self.number = number
        self.title = title
        self.signature = signature
        self.lyricsKannada = lyricsKannada
        self.lyricsEnglish = lyricsEnglish
        self.type = type
        self.category = category
        self.kannadaCategory = kannadaCategory
        
        let kClean = lyricsKannada.trimmingCharacters(in: .whitespacesAndNewlines)
        let kParts = kClean.isEmpty ? [] : kClean.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.stanzasKannada = kParts.isEmpty && !kClean.isEmpty ? [kClean] : kParts
        
        let eClean = lyricsEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        let eParts = eClean.isEmpty ? [] : eClean.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.stanzasEnglish = eParts.isEmpty && !eClean.isEmpty ? [eClean] : eParts
        
        if let idx = lyricsKannada.firstIndex(of: "\n") {
            self.firstLineKannada = String(lyricsKannada[..<idx]).trimmingCharacters(in: .whitespaces)
        } else {
            self.firstLineKannada = lyricsKannada.trimmingCharacters(in: .whitespaces)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.number = try container.decode(Int.self, forKey: .number)
        self.title = try container.decode(String.self, forKey: .title)
        
        // signature is sometimes missing or not standard in other lists, fallback to empty
        if let sig = try? container.decode(String.self, forKey: .signature) {
            self.signature = sig
        } else {
            self.signature = "C.M"
        }
        
        // Decode lyricsKannada from "lyrics_kannada" or "kannadaLyrics"
        if let kannada = try? container.decode(String.self, forKey: .lyricsKannada) {
            self.lyricsKannada = kannada
        } else if let kannada = try? container.decode(String.self, forKey: .kannadaLyricsAlternative) {
            self.lyricsKannada = kannada
        } else {
            self.lyricsKannada = ""
        }
        
        // Decode lyricsEnglish from "lyrics_english" or "lyrics"
        if let english = try? container.decode(String.self, forKey: .lyricsEnglish) {
            self.lyricsEnglish = english
        } else if let english = try? container.decode(String.self, forKey: .lyricsAlternative) {
            self.lyricsEnglish = english
        } else {
            self.lyricsEnglish = ""
        }
        
        // Decode type if present, otherwise default to "hymn"
        if let typeValue = try? container.decode(String.self, forKey: .type) {
            self.type = typeValue
        } else {
            self.type = "hymn"
        }
        
        self.category = try? container.decode(String.self, forKey: .category)
        self.kannadaCategory = try? container.decode(String.self, forKey: .kannadaCategory)
        
        // Pre-parse stanzas and first line once during decoding
        let kClean = self.lyricsKannada.trimmingCharacters(in: .whitespacesAndNewlines)
        let kParts = kClean.isEmpty ? [] : kClean.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.stanzasKannada = kParts.isEmpty && !kClean.isEmpty ? [kClean] : kParts
        
        let eClean = self.lyricsEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        let eParts = eClean.isEmpty ? [] : eClean.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.stanzasEnglish = eParts.isEmpty && !eClean.isEmpty ? [eClean] : eParts
        
        if let idx = self.lyricsKannada.firstIndex(of: "\n") {
            self.firstLineKannada = String(self.lyricsKannada[..<idx]).trimmingCharacters(in: .whitespaces)
        } else {
            self.firstLineKannada = self.lyricsKannada.trimmingCharacters(in: .whitespaces)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encode(signature, forKey: .signature)
        try container.encode(lyricsKannada, forKey: .lyricsKannada)
        try container.encode(lyricsEnglish, forKey: .lyricsEnglish)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(kannadaCategory, forKey: .kannadaCategory)
    }
}
