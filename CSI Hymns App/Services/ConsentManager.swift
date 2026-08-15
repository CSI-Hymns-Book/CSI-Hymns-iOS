import Foundation
import Observation

#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

enum ConsentStorageKeys {
    static let analytics = "csi_consent_analytics"
    static let push = "csi_consent_push"
}

enum LegalPolicy {
    static let currentVersion = "2026-08-15.1"
}

/// Local + remote consent artefact aligned with DPDP Act, 2023 and DPDP Rules, 2025.
/// Required purposes cannot be skipped. Analytics and push are separate opt-in purposes.
@MainActor
@Observable
public final class ConsentManager {
    public static let shared = ConsentManager()
    
    /// Bump this when the notice or policy text materially changes so users re-consent.
    public static let currentPolicyVersion = LegalPolicy.currentVersion
    public static let analyticsStorageKey = ConsentStorageKeys.analytics
    public static let pushStorageKey = ConsentStorageKeys.push
    
    public static let grievanceEmail = "reynoldclare02@gmail.com"
    public static let dataFiduciaryName = "Reynold Clare (CSI Hymns)"
    public static let dataFiduciaryRegion = "Bengaluru, Karnataka, India"
    
    public enum LegalLanguage: String, CaseIterable, Identifiable {
        case english = "en"
        case kannada = "kn"
        public var id: String { rawValue }
        public var label: String { self == .english ? "English" : "ಕನ್ನಡ" }
    }
    
    public var language: LegalLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
    }
    
    public private(set) var hasValidRequiredConsent: Bool
    public private(set) var analyticsConsent: Bool
    public private(set) var pushConsent: Bool
    public private(set) var recordedAt: Date?
    public private(set) var acceptedVersion: String?
    
    private enum Keys {
        static let language = "csi_legal_language"
        static let version = "csi_consent_policy_version"
        static let required = "csi_consent_required_accepted"
        static let terms = "csi_consent_terms_accepted"
        static let age = "csi_consent_age_confirmed"
        static let analytics = ConsentManager.analyticsStorageKey
        static let push = ConsentManager.pushStorageKey
        static let recordedAt = "csi_consent_recorded_at"
        static let legacyPrivacy = "csi_privacy_accepted_local"
    }
    
    private init() {
        let storedLang = UserDefaults.standard.string(forKey: Keys.language) ?? LegalLanguage.english.rawValue
        language = LegalLanguage(rawValue: storedLang) ?? .english
        analyticsConsent = UserDefaults.standard.bool(forKey: Keys.analytics)
        pushConsent = UserDefaults.standard.bool(forKey: Keys.push)
        acceptedVersion = UserDefaults.standard.string(forKey: Keys.version)
        recordedAt = UserDefaults.standard.object(forKey: Keys.recordedAt) as? Date
        hasValidRequiredConsent = false
        refreshValidity()
    }
    
    public func refreshValidity() {
        let defaults = UserDefaults.standard
        let versionOK = defaults.string(forKey: Keys.version) == Self.currentPolicyVersion
        let required = defaults.bool(forKey: Keys.required)
        let terms = defaults.bool(forKey: Keys.terms)
        let age = defaults.bool(forKey: Keys.age)
        hasValidRequiredConsent = versionOK && required && terms && age
        analyticsConsent = defaults.bool(forKey: Keys.analytics)
        pushConsent = defaults.bool(forKey: Keys.push)
        acceptedVersion = defaults.string(forKey: Keys.version)
        recordedAt = defaults.object(forKey: Keys.recordedAt) as? Date
    }
    
    /// Records free, specific, informed, unambiguous consent for the current policy version.
    public func acceptRequiredConsent(
        analytics: Bool,
        push: Bool,
        ageConfirmed: Bool,
        privacyAccepted: Bool,
        termsAccepted: Bool
    ) {
        guard ageConfirmed, privacyAccepted, termsAccepted else { return }
        let now = Date()
        let defaults = UserDefaults.standard
        defaults.set(Self.currentPolicyVersion, forKey: Keys.version)
        defaults.set(true, forKey: Keys.required)
        defaults.set(true, forKey: Keys.terms)
        defaults.set(true, forKey: Keys.age)
        defaults.set(analytics, forKey: Keys.analytics)
        defaults.set(push, forKey: Keys.push)
        defaults.set(now, forKey: Keys.recordedAt)
        defaults.set(1, forKey: Keys.legacyPrivacy)
        refreshValidity()
        applySideEffects(analytics: analytics, push: push)
        Task { await syncToProfile() }
    }
    
    public func setAnalyticsConsent(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.analytics)
        analyticsConsent = enabled
        if !enabled {
            PostHogService.shared.reset()
        }
        Task { await syncToProfile() }
    }
    
    public func setPushConsent(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.push)
        pushConsent = enabled
        applyPushSideEffect(enabled)
        Task { await syncToProfile() }
    }
    
    /// Withdrawal of required consent is as easy as grant: one action. Optional processing stops immediately.
    public func withdrawRequiredConsent() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: Keys.required)
        defaults.set(false, forKey: Keys.terms)
        defaults.set(false, forKey: Keys.age)
        defaults.set(false, forKey: Keys.analytics)
        defaults.set(false, forKey: Keys.push)
        defaults.set(0, forKey: Keys.legacyPrivacy)
        defaults.removeObject(forKey: Keys.version)
        refreshValidity()
        applySideEffects(analytics: false, push: false)
        Task {
            await SupabaseService.instance.setPrivacyPolicyAcceptedInProfile(false)
            if SupabaseService.instance.isAuthenticated {
                try? await SupabaseService.instance.signOut()
            }
        }
    }
    
    public func artefactJSON() -> [String: Any] {
        [
            "policy_version": Self.currentPolicyVersion,
            "recorded_at": ISO8601DateFormatter().string(from: recordedAt ?? Date()),
            "language": language.rawValue,
            "privacy_accepted": hasValidRequiredConsent,
            "terms_accepted": hasValidRequiredConsent,
            "age_confirmed": hasValidRequiredConsent,
            "analytics": analyticsConsent,
            "push_notifications": pushConsent,
            "notice": "DPDP Act 2023 / DPDP Rules 2025 in-app notice"
        ]
    }
    
    public func syncToProfile() async {
        UserDefaults.standard.set(hasValidRequiredConsent ? 1 : 0, forKey: Keys.legacyPrivacy)
        await SupabaseService.instance.syncConsentArtefact(
            requiredAccepted: hasValidRequiredConsent,
            analytics: analyticsConsent,
            push: pushConsent,
            version: hasValidRequiredConsent ? Self.currentPolicyVersion : nil,
            recordedAt: recordedAt,
            artefact: artefactJSON()
        )
    }
    
    private func applySideEffects(analytics: Bool, push: Bool) {
        if !analytics {
            PostHogService.shared.reset()
        }
        applyPushSideEffect(push)
    }
    
    private func applyPushSideEffect(_ enabled: Bool) {
        #if canImport(OneSignalFramework)
        if enabled {
            AppDelegate.startOneSignalIfNeeded()
            OneSignal.User.pushSubscription.optIn()
            OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)
        } else {
            OneSignal.User.pushSubscription.optOut()
        }
        #endif
    }
}
