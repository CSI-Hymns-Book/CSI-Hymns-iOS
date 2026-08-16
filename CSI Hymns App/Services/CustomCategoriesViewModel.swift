import Foundation
import Observation
import SwiftUI

/// Represents a user-customized collection category of hymns or keerthanes.
public struct CustomCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var songIds: [String] // Array of format "hymn_number" or "keerthane_number"
}

/// A reactive manager driving the categories lists, folder creators, and local storage caches.
///
/// Persistence is unified: a local UserDefaults cache always backs the UI for instant
/// rendering and offline use. When the user is authenticated, every mutation is also
/// mirrored to Supabase (`custom_categories` / `custom_category_songs`) and the list is
/// refreshed from the server on load.
@Observable
public final class CustomCategoriesViewModel {
    public static let shared = CustomCategoriesViewModel()
    
    public var categories: [CustomCategory] = []
    public var isShowingCreateDialog = false
    public var newCategoryName = ""
    public var limitAlert = false
    
    static let storageKey = "csi_custom_categories_local_v1"
    private var storageKey: String { Self.storageKey }
    
    public init() {
        loadCategories()
    }
    
    private var isAuthenticated: Bool {
        SupabaseService.instance.isAuthenticated
    }
    
    /// Creates a new user category folder checking limits for guest accounts.
    public func createCategory() -> Bool {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        
        let limit = 5
        if !isAuthenticated && categories.count >= limit {
            limitAlert = true
            return false
        }
        
        let tempId = UUID().uuidString
        let newFolder = CustomCategory(id: tempId, name: name, songIds: [])
        categories.append(newFolder)
        saveCategories()
        
        newCategoryName = ""
        isShowingCreateDialog = false
        
        if isAuthenticated {
            Task { [weak self] in
                guard let self else { return }
                if let remoteId = try? await SupabaseService.instance.createCustomCategoryRemote(name: name) {
                    let pendingSongs: [String] = await MainActor.run {
                        if let idx = self.categories.firstIndex(where: { $0.id == tempId }) {
                            let songs = self.categories[idx].songIds
                            self.categories[idx] = CustomCategory(id: String(remoteId), name: name, songIds: songs)
                            self.saveCategories()
                            return songs
                        }
                        return []
                    }
                    // Songs added while the folder still had a UUID id never reached Supabase.
                    for key in pendingSongs {
                        guard let parsed = SupabaseService.parseSongKey(key) else { continue }
                        try? await SupabaseService.instance.addSongToCustomCategoryRemote(
                            categoryId: remoteId,
                            songId: parsed.id,
                            songType: parsed.type
                        )
                    }
                }
            }
        }
        return true
    }
    
    /// Deletes categories at specific index sets.
    public func deleteCategory(at offsets: IndexSet) {
        let removed = offsets.map { categories[$0] }
        categories.remove(atOffsets: offsets)
        saveCategories()
        
        if isAuthenticated {
            Task {
                for category in removed {
                    if let remoteId = Int(category.id) {
                        try? await SupabaseService.instance.softDeleteCustomCategoryRemote(id: remoteId)
                    }
                }
            }
        }
    }
    
    /// Adds a song key ("hymn_5" / "keerthane_3") to a category.
    public func addSong(categoryId: String, songKey: String) {
        guard let idx = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        guard !categories[idx].songIds.contains(songKey) else { return }
        categories[idx].songIds.append(songKey)
        saveCategories()
        
        if isAuthenticated, let remoteId = Int(categoryId), let parsed = SupabaseService.parseSongKey(songKey) {
            Task {
                try? await SupabaseService.instance.addSongToCustomCategoryRemote(categoryId: remoteId, songId: parsed.id, songType: parsed.type)
            }
        }
    }
    
