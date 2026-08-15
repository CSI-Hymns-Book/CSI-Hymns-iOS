import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

#if canImport(GoogleCast)
import GoogleCast
#endif

/// Manages Chromecast (Google Cast) availability and configuration.
///
/// Mirrors the Flutter `CastService`: casting is gated behind remote-config flags in
/// Supabase `app_config` (`cast_enabled`, `cast_app_id`, `cast_receiver_url`) and is
/// disabled by default. The Cast button is only surfaced when `featureEnabled` is true.
///
/// The actual Google Cast SDK calls are guarded by `#if canImport(GoogleCast)` so the app
/// compiles and ships cleanly whether or not the binary Cast SDK has been added to the
/// project. Google does not provide an official SPM package; the SDK must be added via
/// CocoaPods or a manual XCFramework (plus Bluetooth / Local Network Info.plist usage
/// strings) to fully activate casting once `cast_enabled` is flipped on.
@Observable
public final class CastService {
    public static let shared = CastService()
    
    public private(set) var featureEnabled = false
    public private(set) var appId: String? = nil
    public private(set) var receiverURL: String? = nil
    public private(set) var isConnected = false
    private var didInitializeContext = false
    
    private static let keyEnabled = "cast_enabled"
    private static let keyAppId = "cast_app_id"
    private static let keyReceiverURL = "cast_receiver_url"
    
    private init() {}
    
    /// Whether the running build actually has the Google Cast SDK linked.
    public var isSDKAvailable: Bool {
        #if canImport(GoogleCast)
        return true
        #else
        return false
        #endif
    }
    
    /// Fetches remote config and, if enabled and the SDK is present, initializes the Cast context.
    public func initializeIfEnabled() async {
        #if canImport(Supabase)
        do {
            let rows: [AppConfigRow] = try await SupabaseService.instance.client
                .from("app_config")
                .select("key, value")
                .in("key", values: [Self.keyEnabled, Self.keyAppId, Self.keyReceiverURL])
                .execute()
                .value
            
            var config: [String: AppConfigValue] = [:]
            for row in rows { config[row.key] = row.value }
            
            let enabled = config[Self.keyEnabled]?.boolValue ?? false
            let appId = config[Self.keyAppId]?.stringValue
            
            await MainActor.run {
                self.appId = appId
                self.receiverURL = config[Self.keyReceiverURL]?.stringValue
                // Only expose the feature when the flag is on AND the SDK is linked.
                self.featureEnabled = enabled && self.isSDKAvailable
            }
            
            if enabled {
                await configureCastContext(appId: appId)
            }
        } catch {
            print("CastService: Remote config fetch failed: \(error)")
        }
        #endif
    }
    
    @MainActor
    private func configureCastContext(appId: String?) {
        #if canImport(GoogleCast)
        guard !didInitializeContext else { return }
        let receiverAppId = (appId?.isEmpty == false ? appId! : kGCKDefaultMediaReceiverApplicationID)
        let criteria = GCKDiscoveryCriteria(applicationID: receiverAppId)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        GCKCastContext.setSharedInstanceWith(options)
        didInitializeContext = true
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCKCastSessionDidStart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isConnected = true
        }
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.GCKCastSessionDidEnd,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isConnected = false
        }
        #endif
    }
    
    public func disconnect() {
        #if canImport(GoogleCast)
        GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
        #endif
        isConnected = false
    }
}
