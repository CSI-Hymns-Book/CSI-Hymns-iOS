import Foundation
import UIKit

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// FCM token sync, topic subscription, and in-app notification broadcasts (parity with Android).
@MainActor
final class FirebaseMessagingService: NSObject {
    static let shared = FirebaseMessagingService()

    static let prefFcmTokenKey = "fcm_token"
    static let notificationReceivedName = Notification.Name("com.reyzie.hymns.notificationReceived")

    private static let defaultTopics = ["all_users", "announcements"]
    private static let languageTopics = ["kannada_hymns", "english_hymns"]

    /// True once APNs has handed us a device token and we have forwarded it to FCM.
    private var hasApnsToken = false
    /// Subscribe/sync was requested before APNs finished; run it when the token arrives.
    private var pendingTopicSync = false

    private override init() {
        super.init()
    }

    func configure() {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
    }

    /// Call from `didRegisterForRemoteNotificationsWithDeviceToken`.
    /// Debug builds must use APNs **sandbox**; otherwise FCM can report success while iOS never shows the alert.
    func didReceiveApnsDeviceToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        #if DEBUG
        let apnsType: MessagingAPNSTokenType = .sandbox
        #else
        let apnsType: MessagingAPNSTokenType = .prod
        #endif
        Messaging.messaging().setAPNSToken(deviceToken, type: apnsType)
        hasApnsToken = true
        print("HymnsFCM: APNs token set (\(deviceToken.count) bytes, type=\(apnsType == .sandbox ? "sandbox" : "prod"))")
        if pendingTopicSync || ConsentManager.shared.pushConsent {
            pendingTopicSync = false
            performTokenAndTopicSync()
        }
        #endif
    }

    /// Requests APNs registration. Topic/token sync runs after APNs succeeds.
    static func enablePush() {
        UIApplication.shared.registerForRemoteNotifications()
        Task { @MainActor in
            let service = FirebaseMessagingService.shared
            if service.hasApnsToken {
                service.performTokenAndTopicSync()
            } else {
                service.pendingTopicSync = true
            }
        }
    }

    static func subscribeToDefaultTopics() {
        enablePush()
    }

    static func unsubscribeFromAllTopics() {
        #if canImport(FirebaseMessaging)
        let messaging = Messaging.messaging()
        for topic in defaultTopics + languageTopics {
            messaging.unsubscribe(fromTopic: topic) { error in
                if let error {
                    print("HymnsFCM: unsubscribe \(topic) failed: \(error)")
                }
            }
        }
        #endif
        Task { @MainActor in
            FirebaseMessagingService.shared.pendingTopicSync = false
        }
    }

    static func syncUserLanguageTopics(isKannada: Bool = true, isEnglish: Bool = true) {
        #if canImport(FirebaseMessaging)
        guard Messaging.messaging().apnsToken != nil else {
            print("HymnsFCM: skip language topics until APNs token is ready")
            return
        }
        let messaging = Messaging.messaging()
        if isKannada {
            messaging.subscribe(toTopic: "kannada_hymns") { _ in }
        } else {
            messaging.unsubscribe(fromTopic: "kannada_hymns") { _ in }
        }
        if isEnglish {
            messaging.subscribe(toTopic: "english_hymns") { _ in }
        } else {
            messaging.unsubscribe(fromTopic: "english_hymns") { _ in }
        }
        #endif
    }

    func handleTokenRefresh(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        Self.persistAndSyncToken(token)
        #if canImport(FirebaseMessaging)
        if hasApnsToken || Messaging.messaging().apnsToken != nil {
            hasApnsToken = true
            subscribeDefaultTopicsOnly()
        } else {
            pendingTopicSync = true
        }
        #endif
    }

    private func performTokenAndTopicSync() {
        #if canImport(FirebaseMessaging)
        guard Messaging.messaging().apnsToken != nil || hasApnsToken else {
            pendingTopicSync = true
            print("HymnsFCM: waiting for APNs token before FCM sync")
            return
        }
        // Drop any token minted before APNs was typed (sandbox/prod), then re-fetch.
        Messaging.messaging().deleteToken { error in
            if let error {
                print("HymnsFCM: deleteToken (non-fatal): \(error)")
            }
            Messaging.messaging().token { token, error in
                if let error {
                    print("HymnsFCM: token fetch failed: \(error)")
                    return
                }
                guard let token, !token.isEmpty else { return }
                Task { @MainActor in
                    Self.persistAndSyncToken(token)
                    FirebaseMessagingService.shared.subscribeDefaultTopicsOnly()
                }
            }
        }
        #endif
    }

    private func subscribeDefaultTopicsOnly() {
        #if canImport(FirebaseMessaging)
        let messaging = Messaging.messaging()
        for topic in Self.defaultTopics {
            messaging.subscribe(toTopic: topic) { error in
                if let error {
                    print("HymnsFCM: subscribe \(topic) failed: \(error)")
                } else {
                    print("HymnsFCM: subscribed to \(topic)")
                }
            }
        }
        #endif
    }

    private static func persistAndSyncToken(_ token: String) {
        print("HymnsFCM: token registered: \(token.prefix(8))***")
        UserDefaults.standard.set(token, forKey: prefFcmTokenKey)
        Task {
            await SupabaseService.instance.updateProfileFcmToken(token)
        }
    }
}

#if canImport(FirebaseMessaging)
extension FirebaseMessagingService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            FirebaseMessagingService.shared.handleTokenRefresh(fcmToken)
        }
    }
}
#endif
