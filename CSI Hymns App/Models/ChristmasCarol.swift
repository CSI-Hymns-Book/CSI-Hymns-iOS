import Foundation

/// Represents a custom Christmas carol uploaded by users or fetched from parish directories.
public struct ChristmasCarol: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let churchName: String
    public let lyrics: String
    public let scale: String
    public let pdfUrl: String?
    public let songNumber: String?
    public let createdBy: String
    public let createdByUserId: String?
    public let createdAt: Date
    public let updatedAt: Date?
    
    public var hasPdf: Bool {
        guard let url = pdfUrl else { return false }
        return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var hasLyrics: Bool {
        !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, lyrics, scale
        case churchName = "church_name"
        case churchNameCamel = "churchName"
        case pdfUrl = "pdf_url"
        case pdf = "pdf"
        case songNumber = "song_number"
        case songNumberCamel = "songNumber"
        case createdBy = "created_by"
        case createdByUserId = "created_by_user_id"
        case createdByUserIdCamel = "createdByUserId"
        case createdAt = "created_at"
        case createdAtCamel = "createdAt"
        case updatedAt = "updated_at"
        case updatedAtCamel = "updatedAt"
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        churchName: String,
        lyrics: String = "",
        scale: String = "C Major",
        pdfUrl: String? = nil,
        songNumber: String? = nil,
        createdBy: String = "",
        createdByUserId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.churchName = churchName
        self.lyrics = lyrics
        self.scale = scale
        self.pdfUrl = pdfUrl
        self.songNumber = songNumber
        self.createdBy = createdBy
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ChristmasCarol: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = (try? container.decode(String.self, forKey: .id))
            ?? UUID().uuidString.lowercased()
        title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled Carol"
        
        churchName = Self.decodeString(container, keys: [.churchName, .churchNameCamel]) ?? "Unknown Church"
        lyrics = (try? container.decode(String.self, forKey: .lyrics)) ?? ""
        scale = (try? container.decode(String.self, forKey: .scale)) ?? "C Major"
        
        pdfUrl = Self.decodeString(container, keys: [.pdfUrl, .pdf])
        songNumber = Self.decodeFlexibleString(container, keys: [.songNumber, .songNumberCamel])
        createdBy = Self.decodeString(container, keys: [.createdBy]) ?? ""
        createdByUserId = Self.decodeString(container, keys: [.createdByUserId, .createdByUserIdCamel])
        
        createdAt = Self.decodeDate(container, keys: [.createdAt, .createdAtCamel]) ?? Date()
        updatedAt = Self.decodeDate(container, keys: [.updatedAt, .updatedAtCamel])
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(churchName, forKey: .churchName)
        try container.encode(lyrics, forKey: .lyrics)
        try container.encode(scale, forKey: .scale)
        // Supabase column is `pdf` (Flutter parity)
        try container.encodeIfPresent(pdfUrl, forKey: .pdf)
        try container.encodeIfPresent(songNumber, forKey: .songNumber)
        try container.encodeIfPresent(createdByUserId, forKey: .createdByUserId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    /// Tolerant parser for Supabase / GitHub JSON rows.
    public static func fromDictionary(_ dict: [String: Any]) -> ChristmasCarol? {
        guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
        
        let id = (dict["id"] as? String)?.lowercased() ?? UUID().uuidString.lowercased()
        let church = (dict["church_name"] as? String)
            ?? (dict["churchName"] as? String)
            ?? (dict["parish"] as? String)
            ?? "Unknown Church"
        let lyrics = (dict["lyrics"] as? String) ?? ""
        let scale = (dict["scale"] as? String) ?? "C Major"
        let pdf = (dict["pdf"] as? String) ?? (dict["pdf_url"] as? String)
        let songNumber: String? = {
            if let s = dict["song_number"] as? String, !s.isEmpty { return s }
            if let s = dict["songNumber"] as? String, !s.isEmpty { return s }
            if let n = dict["song_number"] as? Int { return String(n) }
            if let n = dict["songNumber"] as? Int { return String(n) }
            return nil
        }()
        let createdBy = (dict["created_by"] as? String) ?? ""
        let createdByUserId = (dict["created_by_user_id"] as? String) ?? (dict["createdByUserId"] as? String)
        
        let createdAt: Date = {
            if let s = dict["created_at"] as? String ?? dict["createdAt"] as? String {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: s) { return d }
                iso.formatOptions = [.withInternetDateTime]
                if let d = iso.date(from: s) { return d }
            }
            return Date()
        }()
        
        let updatedAt: Date? = {
            guard let s = dict["updated_at"] as? String ?? dict["updatedAt"] as? String else { return nil }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: s) { return d }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: s)
        }()
        
        return ChristmasCarol(
            id: id,
            title: title,
            churchName: church,
            lyrics: lyrics,
            scale: scale,
            pdfUrl: pdf,
            songNumber: songNumber,
            createdBy: createdBy,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public static func parseJSONArray(_ data: Data) -> [ChristmasCarol] {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.compactMap(fromDictionary)
    }
    
    private static func decodeString(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> String? {
        for key in keys {
            if let value = try? container.decode(String.self, forKey: key), !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    private static func decodeFlexibleString(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> String? {
        for key in keys {
            if let s = try? container.decode(String.self, forKey: key), !s.isEmpty { return s }
            if let n = try? container.decode(Int.self, forKey: key) { return String(n) }
        }
        return nil
    }
    
    private static func decodeDate(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        
        for key in keys {
            if let s = try? container.decode(String.self, forKey: key) {
                if let d = iso.date(from: s) ?? isoBasic.date(from: s) { return d }
            }
        }
        return nil
    }
}
