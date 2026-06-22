import Foundation

#if canImport(Supabase)
import Supabase
#endif

/// Decision describing whether the running build must be updated before use.
public struct ForceUpdateDecision: Sendable {
    public let requiresUpdate: Bool
    public let message: String?
    public let iosStoreURL: String?
}

/// Reads force-update feature flags from Supabase `app_config` and decides whether the
/// current build is below the configured minimum version / build number.
///
/// Mirrors the Flutter `ForceUpdateService`. Disabled by default unless a minimum is set.
public final class ForceUpdateService: Sendable {
    public static let shared = ForceUpdateService()
    
    private static let keyEnabled = "force_update_enabled"
    private static let keyMinVersion = "force_update_min_version"
    private static let keyMinBuildNumber = "force_update_min_build_number"
    private static let keyMessage = "force_update_message"
    private static let keyIosStoreURL = "force_update_ios_store_url"
    
    private init() {}
    
    public func getDecision() async -> ForceUpdateDecision {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let currentBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
        
        #if canImport(Supabase)
        do {
            let rows: [AppConfigRow] = try await SupabaseService.instance.client
                .from("app_config")
                .select("key, value")
                .in("key", values: [
                    Self.keyEnabled,
                    Self.keyMinVersion,
                    Self.keyMinBuildNumber,
                    Self.keyMessage,
                    Self.keyIosStoreURL
                ])
                .execute()
                .value
            
            var config: [String: AppConfigValue] = [:]
            for row in rows { config[row.key] = row.value }
            
            let minVersion = config[Self.keyMinVersion]?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let minBuild = config[Self.keyMinBuildNumber].flatMap { Int($0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let enabled = config[Self.keyEnabled]?.boolValue ?? (minVersion != nil || minBuild != nil)
            
            let requiresByVersion: Bool = {
                guard let minVersion, !minVersion.isEmpty else { return false }
                return isVersionLower(currentVersion, than: minVersion)
            }()
            let requiresByBuild = (minBuild != nil) && currentBuild > 0 && currentBuild < minBuild!
            let requiresUpdate = enabled && (requiresByVersion || requiresByBuild)
            
            return ForceUpdateDecision(
                requiresUpdate: requiresUpdate,
                message: config[Self.keyMessage]?.stringValue,
                iosStoreURL: config[Self.keyIosStoreURL]?.stringValue
            )
        } catch {
            print("ForceUpdateService: Remote config fetch failed: \(error)")
            return ForceUpdateDecision(requiresUpdate: false, message: nil, iosStoreURL: nil)
        }
        #else
        return ForceUpdateDecision(requiresUpdate: false, message: nil, iosStoreURL: nil)
        #endif
    }
    
    /// Returns true when `current` is a lower semantic version than `minimum`.
    private func isVersionLower(_ current: String, than minimum: String) -> Bool {
        let a = versionParts(current)
        let b = versionParts(minimum)
        let count = max(a.count, b.count)
        for i in 0..<count {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av < bv { return true }
            if av > bv { return false }
        }
        return false
    }
    
    private func versionParts(_ input: String) -> [Int] {
        let normalized = input.split(separator: "-").first.map(String.init) ?? input
        let trimmed = normalized.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return [0] }
        return trimmed.split(separator: ".").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
    }
}
