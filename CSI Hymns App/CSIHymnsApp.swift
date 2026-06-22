import SwiftUI

#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

@main
struct CSIHymnsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var christmasMode = ChristmasModeService.shared
    @State private var themeManager = ThemeManager.shared
    @State private var isShowingWelcome = false
    @State private var isShowingOnboarding = false
    @State private var forceUpdate: ForceUpdateDecision? = nil
    @State private var hasRequestedPushPermission = false
    
    // Core release info matching 4.2.2-stable asset logs
    private let activeRelease = ChangelogRelease(
        title: "New Public Stable Version Released!",
        version: "4.2.2-stable",
        date: "20-04-2026",
        changes: [
            "Major improvements to Page Flip readability and smoothness (reduced text bleed-through, safer transitions, and more stable gesture behavior)",
            "iOS back navigation is now smoother across key flows, including improved swipe-back behavior for Order of Service reader screens",
            "Order of Service reader bottom navigation now stays properly anchored at the bottom, with cleaner page content spacing",
            "Modernized in-app feedback messages across the app with cleaner floating status toasts for refresh/sync/update actions",
            "Refined Order of Service title grouping and reader headers for clearer section context while navigating pages",
            "Added ticket correction acknowledgement dialog on app open for Jira requests that moved to Done/Resolved/Closed",
            "Fixed audio plugin crash path by removing unused background audio service integration",
            "Fixed crash when opening Settings from Page Flip hint snackbar action in hymn/keerthane/carol detail screens",
            "General stability and runtime bug fixes across startup and ticket-status handling"
        ]
    )
    
    init() {
        setupGlobalAppearances()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let decision = forceUpdate, decision.requiresUpdate {
                    ForceUpdateView(message: decision.message, storeURL: decision.iosStoreURL)
                        .preferredColorScheme(themeManager.colorScheme)
                } else {
                    RootTabView()
                        .preferredColorScheme(themeManager.colorScheme)
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
                        .onAppear {
                            checkOnboardingOrChangelog()
                            requestPushPermissionIfNeeded()
                        }
                }
            }
            .task {
                await waitForSupabaseInitialization()
                forceUpdate = await ForceUpdateService.shared.getDecision()
                await CastService.shared.initializeIfEnabled()
                await PageFlipVisibilityService.shared.refresh()
                try? await ChristmasCarolsService.shared.fetchParishCarols(forceGitHub: true)
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
        guard !hasRequestedPushPermission else { return }
        hasRequestedPushPermission = true
        
        #if canImport(OneSignalFramework)
        OneSignal.Notifications.requestPermission({ accepted in
            print("OneSignal: Push permission accepted: \(accepted)")
        }, fallbackToSettings: false)
        #endif
    }
}
