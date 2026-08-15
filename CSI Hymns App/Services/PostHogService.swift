import Foundation
import UIKit

/// A robust, thread-safe, lightweight PostHog client that sends analytics events
/// directly to the PostHog capture API endpoint without bulky external SDK dependencies.
public final class PostHogService: Sendable {
    public static let shared = PostHogService()
    
    private let apiKey: String?
    private let host: String
    private var distinctId: String {
        if let identified = UserDefaults.standard.string(forKey: "csi_analytics_identified_uid") {
            return identified
        }
        let key = "csi_analytics_distinct_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    private init() {
        // Load configurations securely from Secrets.plist
        var loadedKey: String? = nil
        var loadedHost = "https://us.i.posthog.com"
        
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) {
            loadedKey = dict["PostHogAPIKey"] as? String
            if let hostStr = dict["PostHogHost"] as? String {
                loadedHost = hostStr
            }
        }
        
        self.apiKey = loadedKey
        self.host = loadedHost
        
        print("PostHogService: Initialized")
    }
    
    /// Identifies the user in PostHog by linking their anonymous ID with their Supabase UUID.
    public func identify(userId: String) {
        guard UserDefaults.standard.bool(forKey: ConsentStorageKeys.analytics) else { return }
        let key = "csi_analytics_distinct_id"
        let anonId = UserDefaults.standard.string(forKey: key) ?? UUID().uuidString
        UserDefaults.standard.set(anonId, forKey: key)
        
        UserDefaults.standard.set(userId, forKey: "csi_analytics_identified_uid")
        
        track(event: "$identify", properties: [
            "$anon_distinct_id": anonId
        ])
    }
    
    /// Resets the user identity, reverting to a new anonymous ID.
    public func reset() {
        UserDefaults.standard.removeObject(forKey: "csi_analytics_identified_uid")
        let newAnonId = UUID().uuidString
        UserDefaults.standard.set(newAnonId, forKey: "csi_analytics_distinct_id")
    }
    
    /// Tracks an event with custom properties.
    public func track(event: String, properties: [String: Any] = [:]) {
        guard UserDefaults.standard.bool(forKey: ConsentStorageKeys.analytics) else { return }
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            print("PostHogService: API key missing, ignoring event: \(event)")
            return
        }
        
        let url = URL(string: "\(host)/capture/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Merge system properties (device details, app version, distinct_id)
        var mergedProperties = properties
        mergedProperties["distinct_id"] = distinctId
        mergedProperties["$lib"] = "csi_ios_native_posthog"
        mergedProperties["$lib_version"] = "1.0.0"
        mergedProperties["$os"] = "iOS"
        mergedProperties["$os_version"] = UIDevice.current.systemVersion
        mergedProperties["$device"] = UIDevice.current.model
        mergedProperties["$app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // If Supabase user is logged in, attach their UUID
        if let uid = SupabaseService.instance.currentUser?.id {
            mergedProperties["supabase_uid"] = uid.uuidString
            mergedProperties["authenticated"] = true
        } else {
            mergedProperties["authenticated"] = false
        }
        
        let payload: [String: Any] = [
            "api_key": apiKey,
            "event": event,
            "properties": mergedProperties,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = jsonData
        
        // Dispatch network request asynchronously in background
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("PostHogService: Failed to send event '\(event)': \(error)")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("PostHogService: Server returned status \(httpResponse.statusCode) for event '\(event)'")
            } else {
                print("PostHogService: Successfully tracked event: \(event)")
            }
        }.resume()
    }
    
    /// Tracks screen views natively.
    public func trackScreen(_ name: String) {
        track(event: "$pageview", properties: ["$screen_name": name])
    }
}
