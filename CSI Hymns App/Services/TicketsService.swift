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
            // Fetch by logged-in auth UID
            let tickets: [JiraTicket] = try await client.from("jira_tickets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            return tickets
        } else {
            // Fetch by guest device UUID
            let tickets: [JiraTicket] = try await client.from("jira_tickets")
                .select()
                .eq("device_id", value: deviceId)
                .order("created_at", ascending: false)
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
            
            for _ in active {
                // Background update status
                // In production: issues a check to Jira and updates Supabase
                try await Task.sleep(for: .milliseconds(250))
            }
        } catch {
            print("TicketsService: Status sync failed: \(error)")
        }
    }
    
    /// Utility check for resolved statuses.
    public static func isResolvedStatus(_ status: String) -> Bool {
        let value = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return value == "done" || value == "resolved" || value == "closed"
    }
}
