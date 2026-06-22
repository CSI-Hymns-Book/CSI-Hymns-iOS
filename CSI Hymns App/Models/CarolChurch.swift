import Foundation

/// A parish/church container — created first; songs and PDFs live inside.
public struct CarolChurch: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let createdByUserId: UUID
    public let createdAt: Date
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        createdByUserId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
