import UIKit
import UserNotifications

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// UIKit lifecycle bridge for Firebase Cloud Messaging and APNs registration.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif

        UNUserNotificationCenter.current().delegate = self
        FirebaseMessagingService.shared.configure()

        Task { @MainActor in
            if ConsentManager.shared.pushConsent {
                // Only register for APNs here. FCM token + topics run after
                // didRegisterForRemoteNotificationsWithDeviceToken.
                FirebaseMessagingService.enablePush()
            }
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            FirebaseMessagingService.shared.didReceiveApnsDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("HymnsFCM: APNs registration failed: \(error)")
    }

    /// Required when `FirebaseAppDelegateProxyEnabled` is false so FCM sees data messages.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("HymnsFCM: didReceiveRemoteNotification keys=\(Array(userInfo.keys))")
        #if canImport(FirebaseMessaging)
        Messaging.messaging().appDidReceiveMessage(userInfo)
        #endif
        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        print("HymnsFCM: willPresent title=\(content.title) body=\(content.body)")
        postInAppNotification(from: notification.request.content.userInfo, content: content)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        print("HymnsFCM: didReceive tap title=\(content.title)")
        postInAppNotification(from: response.notification.request.content.userInfo, content: content)
        completionHandler()
    }

    static func registerForRemoteNotificationsIfNeeded() {
        FirebaseMessagingService.enablePush()
    }

    private func postInAppNotification(from userInfo: [AnyHashable: Any], content: UNNotificationContent) {
        let title = content.title.isEmpty
            ? (userInfo["title"] as? String ?? "CSI Hymns Book")
            : content.title
        let message = content.body.isEmpty
            ? (userInfo["body"] as? String ?? userInfo["message"] as? String ?? "")
            : content.body
        let targetScreen = userInfo["target_screen"] as? String ?? userInfo["deep_link"] as? String ?? ""
        let imageURL = userInfo["image_url"] as? String ?? userInfo["image"] as? String ?? ""

        NotificationCenter.default.post(
            name: FirebaseMessagingService.notificationReceivedName,
            object: nil,
            userInfo: [
                "title": title,
                "message": message,
                "target_screen": targetScreen,
                "image_url": imageURL
            ]
        )
    }
}
