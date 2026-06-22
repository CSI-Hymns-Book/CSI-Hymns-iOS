import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

/// Service determining the active festive (Christmas) state.
///
/// Resolution order mirrors the Flutter `ChristmasModeService`:
/// 1. Remote override from Supabase `app_config.is_christmas_time` (cached locally on success)
/// 2. Local cache in UserDefaults (used when the remote fetch fails offline)
/// 3. Automatic calendar detection (Dec 1 - Jan 6, Epiphany)
///
/// A manual override (Settings toggle) persists locally for testing or off-season use.
@MainActor
@Observable
public final class ChristmasModeService {
    public static let shared = ChristmasModeService()
    
    private static let localKey = "is_christmas_time"
    
    // MARK: - Properties
    public private(set) var isChristmasTime = false
    public private(set) var isLoading = true
    
    private init() {
        // Seed synchronously from the local cache / auto-detect so the very first
        // paint already reflects the correct theme, then refine from remote.
        self.isChristmasTime = Self.loadLocalConfig()
        self.isLoading = false
        Task { @MainActor in
            await loadChristmasConfig()
        }
    }
    
    public func loadChristmasConfig() async {
        // Step 1: Try pulling remote overrides from Supabase
        var remoteCheck: Bool? = nil
        #if canImport(Supabase)
        do {
            let client = SupabaseService.instance.client
            let result: [AppConfigRow] = try await client.from("app_config")
                .select("key, value")
                .eq("key", value: "is_christmas_time")
                .execute()
                .value
            
            if let first = result.first {
                remoteCheck = first.value.boolValue ?? false
            }
        } catch {
            print("ChristmasModeService: Remote config fetch error: \(error)")
        }
        #endif
        
        // Step 2: Resolve. Remote wins; otherwise fall back to local cache / auto-detect.
        let resolvedValue = remoteCheck ?? Self.loadLocalConfig()
        
        // Cache successful remote results for offline use.
        if let remote = remoteCheck {
            Self.saveLocalConfig(remote)
        }
        
        await MainActor.run {
            self.isChristmasTime = resolvedValue
        }
    }
    
    /// Manually set Christmas mode (Settings toggle / testing). Persisted locally.
    @MainActor
    public func setChristmasMode(_ enabled: Bool) {
        self.isChristmasTime = enabled
        Self.saveLocalConfig(enabled)
    }
    
    // MARK: - Local persistence
    
    private static func loadLocalConfig() -> Bool {
        if UserDefaults.standard.object(forKey: localKey) != nil {
            return UserDefaults.standard.bool(forKey: localKey)
        }
        return autoDetectChristmasSeason()
    }
    
    private static func saveLocalConfig(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: localKey)
    }
    
    /// Returns true if the current calendar date falls between Dec 1st and Jan 6th.
    private static func autoDetectChristmasSeason() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        
        if month == 12 {
            return true
        } else if month == 1 && day <= 6 {
            return true
        }
        return false
    }
}
