import SwiftUI

/// About App screen with 8-tap sudo unlock (Android `AboutAppScreen` parity).
public struct AboutAppView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeManager.shared
    @State private var tapCount = 0
    @State private var showPasscodeDialog = false
    @State private var passcodeText = ""
    @State private var passcodeError = false
    @State private var isVerifying = false
    @State private var showSudoToast = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Image("app_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        Spacer()
                    }
                    .padding(.bottom, 36)
                    
                    Text("CSI Hymns Book")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .onTapGesture {
                            tapCount += 1
                            if tapCount >= 8 {
                                tapCount = 0
                                passcodeText = ""
                                passcodeError = false
                                showPasscodeDialog = true
                            }
                        }
                    
                    Text("A Kannada CSI Hymns and Keerthane Lyrics Book, with modern minimal UI and functionalities.")
                        .font(.system(size: 15))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 8)
                    
                    Divider().padding(.vertical, 22)
                    
                    Button {
                        openURL(URL(string: "https://t.me/Reynold29")!)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Developed By")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                            Text("Reynold (@Reynold29)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Text("Contribute")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.top, 28)
                    
                    Text("This app is Open Source! Contribute to the project's code and let's enhance it!")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 6)
                    
                    HStack(spacing: 8) {
                        linkChip(title: "GitHub", url: "https://github.com/Reynold29/CSI-Hymns-and-Lyrics/")
                        linkChip(title: "App Store", url: "https://apps.apple.com/in/app/csi-hymns/id6759990066")
                    }
                    .padding(.top, 14)
                    
                    Divider().padding(.vertical, 22)
                    
                    Text("Support")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text("Get Support Here and also find out how we Prioritize User Privacy and Data!")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 6)
                    
                    HStack(spacing: 8) {
                        linkChip(title: "Telegram", url: "https://t.me/Reynold29")
                        NavigationLink(destination: LegalDocumentView(kind: .privacy)) {
                            Text("Privacy Policy")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(theme.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.cardStroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 12)
                    
                    if AdminPrefs.isSudoAdminEnabled {
                        Button(role: .destructive) {
                            AdminPrefs.isSudoAdminEnabled = false
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                        } label: {
                            Text("Exit Sudo Admin Mode")
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .padding(.top, 28)
                    }
                    
                    Text(appVersionLabel)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                }
                .padding(20)
            }
            
            if showSudoToast {
                VStack {
                    Spacer()
                    Text("Sudo Root Admin Mode Activated!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("About This App")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
        .alert("Root Admin Authentication", isPresented: $showPasscodeDialog) {
            SecureField("Passcode", text: $passcodeText)
            Button("Cancel", role: .cancel) {}
            Button("Authorize") {
                Task { await authorizeSudo() }
            }
        } message: {
            Text(passcodeError
                 ? "Invalid Passcode!"
                 : "Enter the Sudo Master Passcode to unlock Root Admin rights on this device.")
        }
    }
    
    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "5.1.0"
        return "CSI Hymns v\(version)"
    }
    
    private func linkChip(title: String, url: String) -> some View {
        Button {
            if let uri = URL(string: url) { openURL(uri) }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func authorizeSudo() async {
        isVerifying = true
        let ok = await AdminPrefs.verifyPasscode(passcodeText)
        await MainActor.run {
            isVerifying = false
            if ok {
                AdminPrefs.isSudoAdminEnabled = true
                showPasscodeDialog = false
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation { showSudoToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { showSudoToast = false }
                    dismiss()
                }
            } else {
                passcodeError = true
                showPasscodeDialog = true
            }
        }
    }
}
