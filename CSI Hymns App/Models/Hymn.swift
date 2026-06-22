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
    
    enum CodingKeys: String, CodingKey {
        case number
        case title
        case signature
        case lyricsKannada = "lyrics_kannada"
        case lyricsEnglish = "lyrics_english"
        case type
        
        // Alternative keys for remote JSON mapping
        case lyricsAlternative = "lyrics"
        case kannadaLyricsAlternative = "kannadaLyrics"
    }
    
    public init(number: Int, title: String, signature: String, lyricsKannada: String, lyricsEnglish: String, type: String = "hymn") {
        self.number = number
        self.title = title
        self.signature = signature
        self.lyricsKannada = lyricsKannada
        self.lyricsEnglish = lyricsEnglish
        self.type = type
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
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encode(signature, forKey: .signature)
        try container.encode(lyricsKannada, forKey: .lyricsKannada)
        try container.encode(lyricsEnglish, forKey: .lyricsEnglish)
        try container.encode(type, forKey: .type)
    }
}
