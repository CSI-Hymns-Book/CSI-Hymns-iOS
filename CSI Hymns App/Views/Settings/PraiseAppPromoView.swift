import SwiftUI

/// App Store promotion for Worship Companion + (related devotions app).
public struct PraiseAppPromoView: View {
    @Environment(\.openURL) private var openURL
    @State private var theme = ThemeManager.shared
    
    private static let appStoreURL = URL(string: "https://apps.apple.com/in/app/worship-companion/id6759990066")!
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor
                .ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient
                    .ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 28) {
                    appPromoHeroCard
                    featuresOutline
                    downloadStoreButton
                }
                .padding(24)
            }
        }
        .navigationTitle("Worship Companion +")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.secondaryBackgroundColor, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private var appPromoHeroCard: some View {
        VStack(spacing: 16) {
            Image("praise_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.strokeColor, lineWidth: 1)
                )
            
            VStack(spacing: 6) {
                Text("Worship Companion +")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(theme.textPrimary)
                
                Text("Your all-in-one praise and worship lyrics app")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 16)
    }
    
    private var featuresOutline: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Why Download Worship Companion +?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 14) {
                featureItemRow(
                    title: "Offline song library",
                    description: "Access a wide collection of praise and worship songs even without internet.",
                    emoji: "📖"
                )
                
                featureItemRow(
                    title: "Smart custom folders",
                    description: "Organize setlists and share worship folders with your parish.",
                    emoji: "📁"
                )
                
                featureItemRow(
                    title: "Lyrics from images",
                    description: "Convert scanned or photographed text into editable worship lyrics on device.",
                    emoji: "📷"
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
            openURL(Self.appStoreURL)
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
