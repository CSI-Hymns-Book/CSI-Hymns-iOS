import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

/// Cached remote `app_config` flags shared across Settings, audio URL resolution, admin, and donations.
public struct RemoteAppConfig: Sendable {
    public var isChristmasTime: Bool?
    public var forceUpdateEnabled: Bool?
    public var forceUpdateMinVersion: String?
    public var forceUpdateMinBuildNumber: Int?
    public var forceUpdateMessage: String?
    public var forceUpdateAndroidStoreUrl: String?
    public var forceUpdateIosStoreUrl: String?
    public var castEnabled: Bool?
    public var castAppId: String?
    public var castReceiverUrl: String?
    public var pageFlipVisible: Bool?
    public var adminEmails: String?
    public var githubMidiToken: String?
    public var isMangaloreHymnsEnabled: Bool?
    public var midiHymnsRanges: String?
    public var midiKeerthanesRanges: String?
    public var disableOggFallback: String?
    public var audioBackupUrl: String?
    public var isAdyenEnabled: Bool?
    public var isRazorpayEnabled: Bool?
    public var paymentsEnabled: Bool?
    public var masterRootPasscode: String?
    
    public var parsedMidiHymns: Set<String> {
        Self.parseMeters(midiHymnsRanges)
    }
    
    public var parsedMidiKeerthanes: Set<Int> {
        Self.parseRanges(midiKeerthanesRanges)
    }
    
    public static func parseMeters(_ metersStr: String?) -> Set<String> {
        guard let metersStr, !metersStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return Set(
            metersStr.split(separator: ",")
                .map { Self.normalizedMeter(String($0)) }
                .filter { !$0.isEmpty && $0 != "default" }
        )
    }
    
    public static func parseRanges(_ rangeStr: String?) -> Set<Int> {
        guard let rangeStr, !rangeStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        var numbers = Set<Int>()
        for part in rangeStr.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.contains("-") {
                let bounds = trimmed.split(separator: "-")
                if bounds.count == 2,
                   let start = Int(bounds[0].trimmingCharacters(in: .whitespaces)),
                   let end = Int(bounds[1].trimmingCharacters(in: .whitespaces)),
                   start <= end {
                    for i in start...end { numbers.insert(i) }
                }
            } else if let num = Int(trimmed) {
                numbers.insert(num)
            }
        }
        return numbers
    }
    
    /// Light normalization for meter / MIDI filenames (Android MeterUtils parity).
    public static func normalizedMeter(_ raw: String) -> String {
        MeterUtils.normalizedMeter(raw)
    }
    
    public static func meterMidiFileName(_ option: String) -> String {
        MeterUtils.meterMidiFileName(option)
    }

    /// Keep previously known values when a fetch omits a key. Explicit false/empty still wins.
    public func coalescing(_ previous: RemoteAppConfig) -> RemoteAppConfig {
        var merged = self
        merged.isChristmasTime = isChristmasTime ?? previous.isChristmasTime
        merged.forceUpdateEnabled = forceUpdateEnabled ?? previous.forceUpdateEnabled
        merged.forceUpdateMinVersion = forceUpdateMinVersion ?? previous.forceUpdateMinVersion
        merged.forceUpdateMinBuildNumber = forceUpdateMinBuildNumber ?? previous.forceUpdateMinBuildNumber
        merged.forceUpdateMessage = forceUpdateMessage ?? previous.forceUpdateMessage
        merged.forceUpdateAndroidStoreUrl = forceUpdateAndroidStoreUrl ?? previous.forceUpdateAndroidStoreUrl
        merged.forceUpdateIosStoreUrl = forceUpdateIosStoreUrl ?? previous.forceUpdateIosStoreUrl
        merged.castEnabled = castEnabled ?? previous.castEnabled
        merged.castAppId = castAppId ?? previous.castAppId
        merged.castReceiverUrl = castReceiverUrl ?? previous.castReceiverUrl
        merged.pageFlipVisible = pageFlipVisible ?? previous.pageFlipVisible
        merged.adminEmails = adminEmails ?? previous.adminEmails
        merged.githubMidiToken = githubMidiToken ?? previous.githubMidiToken
        merged.isMangaloreHymnsEnabled = isMangaloreHymnsEnabled ?? previous.isMangaloreHymnsEnabled
        merged.midiHymnsRanges = midiHymnsRanges ?? previous.midiHymnsRanges
        merged.midiKeerthanesRanges = midiKeerthanesRanges ?? previous.midiKeerthanesRanges
        merged.disableOggFallback = disableOggFallback ?? previous.disableOggFallback
        merged.audioBackupUrl = audioBackupUrl ?? previous.audioBackupUrl
        merged.isAdyenEnabled = isAdyenEnabled ?? previous.isAdyenEnabled
        merged.isRazorpayEnabled = isRazorpayEnabled ?? previous.isRazorpayEnabled
        merged.paymentsEnabled = paymentsEnabled ?? previous.paymentsEnabled
        merged.masterRootPasscode = masterRootPasscode ?? previous.masterRootPasscode
        return merged
    }
}

