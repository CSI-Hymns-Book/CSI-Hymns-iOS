import SwiftUI

/// Review, withdraw, or change optional processing — comparable ease to original consent.
public struct PrivacyCentreView: View {
    @Environment(\.openURL) private var openURL
    @State private var theme = ThemeManager.shared
    @State private var consent = ConsentManager.shared
    @State private var showWithdrawConfirm = false
    
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
                    Text("These are off unless you opt in. Turning them off does not remove hymn access.")
                        .foregroundColor(theme.textSecondary)
                }
                .listRowBackground(theme.cardBackground)
                
                Section {
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
    }
    
    private var analyticsBinding: Binding<Bool> {
        Binding(
            get: { consent.analyticsConsent },
            set: { consent.setAnalyticsConsent($0) }
        )
    }
    
    private var pushBinding: Binding<Bool> {
        Binding(
            get: { consent.pushConsent },
            set: { consent.setPushConsent($0) }
        )
    }
    
    private func settingsLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .foregroundColor(theme.textPrimary)
    }
}
