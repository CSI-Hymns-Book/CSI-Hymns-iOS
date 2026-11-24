import SwiftUI

@main
struct CSIHymnsWatchApp: App {
    init() {
        // Activate WatchConnectivity on launch
        _ = WatchConnectivityService.shared
        // Preload offline hymn data
        _ = WatchDataLoader.shared
    }
    
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
    }
}