public enum AppConfigKeys {
    public static let isChristmasTime = "is_christmas_time"
    public static let forceUpdateEnabled = "force_update_enabled"
    public static let forceUpdateMinVersion = "force_update_min_version"
    public static let forceUpdateMinBuildNumber = "force_update_min_build_number"
    public static let forceUpdateMessage = "force_update_message"
    public static let forceUpdateAndroidStoreUrl = "force_update_android_store_url"
    public static let forceUpdateIosStoreUrl = "force_update_ios_store_url"
    public static let castEnabled = "cast_enabled"
    public static let castAppId = "cast_app_id"
    public static let castReceiverUrl = "cast_receiver_url"
    public static let pageFlipVisible = "page_flip_visible"
    public static let adminEmails = "admin_emails"
    public static let githubMidiToken = "github_midi_token"
    public static let githubToken = "github_token"
    public static let isMangaloreHymnsEnabled = "is_mangalore_hymns_enabled"
    public static let midiHymnsRanges = "midi_hymns_ranges"
    public static let midiKeerthanesRanges = "midi_keerthanes_ranges"
    public static let disableOggFallback = "disable_ogg_fallback"
    public static let audioBackupUrl = "audio_backup_url"
    public static let isAdyenEnabled = "is_adyen_enabled"
    public static let isRazorpayEnabled = "is_razorpay_enabled"
    public static let paymentsEnabled = "payments_enabled"
    public static let masterRootPasscode = "master_root_passcode"
}

@MainActor
@Observable
public final class AppConfigService {
    public static let shared = AppConfigService()
    
    public private(set) var config = RemoteAppConfig()
    public private(set) var isLoaded = false
    
    private static let cacheKey = "remote_app_config_cache_v1"
    
    private init() {
        loadCached()
        Task { await refresh() }
    }
    
