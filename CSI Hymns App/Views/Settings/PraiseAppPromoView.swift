import SwiftUI

/// A premium, App Store-styled promotion screen for the related "Praise App" devotions suite.
public struct PraiseAppPromoView: View {
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
                VStack(spacing: 28) {
                    // App Icon Card Hero
                    appPromoHeroCard
                    
                    // Features list
                    featuresOutline
                    
                    // Call to Action
                    downloadStoreButton
                }
                .padding(24)
            }
        }
        .navigationTitle("Related Devotions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.secondaryBackgroundColor, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Subviews
    
    private var appPromoHeroCard: some View {
        VStack(spacing: 16) {
            Image("praise_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(theme.strokeColor, lineWidth: 1)
                )
            
            VStack(spacing: 6) {
                Text("Praise App")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(theme.textPrimary)
                
                Text("The Ultimate Companion Devotions Suite")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.top, 16)
    }
    
    private var featuresOutline: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Why Download Praise App?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 14) {
                featureItemRow(
                    title: "Universal search index",
                    description: "Access thousands of additional vernacular and bilingual songs offline.",
                    emoji: "🔍"
                )
                
                featureItemRow(
                    title: "Smart custom folders",
                    description: "Share worship setlists directly with parish members instantly.",
                    emoji: "📁"
                )
                
                featureItemRow(
                    title: "Full audio accompaniments",
                    description: "Universal accompaniment tracks and instrumentals suitable for congregational play.",
                    emoji: "🎹"
                )
            }
        }
    }
    
    private func featureItemRow(title: String, description: String, emoji: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.surfaceColor)
                    .frame(width: 38, height: 38)
                
                Text(emoji)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .lineSpacing(4)
            }
            Spacer()
        }
        .padding(14)
        .background(theme.cardBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardStroke, lineWidth: 1))
    }
    
    private var downloadStoreButton: some View {
        Button {
            // Launches related devotions App Store direct search/download URI
            if let uri = URL(string: "https://apps.apple.com") {
                openURL(uri)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "applelogo")
                    .font(.system(size: 16))
                
                Text("Download on App Store")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(theme.selectedAccent.textPairing)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.accentColor)
            .cornerRadius(12)
            .shadow(color: theme.accentColor.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.top, 12)
    }
}
