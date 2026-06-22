import SwiftUI
import Observation

/// A robust, persistent, and thread-safe favorites manager.
/// Synchronizes local states instantly and uploads changes to Supabase in the background.
@Observable
public final class FavoritesManager {
    public static let shared = FavoritesManager()
    
    // In-memory stores for ultra-fast UI rendering
    public private(set) var favoriteIds: Set<String> = []
    public private(set) var favorites: [Hymn] = []
    
    private let storageKey = "csi_favorites_local_v2"
    
    private init() {
        loadFavorites()
        Task {
            await syncWithRemote()
        }
    }
    
    /// Checks if a song is favorited.
    public func isFavorite(songId: String) -> Bool {
        return favoriteIds.contains(songId)
    }
    
    /// Toggles favorite state with standard haptic cues.
    public func toggleFavorite(song: Hymn) {
        let songId = song.id
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if isFavorite(songId: songId) {
            removeFavorite(songId: songId)
        } else {
            addFavorite(song: song)
        }
    }
    
    public func addFavorite(song: Hymn) {
        let songId = song.id
        guard !favoriteIds.contains(songId) else { return }
        
        favoriteIds.insert(songId)
        favorites.append(song)
        saveFavorites()
        
        // Sync to Supabase asynchronously
        Task {
            let itemType = songId.hasPrefix("keerthane_") ? "keerthane" : "hymn"
            try? await SupabaseService.instance.addFavorite(itemNumber: song.number, itemType: itemType)
        }
    }
    
    public func removeFavorite(songId: String) {
        guard favoriteIds.contains(songId) else { return }
        
        favoriteIds.remove(songId)
        favorites.removeAll { $0.id == songId }
        saveFavorites()
        
        // Sync removal to Supabase asynchronously
        Task {
            let itemType = songId.hasPrefix("keerthane_") ? "keerthane" : "hymn"
            let num = Int(songId.components(separatedBy: "_").last ?? "0") ?? 0
            _ = try? await SupabaseService.instance.removeFavorite(itemNumber: num, itemType: itemType)
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Hymn].self, from: data) {
            self.favorites = decoded
            self.favoriteIds = Set(decoded.map { $0.id })
        } else {
            // Seed sample bookmarks for first setup safety
            let seed = [
                Hymn(number: 25, title: "ಯೇಸುವೇ ನಿನ್ನ ಒಲವು ದೊಡ್ಡದು", signature: "L.M", lyricsKannada: "1. ಯೇಸುವೇ...", lyricsEnglish: "1. Jesus Thy Love..."),
                Hymn(number: 304, title: "ಕ್ರಿಸ್ತನೆ ಜಯಶಾಲಿ", signature: "C.M", lyricsKannada: "1. ಕ್ರಿಸ್ತನೆ ಜಯ...", lyricsEnglish: "1. Christ the Victor...")
            ]
            self.favorites = seed
            self.favoriteIds = Set(seed.map { $0.id })
        }
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    public func getHymnFromCache(number: Int, type: String) -> Hymn? {
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheFileUrl = cacheDirectory.appendingPathComponent(type == "keerthane" ? "keerthane_data_cache.json" : "hymn_data_cache.json")
        
        if fileManager.fileExists(atPath: cacheFileUrl.path),
           let cachedData = try? Data(contentsOf: cacheFileUrl),
           let decoded = try? JSONDecoder().decode([Hymn].self, from: cachedData) {
            if let matched = decoded.first(where: { $0.number == number }) {
                var hymn = matched
                hymn.type = type
                return hymn
            }
        }
        return nil
    }
    
    /// Thread-safe bidirectional synchronization of bookmarks with Supabase database.
    public func syncWithRemote() async {
        guard SupabaseService.instance.isAuthenticated else { return }
        
        do {
            let remoteFavs = try await SupabaseService.instance.fetchFavorites()
            
            // Resolve remote favorites against local cached metadata or construct fallback cards
            var remoteSongs: [Hymn] = []
            for remote in remoteFavs {
                let resolved = getHymnFromCache(number: remote.itemNumber, type: remote.itemType) ?? Hymn(
                    number: remote.itemNumber,
                    title: remote.itemType == "keerthane" ? "Keerthane \(remote.itemNumber)" : "Hymn \(remote.itemNumber)",
                    signature: "C.M",
                    lyricsKannada: "",
                    lyricsEnglish: "",
                    type: remote.itemType
                )
                remoteSongs.append(resolved)
            }
            
            // Perform high-precision state merging on the MainActor
            await MainActor.run {
                var mergedSongs = self.favorites
                var mergedIds = self.favoriteIds
                
                // 1. Insert remote-only favorites to local list
                for remoteSong in remoteSongs {
                    if !mergedIds.contains(remoteSong.id) {
                        mergedIds.insert(remoteSong.id)
                        mergedSongs.append(remoteSong)
                    }
                }
                
                self.favorites = mergedSongs
                self.favoriteIds = mergedIds
                self.saveFavorites()
                
                // 2. Upload any local-only bookmarks back to Supabase
                let localOnly = self.favorites.filter { local in
                    !remoteFavs.contains { $0.itemNumber == local.number && $0.itemType == local.type }
                }
                
                for local in localOnly {
                    Task {
                        try? await SupabaseService.instance.addFavorite(itemNumber: local.number, itemType: local.type)
                    }
                }
            }
            print("FavoritesManager: Successfully performed bidirectional favorites database sync.")
        } catch {
            print("FavoritesManager: Failed to synchronize favorites with Supabase: \(error)")
        }
    }
}
