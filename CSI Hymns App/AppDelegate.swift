import UIKit

#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

/// UIKit lifecycle bridge required by OneSignal and other SDKs that expect
/// `didFinishLaunchingWithOptions` rather than SwiftUI `App.init()`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(OneSignalFramework)
        OneSignal.initialize(
            "29f2a6ba-3f56-4ffe-8075-3b70d7440b13",
            withLaunchOptions: launchOptions
        )
        #endif
        return true
    }
}
