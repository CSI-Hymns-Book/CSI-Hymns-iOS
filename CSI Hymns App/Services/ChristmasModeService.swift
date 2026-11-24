import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

/// Service determining the active festive (Christmas) state.
///
/// Resolution order (see `ChristmasModeResolver`):
/// 1. The user's own choice on this phone (the Settings toggle). It always wins and survives a
///    relaunch: the server config never overwrites it.
/// 2. Remote override from Supabase `app_config.is_christmas_time` (cached for offline use)
/// 3. The cached remote value, when the fetch fails offline
/// 4. Automatic calendar detection (Dec 1 - Jan 6)
@MainActor
@Observable
public final class ChristmasModeService {
    public static let shared = ChristmasModeService()

    /// What the server last said. Kept apart from the user's choice so one never overwrites the other.
    private static let remoteCacheKey = "christmas_remote_cached"
    /// What the user chose in Settings. Absent until they flip the toggle.
    private static let manualKey = "christmas_manual_override"
    /// The key older versions used for both. Read once as the cached server value.
    private static let legacyKey = "is_christmas_time"

    // MARK: - Properties
    public private(set) var isChristmasTime = false
    public private(set) var isLoading = true

    private init() {
        // Seed synchronously from the local state so the very first paint already reflects the
        // right theme, then refine from the server.
        self.isChristmasTime = Self.resolveLocal(remote: nil)
        self.isLoading = false
        Task { @MainActor in
            await loadChristmasConfig()
        }
    }

    public func loadChristmasConfig() async {
        // Step 1: Try pulling the remote setting from Supabase
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

        #if DEBUG
        // Debug builds only: `-forceChristmas` on launch previews the festive UI off-season.
        if ProcessInfo.processInfo.arguments.contains("-forceChristmas") { remoteCheck = true }
        #endif

        // Remember what the server said for offline launches. This never touches the user's choice.
        if let remote = remoteCheck { UserDefaults.standard.set(remote, forKey: Self.remoteCacheKey) }

        self.isChristmasTime = Self.resolveLocal(remote: remoteCheck)
    }

    /// The Settings toggle. This is the user's own choice: it is kept across launches and beats the
    /// server setting until `clearManualChoice()` hands control back.
    public func setChristmasMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.manualKey)
        self.isChristmasTime = enabled
    }

    /// True once the user has flipped the toggle on this phone.
    public var hasManualChoice: Bool { Self.manualChoice() != nil }

    /// Forgets the user's choice so the server setting (or the season) decides again.
    public func clearManualChoice() {
        UserDefaults.standard.removeObject(forKey: Self.manualKey)
        self.isChristmasTime = Self.resolveLocal(remote: nil)
    }

    // MARK: - Local state

    private static func manualChoice() -> Bool? {
        UserDefaults.standard.object(forKey: manualKey) as? Bool
    }

    private static func cachedRemote() -> Bool? {
        let defaults = UserDefaults.standard
        if let cached = defaults.object(forKey: remoteCacheKey) as? Bool { return cached }
        return defaults.object(forKey: legacyKey) as? Bool
    }

    private static func resolveLocal(remote: Bool?) -> Bool {
        ChristmasModeResolver.resolve(manual: manualChoice(), remote: remote, cachedRemote: cachedRemote(), season: autoDetectChristmasSeason())
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
