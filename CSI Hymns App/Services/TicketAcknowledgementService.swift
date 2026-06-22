import Foundation
import Observation

/// Item details representing a resolved ticket that is ready for user acknowledgement.
public struct ResolvedTicketAckItem: Identifiable, Hashable, Sendable {
    public var id: String { ticketKey }
    public let ticketKey: String
    public let songType: String
    public let songNumber: Int
    public let songTitle: String
    public let jiraStatus: String
}

/// Service checking for completed correction tasks on startup.
@Observable
public final class TicketAcknowledgementService: Sendable {
    public static let shared = TicketAcknowledgementService()
    
    private let ackStorageKey = "acknowledged_resolved_ticket_keys_v1"
    private let maxStoredKeys = 500
    
    private init() {}
    
    /// Queries newly resolved tickets which the user has not acknowledged yet.
    public func getUnacknowledgedResolvedTickets(syncFirst: Bool = true) async -> [ResolvedTicketAckItem] {
        if syncFirst {
            await TicketsService.shared.syncActiveTicketStatuses()
        }
        
        do {
            let tickets = try await TicketsService.shared.getMyTickets()
            let acknowledgedKeys = loadAcknowledgedKeys()
            
            let unacknowledged = tickets.filter { ticket in
                TicketsService.isResolvedStatus(ticket.jiraStatus) &&
                !ticket.ticketKey.hasPrefix("PENDING-") &&
                !acknowledgedKeys.contains(ticket.ticketKey)
            }
            
            return unacknowledged.map { ticket in
                ResolvedTicketAckItem(
                    ticketKey: ticket.ticketKey,
                    songType: ticket.songType,
                    songNumber: ticket.songNumber,
                    songTitle: ticket.songTitle,
                    jiraStatus: ticket.jiraStatus
                )
            }
        } catch {
            print("TicketAcknowledgementService: Error gathering resolved acks: \(error)")
            return []
        }
    }
    
    /// Persists acknowledged keys locally to prevent duplicate launches.
    public func markAcknowledged(keys: [String]) {
        guard !keys.isEmpty else { return }
        var current = loadAcknowledgedKeys()
        current.formUnion(keys)
        
        var mergedArray = Array(current)
        if mergedArray.count > maxStoredKeys {
            mergedArray = Array(mergedArray.suffix(maxStoredKeys))
        }
        
        UserDefaults.standard.set(mergedArray, forKey: ackStorageKey)
    }
    
    private func loadAcknowledgedKeys() -> Set<String> {
        let keys = UserDefaults.standard.stringArray(forKey: ackStorageKey) ?? []
        return Set(keys)
    }
}
