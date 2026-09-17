import Foundation
import Combine
import WatchConnectivity

/// WatchConnectivity bridge for Apple Watch side.
public final class WatchConnectivityService: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchConnectivityService()
    
    @Published public private(set) var isReachable = false
    
    private override init() {
        super.init()
        activateSession()
    }
    
    public func activateSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchConnectivityService: activation failed: \(error)")
        } else {
            print("WatchConnectivityService: activated with state \(activationState.rawValue)")
            Task { @MainActor in
                self.isReachable = session.isReachable
            }
        }
    }
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
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
        // Sync Favorites
        if let favs = dict["favorites"] as? [String] {
            Task { @MainActor in
                WatchFavoritesStore.shared.syncFromRemote(keys: favs)
            }
        }
        
        // Sync Sunday Setlist
        if let setlistData = dict["setlist"] as? Data {
            if let decoded = try? JSONDecoder().decode([SetlistItem].self, from: setlistData) {
                Task { @MainActor in
                    WatchSetlistStore.shared.syncFromRemote(items: decoded)
                }
            }
        } else if let setlistArray = dict["setlist_raw"] as? [[String: Any]] {
            var items: [SetlistItem] = []
            for item in setlistArray {
                let type = item["type"] as? String ?? "hymn"
                let number = item["number"] as? Int ?? 0
                let title = item["title"] as? String ?? ""
                let label = item["label"] as? String
                if number > 0 {
                    items.append(SetlistItem(type: type, number: number, title: title, label: label))
                }
            }
            Task { @MainActor in
                WatchSetlistStore.shared.syncFromRemote(items: items)
            }
        }
    }
    
    // MARK: - Sending data to Phone
    
    public func sendFavoritesToPhone(_ keys: Set<String>) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let payload: [String: Any] = ["favorites_from_watch": Array(keys)]
        do {
            try session.updateApplicationContext(payload)
        } catch {
            session.transferUserInfo(payload)
        }
    }
    
    public func notifyPhoneToOpenOrderOfService() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        
        let payload: [String: Any] = ["action": "open_order_of_service"]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }
}
