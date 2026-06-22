import Foundation

/// Lyrics/text carol inside a church (hymn-style reader).
public struct CarolSong: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let churchId: UUID
    public let title: String
    public let songNumber: String?
    public let lyrics: String
    public let scale: String
    public let createdByUserId: UUID
    public let createdAt: Date
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, lyrics, scale
        case churchId = "church_id"
        case songNumber = "song_number"
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public var hasLyrics: Bool {
        !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public init(
        id: UUID = UUID(),
        churchId: UUID,
        title: String,
        songNumber: String? = nil,
        lyrics: String,
        scale: String = "C Major",
        createdByUserId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.churchId = churchId
        self.title = title
        self.songNumber = songNumber
        self.lyrics = lyrics
        self.scale = scale
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
