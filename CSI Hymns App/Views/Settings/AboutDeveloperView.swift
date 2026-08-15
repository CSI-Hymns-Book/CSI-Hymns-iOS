import SwiftUI

/// A premium, glassmorphic developer biography and credits panel.
public struct AboutDeveloperView: View {
    @Environment(\.openURL) private var openURL
    @State private var theme = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Adaptive theme background
            theme.backgroundColor
                .ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient
                    .ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile avatar block
                    developerHeader
                    
                    // App details Card
                    appMissionCard
                    
                    // Direct links buttons
                    actionLinksList
                    
                    // Version Footer
                    footerCredits
                }
                .padding(20)
            }
        }
        .navigationTitle("About Developer")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Subviews
    
    private var developerHeader: some View {
        VStack(spacing: 16) {
            Image("developer_pfp")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.cardStroke, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            
            VStack(spacing: 4) {
                Text("Reynold")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Text("Full-Stack Developer | Cyber Security Enthusiast")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.top, 10)
    }
    
    private var appMissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Image("app_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
            }
            
            Text("CSI Hymns Mission")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text("CSI Hymns is a complete feature-parity native migration built to preserve the rich heritage of traditional hymns and keerthanes for Christian congregations worldwide. The project combines state-of-the-art SwiftUI aesthetics, real-time Jira bug support, and bilingual translations to deliver a premium devotional experience.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .lineSpacing(6)
        }
        .padding(18)
        .background(theme.cardBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardStroke, lineWidth: 1))
    }
    
    private var actionLinksList: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: PrivacyPolicyView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1))
                        
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color.green)
                            .font(.system(size: 16, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("View Privacy Policy")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                        
                        Text("Required for Google/Apple OAuth screens")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.textSecondary.opacity(0.5))
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(12)
                .background(theme.cardBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardStroke, lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            
            linkRow(
                title: "Report an Issue",
                subtitle: "Email support directly for lyric corrections",
                icon: "envelope.fill",
                url: "mailto:reynoldclare02@gmail.com",
                iconColor: Color.orange
            )
            
            linkRow(
                title: "GitHub Repository",
                subtitle: "Browse project files & audio hosts",
                icon: "terminal.fill",
                url: "https://github.com/reynold29/midi-files",
                iconColor: Color.purple
            )
        }
    }
    
    private func linkRow(title: String, subtitle: String, icon: String, url: String, iconColor: Color) -> some View {
        Button {
            if let uri = URL(string: url) {
                openURL(uri)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(iconColor.opacity(0.25), lineWidth: 1))
                    
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 16, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                
                Image(systemName: "arrow.up.forward")
                    .foregroundColor(theme.textSecondary.opacity(0.5))
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(12)
            .background(theme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var footerCredits: some View {
        VStack(spacing: 6) {
            Text("CSI Hymns v4.2.2-stable")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(theme.textSecondary.opacity(0.6))
            
            Text("Made with ❤️ in Bengaluru, India")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary.opacity(0.4))
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}
