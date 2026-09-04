import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

/// Reprsents a syncable Jira support ticket retrieved from Supabase.
public struct JiraTicket: Codable, Identifiable, Hashable {
    public let id: String
    public let ticketKey: String
    public let ticketUrl: String
    public let songType: String
    public let songNumber: Int
    public let songTitle: String
    public let description: String?
    public let appVersion: String?
    public var jiraStatus: String
    public let jiraStatusId: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case ticketKey = "ticket_key"
        case ticketUrl = "ticket_url"
        case songType = "song_type"
        case songNumber = "song_number"
        case songTitle = "song_title"
        case description
        case appVersion = "app_version"
        case jiraStatus = "jira_status"
        case jiraStatusId = "jira_status_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Service managing ticket synchronization with Jira Cloud API and Supabase tables.
@Observable
public final class TicketsService: Sendable {
    public static let shared = TicketsService()
    
    private init() {}
    
    /// Generates or loads a secure unique device identifier for unregistered users.
    public func getDeviceId() -> String {
        let key = "csi_hymns_device_id_v1"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = "device_\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    /// Fetches all tickets submitted by this user (or this device if unregistered).
    public func getMyTickets() async throws -> [JiraTicket] {
        let svc = SupabaseService.instance
        let deviceId = getDeviceId()
        
        #if canImport(Supabase)
        let client = SupabaseService.instance.client
        if svc.isAuthenticated, let userId = svc.currentUser?.id {
            let tickets: [JiraTicket] = try await client.from("jira_tickets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            return tickets
        } else {
            let tickets: [JiraTicket] = try await client.rpc(
                "get_guest_tickets",
                params: ["p_device_id": deviceId]
            )
            .execute()
            .value
            return tickets
        }
        #else
        // Clean empty ticket list for offline production state
        try? await Task.sleep(for: .seconds(0.3))
        return []
        #endif
    }
    
    /// Sync active status fields off Jira APIs for open items.
    public func syncActiveTicketStatuses(maxTickets: Int = 12) async {
        do {
            let tickets = try await getMyTickets()
            let active = tickets
                .filter { !Self.isResolvedStatus($0.jiraStatus) }
                .prefix(maxTickets)
            
            for ticket in active {
                await JiraService.shared.syncTicketStatus(ticketKey: ticket.ticketKey)
                await JiraService.shared.syncTicketComments(ticketId: ticket.id, ticketKey: ticket.ticketKey)
                try? await Task.sleep(for: .milliseconds(250))
            }
        } catch {
            print("TicketsService: Status sync failed: \(error)")
        }
    }
    
    /// Sync comments from Jira to Supabase for a specific ticket
    public func syncTicketComments(ticketId: String, ticketKey: String) async {
        await JiraService.shared.syncTicketComments(ticketId: ticketId, ticketKey: ticketKey)
    }
    
    /// Fetch messages from Supabase for a specific ticket
    public func getTicketMessages(ticketKey: String) async throws -> [TicketMessage] {
        #if canImport(Supabase)
        let client = SupabaseService.instance.client
        if SupabaseService.instance.isAuthenticated {
            let messages: [TicketMessage] = try await client.from("ticket_messages")
                .select()
                .eq("ticket_key", value: ticketKey)
                .execute()
                .value
            return messages.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        } else {
            let messages: [TicketMessage] = try await client.rpc(
                "get_guest_ticket_messages",
                params: [
                    "p_device_id": getDeviceId(),
                    "p_ticket_key": ticketKey
                ]
            )
            .execute()
            .value
            return messages.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        }
        #else
        return []
        #endif
    }
    
    /// Send a message: post comment to Jira and insert to Supabase
    public func sendTicketMessage(ticketId: String, ticketKey: String, message: String) async throws -> TicketMessage? {
        // Post directly to Jira ticket
        let posted = await JiraService.shared.addComment(ticketKey: ticketKey, commentText: message)
        guard posted else { return nil }
        
        #if canImport(Supabase)
        struct InsertMessage: Encodable {
            let ticket_id: String
            let ticket_key: String
            let sender: String
            let message: String
        }
        
        let client = SupabaseService.instance.client
        let payload = InsertMessage(
            ticket_id: ticketId,
            ticket_key: ticketKey,
            sender: "user",
            message: message
        )
        
        if SupabaseService.instance.isAuthenticated {
            let response: TicketMessage = try await client.from("ticket_messages")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            return response
        }
        
        try await client.from("ticket_messages")
            .insert(payload)
            .execute()
        return TicketMessage(
            id: UUID().uuidString,
            ticketId: ticketId,
            ticketKey: ticketKey,
            sender: "user",
            message: message,
            createdAt: Date()
        )
        #else
        return TicketMessage(
            id: UUID().uuidString,
            ticketId: ticketId,
            ticketKey: ticketKey,
            sender: "user",
            message: message,
            createdAt: Date()
        )
        #endif
    }
    
    /// Utility check for resolved statuses.
    public static func isResolvedStatus(_ status: String) -> Bool {
        let value = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "done" || value == "resolved" || value == "closed"
    }
}

/// Represents a support message synced with Jira and Supabase
public struct TicketMessage: Codable, Identifiable, Hashable, Sendable {
    public let id: String?
    public let ticketId: String
    public let ticketKey: String
    public let sender: String // "user" or "admin"
    public let message: String
    public let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ticketId = "ticket_id"
        case ticketKey = "ticket_key"
        case sender
        case message
        case createdAt = "created_at"
    }
}