    /// Removes a song key from a category.
    public func removeSong(categoryId: String, songKey: String) {
        guard let idx = categories.firstIndex(where: { $0.id == categoryId }) else { return }
        categories[idx].songIds.removeAll { $0 == songKey }
        saveCategories()
        
        if isAuthenticated, let remoteId = Int(categoryId), let parsed = SupabaseService.parseSongKey(songKey) {
            Task {
                try? await SupabaseService.instance.removeSongFromCustomCategoryRemote(categoryId: remoteId, songId: parsed.id, songType: parsed.type)
            }
        }
    }
    
    public func loadCategories() {
        // 1. Load local cache synchronously for instant UI.
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            if let decoded = try? JSONDecoder().decode([CustomCategory].self, from: data) {
                // Dynamic cleanup: strip out any lingering mock categories cached in previous installations
                let filtered = decoded.filter { $0.id != "seed_1" && $0.name != "Choir Favorites" }
                self.categories = filtered
                if filtered.count != decoded.count {
                    saveCategories()
                }
            }
            // Decode failure: keep in-memory / on-disk data. Never wipe collections.
        } else {
            self.categories = []
        }
        
        // 2. If authenticated, refresh from Supabase in the background.
        if isAuthenticated {
            Task { [weak self] in
                guard let self else { return }
                if let remote = try? await SupabaseService.instance.fetchCustomCategoriesWithSongs() {
                    let localSnapshot = await MainActor.run { self.categories }
                    let merged = Self.mergeRemoteKeepingLocalPending(remote: remote, local: localSnapshot)
                    await MainActor.run {
                        self.categories = merged
                        self.saveCategories()
                    }
                    self.uploadSongsMissingRemotely(local: localSnapshot, remote: remote)
                }
            }
        }
    }
    
    public func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    /// Called once after sign-in: migrates local-only categories to Supabase and
    /// replaces the local cache with the authoritative remote set.
    public static func syncAfterSignIn() async {
        let local: [CustomCategory]
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                local = try JSONDecoder().decode([CustomCategory].self, from: data)
            } catch {
                print("CustomCategoriesViewModel: JSON decoding failed: \(error)")
                local = []
            }
        } else {
            local = []
        }
        
        if let remote = try? await SupabaseService.instance.migrateAndFetchCustomCategories(localCategories: local) {
            let merged = mergeRemoteKeepingLocalPending(remote: remote, local: local)
            if let encoded = try? JSONEncoder().encode(merged) {
                UserDefaults.standard.set(encoded, forKey: storageKey)
            }
            await MainActor.run {
                shared.categories = merged
            }
            shared.uploadSongsMissingRemotely(local: local, remote: remote)
        }
    }
    
    /// Remote list is authoritative for server-backed folders, but a concurrent
    /// fetch must not drop UUID folders still being created or songs added
    /// before their remote insert finished.
    static func mergeRemoteKeepingLocalPending(remote: [CustomCategory], local: [CustomCategory]) -> [CustomCategory] {
        var merged = remote
        for localCat in local {
            if let idx = merged.firstIndex(where: {
                $0.id == localCat.id || $0.name.caseInsensitiveCompare(localCat.name) == .orderedSame
            }) {
                var songs = merged[idx].songIds
                for song in localCat.songIds where !songs.contains(song) {
                    songs.append(song)
                }
                merged[idx].songIds = songs
            } else if Int(localCat.id) == nil {
                merged.append(localCat)
            }
        }
        return merged
    }
    
    private func uploadSongsMissingRemotely(local: [CustomCategory], remote: [CustomCategory]) {
        guard isAuthenticated else { return }
        for remoteCat in remote {
            guard let remoteId = Int(remoteCat.id) else { continue }
            guard let localCat = local.first(where: {
                $0.id == remoteCat.id || $0.name.caseInsensitiveCompare(remoteCat.name) == .orderedSame
            }) else { continue }
            let missing = localCat.songIds.filter { !remoteCat.songIds.contains($0) }
            for key in missing {
                guard let parsed = SupabaseService.parseSongKey(key) else { continue }
                Task {
                    try? await SupabaseService.instance.addSongToCustomCategoryRemote(
                        categoryId: remoteId,
                        songId: parsed.id,
                        songType: parsed.type
                    )
                }
            }
        }
    }
}
