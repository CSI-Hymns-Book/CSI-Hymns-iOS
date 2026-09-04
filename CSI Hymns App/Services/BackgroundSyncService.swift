import Foundation
import UIKit
import SwiftUI

public final class BackgroundSyncService {
    public static let shared = BackgroundSyncService()
    
    private init() {}
    
    public func performBackgroundSync() {
        var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "com.csihymns.backgroundsync") {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
        
        Task {
            print("[BackgroundSync] Starting background sync checks...")
            
            await syncSongsIfNeeded(section: .hymns)
            await syncSongsIfNeeded(section: .keerthanes)
            await syncSongsIfNeeded(section: .mt)
            await syncOrderOfServiceIfNeeded()
            
            print("[BackgroundSync] Background sync completed.")
            
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    private func syncSongsIfNeeded(section: HymnsListViewModel.AppSection) async {
        let key: String
        let urlString: String
        let cacheFileName: String
        
        switch section {
        case .keerthanes:
            key = "last_keerthane_update"
            urlString = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/keerthane_data.json"
            cacheFileName = "keerthane_data_cache.json"
        case .mt:
            key = "last_mt_update"
            urlString = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/mangalore_hymns_data.json"
            cacheFileName = "mangalore_data_cache.json"
        case .hymns:
            key = "last_lyrics_update"
            urlString = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/hymns_data.json"
            cacheFileName = "hymn_data_cache.json"
        }
        
        let last = UserDefaults.standard.double(forKey: key)
        let now = Date().timeIntervalSince1970
        let interval: TimeInterval = 3 * 24 * 60 * 60 // 3 days
        
        guard now - last >= interval else {
            print("[BackgroundSync] \(section) update skipped (within 3 days).")
            return
        }
        
        print("[BackgroundSync] Syncing \(section)...")
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Ensure valid format
                _ = try JSONDecoder().decode([Hymn].self, from: data)
                
                let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                let cacheFileUrl = cacheDirectory.appendingPathComponent(cacheFileName)
                try data.write(to: cacheFileUrl)
                
                UserDefaults.standard.set(now, forKey: key)
                print("[BackgroundSync] \(section) sync succeeded.")
            }
        } catch {
            print("[BackgroundSync] \(section) sync failed: \(error)")
        }
    }
    
    private func syncOrderOfServiceIfNeeded() async {
        await OrderOfServiceStore.ensureSeededAndRefreshIfStale()
    }
}
