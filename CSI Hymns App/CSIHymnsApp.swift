import SwiftUI
import Observation

#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

@main
struct CSIHymnsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var christmasMode = ChristmasModeService.shared
    @State private var themeManager = ThemeManager.shared
    @State private var isShowingWelcome = false
    @State private var isShowingOnboarding = false
    @State private var forceUpdate: ForceUpdateDecision? = nil
    @State private var hasRequestedPushPermission = false
    @Bindable private var consent = ConsentManager.shared
    
    // Core release info parsed dynamically from changelog.json
    private var activeRelease: ChangelogRelease {
        guard let url = Bundle.main.url(forResource: "changelog", withExtension: "json") else {
            print("CSIHymnsApp: Error finding changelog.json in bundle")
            return fallbackRelease()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let releases = try JSONDecoder().decode([ChangelogRelease].self, from: data)
            
            // Find the release matching the current app version
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "5.1.0"
            if let matched = releases.first(where: { $0.version == currentVersion }) {
                return matched
            }
            return releases.first ?? fallbackRelease()
        } catch let error as DecodingError {
            print("CSIHymnsApp: DecodingError parsing changelog.json: \(error)")
            return fallbackRelease()
        } catch {
            print("CSIHymnsApp: Error parsing changelog.json: \(error)")
            return fallbackRelease()
        }
    }
    
    private func fallbackRelease() -> ChangelogRelease {
        return ChangelogRelease(
            title: "New Public Stable Version Released!",
            version: "5.1.0",
            date: "13-07-2026",
            changes: [
                "New Mangalore Tunes (M.T.) Hymns section",
                "New MIDI Playback Engine with realistic instrument settings",
                "Robust JSON parsing with safety nets",
                "Admin Controls Dashboard with Supabase Sync"
            ]
        )
    }
    
    init() {
        setupGlobalAppearances()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let decision = forceUpdate, decision.requiresUpdate {
                    ForceUpdateView(message: decision.message, storeURL: decision.iosStoreURL)
                        .preferredColorScheme(themeManager.preferredColorScheme)
                } else {
                    RootTabView()
                        .preferredColorScheme(themeManager.preferredColorScheme)
                        .sheet(isPresented: $isShowingWelcome) {
                            WelcomeChangelogView(release: activeRelease) {
                                isShowingWelcome = false
                                UserDefaults.standard.set(activeRelease.version, forKey: "last_seen_changelog_version")
                            }
                        }
                        .sheet(isPresented: $isShowingOnboarding, onDismiss: {
                            checkChangelogLaunch()
                        }) {
                            OnboardingView()
                        }
                        .fullScreenCover(isPresented: Binding(
                            get: { !consent.hasValidRequiredConsent },
                            set: { _ in }
                        )) {
                            ConsentGateView()
                        }
                        .onAppear {
                            if consent.hasValidRequiredConsent {
                                checkOnboardingOrChangelog()
                                requestPushPermissionIfNeeded()
                            }
                        }
                        .onChange(of: consent.hasValidRequiredConsent) { _, accepted in
                            if accepted {
                                checkOnboardingOrChangelog()
                                requestPushPermissionIfNeeded()
                            }
                        }
                }
            }
            .task {
                await waitForSupabaseInitialization()
                await AppConfigService.shared.refresh()
                await MidiFileCatalog.shared.refresh()
                forceUpdate = await ForceUpdateService.shared.getDecision()
                await CastService.shared.initializeIfEnabled()
                await PageFlipVisibilityService.shared.refresh()
                try? await ChristmasCarolsService.shared.fetchParishCarols(forceGitHub: true)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .background {
                    BackgroundSyncService.shared.performBackgroundSync()
                }
            }
        }
    }
    
    private func checkOnboardingOrChangelog() {
        // Check onboarding first
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "csi_has_seen_onboarding_v1")
        if !hasSeenOnboarding {
            isShowingOnboarding = true
        } else {
            checkChangelogLaunch()
        }
    }
    
    private func checkChangelogLaunch() {
        // Launch changelog prompt only if this exact version's logs have not been acknowledged
        let lastSeen = UserDefaults.standard.string(forKey: "last_seen_changelog_version")
        if lastSeen != activeRelease.version {
            isShowingWelcome = true
        }
    }
    
    private func setupGlobalAppearances() {
        // Enforce smooth translucent navigation bars across standard ScrollViews
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    /// Waits for Supabase session hydration before other remote-config tasks run.
    private func waitForSupabaseInitialization() async {
        while SupabaseService.instance.isInitializing {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
    
    /// Requests push permission after the first frame so iOS 27 beta lifecycle is stable.
    private func requestPushPermissionIfNeeded() {
        guard consent.pushConsent else { return }
        guard !hasRequestedPushPermission else { return }
        hasRequestedPushPermission = true
        AppDelegate.startOneSignalIfNeeded()
        
        #if canImport(OneSignalFramework)
        OneSignal.Notifications.requestPermission({ accepted in
            print("OneSignal: Push permission accepted: \(accepted)")
        }, fallbackToSettings: false)
        #endif
    }
}