    public func refresh() async {
        #if canImport(Supabase)
        do {
            let keys = [
                AppConfigKeys.isChristmasTime,
                AppConfigKeys.forceUpdateEnabled,
                AppConfigKeys.forceUpdateMinVersion,
                AppConfigKeys.forceUpdateMinBuildNumber,
                AppConfigKeys.forceUpdateMessage,
                AppConfigKeys.forceUpdateAndroidStoreUrl,
                AppConfigKeys.forceUpdateIosStoreUrl,
                AppConfigKeys.castEnabled,
                AppConfigKeys.castAppId,
                AppConfigKeys.castReceiverUrl,
                AppConfigKeys.pageFlipVisible,
                AppConfigKeys.adminEmails,
                AppConfigKeys.githubMidiToken,
                AppConfigKeys.githubToken,
                AppConfigKeys.isMangaloreHymnsEnabled,
                AppConfigKeys.midiHymnsRanges,
                AppConfigKeys.midiKeerthanesRanges,
                AppConfigKeys.disableOggFallback,
                AppConfigKeys.audioBackupUrl,
                AppConfigKeys.isAdyenEnabled,
                AppConfigKeys.isRazorpayEnabled,
                AppConfigKeys.paymentsEnabled,
                AppConfigKeys.masterRootPasscode
            ]
            
            let rows: [AppConfigRow] = try await SupabaseService.instance.client
                .from("app_config")
                .select("key, value")
                .in("key", values: keys)
                .execute()
                .value
            
            var dict: [String: AppConfigValue] = [:]
            for row in rows { dict[row.key] = row.value }
            
            var next = RemoteAppConfig()
            next.isChristmasTime = dict[AppConfigKeys.isChristmasTime]?.boolValue
            next.forceUpdateEnabled = dict[AppConfigKeys.forceUpdateEnabled]?.boolValue
            next.forceUpdateMinVersion = nonEmpty(dict[AppConfigKeys.forceUpdateMinVersion]?.stringValue)
            next.forceUpdateMinBuildNumber = Int(dict[AppConfigKeys.forceUpdateMinBuildNumber]?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            next.forceUpdateMessage = nonEmpty(dict[AppConfigKeys.forceUpdateMessage]?.stringValue)
            next.forceUpdateAndroidStoreUrl = nonEmpty(dict[AppConfigKeys.forceUpdateAndroidStoreUrl]?.stringValue)
            next.forceUpdateIosStoreUrl = nonEmpty(dict[AppConfigKeys.forceUpdateIosStoreUrl]?.stringValue)
            next.castEnabled = dict[AppConfigKeys.castEnabled]?.boolValue
            next.castAppId = nonEmpty(dict[AppConfigKeys.castAppId]?.stringValue)
            next.castReceiverUrl = nonEmpty(dict[AppConfigKeys.castReceiverUrl]?.stringValue)
            next.pageFlipVisible = dict[AppConfigKeys.pageFlipVisible]?.boolValue
            let adminRaw = dict[AppConfigKeys.adminEmails]?.stringValue
            let prettyAdmin = AdminPrefs.prettifyAdminEmailsConfig(adminRaw)
            next.adminEmails = nonEmpty(prettyAdmin.isEmpty ? adminRaw : prettyAdmin)
            next.githubMidiToken = nonEmpty(dict[AppConfigKeys.githubMidiToken]?.stringValue)
                ?? nonEmpty(dict[AppConfigKeys.githubToken]?.stringValue)
            next.isMangaloreHymnsEnabled = dict[AppConfigKeys.isMangaloreHymnsEnabled]?.boolValue
            next.midiHymnsRanges = dict[AppConfigKeys.midiHymnsRanges]?.stringValue
            next.midiKeerthanesRanges = dict[AppConfigKeys.midiKeerthanesRanges]?.stringValue
            next.disableOggFallback = dict[AppConfigKeys.disableOggFallback]?.stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            next.audioBackupUrl = nonEmpty(dict[AppConfigKeys.audioBackupUrl]?.stringValue)
            next.isAdyenEnabled = dict[AppConfigKeys.isAdyenEnabled]?.boolValue
            next.isRazorpayEnabled = dict[AppConfigKeys.isRazorpayEnabled]?.boolValue
            next.paymentsEnabled = dict[AppConfigKeys.paymentsEnabled]?.boolValue
            next.masterRootPasscode = nonEmpty(dict[AppConfigKeys.masterRootPasscode]?.stringValue)

            let previous = config
            next = next.coalescing(previous)
            config = next
            isLoaded = true
            persistCache(next)
            print("AppConfigService: fetched rows=\(rows.count) mangalore=\(String(describing: next.isMangaloreHymnsEnabled))")
            
            if let passcode = next.masterRootPasscode {
                UserDefaults.standard.set(passcode, forKey: "cached_master_root_passcode")
            }
            if let emails = next.adminEmails {
                UserDefaults.standard.set(emails, forKey: "admin_emails_cached")
            }
            if let token = next.githubMidiToken {
                UserDefaults.standard.set(token, forKey: "github_midi_token_cached")
            }
            if let pageFlip = next.pageFlipVisible {
                UserDefaults.standard.set(pageFlip, forKey: "page_flip_visible_cached")
            }
            if let payments = next.paymentsEnabled {
                UserDefaults.standard.set(payments, forKey: "payments_enabled_cached")
            }
            UserDefaults.standard.set(next.midiHymnsRanges, forKey: "midi_hymns_ranges_cached")
            UserDefaults.standard.set(next.midiKeerthanesRanges, forKey: "midi_keerthanes_ranges_cached")
            UserDefaults.standard.set(next.disableOggFallback, forKey: "disable_ogg_fallback_cached")
            UserDefaults.standard.set(next.audioBackupUrl, forKey: "audio_backup_url_cached")
        } catch {
            print("AppConfigService: refresh failed: \(error)")
        }
        #endif
    }
    
    public var paymentsEnabled: Bool {
        if let cached = UserDefaults.standard.object(forKey: "payments_enabled_cached") as? Bool {
            return config.paymentsEnabled ?? cached
        }
        return config.paymentsEnabled == true
    }
    
    public var isMangaloreEnabled: Bool {
        config.isMangaloreHymnsEnabled ?? true
    }
    
    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            config.paymentsEnabled = UserDefaults.standard.object(forKey: "payments_enabled_cached") as? Bool
            return
        }
        var next = RemoteAppConfig()
        next.paymentsEnabled = dict["payments_enabled"] as? Bool
        next.isAdyenEnabled = dict["is_adyen_enabled"] as? Bool
        next.isRazorpayEnabled = dict["is_razorpay_enabled"] as? Bool
        next.isMangaloreHymnsEnabled = dict["is_mangalore_hymns_enabled"] as? Bool
        next.midiHymnsRanges = dict["midi_hymns_ranges"] as? String
        next.midiKeerthanesRanges = dict["midi_keerthanes_ranges"] as? String
        next.disableOggFallback = dict["disable_ogg_fallback"] as? String
        next.audioBackupUrl = dict["audio_backup_url"] as? String
        next.adminEmails = dict["admin_emails"] as? String
            ?? UserDefaults.standard.string(forKey: "admin_emails_cached")
        next.githubMidiToken = dict["github_midi_token"] as? String
            ?? UserDefaults.standard.string(forKey: "github_midi_token_cached")
        next.masterRootPasscode = dict["master_root_passcode"] as? String
            ?? UserDefaults.standard.string(forKey: "cached_master_root_passcode")
        next.pageFlipVisible = dict["page_flip_visible"] as? Bool
        next.forceUpdateIosStoreUrl = dict["force_update_ios_store_url"] as? String
        config = next
    }
    
    private func persistCache(_ config: RemoteAppConfig) {
        var dict: [String: Any] = [:]
        if let v = config.paymentsEnabled { dict["payments_enabled"] = v }
        if let v = config.isAdyenEnabled { dict["is_adyen_enabled"] = v }
        if let v = config.isRazorpayEnabled { dict["is_razorpay_enabled"] = v }
        if let v = config.isMangaloreHymnsEnabled { dict["is_mangalore_hymns_enabled"] = v }
        if let v = config.midiHymnsRanges { dict["midi_hymns_ranges"] = v }
        if let v = config.midiKeerthanesRanges { dict["midi_keerthanes_ranges"] = v }
        if let v = config.disableOggFallback { dict["disable_ogg_fallback"] = v }
        if let v = config.audioBackupUrl { dict["audio_backup_url"] = v }
        if let v = config.adminEmails { dict["admin_emails"] = v }
        if let v = config.githubMidiToken { dict["github_midi_token"] = v }
        if let v = config.masterRootPasscode { dict["master_root_passcode"] = v }
        if let v = config.pageFlipVisible { dict["page_flip_visible"] = v }
        if let v = config.forceUpdateIosStoreUrl { dict["force_update_ios_store_url"] = v }
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }
}
