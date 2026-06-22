import Foundation

/// Lightweight App Store version check (iOS equivalent of Android Play Core flexible update prompt).
public enum AppStoreUpdateService {
    private static let bundleId = "com.reyzie.hymns"
    
    public struct UpdateInfo: Sendable {
        public let storeVersion: String
        public let trackViewUrl: String
    }
    
    /// Returns update info when the App Store version is newer than the installed build.
    public static func checkForUpdate() async -> UpdateInfo? {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=in") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let first = results.first,
                let storeVersion = first["version"] as? String,
                let trackURL = first["trackViewUrl"] as? String
            else { return nil }
            
            if isVersionLower(current, than: storeVersion) {
                return UpdateInfo(storeVersion: storeVersion, trackViewUrl: trackURL)
            }
        } catch {
            print("AppStoreUpdateService: lookup failed: \(error)")
        }
        return nil
    }
    
    private static func isVersionLower(_ current: String, than minimum: String) -> Bool {
        let a = current.split(separator: ".").map { Int($0) ?? 0 }
        let b = minimum.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(a.count, b.count)
        for i in 0..<count {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av < bv { return true }
            if av > bv { return false }
        }
        return false
    }
}
