import Foundation
import Combine

/// Represents a song entry pinned in the "Sunday Service Setlist".
public struct SetlistItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String { "\(type)_\(number)" }
    public let type: String // hymn, keerthane, mt
    public let number: Int
    public let title: String
    public var label: String? // e.g. "Opening Hymn", "Offertory", "Closing Hymn"
    
    public init(type: String, number: Int, title: String, label: String? = nil) {
        self.type = type
        self.number = number
        self.title = title
        self.label = label
    }
}

/// Manages the active Sunday service setlist on Apple Watch.
@MainActor
public final class WatchSetlistStore: ObservableObject {
    public static let shared = WatchSetlistStore()
    
    private let defaultsKey = "csi_watch_setlist_v1"
    @Published public private(set) var items: [SetlistItem] = []
    
    private init() {
        loadFromDefaults()
    }
    
    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            self.items = try JSONDecoder().decode([SetlistItem].self, from: data)
        } catch {
            print("WatchSetlistStore: Error decoding setlist: \(error)")
        }
    }
    
    private func saveToDefaults() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            print("WatchSetlistStore: Error encoding setlist: \(error)")
        }
    }
    
    public func isInSetlist(type: String, number: Int) -> Bool {
        items.contains { $0.type == type && $0.number == number }
    }
    
    public func add(hymn: Hymn, label: String? = nil) {
        if !isInSetlist(type: hymn.type, number: hymn.number) {
            items.append(SetlistItem(type: hymn.type, number: hymn.number, title: hymn.title, label: label))
            saveToDefaults()
        }
    }
    
    public func remove(type: String, number: Int) {
        items.removeAll { $0.type == type && $0.number == number }
        saveToDefaults()
    }
    
    public func toggle(hymn: Hymn) {
        if isInSetlist(type: hymn.type, number: hymn.number) {
            remove(type: hymn.type, number: hymn.number)
        } else {
            add(hymn: hymn)
        }
    }
    
    public func clear() {
        items.removeAll()
        saveToDefaults()
    }
    
    public func syncFromRemote(items: [SetlistItem]) {
        self.items = items
        saveToDefaults()
    }
}
