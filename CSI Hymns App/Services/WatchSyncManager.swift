import Foundation
import Combine
import WatchConnectivity

/// Manages data synchronization between the iOS app and paired Apple Watch.
public final class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSyncManager()
    
    @Published public private(set) var isWatchAppInstalled = false
    @Published public private(set) var isPaired = false
    
    private override init() {
        super.init()
        activateSession()
    }
    
    public func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    // MARK: - WCSessionDelegate
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchSyncManager: activation error: \(error)")
        } else {
            DispatchQueue.main.async {
                self.isWatchAppInstalled = session.isWatchAppInstalled
                self.isPaired = session.isPaired
            }
            // Push initial favorites to Watch
            syncFavorites(ids: FavoritesManager.shared.favoriteIds)
        }
    }
    
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    
    public func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate if user switches watches
        WCSession.default.activate()
    }
    
    public func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isPaired = session.isPaired
        }
    }
    
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingData(applicationContext)
    }
    
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingData(userInfo)
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingData(message)
    }
    
    private func handleIncomingData(_ dict: [String: Any]) {
        if let favs = dict["favorites_from_watch"] as? [String] {
            print("WatchSyncManager: Received favorites update from watch: \(favs.count) items")
            // Can be bridged into FavoritesManager if needed
        }
        
        if let action = dict["action"] as? String, action == "open_order_of_service" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("OpenOrderOfServiceRequested"), object: nil)
            }
        }
    }
    
    // MARK: - Sync Methods
    
    /// Syncs current favorites set to the Apple Watch.
    public func syncFavorites(ids: Set<String>) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }
        
        let payload: [String: Any] = ["favorites": Array(ids)]
        do {
            try session.updateApplicationContext(payload)
        } catch {
            session.transferUserInfo(payload)
        }
    }
    
    /// Syncs the Sunday Service Setlist to the Apple Watch.
    public func syncSundaySetlist(songs: [(type: String, number: Int, title: String, label: String?)]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isWatchAppInstalled else { return }
        
        let rawArray: [[String: Any]] = songs.map {
            var d: [String: Any] = [
                "type": $0.type,
                "number": $0.number,
                "title": $0.title
            ]
            if let label = $0.label {
                d["label"] = label
            }
            return d
        }
        
        let payload: [String: Any] = ["setlist_raw": rawArray]
        do {
            try session.updateApplicationContext(payload)
        } catch {
            session.transferUserInfo(payload)
        }
    }
}
