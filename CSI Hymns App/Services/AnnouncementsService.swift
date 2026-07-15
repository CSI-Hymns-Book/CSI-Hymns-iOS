import Foundation

#if canImport(Supabase)
import Supabase
#endif

@Observable
public final class AnnouncementsService: Sendable {
    public static let shared = AnnouncementsService()
    
    private let dismissedBroadcastsKey = "dismissed_broadcasts_ids_v1"
    
    private init() {}
    
    public func getActiveUndismissedBroadcast() async -> InAppMessage? {
        #if canImport(Supabase)
        do {
            let client = SupabaseService.instance.client
            let activeAnnouncements: [InAppMessage] = try await client.from("in_app_messages")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value
            
            let sorted = activeAnnouncements.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            let dismissedIds = getDismissedIds()
            return sorted.first { !dismissedIds.contains($0.id) }
        } catch {
            print("AnnouncementsService: Error getting active broadcast: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
    
    public func dismissBroadcast(id: String) {
        var dismissed = getDismissedIds()
        dismissed.insert(id)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedBroadcastsKey)
    }
    
    public func getAllBroadcasts() async -> [InAppMessage] {
        #if canImport(Supabase)
        do {
            let client = SupabaseService.instance.client
            let list: [InAppMessage] = try await client.from("in_app_messages")
                .select()
                .execute()
                .value
            return list.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        } catch {
            print("AnnouncementsService: Error getting all broadcasts: \(error)")
            return []
        }
        #else
        return []
        #endif
    }
    
    public func createBroadcast(message: InAppMessage) async -> String? {
        #if canImport(Supabase)
        do {
            struct InsertRow: Encodable {
                let id: String
                let title: String
                let message: String
                let action_text: String?
                let action_url: String?
                let is_active: Bool
            }
            
            let client = SupabaseService.instance.client
            let payload = InsertRow(
                id: message.id,
                title: message.title,
                message: message.message,
                action_text: message.actionText,
                action_url: message.actionUrl,
                is_active: message.isActive
            )
            
            try await client.from("in_app_messages")
                .insert(payload)
                .execute()
            return nil
        } catch {
            return error.localizedDescription
        }
        #else
        return "Supabase client not available"
        #endif
    }
    
    public func updateBroadcast(message: InAppMessage) async -> String? {
        #if canImport(Supabase)
        do {
            struct UpdateRow: Encodable {
                let title: String
                let message: String
                let action_text: String?
                let action_url: String?
                let is_active: Bool
            }
            
            let client = SupabaseService.instance.client
            let payload = UpdateRow(
                title: message.title,
                message: message.message,
                action_text: message.actionText,
                action_url: message.actionUrl,
                is_active: message.isActive
            )
            
            try await client.from("in_app_messages")
                .update(payload)
                .eq("id", value: message.id)
                .execute()
            return nil
        } catch {
            return error.localizedDescription
        }
        #else
        return "Supabase client not available"
        #endif
    }
    
    public func deleteBroadcast(id: String) async -> String? {
        #if canImport(Supabase)
        do {
            let client = SupabaseService.instance.client
            try await client.from("in_app_messages")
                .delete()
                .eq("id", value: id)
                .execute()
            return nil
        } catch {
            return error.localizedDescription
        }
        #else
        return "Supabase client not available"
        #endif
    }
    
    public func retriggerBroadcast(oldId: String, newId: String, currentMessage: InAppMessage) async -> String? {
        #if canImport(Supabase)
        do {
            struct InsertRow: Encodable {
                let id: String
                let title: String
                let message: String
                let action_text: String?
                let action_url: String?
                let is_active: Bool
            }
            
            let client = SupabaseService.instance.client
            
            // 1. Delete the old broadcast from database
            try await client.from("in_app_messages")
                .delete()
                .eq("id", value: oldId)
                .execute()
                
            // 2. Insert the updated copy with newId and current time
            let payload = InsertRow(
                id: newId,
                title: currentMessage.title,
                message: currentMessage.message,
                action_text: currentMessage.actionText,
                action_url: currentMessage.actionUrl,
                is_active: currentMessage.isActive
            )
            try await client.from("in_app_messages")
                .insert(payload)
                .execute()
                
            return nil
        } catch {
            return error.localizedDescription
        }
        #else
        return "Supabase client not available"
        #endif
    }
    
    public func uploadAnnouncementImage(fileName: String, data: Data) async throws -> String {
        #if canImport(Supabase)
        let client = SupabaseService.instance.client
        let path = "announcements/\(fileName)"
        let storage = client.storage.from("carol-pdfs")
        
        try await storage.upload(
            path,
            data: data,
            options: FileOptions(
                contentType: "image/jpeg",
                upsert: true
            )
        )
        return try storage.getPublicURL(path: path).absoluteString
        #else
        throw NSError(domain: "AnnouncementsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not available"])
        #endif
    }
    
    public func deleteAnnouncementImage(imageUrl: String) async {
        #if canImport(Supabase)
        do {
            let marker = "/public/carol-pdfs/"
            if let range = imageUrl.range(of: marker) {
                let path = String(imageUrl[range.upperBound...])
                let client = SupabaseService.instance.client
                _ = try await client.storage.from("carol-pdfs").remove(paths: [path])
            }
        } catch {
            print("AnnouncementsService: Error deleting image asset: \(error)")
        }
        #endif
    }
    
    private func getDismissedIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: dismissedBroadcastsKey) ?? []
        return Set(array)
    }
}

public struct InAppMessage: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let message: String
    public let actionText: String?
    public let actionUrl: String?
    public let isActive: Bool
    public let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case actionText = "action_text"
        case actionUrl = "action_url"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
    
    public var displayMessage: String {
        let marker = "||image_url="
        if let range = message.range(of: marker) {
            return String(message[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return message
    }
    
    public var imageUrl: String? {
        let marker = "||image_url="
        if let range = message.range(of: marker) {
            return String(message[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
