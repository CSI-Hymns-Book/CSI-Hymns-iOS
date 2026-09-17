import Foundation
import Combine

/// Local store for user's favorite hymns and keerthanes on Apple Watch.
@MainActor
public final class WatchFavoritesStore: ObservableObject {
    public static let shared = WatchFavoritesStore()
    
    private let defaultsKey = "csi_watch_favorites_v1"
    @Published public private(set) var favoriteKeys: Set<String> = []
    
    private init() {
        loadFromDefaults()
    }
    
    private func loadFromDefaults() {
        if let array = UserDefaults.standard.stringArray(forKey: defaultsKey) {
            self.favoriteKeys = Set(array)
        }
    }
    
    private func saveToDefaults() {
        UserDefaults.standard.set(Array(favoriteKeys), forKey: defaultsKey)
    }
    
    public func key(for hymn: Hymn) -> String {
        "\(hymn.type)_\(hymn.number)"
    }
    
    public func isFavorite(_ hymn: Hymn) -> Bool {
        let k = key(for: hymn)
        return favoriteKeys.contains(k) ||
               favoriteKeys.contains("\(hymn.number)") ||
               favoriteKeys.contains("MT_\(hymn.number)")
    }
    
    public func toggleFavorite(_ hymn: Hymn) {
        let k = key(for: hymn)
        if isFavorite(hymn) {
            favoriteKeys.remove(k)
            favoriteKeys.remove("\(hymn.number)")
            favoriteKeys.remove("MT_\(hymn.number)")
        } else {
            favoriteKeys.insert(k)
        }
        saveToDefaults()
        WatchConnectivityService.shared.sendFavoritesToPhone(favoriteKeys)
    }
    
    public func syncFromRemote(keys: [String]) {
        self.favoriteKeys = Set(keys)
        saveToDefaults()
    }
}
