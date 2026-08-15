import UIKit

#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

/// UIKit lifecycle bridge required by OneSignal and other SDKs that expect
/// `didFinishLaunchingWithOptions` rather than SwiftUI `App.init()`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    private static var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    private static var didStartOneSignal = false
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.launchOptions = launchOptions
        if UserDefaults.standard.bool(forKey: ConsentStorageKeys.push) {
            Self.startOneSignalIfNeeded()
        }
        return true
    }
    
    static func startOneSignalIfNeeded() {
        #if canImport(OneSignalFramework)
        guard !didStartOneSignal else { return }
        didStartOneSignal = true
        OneSignal.initialize(
            "29f2a6ba-3f56-4ffe-8075-3b70d7440b13",
            withLaunchOptions: launchOptions
        )
        #endif
    }
}
