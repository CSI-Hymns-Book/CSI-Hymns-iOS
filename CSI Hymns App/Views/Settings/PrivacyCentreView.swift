import SwiftUI

/// Review, withdraw, or change optional processing — comparable ease to original consent.
public struct PrivacyCentreView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var theme = ThemeManager.shared
    @State private var consent = ConsentManager.shared
    @State private var supabase = SupabaseService.instance
    @State private var showWithdrawConfirm = false
    @State private var showPushDeclineDialog = false
    @State private var osPushGranted = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            List {
                Section {
                    LabeledContent("Policy version") {
                        Text(consent.acceptedVersion ?? "—")
                            .foregroundColor(theme.textSecondary)
                    }
                    LabeledContent("Recorded") {
                        Text(consent.recordedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short) } ?? "—")
                            .foregroundColor(theme.textSecondary)
                    }
                } header: {
                    Text("Consent record").foregroundColor(theme.textSecondary)
                } footer: {
                    Text("This record is stored on your device and, if you are signed in, on your profile in India.")
                        .foregroundColor(theme.textSecondary)
                }
                .listRowBackground(theme.cardBackground)
                
                Section {
                    NavigationLink(destination: LegalDocumentView(kind: .privacy)) {
                        settingsLabel("Privacy Policy", "hand.raised")
                    }
                    NavigationLink(destination: LegalDocumentView(kind: .terms)) {
                        settingsLabel("Terms of Use", "doc.text")
                    }
                }
                .listRowBackground(theme.cardBackground)
                
                Section {
                    Toggle(isOn: analyticsBinding) {
                        settingsLabel("Product analytics", "chart.bar")
                    }
                    .tint(theme.accentColor)
                    Toggle(isOn: pushBinding) {
                        settingsLabel("Push notifications", "bell")
                    }
                    .tint(theme.accentColor)
                } header: {
                    Text("Optional processing").foregroundColor(theme.textSecondary)
                } footer: {
                    Text("These help us improve the app. You can turn them off any time. Hymn reading still works.")
                        .foregroundColor(theme.textSecondary)
                }
                .listRowBackground(theme.cardBackground)
                
                Section {
                    if supabase.isAuthenticated {
                        NavigationLink(destination: ProfileEditView()) {
                            settingsLabel("Download or deactivate account", "person.crop.circle")
                        }
                    }
                    Button {
                        if let url = URL(string: "mailto:\(ConsentManager.grievanceEmail)?subject=DPDP%20rights%20request") {
                            openURL(url)
                        }
                    } label: {
                        settingsLabel("Request access, correction, or erasure", "envelope")
                    }
                    Button {
                        if let url = URL(string: "https://www.meity.gov.in/") {
                            openURL(url)
                        }
                    } label: {
                        settingsLabel("MeitY / Data Protection Board", "building.columns")
                    }
                } header: {
                    Text("Your rights").foregroundColor(theme.textSecondary)
                } footer: {
                    Text("Grievance contact: \(ConsentManager.grievanceEmail). You may also complain to the Data Protection Board of India.")
                        .foregroundColor(theme.textSecondary)
                }
                .listRowBackground(theme.cardBackground)
                
                Section {
                    Button(role: .destructive) {
                        showWithdrawConfirm = true
                    } label: {
                        Text("Withdraw consent")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("This stops optional analytics and notifications immediately, signs you out, and shows the privacy notice again. Bundled hymns stay on the device after you accept a current notice.")
                        .foregroundColor(theme.textSecondary)
                }
                .listRowBackground(Color.red.opacity(0.12))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Privacy Centre")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
        .alert("Withdraw consent?", isPresented: $showWithdrawConfirm) {
            Button("Withdraw", role: .destructive) {
                consent.withdrawRequiredConsent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be signed out and asked to review the notice again. Optional analytics and notifications stop immediately.")
        }
        .alert("Keep notifications on?", isPresented: $showPushDeclineDialog) {
            Button("Keep on", role: .cancel) {}
            Button("Turn off", role: .destructive) {
                consent.setPushConsent(false)
                osPushGranted = false
            }
        } message: {
            Text("Notifications are important — they help keep you updated. We do not send unwanted content.")
        }
        .task { await refreshPushFromSystem() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshPushFromSystem() }
            }
        }
    }
    
    private var analyticsBinding: Binding<Bool> {
        Binding(
            get: { consent.analyticsConsent },
            set: { consent.setAnalyticsConsent($0) }
        )
    }
    
    private var pushBinding: Binding<Bool> {
        Binding(
            get: { consent.pushConsent && osPushGranted },
            set: { enabled in
                if enabled {
                    Task {
                        let granted = await consent.requestOsPushPermission()
                        osPushGranted = granted
                        if !granted {
                            showPushDeclineDialog = true
                        }
                    }
                } else {
                    showPushDeclineDialog = true
                }
            }
        )
    }
    
    private func refreshPushFromSystem() async {
        osPushGranted = await consent.hasOsNotificationPermission()
        await consent.syncPushConsentWithOsPermission()
        osPushGranted = await consent.hasOsNotificationPermission()
    }
    
    private func settingsLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .foregroundColor(theme.textPrimary)
    }
}
