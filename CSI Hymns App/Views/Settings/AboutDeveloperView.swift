import SwiftUI

/// A premium, glassmorphic developer biography and credits panel.
public struct AboutDeveloperView: View {
    @Environment(\.openURL) private var openURL
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Immersive dark gradient
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
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
    }
    
    // MARK: - Subviews
    
    private var developerHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 110, height: 110)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                
                Text("👨‍💻")
                    .font(.system(size: 58))
            }
            
            VStack(spacing: 4) {
                Text("Reynold")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Staff iOS Engineer & Architect")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.top, 10)
    }
    
    private var appMissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CSI Hymns Mission")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text("CSI Hymns is a complete feature-parity native migration built to preserve the rich heritage of traditional hymns and keerthanes for Christian congregations worldwide. The project combines state-of-the-art SwiftUI aesthetics, real-time Jira bug support, and bilingual translations to deliver an premium devotional experience.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(6)
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var actionLinksList: some View {
        VStack(spacing: 12) {
            linkRow(
                title: "View Privacy Policy",
                subtitle: "Required for Google/Apple OAuth screens",
                icon: "shield.text.case.fill",
                url: "https://sites.google.com/view/csi-hymns-privacy-policy/home"
            )
            
            linkRow(
                title: "GitHub Repository",
                subtitle: "Browse project files & audio hosts",
                icon: "code.branch",
                url: "https://github.com/reynold29/midi-files"
            )
        }
    }
    
    private func linkRow(title: String, subtitle: String, icon: String, url: String) -> some View {
        Button {
            if let uri = URL(string: url) {
                openURL(uri)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                
                Image(systemName: "arrow.up.forward")
                    .foregroundColor(.white.opacity(0.3))
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var footerCredits: some View {
        VStack(spacing: 6) {
            Text("CSI Hymns v4.2.2-stable")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
            
            Text("Made with ❤️ in Bengaluru, India")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}
