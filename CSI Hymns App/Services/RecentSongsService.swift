import Foundation
import Observation

/// Clean cache coordinator tracking recently read hymns and keerthanes.
@Observable
public final class RecentSongsService {
    public static let shared = RecentSongsService()
    
    public var recentSongKeys: [String] = []
    private let storageKey = "csi_recent_songs_keys_v1"
    private let maxLimit = 25
    
    private init() {
        loadRecents()
    }
    
    /// Records a song opened by the user, moving it to the top and enforcing the 25 limit.
    public func addRecentSong(prefix: String, number: Int) {
        let key = "\(prefix)\(number)"
        
        // Remove duplicate if it already exists
        recentSongKeys.removeAll { $0 == key }
        
        // Insert at the beginning (most recent)
        recentSongKeys.insert(key, at: 0)
        
        // Enforce max limit of 25
        if recentSongKeys.count > maxLimit {
            recentSongKeys = Array(recentSongKeys.prefix(maxLimit))
        }
        
        saveRecents()
    }
    
    public func clearAllRecents() {
        recentSongKeys.removeAll()
        saveRecents()
    }
    
    private func loadRecents() {
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey) {
            self.recentSongKeys = saved
        }
    }
    
    private func saveRecents() {
        UserDefaults.standard.set(recentSongKeys, forKey: storageKey)
    }
}
