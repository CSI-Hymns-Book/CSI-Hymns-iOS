import Foundation

/// PDF sheet inside a church — opens directly in the PDF reader.
public struct CarolPdf: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let churchId: UUID
    public let title: String
    public let songNumber: String?
    public let pdfUrl: String
    public let createdByUserId: UUID
    public let createdAt: Date
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case churchId = "church_id"
        case songNumber = "song_number"
        case pdfUrl = "pdf_url"
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        id: UUID = UUID(),
        churchId: UUID,
        title: String,
        songNumber: String? = nil,
        pdfUrl: String,
        createdByUserId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.churchId = churchId
        self.title = title
        self.songNumber = songNumber
        self.pdfUrl = pdfUrl
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
